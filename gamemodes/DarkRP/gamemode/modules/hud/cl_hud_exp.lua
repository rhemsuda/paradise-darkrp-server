--[[---------------------------------------------------------------------------
  Paradise RP – EXP bar and Level at top of screen.
  Uses NWInt: DarkRP_Level, DarkRP_Experience, DarkRP_ExperienceNeeded (set by leveling module when enabled).
  Placeholder values when leveling is not yet active.
---------------------------------------------------------------------------]]
if not CLIENT then return end

surface.CreateFont("HUD_EXPBar", {
    font = "DermaDefault",
    size = 14,
    weight = 600,
    antialias = true,
})

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

    -- Background
    draw.RoundedBox(6, x - 2, y - 2, barW + 4, barH + 4, Color(20, 24, 32, 220))
    draw.RoundedBox(4, x, y, barW, barH, Color(40, 48, 60, 240))
    -- Fill
    draw.RoundedBox(4, x, y, barW * ratio, barH, Color(0, 180, 220, 220))
    -- Border
    surface.SetDrawColor(0, 200, 255, 120)
    surface.DrawOutlinedRect(x, y, barW, barH)

    -- Text: show XP percentage only (no Level here)
    local percent = math.floor(ratio * 100 + 0.5)
    local xpStr = tostring(percent) .. "% XP"
    draw.SimpleText(xpStr, "HUD_EXPBar", x + barW / 2, y + barH / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
