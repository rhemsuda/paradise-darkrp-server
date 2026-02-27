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

local function GetXPNeeded()
    local ply = LocalPlayer()
    if not IsValid(ply) then return 100 end
    local need = ply:GetNWInt("DarkRP_ExperienceNeeded", 100)
    return need > 0 and need or 100
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

    local level = GetLevel()
    local xp = GetXP()
    local need = GetXPNeeded()
    local ratio = math.Clamp(need > 0 and (xp / need) or 0, 0, 1)

    -- Background
    draw.RoundedBox(6, x - 2, y - 2, barW + 4, barH + 4, Color(20, 24, 32, 220))
    draw.RoundedBox(4, x, y, barW, barH, Color(40, 48, 60, 240))
    -- Fill
    draw.RoundedBox(4, x, y, barW * ratio, barH, Color(0, 180, 220, 220))
    -- Border
    surface.SetDrawColor(0, 200, 255, 120)
    surface.DrawOutlinedRect(x, y, barW, barH)

    -- Text: "Level N" left, "current / needed" center/right
    local levelStr = "Level " .. tostring(level)
    local xpStr = tostring(xp) .. " / " .. tostring(need) .. " XP"
    draw.SimpleText(levelStr, "HUD_EXPBar", x + 8, y + barH / 2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(xpStr, "HUD_EXPBar", x + barW - 8, y + barH / 2, Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)
