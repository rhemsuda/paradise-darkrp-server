-- Main ScoreBoard panel (player_row + player_frame already loaded by cl_scoreboard)
surface.CreateFont("ScoreboardHeader", { font = "coolvetica", size = 32, weight = 500, antialias = true })
surface.CreateFont("ScoreboardSubtitle", { font = "coolvetica", size = 22, weight = 500, antialias = true })

local texGradient = surface.GetTextureID("gui/center_gradient")
local texLogo = surface.GetTextureID("gui/gmod_logo")

local PANEL = {}

function PANEL:Init()
    SCOREBOARD = self
    self.Hostname = vgui.Create("DLabel", self)
    self.Hostname:SetText(GetHostName())
    self.Description = vgui.Create("DLabel", self)
    self.Description:SetText(GAMEMODE.Name .. " - " .. GAMEMODE.Author)
    self.PlayerFrame = vgui.Create("PlayerFrame", self)
    self.PlayerRows = {}
    self:UpdateScoreboard()
    timer.Create("ScoreboardUpdater", 1, 0, self.UpdateScoreboard, self)
    if GM10_IsDarkRP then
        self.lblJobName = vgui.Create("DLabel", self)
        self.lblJobName:SetText("Job")
        self.lblRank = vgui.Create("DLabel", self)
        self.lblRank:SetText("Rank")
        self.lblGang = vgui.Create("DLabel", self)
        self.lblGang:SetText("Gang")
    end
    self.lblPing = vgui.Create("DLabel", self)
    self.lblPing:SetText("Ping")
    self.lblKills = vgui.Create("DLabel", self)
    self.lblKills:SetText("Kills")
    self.lblDeaths = vgui.Create("DLabel", self)
    self.lblDeaths:SetText("Deaths")
end

function PANEL:AddPlayerRow(ply)
    local button = vgui.Create("ScorePlayerRow", self.PlayerFrame:GetCanvas())
    button:SetPlayer(ply)
    self.PlayerRows[ply] = button
end

function PANEL:GetPlayerRow(ply)
    return self.PlayerRows[ply]
end

function PANEL:Paint()
    draw.RoundedBox(8, 0, 0, self:GetWide(), self:GetTall(), Color(170, 170, 170, 255))
    surface.SetTexture(texGradient)
    surface.SetDrawColor(255, 255, 255, 50)
    surface.DrawTexturedRect(0, 0, self:GetWide(), self:GetTall())
    draw.RoundedBox(8, 4, self.Description.y - 4, self:GetWide() - 8, self:GetTall() - self.Description.y - 4, Color(230, 230, 230, 200))
    surface.SetTexture(texGradient)
    surface.SetDrawColor(255, 255, 255, 50)
    surface.DrawTexturedRect(4, self.Description.y - 4, self:GetWide() - 8, self:GetTall() - self.Description.y - 4)
    draw.RoundedBox(6, 5, self.Description.y - 3, self:GetWide() - 10, self.Description:GetTall() + 5, Color(150, 200, 50, 200))
    surface.SetTexture(texGradient)
    surface.SetDrawColor(255, 255, 255, 50)
    surface.DrawTexturedRect(4, self.Description.y - 4, self:GetWide() - 8, self.Description:GetTall() + 8)
    surface.SetTexture(texLogo)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(0, 0, 128, 128)
end

