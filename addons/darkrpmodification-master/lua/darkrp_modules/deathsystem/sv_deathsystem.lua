-- Debug print to confirm the file is loading
print("[Death System] sv_deathsystem.lua is loading...")

if not SERVER then return end

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

-- Table to store active light spheres
local lightSpheres = {}

-- Table of predefined coordinates for random light sphere spawns
local spawnCoordinates = {
    Vector(654.717834, -602.373657, -93.968750), -- Example coordinate 1
    Vector(694.453613, 203.186691, -93.968750),  -- Example coordinate 2
    Vector(100.0, 100.0, 0.0),                   -- Example coordinate 3
    Vector(-100.0, -100.0, 0.0),                 -- Example coordinate 4
    Vector(500.0, 0.0, 0.0),                     -- Example coordinate 5
    -- Add more coordinates as needed
}

-- Hook into PlayerDeath to handle the death system
hook.Add("PlayerDeath", "CustomDeathSystem", function(ply, inflictor, attacker)
    if not IsValid(ply) then return end

    print("[Death System] Player " .. ply:Nick() .. " died, initiating ghost mode.")

    -- Store the player's death position and angles
    local deathPos = ply:GetPos()
    local deathAng = ply:EyeAngles()

    -- Create a ragdoll at the player's death position
    local ragdoll = ents.Create("prop_ragdoll")
    if not IsValid(ragdoll) then
        print("[Death System] Failed to create ragdoll for " .. ply:Nick())
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
        isInteracting = false -- Track if the player is interacting with a sphere
    }

    -- Respawn the player immediately as a ghost at their death position
    ply:Spawn()
    MakePlayerGhost(ply)
end)

-- Function to turn a player into a ghost
function MakePlayerGhost(ply)
    if not IsValid(ply) then return end

    local deathData = playerDeathData[ply]
    if not deathData then return end

    print("[Death System] Making " .. ply:Nick() .. " a ghost.")

    -- Set the player's position to their death position
    ply:SetPos(deathData.deathPos + Vector(0, 0, 50)) -- Slightly above the ragdoll to avoid clipping
    ply:SetEyeAngles(deathData.deathAng)

    -- Make the player almost invisible (alpha 50 for faint visibility)
    ply:SetRenderMode(RENDERMODE_TRANSCOLOR)
    ply:SetColor(Color(255, 255, 255, 50)) -- Alpha of 50 for very faint visibility

    -- Lower the player's gravity (50% of normal)
    ply:SetGravity(0.5)

    -- Strip weapons to prevent interaction
    ply:StripWeapons()

    -- Prevent the player from taking damage
    ply:GodEnable()

    -- Set the player to a move type that allows ghost-like movement
    ply:SetMoveType(MOVETYPE_FLY)
    ply:SetCollisionGroup(COLLISION_GROUP_NONE) -- Use COLLISION_GROUP_NONE to avoid collision issues

    -- Mark the player as a ghost for client-side checks
    ply:SetNWBool("IsGhost", true)

    -- Notify the player only if the message hasn't been sent
    if not deathData.messageSent then
        ply:ChatPrint("You are now a ghost for 300 seconds. Press E while looking at a light sphere to reduce your timer by 120 seconds.")
        deathData.messageSent = true
    end

    -- Start the ghost timer
    print("[Death System] Starting ghost timer for " .. ply:Nick()) -- Added debug print
    timer.Create(deathData.timerName, deathData.duration, 1, function()
        if not IsValid(ply) then return end
        EndGhostMode(ply)
    end)

    -- Send the timer data to the client
    print("[Death System] Sending GhostTimerSync to " .. ply:Nick())
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

    print("[Death System] Ending ghost mode for " .. ply:Nick())

    -- Stop any ongoing interaction
    if deathData.isInteracting then
        deathData.isInteracting = false
        print("[Death System] Sending StopSphereInteraction to " .. ply:Nick() .. " (EndGhostMode)")
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
        print("[Death System] Player " .. ply:Nick() .. " is not in ghost mode or not dead")
        return
    end

    local deathData = playerDeathData[ply]

    if startInteraction then
        if deathData.isInteracting then
            print("[Death System] Player " .. ply:Nick() .. " is already interacting with a sphere")
            return
        end

        local ent = Entity(sphereEntIndex)
        if not IsValid(ent) or ent:GetClass() ~= "light_sphere" then
            print("[Death System] Invalid light sphere entity (EntIndex=" .. sphereEntIndex .. ")")
            return
        end

        -- Check distance (must be within 100 units)
        local distance = ply:GetPos():Distance(ent:GetPos())
        if distance > 100 then
            print("[Death System] Player " .. ply:Nick() .. " is too far from the light sphere (distance=" .. distance .. ")")
            return
        end

        deathData.isInteracting = true

        print("[Death System] " .. ply:Nick() .. " started interacting with light sphere (EntIndex=" .. ent:EntIndex() .. ") at distance " .. distance)

        -- Notify the client to start the loading bar and sound
        net.Start("StartSphereInteraction")
        net.Send(ply)

        -- Start a 3-second timer for the interaction
        timer.Create("SphereInteraction_" .. ply:SteamID64(), 3, 1, function()
            if not IsValid(ply) or not IsValid(ent) or not deathData.isDead then
                if IsValid(ply) then
                    deathData.isInteracting = false
                    print("[Death System] Sending StopSphereInteraction to " .. ply:Nick() .. " (Timer Invalid)")
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

            print("[Death System] Interaction complete for " .. ply:Nick() .. ". Timer values: elapsed=" .. elapsed .. ", remaining=" .. remaining .. ", reduction=" .. reduction .. ", newRemaining=" .. newRemaining)

            -- Update the deathData before adjusting the timer
            deathData.startTime = CurTime()
            deathData.duration = newRemaining
            deathData.isInteracting = false

            if newRemaining <= 0 then
                print("[Death System] Timer reduced to 0, ending ghost mode for " .. ply:Nick())
                EndGhostMode(ply)
            else
                if timer.Exists(deathData.timerName) then
                    timer.Adjust(deathData.timerName, newRemaining, 1, function()
                        if not IsValid(ply) then return end
                        EndGhostMode(ply)
                    end)
                    print("[Death System] Adjusted timer for " .. ply:Nick() .. " to " .. newRemaining .. " seconds")
                else
                    print("[Death System] Timer " .. deathData.timerName .. " no longer exists, ending ghost mode for " .. ply:Nick())
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
            print("[Death System] Sending StopSphereInteraction to " .. ply:Nick() .. " (Interaction Complete)")
            net.Start("StopSphereInteraction")
            net.Send(ply)
        end)
    else
        -- Stop interaction (player released E)
        if not deathData.isInteracting then return end

        deathData.isInteracting = false
        timer.Remove("SphereInteraction_" .. ply:SteamID64())
        print("[Death System] Sending StopSphereInteraction to " .. ply:Nick() .. " (Player Released E)")
        net.Start("StopSphereInteraction")
        net.Send(ply)
        print("[Death System] " .. ply:Nick() .. " stopped interacting with light sphere (EntIndex=" .. sphereEntIndex .. ")")
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
    if playerDeathData[ply] then
        -- Reapply ghost properties without sending the message again
        local deathData = playerDeathData[ply]
        deathData.messageSent = true -- Ensure the message isn't sent again
        MakePlayerGhost(ply)
    end
