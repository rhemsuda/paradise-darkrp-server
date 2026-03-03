if not SERVER then return end

-- Create the rp_debug ConVar (default to 0, replicate to clients)
CreateConVar("rp_debug", "0", FCVAR_REPLICATED + FCVAR_NOTIFY + FCVAR_ARCHIVE, "Enable debug prints for RP systems (0 = off, 1 = on)")

-- Helper function to print debug messages conditionally (set rp_debug 1 to see)
local function DebugPrint(...)
    local cv = GetConVar("rp_debug")
    if cv and cv:GetInt() == 1 then print(...) end
end

-- Initialize network strings
util.AddNetworkString("GhostTimerSync")
util.AddNetworkString("PlayGhostSound")
util.AddNetworkString("StopGhostSound")
util.AddNetworkString("PlaySpherePulseSound")
util.AddNetworkString("SphereSparkEffect")
util.AddNetworkString("PlaySphereBangSound")
util.AddNetworkString("StartSphereInteraction")
util.AddNetworkString("StopSphereInteraction")
util.AddNetworkString("RequestSphereInteraction")

-- Table to store player death data (ragdoll, timer, etc.)
local playerDeathData = {}

-- Expose so other modules (rpjobs, inventory, resources) can block ghost actions
function IsPlayerGhost(ply)
    if not IsValid(ply) then return false end
    return playerDeathData[ply] ~= nil
end

-- Table to store active light spheres
local lightSpheres = {}

-- Fallback coordinates when no Death Orb locations are set in admin settings
local spawnCoordinates = {
    Vector(654.717834, -602.373657, -93.968750),
    Vector(694.453613, 203.186691, -93.968750),
    Vector(100.0, 100.0, 0.0),
    Vector(-100.0, -100.0, 0.0),
    Vector(500.0, 0.0, 0.0),
}

-- Paradise.DeathOrbLocations (from admin Settings tab when set): { { pos = Vector(...), ang = Angle(...) }, ... }
-- If set, random orb spawns use these instead of spawnCoordinates.
Paradise = Paradise or {}
Paradise.DeathOrbLocations = Paradise.DeathOrbLocations or {}
Paradise.NPCSpawnLocations = Paradise.NPCSpawnLocations or {}

-- Hook into PlayerDeath to handle the death system
hook.Add("PlayerDeath", "CustomDeathSystem", function(ply, inflictor, attacker)
    if not IsValid(ply) then return end

    DebugPrint("[Death System] Player " .. ply:Nick() .. " died, initiating ghost mode.")

    -- Remove the ragdoll created by the base gamemode (DoPlayerDeath calls ply:CreateRagdoll()) so we only have one.
    local baseRagdoll = ply:GetRagdollEntity()
    if IsValid(baseRagdoll) then
        baseRagdoll:Remove()
    end

    -- Store the player's death position and angles
    local deathPos = ply:GetPos()
    local deathAng = ply:EyeAngles()

    -- Create a ragdoll at the player's death position
    local ragdoll = ents.Create("prop_ragdoll")
    if not IsValid(ragdoll) then
        DebugPrint("[Death System] Failed to create ragdoll for " .. ply:Nick())
        return
    end

    ragdoll:SetPos(deathPos)
    ragdoll:SetAngles(deathAng)
    ragdoll:SetModel(ply:GetModel())
    ragdoll:Spawn()
    ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS) -- Allows players to move the ragdoll
    ragdoll:PhysWake() -- Ensure the ragdoll's physics are active

    -- Copy the player's skin, bodygroups, and colors to the ragdoll
    ragdoll:SetSkin(ply:GetSkin())
    for i = 0, ply:GetNumBodyGroups() - 1 do
        ragdoll:SetBodygroup(i, ply:GetBodygroup(i))
    end
    ragdoll:SetColor(ply:GetColor())
    ragdoll:SetMaterial(ply:GetMaterial())

    -- Store the ragdoll and death position in the player's death data
    playerDeathData[ply] = {
        ragdoll = ragdoll,
        deathPos = deathPos,
        deathAng = deathAng,
        timerName = "GhostTimer_" .. ply:SteamID64(),
        duration = 300, -- 300 seconds (5 minutes)
        startTime = CurTime(), -- Record the start time for the timer
        messageSent = false, -- Flag to track if the message has been sent
        isDead = true, -- Mark the player as dead
        isInteracting = false, -- Track if the player is interacting with a sphere
        initialSpawnDone = false -- First spawn after death = ghost at spawn; later spawns = move ghost to spawn
    }

    -- Do not spawn here: let the player stay dead (camera at death) until they left-click.
    -- Base gamemode sets NextSpawnTime in PlayerDeath; when they press attack, PlayerDeathThink calls pl:Spawn().
    -- Our PlayerSpawn hook then runs and MakePlayerGhost(ply), so they become a ghost at spawn on first click.
    ply.NextSpawnTime = CurTime() -- Allow spawn as soon as they click (or use respawntime from GM:PlayerDeath if you want a delay)
