include("darkrp_modules/scoreboard/client/player_row.lua")
include("darkrp_modules/scoreboard/client/player_frame.lua")
include("darkrp_modules/scoreboard/client/player_infocard.lua")

-- Debug helper function
local function DebugPrint(...)
    if GetConVar("rp_debug") and GetConVar("rp_debug"):GetInt() == 1 then
        print("[SCOREBOARD MODULE]", ...)
    end
end

surface.CreateFont("ScoreboardHeader", {font = "coolvetica", size = 32, weight = 500, antialias = true})
surface.CreateFont("ScoreboardSubtitle", {font = "coolvetica", size = 22, weight = 500, antialias = true})
surface.CreateFont("ScoreboardPlayerName", {font = "coolvetica", size = 20, weight = 500, antialias = true})

local texGradient = surface.GetTextureID("gui/center_gradient")
local texLogo = surface.GetTextureID("gui/gmod_logo")

local gangWidthCache = 80

local PANEL = {}

function PANEL:Init()
    DebugPrint("ScoreBoard Init - VERSION 14")
    SCOREBOARD = self

    self.Hostname = vgui.Create("DLabel", self)
    self.Hostname:SetText(GetHostName())

    self.Description = vgui.Create("DLabel", self)
    self.Description:SetText(GAMEMODE.Name .. " - " .. GAMEMODE.Author)

    self.PlayerFrame = vgui.Create("PlayerFrame", self)

    self.PlayerRows = {}

    self.lblGang = vgui.Create("DLabel", self)
    self.lblGang:SetText("Gang")

    if GM10_IsDarkRP then
        self.lblJobName = vgui.Create("DLabel", self)
        self.lblJobName:SetText("Job")
    end

    self.lblPing = vgui.Create("DLabel", self)
    self.lblPing:SetText("Ping")

    self:UpdateScoreboard()

    timer.Create("ScoreboardUpdater", 1, 0, function()
        self:UpdateScoreboard()
    end)

    self:SetVisible(false)
end

function PANEL:AddPlayerRow(ply)
    local button = vgui.Create("ScorePlayerRow", self.PlayerFrame:GetCanvas())
    button:SetPlayer(ply)
    button:SetVisible(true)
    self.PlayerRows[ply] = button
    DebugPrint("Added player row for " .. ply:Nick())
end

function PANEL:GetPlayerRow(ply)
    return self.PlayerRows[ply]
end

function PANEL:Paint()
    draw.RoundedBox(4, 0, 0, self:GetWide(), self:GetTall(), Color(30, 30, 30, 255))  -- Very dark gray
    surface.SetTexture(texGradient)
    surface.SetDrawColor(255, 255, 255, 50)
    surface.DrawTexturedRect(0, 0, self:GetWide(), self:GetTall())
end

