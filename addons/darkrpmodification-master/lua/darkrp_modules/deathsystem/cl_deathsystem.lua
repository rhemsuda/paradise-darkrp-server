-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Death System] cl_deathsystem.lua is loading...")

if not CLIENT then return end

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

local isGhost = false
local startTime = 0
local duration = 0
local screenOverlay = Material("effects/tp_eyefx/tpeye")
local ambientSound = nil
local lastRemaining = -1 -- To throttle HUD timer debug prints
local lastDebugPrint = 0 -- To throttle debug prints
local knownSpheres = {} -- To track known entities and reduce spam
local lastSphereCheck = 0 -- To limit the frequency of sphere rendering checks
local isInteracting = false -- Track if the player is interacting with a sphere
local interactionStartTime = 0 -- Time when the interaction started
local interactionDuration = 3 -- Duration of the interaction (3 seconds)
local interactionSound = nil -- Sound played during interaction
local wasUsePressed = false -- Track the previous state of the use key
local wasInteracting = false -- Track the previous state of isInteracting for HUD debug

-- Create a custom font for the timer and loading bar
surface.CreateFont("GhostTimerFont", {
    font = "Arial",
    size = 32,
    weight = 700,
    antialias = true,
    shadow = true
})

-- Receive the ghost timer data from the server
net.Receive("GhostTimerSync", function()
    isGhost = net.ReadBool()
    startTime = net.ReadFloat()
    duration = net.ReadFloat()
    DebugPrint("[Death System] Client received GhostTimerSync: isGhost=" .. tostring(isGhost) .. ", startTime=" .. startTime .. ", duration=" .. duration)
end)

-- Play the ambient ghost sound
net.Receive("PlayGhostSound", function()
    if ambientSound then
        ambientSound:Stop()
        ambientSound = nil
    end

    -- Use a built-in ambient sound (you can replace this with a custom sound file)
    ambientSound = CreateSound(LocalPlayer(), "ambient/atmosphere/ambience_base.wav")
    if ambientSound then
        ambientSound:SetSoundLevel(0) -- Play for the local player only
        ambientSound:Play()
        ambientSound:ChangeVolume(0.5, 0) -- Adjust volume (0 to 1)
        DebugPrint("[Death System] Playing ambient ghost sound.")
    end
end)

-- Stop the ambient ghost sound
net.Receive("StopGhostSound", function()
    if ambientSound then
        ambientSound:Stop()
        ambientSound = nil
        DebugPrint("[Death System] Stopped ambient ghost sound.")
    end
end)

-- Start the sphere interaction (loading bar and sound)
net.Receive("StartSphereInteraction", function()
    isInteracting = true
    interactionStartTime = CurTime()
    DebugPrint("[Death System] Started sphere interaction")

    -- Play a ghostly sound during interaction
    if interactionSound then
        interactionSound:Stop()
        interactionSound = nil
    end
    interactionSound = CreateSound(LocalPlayer(), "ambient/atmosphere/cave_hit1.wav")
    if interactionSound then
        interactionSound:SetSoundLevel(0)
        interactionSound:Play()
        interactionSound:ChangeVolume(0.5, 0)
        DebugPrint("[Death System] Playing interaction sound")
    end
end)

-- Stop the sphere interaction
net.Receive("StopSphereInteraction", function()
    isInteracting = false
    if interactionSound then
        interactionSound:Stop()
        interactionSound = nil
        DebugPrint("[Death System] Stopped interaction sound")
    end
    DebugPrint("[Death System] Stopped sphere interaction (via network message)")
end)

-- Play the sphere bang sound when the sphere is removed
net.Receive("PlaySphereBangSound", function()
    local pos = net.ReadVector()
    sound.Play("ambient/levels/citadel/weapon_disintegrate1.wav", pos, 75, 100, 0.5)
    DebugPrint("[Death System] Playing sphere bang sound at " .. tostring(pos))

    -- Play a completion sound for the local player
    local completionSound = CreateSound(LocalPlayer(), "ambient/atmosphere/thunder1.wav")
    if completionSound then
        completionSound:SetSoundLevel(0)
        completionSound:Play()
        completionSound:ChangeVolume(0.5, 0)
        DebugPrint("[Death System] Playing interaction completion sound")
    end
end)

-- Play the spark effect for ghosts
net.Receive("SphereSparkEffect", function()
    if not isGhost then return end
    local pos = net.ReadVector()
    local effectData = EffectData()
    effectData:SetOrigin(pos)
    effectData:SetMagnitude(2)
    effectData:SetScale(1)
    util.Effect("Sparks", effectData)
    sound.Play("ambient/energy/spark1.wav", pos, 75, 100, 0.5)
    DebugPrint("[Death System] Playing spark effect at " .. tostring(pos))
end)

