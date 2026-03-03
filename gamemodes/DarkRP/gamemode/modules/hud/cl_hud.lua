--[[---------------------------------------------------------------------------
HUD ConVars
---------------------------------------------------------------------------]]
local ConVars = {}
local HUDWidth
local HUDHeight

local Color = Color
local CurTime = CurTime
local cvars = cvars
local DarkRP = DarkRP
local draw = draw
local GetConVar = GetConVar
local hook = hook
local IsValid = IsValid
local Lerp = Lerp
local localplayer
local math = math
local pairs = pairs
local ScrW, ScrH = ScrW, ScrH
local SortedPairs = SortedPairs
local string = string
local surface = surface
local table = table
local timer = timer
local tostring = tostring
local plyMeta = FindMetaTable("Player")

local colors = {}
colors.black = color_black
colors.blue = Color(0, 0, 255, 255)
colors.brightred = Color(200, 30, 30, 255)
colors.darkred = Color(0, 0, 70, 100)
colors.darkblack = Color(0, 0, 0, 200)
colors.gray1 = Color(0, 0, 0, 155)
colors.gray2 = Color(51, 58, 51,100)
colors.red = Color(255, 0, 0, 255)
colors.white = color_white
colors.white1 = Color(255, 255, 255, 200)

local function ReloadConVars()
    -- Fixed colors/sizes for a consistent custom HUD (ignore DarkRP CVars).
    ConVars.background      = Color(5, 10, 16, 210)   -- main panel
    ConVars.Healthbackground = Color(8, 12, 20, 230)  -- HP bar background
    ConVars.Healthforeground = Color(200, 40, 40, 230) -- HP bar fill (modern red)
    ConVars.HealthText       = Color(255, 255, 255, 230)

    -- Slightly wide panel but not too tall, so text sits neatly above bars.
    HUDWidth  = 420
    HUDHeight = 115
end
ReloadConVars()

local Scrw, Scrh, RelativeX, RelativeY
--[[---------------------------------------------------------------------------
HUD separate Elements
---------------------------------------------------------------------------]]
local Health = 0
local function DrawHealth()
    local maxHealth = localplayer:GetMaxHealth()
    local myHealth = localplayer:Health()
    Health = math.min(maxHealth, (Health == myHealth and Health) or Lerp(0.1, Health, myHealth))

    local healthRatio = math.Min(Health / maxHealth, 1)
    local rounded = math.Round(3 * healthRatio)
    local Border = math.Min(6, rounded * rounded)
    -- Health bar (red) – full-width background, filled by ratio, with safe bottom margin
    local barX = RelativeX + 8
    local barW = HUDWidth - 16
    local barH = 18
    local bottomMargin = 6
    local gap = 2

    -- Place armor bar so its bottom sits at Scrh - bottomMargin, then HP bar above it
    local armorY = RelativeY - bottomMargin - barH
    local barY = armorY - gap - barH

    draw.RoundedBox(Border, barX, barY, barW, barH, ConVars.Healthbackground)
    draw.RoundedBox(Border, barX, barY, barW * healthRatio, barH, ConVars.Healthforeground)
    draw.DrawNonParsedText(math.Max(0, math.Round(myHealth)), "DarkRPHUD2", barX + barW / 2, barY - 2, ConVars.HealthText, 1)

    -- Armor bar (blue) – same size as HP, slight vertical gap below, always on-screen
    local armor = math.Clamp(localplayer:Armor() or 0, 0, 100)
    draw.RoundedBox(Border, barX, armorY, barW, barH, Color(8, 12, 20, 220))
    if armor > 0 then
        draw.RoundedBox(Border, barX, armorY, barW * (armor / 100), barH, Color(0, 150, 230, 230))
    end
    draw.DrawNonParsedText(tostring(armor), "DarkRPHUD2", barX + barW / 2, armorY - 2, colors.white1, 1)
end