end)

-- Function to turn a player into a ghost
function MakePlayerGhost(ply)
    if not IsValid(ply) then return end

    local deathData = playerDeathData[ply]
    if not deathData then return end

    DebugPrint("[Death System] Making " .. ply:Nick() .. " a ghost.")

    -- Ghost appearance and physics (position left as set by gamemode = spawn): barely visible, cannot block others, can be shot through
    ply:SetRenderMode(RENDERMODE_TRANSCOLOR)
    ply:SetColor(Color(255, 255, 255, 50)) -- Alpha 50 = very faint visibility

    ply:SetGravity(0.5)
    ply:StripWeapons()
    ply:GodEnable()
    ply:SetMoveType(MOVETYPE_FLY)
    ply:SetCollisionGroup(COLLISION_GROUP_NONE) -- No collision: ghost does not block players or block movement

    -- Mark the player as a ghost for client-side checks
    ply:SetNWBool("IsGhost", true)

    -- Notify the player only if the message hasn't been sent
    if not deathData.messageSent then
        ply:ChatPrint("You are now a ghost for 300 seconds. Press E while looking at a light sphere to reduce your timer by 120 seconds.")
        deathData.messageSent = true
    end

    -- Start the ghost timer (use remaining time from death so 300s is from death, not from spawn)
    local elapsed = CurTime() - deathData.startTime
    local remaining = math.max(0.1, deathData.duration - elapsed)
    DebugPrint("[Death System] Starting ghost timer for " .. ply:Nick() .. " (" .. remaining .. "s remaining)")
    timer.Create(deathData.timerName, remaining, 1, function()
        if not IsValid(ply) then return end
        EndGhostMode(ply)
    end)

    -- Send the timer data to the client
    DebugPrint("[Death System] Sending GhostTimerSync to " .. ply:Nick())
    net.Start("GhostTimerSync")
    net.WriteBool(true) -- Indicate the player is in ghost mode
    net.WriteFloat(deathData.startTime)
    net.WriteFloat(deathData.duration)
    net.Send(ply)

    -- Play the ambient ghost sound
    net.Start("PlayGhostSound")
    net.Send(ply)
end

-- Function to end ghost mode and respawn the player normally
function EndGhostMode(ply)
    if not IsValid(ply) then return end

    local deathData = playerDeathData[ply]
    if not deathData then return end

    DebugPrint("[Death System] Ending ghost mode for " .. ply:Nick())

    -- Stop any ongoing interaction
    if deathData.isInteracting then
        deathData.isInteracting = false
        DebugPrint("[Death System] Sending StopSphereInteraction to " .. ply:Nick() .. " (EndGhostMode)")
        net.Start("StopSphereInteraction")
        net.Send(ply)
    end

    -- Remove the ragdoll
    if deathData and IsValid(deathData.ragdoll) then
        deathData.ragdoll:Remove()
    end

    -- Clear the player's death data
    playerDeathData[ply] = nil

    -- Reset the player's properties
    ply:SetRenderMode(RENDERMODE_NORMAL)
    ply:SetColor(Color(255, 255, 255, 255)) -- Fully opaque
    ply:SetGravity(1.0) -- Normal gravity
    ply:GodDisable() -- Allow the player to take damage again
    ply:SetMoveType(MOVETYPE_WALK)
    ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
    ply:SetNWBool("IsGhost", false)

    -- Respawn the player at their death position
    ply:Spawn()
    ply:SetPos(deathData.deathPos)
    ply:SetEyeAngles(deathData.deathAng)

    -- Notify the client to stop the timer and screen effect
    net.Start("GhostTimerSync")
    net.WriteBool(false) -- Indicate the player is no longer in ghost mode
    net.WriteFloat(0)
    net.WriteFloat(0)
    net.Send(ply)

    -- Stop the ambient ghost sound
    net.Start("StopGhostSound")
    net.Send(ply)
