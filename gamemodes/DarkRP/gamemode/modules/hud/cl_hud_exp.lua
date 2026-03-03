--[[---------------------------------------------------------------------------
  Paradise RP – EXP bar and Level at top of screen.
  Uses NWInt: DarkRP_Level, DarkRP_Experience, DarkRP_ExperienceNeeded (set by leveling module when enabled).
  On level up: tooltip, sound, and XP bar drains to 0% then shows new level progress.
---------------------------------------------------------------------------]]
if not CLIENT then return end

surface.CreateFont("HUD_EXPBar", {
    font = "DermaDefault",
    size = 14,
    weight = 600,
    antialias = true,
})

surface.CreateFont("HUD_LevelUpTitle", {
    font = "DermaDefault",
    size = 28,
    weight = 700,
    antialias = true,
})

surface.CreateFont("HUD_LevelUpLevel", {
    font = "DermaDefault",
    size = 22,
    weight = 600,
    antialias = true,
})

-- Level-up tooltip and bar drain state
local levelUpShowUntil = 0
local levelUpNewLevel = 0
local displayRatio = 0
local drainStartTime = 0
local drainDuration = 1.2

net.Receive("Paradise_LevelUp", function()
    levelUpNewLevel = net.ReadUInt(8)
    levelUpShowUntil = CurTime() + 3
    drainStartTime = CurTime()
    displayRatio = 1
    surface.PlaySound("buttons/button15.wav")
end)

local function GetLevel()
    local ply = LocalPlayer()
    if not IsValid(ply) then return 0 end
    return ply:GetNWInt("DarkRP_Level", 0)
end

local function GetXP()
    local ply = LocalPlayer()
    if not IsValid(ply) then return 0 end
    return ply:GetNWInt("DarkRP_Experience", 0)
end

-- XP required to reach next level (server sets DarkRP_ExperienceCurrentLevel and DarkRP_ExperienceNeeded)
local function GetXPNeeded()
    local ply = LocalPlayer()
    if not IsValid(ply) then return 100 end
    return ply:GetNWInt("DarkRP_ExperienceNeeded", 100)
end

local function GetXPCurrentLevelStart()
    local ply = LocalPlayer()
    if not IsValid(ply) then return 0 end
    return ply:GetNWInt("DarkRP_ExperienceCurrentLevel", 0)
end

hook.Add("HUDPaint", "Paradise_EXPBar", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local shouldDraw = hook.Call("HUDShouldDraw", GAMEMODE or GM, "Paradise_EXPBar")
    if shouldDraw == false then return end

    local w, h = ScrW(), ScrH()
    local barW = math.min(400, w * 0.35)
    local barH = 22
    local topMargin = 12
    local x = (w - barW) / 2
    local y = topMargin

    local xp = GetXP()
    local currentStart = GetXPCurrentLevelStart()
    local nextStart = GetXPNeeded()
    local segment = nextStart - currentStart
    local ratio = (segment > 0 and (xp - currentStart) / segment) or 0
    ratio = math.Clamp(ratio, 0, 1)

    -- After level up: drain display from 100% to 0% over drainDuration, then use real ratio
    if drainStartTime > 0 then
        local elapsed = CurTime() - drainStartTime
        if elapsed >= drainDuration then
            drainStartTime = 0
            displayRatio = ratio
        else
            displayRatio = 1 - (elapsed / drainDuration)
        end
    else
        displayRatio = ratio
    end

    -- Background
    draw.RoundedBox(6, x - 2, y - 2, barW + 4, barH + 4, Color(20, 24, 32, 220))
    draw.RoundedBox(4, x, y, barW, barH, Color(40, 48, 60, 240))
    -- Fill (use display ratio for drain effect)
    draw.RoundedBox(4, x, y, barW * displayRatio, barH, Color(0, 180, 220, 220))
    -- Border
    surface.SetDrawColor(0, 200, 255, 120)
    surface.DrawOutlinedRect(x, y, barW, barH)

    -- Text: show XP percentage
    local percent = math.floor(displayRatio * 100 + 0.5)
    local xpStr = tostring(percent) .. "% XP"
    draw.SimpleText(xpStr, "HUD_EXPBar", x + barW / 2, y + barH / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Level-up tooltip (centered below bar)
    if levelUpShowUntil > CurTime() and levelUpNewLevel > 0 then
        local tipW, tipH = 220, 72
        local tipX = (w - tipW) / 2
        local tipY = y + barH + 16
        local alpha = 1
        if CurTime() > levelUpShowUntil - 0.8 then
            alpha = (levelUpShowUntil - CurTime()) / 0.8
        end
        draw.RoundedBox(8, tipX, tipY, tipW, tipH, Color(24, 28, 36, 240 * alpha))
        surface.SetDrawColor(0, 200, 255, 150 * alpha)
        surface.DrawOutlinedRect(tipX, tipY, tipW, tipH)
        draw.SimpleText("Level Up!", "HUD_LevelUpTitle", w / 2, tipY + 22, Color(255, 220, 100, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Level " .. tostring(levelUpNewLevel), "HUD_LevelUpLevel", w / 2, tipY + 50, Color(200, 240, 255, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)