function PANEL:PerformLayout()
    self.Hostname:SizeToContents()
    self.Hostname:SetPos(115, 16)

    self.Description:SizeToContents()
    self.Description:SetPos(128, 64)

    local iTall = self.PlayerFrame:GetCanvas():GetTall() + self.Description.y + self.Description:GetTall() + 30
    iTall = math.Clamp(iTall, 100, ScrH() * 0.9)
    local iWide = math.Clamp(ScrW() * 0.8, 900, ScrW() * 0.6)

    self:SetSize(iWide, iTall)
    self:SetPos((ScrW() - self:GetWide()) / 2, (ScrH() - self:GetTall()) / 4)

    self.PlayerFrame:SetPos(5, self.Description.y + self.Description:GetTall() + 20)
    self.PlayerFrame:SetSize(self:GetWide() - 10, self:GetTall() - self.PlayerFrame.y - 10)

    local y = 0
    local PlayerSorted = {}

    for k, v in pairs(self.PlayerRows) do
        if not IsValid(k) then
            DebugPrint("Removing invalid player row for " .. tostring(k))
            v:Remove()
            self.PlayerRows[k] = nil
        else
            table.insert(PlayerSorted, v)
        end
    end

    table.sort(PlayerSorted, function(a, b) return a:HigherOrLower(b) end)

    for k, v in ipairs(PlayerSorted) do
        v:SetPos(0, y)
        v:SetSize(self.PlayerFrame:GetWide(), v:GetTall())
        self.PlayerFrame:GetCanvas():SetSize(self.PlayerFrame:GetCanvas():GetWide(), y + v:GetTall())
        DebugPrint("Positioned player row for " .. tostring(v.Player:Nick()) .. " at y = " .. tostring(y) .. ", size = " .. tostring(v:GetWide()) .. "x" .. tostring(v:GetTall()))
        y = y + v:GetTall() + 1
    end

    self.Hostname:SetText(GetHostName())

    local x = 16
    local nameWidth = self:GetWide() * 0.3
    DebugPrint("Name width: " .. tostring(nameWidth))
    x = x + nameWidth + 70

    -- Gang header (centered at x = 431.6)
    self.lblGang:SizeToContents()
    local gangWidth = self.lblGang:GetWide()
    self.lblGang:SetPos(431.6 - gangWidth / 2, self.PlayerFrame.y - self.lblGang:GetTall() - 3)
    DebugPrint("Gang header x: " .. tostring(431.6 - gangWidth / 2))

    x = 431.6 + 80 + 70

    -- Job header (centered at x = 581.6)
    if GM10_IsDarkRP and self.lblJobName then
        self.lblJobName:SizeToContents()
        local jobWidth = self.lblJobName:GetWide()
        self.lblJobName:SetPos(581.6 - jobWidth / 2, self.PlayerFrame.y - self.lblJobName:GetTall() - 3)
        DebugPrint("Job header x: " .. tostring(581.6 - jobWidth / 2))
        x = 581.6 + 100 + 70
    end

    -- Position Ping header from the right edge
    local rowWidth = self.PlayerFrame:GetWide()
    local padding = 15

    -- Ping header (rightmost, with padding for triple-digit ping)
    self.lblPing:SizeToContents()
    local pingWidth = self.lblPing:GetWide()
    self.lblPing:SetPos(rowWidth - pingWidth - padding, self.PlayerFrame.y - self.lblPing:GetTall() - 3)
    DebugPrint("Ping header x: " .. tostring(rowWidth - pingWidth - padding))
end

function PANEL:ApplySchemeSettings()
    self.Hostname:SetFont("ScoreboardHeader")
    self.Description:SetFont("ScoreboardSubtitle")

    self.Hostname:SetTextColor(Color(255, 255, 255, 200))  -- Adjusted for better contrast
    self.Description:SetTextColor(color_white)

    self.lblGang:SetFont("ScoreboardPlayerName")
    self.lblGang:SetTextColor(Color(255, 255, 255, 100))  -- Adjusted for better contrast

    if GM10_IsDarkRP and self.lblJobName then
        self.lblJobName:SetFont("ScoreboardPlayerName")
        self.lblJobName:SetTextColor(Color(255, 255, 255, 100))  -- Adjusted for better contrast
    end

    self.lblPing:SetFont("ScoreboardPlayerName")
    self.lblPing:SetTextColor(Color(255, 255, 255, 100))  -- Adjusted for better contrast
end

function PANEL:UpdateScoreboard(force)
    if not force and not self:IsVisible() then return end

    for k, v in pairs(self.PlayerRows) do
        if not k:IsValid() then
            v:Remove()
            self.PlayerRows[k] = nil
        end
    end

    local PlayerList = player.GetAll()
    for id, pl in pairs(PlayerList) do
        if not self:GetPlayerRow(pl) then
            self:AddPlayerRow(pl)
        end
    end

    self:InvalidateLayout()
end

function PANEL:Show()
    self:SetVisible(true)
    self:UpdateScoreboard(true)
    gui.EnableScreenClicker(true)
    DebugPrint("Scoreboard shown")
end

function PANEL:Hide()
    self:SetVisible(false)
    gui.EnableScreenClicker(false)
    DebugPrint("Scoreboard hidden")
end

hook.Add("InitPostEntity", "ForceScoreboardRefresh", function()
    if SCOREBOARD and SCOREBOARD:IsValid() then
        SCOREBOARD:UpdateScoreboard(true)
        DebugPrint("Forced scoreboard refresh on client join")
    end
end)

vgui.Register("ScoreBoard", PANEL, "Panel")

DebugPrint("ScoreBoard panel registered - VERSION 14")