end

-- Clean up when a player disconnects
hook.Add("PlayerDisconnected", "CleanupDeathSystem", function(ply)
    if playerDeathData[ply] then
        if IsValid(playerDeathData[ply].ragdoll) then
            playerDeathData[ply].ragdoll:Remove()
        end
        timer.Remove(playerDeathData[ply].timerName)
        playerDeathData[ply] = nil

        -- Notify the client to stop the timer and screen effect
        net.Start("GhostTimerSync")
        net.WriteBool(false)
        net.WriteFloat(0)
        net.WriteFloat(0)
        net.Send(ply)

        -- Stop the ambient ghost sound
        net.Start("StopGhostSound")
        net.Send(ply)
    end
end)

-- Prevent ghosts from picking up weapons or interacting with the world
hook.Add("PlayerCanPickupWeapon", "PreventGhostPickup", function(ply, weapon)
    if playerDeathData[ply] then
        return false -- Ghosts can't pick up weapons
    end
end)

-- Prevent ghosts from using entities (except light spheres)
hook.Add("PlayerUse", "PreventGhostUse", function(ply, ent)
    if playerDeathData[ply] then
        return false -- Ghosts can't use entities (we'll handle interaction via client request)
    end
end)

-- Handle interaction request from the client
net.Receive("RequestSphereInteraction", function(len, ply)
    local startInteraction = net.ReadBool()
    local sphereEntIndex = net.ReadInt(32)

    if not playerDeathData[ply] or not playerDeathData[ply].isDead then
        DebugPrint("[Death System] Player " .. ply:Nick() .. " is not in ghost mode or not dead")
        return
    end

    local deathData = playerDeathData[ply]

    if startInteraction then
        if deathData.isInteracting then
            DebugPrint("[Death System] Player " .. ply:Nick() .. " is already interacting with a sphere")
            return
        end

        local ent = Entity(sphereEntIndex)
        if not IsValid(ent) or ent:GetClass() ~= "light_sphere" then
            DebugPrint("[Death System] Invalid light sphere entity (EntIndex=" .. sphereEntIndex .. ")")
            return
        end

        -- Check distance (must be within 100 units)
        local distance = ply:GetPos():Distance(ent:GetPos())
        if distance > 100 then
            DebugPrint("[Death System] Player " .. ply:Nick() .. " is too far from the light sphere (distance=" .. distance .. ")")
            return
        end

        deathData.isInteracting = true

        DebugPrint("[Death System] " .. ply:Nick() .. " started interacting with light sphere (EntIndex=" .. ent:EntIndex() .. ") at distance " .. distance)

        -- Notify the client to start the loading bar and sound
        net.Start("StartSphereInteraction")
        net.Send(ply)

        -- Start a 3-second timer for the interaction
        timer.Create("SphereInteraction_" .. ply:SteamID64(), 3, 1, function()
            if not IsValid(ply) or not IsValid(ent) or not deathData.isDead then
                if IsValid(ply) then
                    deathData.isInteracting = false
                    DebugPrint("[Death System] Sending StopSphereInteraction to " .. ply:Nick() .. " (Timer Invalid)")
                    net.Start("StopSphereInteraction")
                    net.Send(ply)
                end
                return
            end

            -- Reduce the timer
            local elapsed = CurTime() - deathData.startTime
            local remaining = math.max(0, deathData.duration - elapsed)
            local reduction = ent.TimerReduction or 120
            local newRemaining = math.max(0, remaining - reduction)

            DebugPrint("[Death System] Interaction complete for " .. ply:Nick() .. ". Timer values: elapsed=" .. elapsed .. ", remaining=" .. remaining .. ", reduction=" .. reduction .. ", newRemaining=" .. newRemaining)

            -- Update the deathData before adjusting the timer
            deathData.startTime = CurTime()
            deathData.duration = newRemaining
            deathData.isInteracting = false

            if newRemaining <= 0 then
                DebugPrint("[Death System] Timer reduced to 0, ending ghost mode for " .. ply:Nick())
                EndGhostMode(ply)
            else
                if timer.Exists(deathData.timerName) then
                    timer.Adjust(deathData.timerName, newRemaining, 1, function()
                        if not IsValid(ply) then return end
                        EndGhostMode(ply)
                    end)
                    DebugPrint("[Death System] Adjusted timer for " .. ply:Nick() .. " to " .. newRemaining .. " seconds")
                else
                    DebugPrint("[Death System] Timer " .. deathData.timerName .. " no longer exists, ending ghost mode for " .. ply:Nick())
                    EndGhostMode(ply)
                end

                -- Update the client with the new timer data
                net.Start("GhostTimerSync")
                net.WriteBool(true)
                net.WriteFloat(deathData.startTime)
                net.WriteFloat(deathData.duration)
                net.Send(ply)
            end

            -- Play the bang sound for all ghosts
            for ghost, _ in pairs(playerDeathData) do
                if IsValid(ghost) then
                    net.Start("PlaySphereBangSound")
                    net.WriteVector(ent:GetPos())
                    net.Send(ghost)
                end
            end

            -- Remove the sphere
            lightSpheres[ent] = nil
            ent:Remove()
            ply:ChatPrint("You interacted with a light sphere, reducing your ghost timer by 120 seconds!")

            -- Ensure the client stops the interaction
            DebugPrint("[Death System] Sending StopSphereInteraction to " .. ply:Nick() .. " (Interaction Complete)")
            net.Start("StopSphereInteraction")
            net.Send(ply)
        end)
    else
        -- Stop interaction (player released E)
        if not deathData.isInteracting then return end

        deathData.isInteracting = false
        timer.Remove("SphereInteraction_" .. ply:SteamID64())
        DebugPrint("[Death System] Sending StopSphereInteraction to " .. ply:Nick() .. " (Player Released E)")
        net.Start("StopSphereInteraction")
        net.Send(ply)
        DebugPrint("[Death System] " .. ply:Nick() .. " stopped interacting with light sphere (EntIndex=" .. sphereEntIndex .. ")")
    end
end)

