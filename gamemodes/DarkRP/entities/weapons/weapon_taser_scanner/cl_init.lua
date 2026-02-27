-- Client: loading bar for scanner, play sounds, tase effects
local SCAN_DURATION = 5
local TASE_SOUND = "weapons/stunstick/stunstick_fleshhit1.wav"
local SCAN_SOUND = "items/suitcharge1.wav"

-- Play suit charging sound when scan starts (all players hear it globally)
net.Receive("TaserScanner_PlayScanSound", function()
    local pos = net.ReadVector()
    sound.Play(SCAN_SOUND, pos, 150, 100)  -- High volume so everyone on map hears
end)

-- Play tase sound when someone gets tased
net.Receive("TaserScanner_TaseHit", function()
    local victim = net.ReadEntity()
    if IsValid(victim) then
        victim:EmitSound(TASE_SOUND, 75, 100)
    end
end)

-- Draw loading bar when scanning
hook.Add("HUDPaint", "TaserScanner_LoadingBar", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_taser_scanner" then return end
    if not wep.GetScanning or not wep:GetScanning() then return end

    local startTime = 0
    if wep.GetScanStartTime then
        startTime = wep:GetScanStartTime()
    end
    local elapsed = CurTime() - (startTime or 0)
    local progress = math.Clamp(elapsed / SCAN_DURATION, 0, 1)

    local w, h = 300, 24
    local x, y = ScrW() / 2 - w / 2, ScrH() * 0.4

    -- Background
    surface.SetDrawColor(0, 0, 0, 180)
    surface.DrawRect(x - 2, y - 2, w + 4, h + 4)

    -- Bar fill
    surface.SetDrawColor(50, 150, 255, 220)
    surface.DrawRect(x, y, w * progress, h)

    -- Border
    surface.SetDrawColor(255, 255, 255, 120)
    surface.DrawOutlinedRect(x - 2, y - 2, w + 4, h + 4)

    draw.SimpleText("Scanning...", "DermaDefault", ScrW() / 2, y + h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- Slow movement + blurry screen when recovering from tase
hook.Add("Think", "TaserScanner_TaseSlow", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local taseEnd = ply:GetNWFloat("TaseSlowEnd", 0)
    if CurTime() >= taseEnd then return end

    -- Slow movement (handled in CalcMove if we had server access; client-side we can't easily slow the player)
    -- Screen effects via DrawOverlay
end)

hook.Add("RenderScreenspaceEffects", "TaserScanner_TaseBlur", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local taseEnd = ply:GetNWFloat("TaseSlowEnd", 0)
    if CurTime() >= taseEnd then return end

    local remaining = taseEnd - CurTime()
    local intensity = math.Clamp(remaining / 5, 0, 1) * 0.15

    DrawMotionBlur(0.1, intensity, 0.02)
end)