end)

-- Block menu access for ghosts
hook.Add("PlayerBindPress", "PreventGhostMenus", function(ply, bind, pressed)
    if playerDeathData[ply] and not ply:IsAdmin() then
        -- Block Q menu (spawnmenu) and other common menu binds
        if bind == "impulse 100" or bind == "+menu" or bind == "+menu_context" then
            return true -- Prevent the bind from executing
        end
    end
end)

-- Function to spawn a light sphere at a specific position
local function SpawnLightSphereAtPos(pos)
    local sphere = ents.Create("light_sphere")
    if not IsValid(sphere) then
        print("[Death System] Failed to spawn light sphere at " .. tostring(pos))
        return
    end

    sphere:SetPos(pos)
    sphere:Spawn()

    -- Store the sphere in the lightSpheres table
    lightSpheres[sphere] = true

    print("[Death System] Added sphere (EntIndex=" .. sphere:EntIndex() .. ") to lightSpheres table at " .. tostring(pos))
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
    print("[Death System] Trace hit position for " .. ply:Nick() .. ": " .. tostring(trace.HitPos))

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
    print("[Death System] Final spawn position for " .. ply:Nick() .. ": " .. tostring(spawnPos))

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
        print("[Death System] No ghosts present, skipping random light sphere spawn.")
        return
    end

    -- 1/15 chance to spawn a light sphere
    if math.random(1, 15) == 1 then
        -- Select a random coordinate
        local spawnPos = spawnCoordinates[math.random(1, #spawnCoordinates)]
        SpawnLightSphereAtPos(spawnPos)
        print("[Death System] Randomly spawned a light sphere at " .. tostring(spawnPos))
    else
        print("[Death System] Random light sphere spawn chance failed (1/15).")
    end
end)

-- Console command to spawn a sphere of light (for testing)
concommand.Add("spawn_light_sphere", function(ply)
    print("[Death System] spawn_light_sphere command executed by " .. (IsValid(ply) and ply:Nick() or "Console"))
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("Admin only!") end
        return
    end

    SpawnLightSphere(ply)
end)

-- Chat command to spawn a sphere of light (e.g., !spawnlightsphere)
hook.Add("PlayerSay", "SpawnLightSphereChatCommand", function(ply, text)
    if string.lower(text) == "!spawnlightsphere" then
        print("[Death System] !spawnlightsphere chat command executed by " .. ply:Nick())
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
    print("[Death System] Test command executed successfully.")
end)

-- Command to check if a player is dead
concommand.Add("check_dead", function(ply)
    if not IsValid(ply) then
        print("[Death System] check_dead command executed by Console")
        return
    end
    if playerDeathData[ply] and playerDeathData[ply].isDead then
        ply:ChatPrint("You are currently dead and in ghost mode.")
    else
        ply:ChatPrint("You are not dead.")
    end
end)

-- Command to respawn a dead player
concommand.Add("respawn_player", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then ply:ChatPrint("Admin only!") end
        return
    end

    local targetSteamID = args[1]
    if not targetSteamID then
        ply:ChatPrint("Usage: respawn_player <SteamID>")
        return
    end

    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == targetSteamID then
            target = p
            break
        end
    end

    if not IsValid(target) then
        ply:ChatPrint("Player with SteamID " .. targetSteamID .. " not found!")
        return
    end

    if not playerDeathData[target] or not playerDeathData[target].isDead then
        ply:ChatPrint("Player " .. target:Nick() .. " is not dead!")
        return
    end

    print("[Death System] Admin " .. ply:Nick() .. " is respawning " .. target:Nick())
    EndGhostMode(target)
    ply:ChatPrint("Successfully respawned " .. target:Nick())
    target:ChatPrint("You have been respawned by an admin.")
end)

print("[Death System] Loaded successfully (Server).")