local function DrawInfo()
    local level = localplayer:GetNWInt("DarkRP_Level", 0)
    local job = localplayer:getDarkRPVar("job") or ""
    local money = DarkRP.formatMoney(localplayer:getDarkRPVar("money") or 0)

    local boxH = 26
    local boxPad = 10
    local boxGap = 8
    local leftX = RelativeX + 12
    -- Nudge the info boxes a bit higher so they don't kiss the health bar
    local startY = RelativeY - HUDHeight + 8

    -- Helper: draw a label in its own rounded box (like Level)
    local function drawLabelBox(text, y)
        surface.SetFont("DarkRPHUD2")
        local tw = surface.GetTextSize(text)
        local boxW = math.max(80, tw + boxPad * 2)
        draw.RoundedBox(6, leftX, y, boxW, boxH, Color(8, 12, 20, 230))
        draw.DrawNonParsedText(text, "DarkRPHUD2", leftX + 1 + boxPad, y + 1 + (boxH - 18) / 2, colors.black, 0)
        draw.DrawNonParsedText(text, "DarkRPHUD2", leftX + boxPad, y + (boxH - 18) / 2, colors.white1, 0)
        return y + boxH + boxGap
    end

    local y = startY
    y = drawLabelBox(string.format("Job: %s", job), y)
    drawLabelBox(string.format("Money: %s", money), y)

    -- Level badge on the top-right of the HUD panel
    local badgeW, badgeH = 90, 26
    local badgeX = RelativeX + HUDWidth - badgeW - 12
    local badgeY = RelativeY - HUDHeight + 12

    draw.RoundedBox(6, badgeX, badgeY, badgeW, badgeH, Color(8, 12, 20, 230))
    draw.DrawNonParsedText("Level " .. tostring(level), "DarkRPHUD2", badgeX + badgeW / 2, badgeY + 5, colors.white1, 1)
end

local Page = Material("icon16/page_white_text.png")
local function GunLicense()
    if localplayer:getDarkRPVar("HasGunlicense") then
        surface.SetMaterial(Page)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(RelativeX + HUDWidth, Scrh - 34, 32, 32)
    end
end

local agendaText
local function Agenda(gamemodeTable)
    local shouldDraw = hook.Call("HUDShouldDraw", gamemodeTable, "DarkRP_Agenda")
    if shouldDraw == false then return end

    local agenda = localplayer:getAgendaTable()
    if not agenda then return end
    agendaText = agendaText or DarkRP.textWrap((localplayer:getDarkRPVar("agenda") or ""):gsub("//", "\n"):gsub("\\n", "\n"), "DarkRPHUD1", 440)

    draw.RoundedBox(10, 10, 10, 460, 110, colors.gray1)
    draw.RoundedBox(10, 12, 12, 456, 106, colors.gray2)
    draw.RoundedBox(10, 12, 12, 456, 20, colors.darkred)

    draw.DrawNonParsedText(agenda.Title, "DarkRPHUD1", 30, 12, colors.red, 0)
    draw.DrawNonParsedText(agendaText, "DarkRPHUD1", 30, 35, colors.white, 0)
end

hook.Add("DarkRPVarChanged", "agendaHUD", function(ply, var, _, new)
    if ply ~= localplayer then return end
    if var == "agenda" and new then
        agendaText = DarkRP.textWrap(new:gsub("//", "\n"):gsub("\\n", "\n"), "DarkRPHUD1", 440)
    else
        agendaText = nil
    end
end)

local VoiceChatTexture = surface.GetTextureID("voice/icntlk_pl")
local function DrawVoiceChat(gamemodeTable)
    local shouldDraw = hook.Call("HUDShouldDraw", gamemodeTable, "DarkRP_VoiceChat")
    if shouldDraw == false then return end

    if localplayer.DRPIsTalking then
        local _, chboxY = chat.GetChatBoxPos()

        local Rotating = math.sin(CurTime() * 3)
        local backwards = 0

        if Rotating < 0 then
            Rotating = 1 - (1 + Rotating)
            backwards = 180
        end

        surface.SetTexture(VoiceChatTexture)
        surface.SetDrawColor(ConVars.Healthforeground)
        surface.DrawTexturedRectRotated(Scrw - 100, chboxY, Rotating * 96, 96, backwards)
    end
end

local function LockDown(gamemodeTable)
    local chbxX, chboxY = chat.GetChatBoxPos()
    if GetGlobalBool("DarkRP_LockDown") then
        local shouldDraw = hook.Call("HUDShouldDraw", gamemodeTable, "DarkRP_LockdownHUD")
        if shouldDraw == false then return end
        local cin = (math.sin(CurTime()) + 1) / 2
        local chatBoxSize = math.floor(Scrh / 4)
        draw.DrawNonParsedText(DarkRP.getPhrase("lockdown_started"), "ScoreboardSubtitle", chbxX, chboxY + chatBoxSize, Color(cin * 255, 0, 255 - (cin * 255), 255), TEXT_ALIGN_LEFT)
    end
end

local Arrested = function() end