-- Draw the timer and loading bar
hook.Add("HUDPaint", "DrawGhostTimer", function()
    if not isGhost then return end

    -- Calculate remaining time
    local elapsed = CurTime() - startTime
    local remaining = math.max(0, duration - elapsed)
    local remainingText = string.format("Time until respawn: %d seconds", math.ceil(remaining))

    -- Debug print only when the remaining time changes
    if math.ceil(remaining) ~= lastRemaining then
        DebugPrint("[Death System] Drawing HUD timer: " .. remainingText)
        lastRemaining = math.ceil(remaining)
    end

    -- Draw the timer text
    surface.SetFont("GhostTimerFont")
    local textW, textH = surface.GetTextSize(remainingText)
    local x = ScrW() / 2 - textW / 2
    local y = ScrH() / 2 - textH / 2 -- Center of the screen
    draw.RoundedBox(8, x - 10, y - 10, textW + 20, textH + 20, Color(0, 0, 0, 200))
    draw.SimpleText(remainingText, "GhostTimerFont", x + textW / 2, y + textH / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Fallback: If interaction has been active for longer than the duration, force stop
    if isInteracting and (CurTime() - interactionStartTime > interactionDuration + 0.5) then
        isInteracting = false
        if interactionSound then
            interactionSound:Stop()
            interactionSound = nil
            DebugPrint("[Death System] Stopped interaction sound (fallback)")
        end
        DebugPrint("[Death System] Stopped sphere interaction (fallback timer)")
    end

    -- Debug print when the interaction state changes
    if isInteracting ~= wasInteracting then
        if isInteracting then
            DebugPrint("[Death System] Drawing HUD: Started drawing power syphoning bar")
        else
            DebugPrint("[Death System] Drawing HUD: Stopped drawing power syphoning bar")
        end
        wasInteracting = isInteracting
    end

    -- Draw the loading bar if interacting
    if isInteracting then
        local interactionElapsed = CurTime() - interactionStartTime
        local progress = math.Clamp(interactionElapsed / interactionDuration, 0, 1)
        local barWidth = 200
        local barHeight = 20
        local barX = ScrW() / 2 - barWidth / 2
        local barY = y + textH + 20

        -- Draw the background
        draw.RoundedBox(4, barX, barY, barWidth, barHeight, Color(0, 0, 0, 200))
        -- Draw the progress
        draw.RoundedBox(4, barX, barY, barWidth * progress, barHeight, Color(50, 150, 255, 255))
        -- Draw the text
        local barText = "Power Syphoning..."
        local barTextW, barTextH = surface.GetTextSize(barText)
        draw.SimpleText(barText, "GhostTimerFont", barX + barWidth / 2, barY + barHeight / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- Apply the screen darkening effect
hook.Add("RenderScreenspaceEffects", "DarkenGhostScreen", function()
    if not isGhost then return end

    -- Darken the screen using a color modify effect
    local tab = {
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = -0.3, -- Increased darkening
        ["$pp_colour_contrast"] = 0.7,   -- Adjusted contrast
        ["$pp_colour_colour"] = 0.6,     -- Reduced saturation for a ghostly feel
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0
    }
    DrawColorModify(tab)
end)

-- Block custom menu access (e.g., Player Loadout menu) and ensure Q menu is closed
hook.Add("PreRender", "PreventGhostMenus", function()
    local ply = LocalPlayer()
    if isGhost and not ply:IsAdmin() then
        -- Close any open VGUI panels
        if vgui.GetKeyboardFocus() then
            vgui.GetKeyboardFocus():KillFocus()
        end
        -- Disable the screen clicker (prevents mouse interaction with menus)
        gui.EnableScreenClicker(false)
        -- Explicitly close the spawn menu if it's open
        if g_SpawnMenu and g_SpawnMenu:IsVisible() then
            g_SpawnMenu:Close()
            DebugPrint("[Death System] Closed spawn menu for non-admin ghost player.")
        end
    end
end)

-- Block menu binds for non-admin ghosts
hook.Add("PlayerBindPress", "PreventGhostMenus", function(ply, bind, pressed)
    if isGhost and not ply:IsAdmin() then
        -- Block Q menu (spawnmenu) and other common menu binds
        if bind == "impulse 100" or bind == "+menu" or bind == "+menu_context" then
            DebugPrint("[Death System] Blocked menu bind (" .. bind .. ") for non-admin ghost player.")
            return true -- Prevent the bind from executing
        end
        -- Block potential binds for rp_loadout (if bound to a key)
        if string.find(string.lower(bind), "rp_loadout") then
            DebugPrint("[Death System] Blocked rp_loadout bind (" .. bind .. ") for non-admin ghost player.")
            return true -- Prevent the bind from executing
        end
    end
end)

-- Render light spheres and their attached lights only for ghosts
hook.Add("PreDrawOpaqueRenderables", "DrawLightSpheresForGhosts", function()
    if not isGhost then return end

    -- Limit the frequency of this hook to once every 0.5 seconds
    local currentTime = CurTime()
    if currentTime - lastSphereCheck < 0.5 then return end
    lastSphereCheck = currentTime

    -- Clear knownSpheres every 30 seconds to prevent memory buildup
    if currentTime - lastDebugPrint >= 30 then
        knownSpheres = {}
        lastDebugPrint = currentTime
        DebugPrint("[Death System] Cleared knownSpheres table to prevent memory buildup")
    end

    local sphereCount = 0
    for _, sphere in pairs(ents.FindByClass("light_sphere")) do
        local sphereIndex = sphere:EntIndex()
        local isLightSphere = sphere:GetNWBool("IsLightSphere", false)

        if isLightSphere then
            sphereCount = sphereCount + 1
            -- Ensure the sphere's render settings are applied
            sphere:SetRenderMode(RENDERMODE_TRANSALPHA)
            sphere:SetMaterial("lights/white")
            sphere:SetColor(Color(255, 255, 255, 200))
            -- Render the sphere
            sphere:DrawModel()

            -- Only print debug info every 0.5 seconds
            DebugPrint("[Death System] Drawing light sphere (EntIndex=" .. sphereIndex .. ") at " .. tostring(sphere:GetPos()))

            -- Render the attached light if it exists
            local light = sphere.AttachedLight
            if IsValid(light) then
                light:DrawModel()
                DebugPrint("[Death System] Drawing attached light for sphere (EntIndex=" .. sphereIndex .. ") at " .. tostring(light:GetPos()))
            end
        end
    end

    if sphereCount > 0 then
        DebugPrint("[Death System] Rendering " .. sphereCount .. " light spheres for ghost player.")
    end
end)

-- Detect E key press and interact with light spheres
hook.Add("Think", "DetectSphereInteraction", function()
    if not isGhost then
        -- Throttle the debug print to once per second
        if CurTime() - lastDebugPrint >= 1 then
            DebugPrint("[Death System] Think hook: Not in ghost mode")
            lastDebugPrint = CurTime()
        end
        return
    end

    local ply = LocalPlayer()
    -- Use LocalPlayer():KeyDown(IN_USE) to detect the use key
    local usePressed = ply:KeyDown(IN_USE)

    -- Debug print to confirm the hook is running and the key state
    if CurTime() - lastDebugPrint >= 1 then
        DebugPrint("[Death System] Think hook: usePressed=" .. tostring(usePressed) .. ", wasUsePressed=" .. tostring(wasUsePressed))
        lastDebugPrint = CurTime()
    end

    -- Check if the use key state has changed
    if usePressed and not wasUsePressed then
        DebugPrint("[Death System] Use key pressed, performing trace")
        -- Use key was just pressed, check if we're looking at a light sphere
        local trace = util.TraceLine({
            start = ply:EyePos(),
            endpos = ply:EyePos() + ply:GetAimVector() * 150, -- Increased distance to 150
            filter = function(ent)
                if ent == ply then return false end -- Ignore the player
                if ent:GetClass() == "light_sphere" then return true end -- Always hit light spheres
                return false -- Ignore other entities
            end,
            mask = MASK_SHOT -- Use MASK_SHOT to ignore collision groups
        })
        local ent = trace.Entity
        DebugPrint("[Death System] Trace result: Entity=" .. tostring(ent) .. (IsValid(ent) and " (Class=" .. ent:GetClass() .. ", Pos=" .. tostring(ent:GetPos()) .. ")" or ""))

        if IsValid(ent) and ent:GetClass() == "light_sphere" then
            -- Check distance (must be within 100 units)
            local distance = ply:GetPos():Distance(ent:GetPos())
            DebugPrint("[Death System] Distance to light sphere (EntIndex=" .. ent:EntIndex() .. "): " .. distance)
            if distance <= 100 then
                DebugPrint("[Death System] Requesting interaction with light sphere (EntIndex=" .. ent:EntIndex() .. ")")
                net.Start("RequestSphereInteraction")
                net.WriteBool(true) -- Start interaction
                net.WriteInt(ent:EntIndex(), 32)
                net.SendToServer()
            else
                DebugPrint("[Death System] Too far from light sphere (distance=" .. distance .. ")")
            end
        else
            DebugPrint("[Death System] No light sphere found in trace")
        end
    elseif not usePressed and wasUsePressed then
        -- Use key was just released, stop interaction only if still interacting
        if isInteracting then
            DebugPrint("[Death System] Stopping interaction with light sphere (E released)")
            net.Start("RequestSphereInteraction")
            net.WriteBool(false) -- Stop interaction
            net.WriteInt(-1, 32) -- EntIndex not needed for stopping
            net.SendToServer()
        end
    end

    wasUsePressed = usePressed
end)

-- Clean up the sound on map change or client disconnect
hook.Add("ShutDown", "CleanupGhostSound", function()
    if ambientSound then
        ambientSound:Stop()
        ambientSound = nil
    end
    if interactionSound then
        interactionSound:Stop()
        interactionSound = nil
    end
end)

-- This print will always show to confirm successful load
print("[Death System] Loaded successfully (Client).")