-- Ensure ghosts don't take damage and bullets pass through
hook.Add("EntityTakeDamage", "PreventGhostDamage", function(target, dmginfo)
    if target:IsPlayer() and playerDeathData[target] then
        dmginfo:SetDamage(0) -- Set damage to 0 to ensure bullets pass through
        return true -- Prevent damage to ghosts
    end
end)

-- Notify players when they spawn if they're still in ghost mode
hook.Add("PlayerSpawn", "CheckGhostMode", function(ply)
    if not playerDeathData[ply] then return end
    local deathData = playerDeathData[ply]
    deathData.messageSent = true -- Ensure the message isn't sent again

    -- First spawn after death: ghost at spawn (gamemode already set position); just apply ghost state.
    if not deathData.initialSpawnDone then
        deathData.initialSpawnDone = true
        MakePlayerGhost(ply)
        return
    end

    -- Already a ghost and spawn was triggered again (e.g. respawn at base): move ghost to spawn point
    local spawnPos
    if GAMEMODE and GAMEMODE.PlayerSelectSpawn then
        local sp = GAMEMODE:PlayerSelectSpawn(ply)
        if IsValid(sp) then spawnPos = sp:GetPos() end
    end
    if not spawnPos and Paradise.DeathOrbLocations and #Paradise.DeathOrbLocations > 0 then
        local loc = Paradise.DeathOrbLocations[math.random(1, #Paradise.DeathOrbLocations)]
        spawnPos = isvector(loc) and loc or (loc and loc.pos)
    end
    if not spawnPos and spawnCoordinates and #spawnCoordinates > 0 then
        spawnPos = spawnCoordinates[math.random(1, #spawnCoordinates)]
    end
    if spawnPos then
        ply:SetPos(spawnPos + Vector(0, 0, 10))
    end
    -- Make them "alive" (full health) so spawn logic and other systems see a valid state, then keep ghost
    ply:SetHealth(ply:GetMaxHealth())
    ply:SetArmor(0)
    -- Reapply ghost appearance/state (position was set above)
    ply:SetRenderMode(RENDERMODE_TRANSCOLOR)
    ply:SetColor(Color(255, 255, 255, 50))
    ply:SetGravity(0.5)
    ply:StripWeapons()
    ply:GodEnable()
    ply:SetMoveType(MOVETYPE_FLY)
    ply:SetCollisionGroup(COLLISION_GROUP_NONE)
    ply:SetNWBool("IsGhost", true)
end)

-- Block menu access for all ghosts (no exceptions: dead = no Q menu, no job change, etc.)
hook.Add("PlayerBindPress", "PreventGhostMenus", function(ply, bind, pressed)
    if not playerDeathData[ply] then return end
    if bind == "impulse 100" or bind == "+menu" or bind == "+menu_context" then
        return true
    end
end)

-- Prevent ghosts from spawning any props/entities
hook.Add("PlayerSpawnProp", "PreventGhostSpawnProp", function(ply, model)
    if playerDeathData[ply] then return false end
end)
hook.Add("PlayerSpawnObject", "PreventGhostSpawnObject", function(ply)
    if playerDeathData[ply] then return false end
end)

-- Prevent ghosts from dropping weapons
hook.Add("canDropWeapon", "PreventGhostDropWeapon", function(gm, ply, weapon)
    if playerDeathData[ply] then return false end
end)

-- Dead users can never kill themselves again (no setting; always blocked)
hook.Add("CanPlayerSuicide", "PreventGhostSuicide", function(ply)
    if not IsPlayerGhost(ply) then return end
    DarkRP.notify(ply, 1, 4, "You cannot suicide while dead!")
    return false
end)

-- Function to spawn a light sphere at a specific position
local function SpawnLightSphereAtPos(pos)
    local sphere = ents.Create("light_sphere")
    if not IsValid(sphere) then
        DebugPrint("[Death System] Failed to spawn light sphere at " .. tostring(pos))
        return
    end

    sphere:SetPos(pos)
    sphere:Spawn()

    -- Store the sphere in the lightSpheres table
    lightSpheres[sphere] = true

    DebugPrint("[Death System] Added sphere (EntIndex=" .. sphere:EntIndex() .. ") to lightSpheres table at " .. tostring(pos))
end

-- Function to spawn a light sphere at the player's cursor position
local function SpawnLightSphere(ply)
    if not IsValid(ply) then return end

    -- Use a trace to find where the player is aiming
    local eyePos = ply:EyePos()
    local trace = ply:GetEyeTrace()
    if not trace.Hit then
        ply:ChatPrint("Cannot spawn light sphere: No surface found in aim direction!")
        return
    end

    -- Debug print for the trace hit position
    DebugPrint("[Death System] Trace hit position for " .. ply:Nick() .. ": " .. tostring(trace.HitPos))

    -- Calculate the spawn position
    local hitPos = trace.HitPos
    local plyPos = ply:GetPos()
    local direction = (hitPos - plyPos):GetNormalized()
    local distance = plyPos:Distance(hitPos)

    -- Ensure the sphere spawns at least 200 units away from the player
    if distance < 200 then
        hitPos = plyPos + direction * 200
        -- Adjust the height to ensure it spawns above the ground
        local groundTrace = util.TraceLine({
            start = hitPos + Vector(0, 0, 50),
            endpos = hitPos - Vector(0, 0, 1000),
            filter = ply
        })
        if groundTrace.Hit then
            hitPos = groundTrace.HitPos
        end
    end

    -- Spawn the sphere 50 units above the hit position
    local spawnPos = hitPos + Vector(0, 0, 50)

    -- Debug print for the final spawn position
    DebugPrint("[Death System] Final spawn position for " .. ply:Nick() .. ": " .. tostring(spawnPos))

    SpawnLightSphereAtPos(spawnPos)

    ply:ChatPrint("Spawned a light sphere at your cursor position. Press E while looking at it as a ghost to reduce your timer by 120 seconds.")
end

-- Timer to randomly spawn light spheres
timer.Create("RandomLightSphereSpawn", 60, 0, function()
    -- Check if there are any ghosts
    local hasGhosts = false
    for ply, data in pairs(playerDeathData) do
        if IsValid(ply) and data.isDead then
            hasGhosts = true
            break
        end
    end

    if not hasGhosts then
        DebugPrint("[Death System] No ghosts present, skipping random light sphere spawn.")
        return
    end

    -- 1/15 chance to spawn a light sphere
    if math.random(1, 15) == 1 then
        local spawnPos
        if Paradise.DeathOrbLocations and #Paradise.DeathOrbLocations > 0 then
            local loc = Paradise.DeathOrbLocations[math.random(1, #Paradise.DeathOrbLocations)]
            spawnPos = isvector(loc) and loc or (loc.pos or loc)
        end
        if not spawnPos then
            spawnPos = spawnCoordinates[math.random(1, #spawnCoordinates)]
        end
        SpawnLightSphereAtPos(spawnPos)
        DebugPrint("[Death System] Randomly spawned a light sphere at " .. tostring(spawnPos))
    else
        DebugPrint("[Death System] Random light sphere spawn chance failed (1/15).")
    end
end)

-- Console command to spawn a sphere of light (for testing)
concommand.Add("spawn_light_sphere", function(ply)
    DebugPrint("[Death System] spawn_light_sphere command executed by " .. (IsValid(ply) and ply:Nick() or "Console"))
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("Admin only!") end
        return
    end

    SpawnLightSphere(ply)
end)

-- Chat command to spawn a sphere of light (e.g., !spawnlightsphere)
hook.Add("PlayerSay", "SpawnLightSphereChatCommand", function(ply, text)
    if string.lower(text) == "!spawnlightsphere" then
        DebugPrint("[Death System] !spawnlightsphere chat command executed by " .. ply:Nick())
        if not ply:IsAdmin() then
            ply:ChatPrint("Admin only!")
            return ""
        end

        SpawnLightSphere(ply)
        return "" -- Suppress the chat message
    end
end)

-- Block rp_loadout command for non-admin ghosts
hook.Add("PlayerSay", "BlockGhostLoadoutCommand", function(ply, text)
    if string.lower(text) == "!rp_loadout" or string.lower(text) == "/rp_loadout" then
        if playerDeathData[ply] and not ply:IsAdmin() then
            ply:ChatPrint("You cannot access the loadout menu while in ghost mode!")
            return "" -- Suppress the chat message
        end
    end
end)

-- Test command to confirm the file is loaded
concommand.Add("test_deathsystem", function()
    DebugPrint("[Death System] Test command executed successfully.")
end)

-- Command to check if a player is dead
concommand.Add("check_dead", function(ply)
    if not IsValid(ply) then
        DebugPrint("[Death System] check_dead command executed by Console")
        return
    end
    if playerDeathData[ply] and playerDeathData[ply].isDead then
        ply:ChatPrint("You are currently dead and in ghost mode.")
    else
        ply:ChatPrint("You are not dead.")
    end
end)

-- Command to respawn a dead player (rp_respawn <name|steamID>)
concommand.Add("rp_respawn", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("Admin only!") end
        return
    end

    local identifier = args[1]
    if not identifier then
        ply:ChatPrint("Usage: rp_respawn <name|SteamID>")
        return
    end

    local target = nil
    -- First, try to match by SteamID
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == identifier then
            target = p
            break
        end
    end

    -- If no match by SteamID, try partial name match
    if not target then
        local lowerIdentifier = string.lower(identifier)
        local matches = {}
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), lowerIdentifier, 1, true) then
                table.insert(matches, p)
            end
        end

        if #matches == 1 then
            target = matches[1]
        elseif #matches > 1 then
            ply:ChatPrint("Multiple players found matching '" .. identifier .. "':")
            for _, p in ipairs(matches) do
                ply:ChatPrint("- " .. p:Nick() .. " (" .. p:SteamID() .. ")")
            end
            ply:ChatPrint("Please use a more specific name or the SteamID.")
            return
        end
    end

    if not IsValid(target) then
        ply:ChatPrint("Player with name or SteamID '" .. identifier .. "' not found!")
        return
    end

    if not playerDeathData[target] or not playerDeathData[target].isDead then
        ply:ChatPrint("Player " .. target:Nick() .. " is not dead!")
        return
    end

    DebugPrint("[Death System] Admin " .. ply:Nick() .. " is respawning " .. target:Nick())
    EndGhostMode(target)
    ply:ChatPrint("Successfully respawned " .. target:Nick() .. " (" .. target:SteamID() .. ").")
    target:ChatPrint("You have been respawned by an admin.")
end)

-- Hook for admin modules to silently respawn a dead player (returns true if respawned)
hook.Add("AdminRequestRespawn", "DeathSystem_RespawnTarget", function(target)
    if not IsValid(target) then return false end
    if not playerDeathData[target] or not playerDeathData[target].isDead then return false end
    EndGhostMode(target)
    return true
end)

-- Load confirmation only when rp_debug 1
DebugPrint("[Death System] Loaded successfully (Server).")