usermessage.Hook("GotArrested", function(msg)
    local StartArrested = CurTime()
    local ArrestedUntil = msg:ReadFloat()

    Arrested = function(gamemodeTable)
        local shouldDraw = hook.Call("HUDShouldDraw", gamemodeTable, "DarkRP_ArrestedHUD")
        if shouldDraw == false then return end

        if CurTime() - StartArrested <= ArrestedUntil and localplayer:getDarkRPVar("Arrested") then
            draw.DrawNonParsedText(DarkRP.getPhrase("youre_arrested", math.ceil((ArrestedUntil - (CurTime() - StartArrested)) * 1 / game.GetTimeScale())), "DarkRPHUD1", Scrw / 2, Scrh - Scrh / 12, colors.white, 1)
        elseif not localplayer:getDarkRPVar("Arrested") then
            Arrested = function() end
        end
    end
end)

local AdminTell = function() end

usermessage.Hook("AdminTell", function(msg)
    timer.Remove("DarkRP_AdminTell")
    local Message = msg:ReadString()

    AdminTell = function()
        draw.RoundedBox(4, 10, 10, Scrw - 20, 110, colors.darkblack)
        draw.DrawNonParsedText(DarkRP.getPhrase("listen_up"), "GModToolName", Scrw / 2 + 10, 10, colors.white, 1)
        draw.DrawNonParsedText(Message, "ChatFont", Scrw / 2 + 10, 90, colors.brightred, 1)
    end

    timer.Create("DarkRP_AdminTell", 10, 1, function()
        AdminTell = function() end
    end)
end)

--[[---------------------------------------------------------------------------
Drawing the HUD elements such as Health etc.
---------------------------------------------------------------------------]]
local function DrawHUD(gamemodeTable)
    local shouldDraw = hook.Call("HUDShouldDraw", gamemodeTable, "DarkRP_HUD")
    if shouldDraw == false then return end

    Scrw, Scrh = ScrW(), ScrH()
    RelativeX, RelativeY = 0, Scrh

    shouldDraw = hook.Call("HUDShouldDraw", gamemodeTable, "DarkRP_LocalPlayerHUD")
    shouldDraw = shouldDraw ~= false
    if shouldDraw then
        --Background
        draw.RoundedBox(6, 0, Scrh - HUDHeight, HUDWidth, HUDHeight, ConVars.background)
        DrawHealth()
        DrawInfo()
        GunLicense()
    end
    Agenda(gamemodeTable)
    DrawVoiceChat(gamemodeTable)
    LockDown(gamemodeTable)

    Arrested(gamemodeTable)
    AdminTell()
end

--[[---------------------------------------------------------------------------
Entity HUDPaint things
---------------------------------------------------------------------------]]
-- Draw a player's name, health and/or job above the head
-- This syntax allows for easy overriding
plyMeta.drawPlayerInfo = plyMeta.drawPlayerInfo or function(self)
    local pos = self:EyePos()

    pos.z = pos.z + 10 -- The position we want is a bit above the position of the eyes
    pos = pos:ToScreen()
    if not self:getDarkRPVar("wanted") then
        -- Move the text up a few pixels to compensate for the height of the text
        pos.y = pos.y - 50
    end

    if GAMEMODE.Config.showname then
        local nick, plyTeam = self:Nick(), self:Team()
        draw.DrawNonParsedText(nick, "DarkRPHUD2", pos.x + 1, pos.y + 1, colors.black, 1)
        draw.DrawNonParsedText(nick, "DarkRPHUD2", pos.x, pos.y, RPExtraTeams[plyTeam] and RPExtraTeams[plyTeam].color or team.GetColor(plyTeam) , 1)
    end

    if GAMEMODE.Config.showhealth then
        local health = DarkRP.getPhrase("health", math.max(0, self:Health()))
        draw.DrawNonParsedText(health, "DarkRPHUD2", pos.x + 1, pos.y + 21, colors.black, 1)
        draw.DrawNonParsedText(health, "DarkRPHUD2", pos.x, pos.y + 20, colors.white1, 1)
    end

    if GAMEMODE.Config.showjob then
        local teamname = self:getDarkRPVar("job") or team.GetName(self:Team())
        draw.DrawNonParsedText(teamname, "DarkRPHUD2", pos.x + 1, pos.y + 41, colors.black, 1)
        draw.DrawNonParsedText(teamname, "DarkRPHUD2", pos.x, pos.y + 40, colors.white1, 1)
    end

    if self:getDarkRPVar("HasGunlicense") then
        surface.SetMaterial(Page)
        surface.SetDrawColor(255,255,255,255)
        surface.DrawTexturedRect(pos.x-16, pos.y + 60, 32, 32)
    end
end