function PANEL:PerformLayout()
    self.Hostname:SizeToContents()
    self.Hostname:SetPos(115, 16)
    self.Description:SizeToContents()
    self.Description:SetPos(128, 64)
    local iTall = self.PlayerFrame:GetCanvas():GetTall() + self.Description.y + self.Description:GetTall() + 30
    iTall = math.Clamp(iTall, 100, ScrH() * 0.9)
    local iWide = math.Clamp(ScrW() * 0.8, 700, ScrW() * 0.6)
    self:SetSize(iWide, iTall)
    self:SetPos((ScrW() - self:GetWide()) / 2, (ScrH() - self:GetTall()) / 4)
    self.PlayerFrame:SetPos(5, self.Description.y + self.Description:GetTall() + 20)
    self.PlayerFrame:SetSize(self:GetWide() - 10, self:GetTall() - self.PlayerFrame.y - 10)
    local y = 0
    local PlayerSorted = {}
    for k, v in pairs(self.PlayerRows) do
        table.insert(PlayerSorted, v)
    end
    table.sort(PlayerSorted, function(a, b) return a:HigherOrLower(b) end)
    for k, v in ipairs(PlayerSorted) do
        v:SetPos(0, y)
        v:SetSize(self.PlayerFrame:GetWide(), v:GetTall())
        self.PlayerFrame:GetCanvas():SetSize(self.PlayerFrame:GetCanvas():GetWide(), y + v:GetTall())
        y = y + v:GetTall() + 1
    end
    self.Hostname:SetText(GetHostName())
    self.lblPing:SizeToContents()
    self.lblKills:SizeToContents()
    self.lblDeaths:SizeToContents()
    local headerY = self.PlayerFrame.y - self.lblPing:GetTall() - 3
    local W = self:GetWide()
    local COL_W = 50
    -- Right-aligned columns: Ping, Deaths, Kills, Gang (left edge of each)
    self.lblPing:SetPos(W - COL_W * 1 - self.lblPing:GetWide(), headerY)
    self.lblDeaths:SetPos(W - COL_W * 2 - self.lblDeaths:GetWide(), headerY)
    self.lblKills:SetPos(W - COL_W * 3 - self.lblKills:GetWide(), headerY)
    self.lblPing:SetFont("DefaultSmall")
    self.lblKills:SetFont("DefaultSmall")
    self.lblDeaths:SetFont("DefaultSmall")
    if GM10_IsDarkRP then
        self.lblJobName:SizeToContents()
        self.lblJobName:SetPos(W / 2 - self.lblJobName:GetWide() / 2, headerY)
        self.lblJobName:SetFont("DefaultSmall")
        self.lblRank:SizeToContents()
        self.lblRank:SetPos(6, headerY)
        self.lblRank:SetFont("DefaultSmall")
        self.lblGang:SizeToContents()
        self.lblGang:SetPos(W - COL_W * 4 - self.lblGang:GetWide(), headerY)
        self.lblGang:SetFont("DefaultSmall")
    end
end

function PANEL:ApplySchemeSettings()
    self.Hostname:SetFont("ScoreboardHeader")
    self.Description:SetFont("ScoreboardSubtitle")
    self.Hostname:SetTextColor(Color(0, 0, 0, 200))
    self.Description:SetTextColor(color_white)
    self.lblPing:SetFont("DefaultSmall")
    self.lblKills:SetFont("DefaultSmall")
    self.lblDeaths:SetFont("DefaultSmall")
    self.lblPing:SetTextColor(Color(0, 0, 0, 100))
    self.lblKills:SetTextColor(Color(0, 0, 0, 100))
    self.lblDeaths:SetTextColor(Color(0, 0, 0, 100))
    if GM10_IsDarkRP then
        self.lblJobName:SetFont("DefaultSmall")
        self.lblJobName:SetTextColor(Color(0, 0, 0, 100))
        self.lblRank:SetFont("DefaultSmall")
        self.lblRank:SetTextColor(Color(0, 0, 0, 100))
        self.lblGang:SetFont("DefaultSmall")
        self.lblGang:SetTextColor(Color(0, 0, 0, 100))
    end
end

function PANEL:UpdateScoreboard(force)
    if not force and (not SCOREBOARD or not SCOREBOARD:IsVisible()) then return end
    for k, v in pairs(SCOREBOARD.PlayerRows) do
        if not k:IsValid() then
            v:Remove()
            SCOREBOARD.PlayerRows[k] = nil
        end
    end
    local PlayerList = player.GetAll()
    for id, pl in pairs(PlayerList) do
        if not SCOREBOARD:GetPlayerRow(pl) then
            SCOREBOARD:AddPlayerRow(pl)
        end
    end
    SCOREBOARD:InvalidateLayout()
end

vgui.Register("ScoreBoard", PANEL, "Panel")