-- Draw wanted information above a player's head
-- This syntax allows for easy overriding
plyMeta.drawWantedInfo = plyMeta.drawWantedInfo or function(self)
    if not self:Alive() then return end

    local pos = self:EyePos()
    if not pos:isInSight({localplayer, self}) then return end

    pos.z = pos.z + 10
    pos = pos:ToScreen()

    if GAMEMODE.Config.showname then
        local nick, plyTeam = self:Nick(), self:Team()
        draw.DrawNonParsedText(nick, "DarkRPHUD2", pos.x + 1, pos.y + 1, colors.black, 1)
        draw.DrawNonParsedText(nick, "DarkRPHUD2", pos.x, pos.y, RPExtraTeams[plyTeam] and RPExtraTeams[plyTeam].color or team.GetColor(plyTeam) , 1)
    end

    local wantedText = DarkRP.getPhrase("wanted", tostring(self:getDarkRPVar("wantedReason")))

    draw.DrawNonParsedText(wantedText, "DarkRPHUD2", pos.x, pos.y - 40, colors.white1, 1)
    draw.DrawNonParsedText(wantedText, "DarkRPHUD2", pos.x + 1, pos.y - 41, colors.red, 1)
end

--[[---------------------------------------------------------------------------
The Entity display: draw HUD information about entities
---------------------------------------------------------------------------]]
local function DrawEntityDisplay(gamemodeTable)
    local shouldDraw, players = hook.Call("HUDShouldDraw", gamemodeTable, "DarkRP_EntityDisplay")
    if shouldDraw == false then return end

    local shootPos = localplayer:GetShootPos()
    local aimVec = localplayer:GetAimVector()

    for _, ply in ipairs(players or player.GetAll()) do
        if not IsValid(ply)
           or ply == localplayer
           or not ply:Alive()
           or ply:GetNoDraw()
           or ply:IsDormant()
           or ply:GetColor().a == 0 and (ply:GetRenderMode() == RENDERMODE_TRANSALPHA or ply:GetRenderMode() == RENDERMODE_TRANSCOLOR) then
           continue
        end
        local hisPos = ply:GetShootPos()
        if ply:getDarkRPVar("wanted") then ply:drawWantedInfo() end

        if gamemodeTable.Config.globalshow then
            ply:drawPlayerInfo()
        -- Draw when you're (almost) looking at him
        elseif hisPos:DistToSqr(shootPos) < 160000 then
            local pos = hisPos - shootPos
            local unitPos = pos:GetNormalized()
            if unitPos:Dot(aimVec) > 0.95 then
                local trace = util.QuickTrace(shootPos, pos, localplayer)
                if trace.Hit and trace.Entity ~= ply then
                    -- When the trace says you're directly looking at a
                    -- different player, that means you can draw /their/ info
                    if trace.Entity:IsPlayer() then
                        trace.Entity:drawPlayerInfo()
                    end
                    break
                end
                ply:drawPlayerInfo()
            end
        end
    end

    local ent = localplayer:GetEyeTrace().Entity

    if IsValid(ent) and ent:isKeysOwnable() and ent:GetPos():DistToSqr(localplayer:GetPos()) < 40000 then
        ent:drawOwnableInfo()
    end
end

--[[---------------------------------------------------------------------------
Drawing death notices
---------------------------------------------------------------------------]]
function GM:DrawDeathNotice(x, y)
    if not self.Config.showdeaths then return end
    self.Sandbox.DrawDeathNotice(self, x, y)
end

--[[---------------------------------------------------------------------------
Display notifications
---------------------------------------------------------------------------]]
local notificationSound = GM.Config.notificationSound
local function DisplayNotify(msg)
    local txt = msg:ReadString()
    GAMEMODE:AddNotify(txt, msg:ReadShort(), msg:ReadLong())
    surface.PlaySound(notificationSound)

    -- Log to client console (no gamemode prefix; tooltip shows message only)
    MsgC(Color(200, 200, 200, 255), txt, "\n")
end
usermessage.Hook("_Notify", DisplayNotify)

--[[---------------------------------------------------------------------------
Remove some elements from the HUD in favour of the DarkRP HUD
---------------------------------------------------------------------------]]
local noDraw = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
    ["CHudSuitPower"] = true,
    ["CHUDQuickInfo"] = true
}
function GM:HUDShouldDraw(name)
    if noDraw[name] or (HelpToggled and name == "CHudChat") then
        return false
    else
        return self.Sandbox.HUDShouldDraw(self, name)
    end
end

--[[---------------------------------------------------------------------------
Disable players' names popping up when looking at them
---------------------------------------------------------------------------]]
function GM:HUDDrawTargetID()
    return false
end

--[[---------------------------------------------------------------------------
Actual HUDPaint hook
---------------------------------------------------------------------------]]
function GM:HUDPaint()
    localplayer = localplayer or LocalPlayer()

    DrawHUD(self)
    DrawEntityDisplay(self)

    self.Sandbox.HUDPaint(self)
end
