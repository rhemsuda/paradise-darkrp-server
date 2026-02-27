-- Panel: ScorePlayerRow (player_infocard already loaded by cl_scoreboard)
surface.CreateFont("ScoreboardPlayerName", { font = "coolvetica", size = 20, weight = 500, antialias = true })
local texGradient = surface.GetTextureID("gui/center_gradient")
local texRatings = {}
texRatings["none"] = Material("icon16/user.png")
texRatings["smile"] = Material("icon16/emoticon_smile.png")
texRatings["bad"] = Material("icon16/exclamation.png")
texRatings["love"] = Material("icon16/heart.png")
texRatings["artistic"] = Material("icon16/palette.png")
texRatings["star"] = Material("icon16/star.png")
texRatings["builder"] = Material("icon16/wrench.png")

local PANEL = {}

function PANEL:Paint()
    if not IsValid(self.Player) then return end
    local color = color_white
    if GM10_IsDarkRP then
        color = team.GetColor(self.Player:Team())
    else
        color = Color(100, 150, 245, 255)
        if self.Player:Team() == TEAM_CONNECTING then
            color = Color(200, 120, 50, 255)
        elseif self.Player:IsAdmin() then
            color = Color(30, 200, 50, 255)
        elseif self.Player:SteamID() == "STEAM_0:1:16806171" then
            color = Color(255, 105, 180, 255)
        end
    end
    if self.Armed then color = Color(110, 160, 245, 255) end
    if self.Selected then color = Color(50, 100, 245, 255) end
    if self.Player == LocalPlayer() then
        color.r = color.r + math.sin(CurTime() * 8) * 10
        color.g = color.g + math.sin(CurTime() * 8) * 10
        color.b = color.b + math.sin(CurTime() * 8) * 10
    end
    if self.Open or self.Size ~= self.TargetSize then
        draw.RoundedBox(6, 0, 16, self:GetWide(), self:GetTall() - 16, color)
        draw.RoundedBox(6, 2, 16, self:GetWide() - 4, self:GetTall() - 16 - 2, Color(250, 250, 245, 255))
        surface.SetTexture(texGradient)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(2, 16, self:GetWide() - 4, self:GetTall() - 16 - 2)
    end
    draw.RoundedBox(6, 0, 0, self:GetWide(), 24, color)
    surface.SetTexture(texGradient)
    surface.SetDrawColor(255, 255, 255, 50)
    surface.DrawTexturedRect(0, 0, self:GetWide(), 24)
    surface.SetMaterial(self.texRating)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(4, 4, 16, 16)
    return true
end

function PANEL:SetPlayer(ply)
    self.Player = ply
    self.infoCard:SetPlayer(ply)
    self:UpdatePlayerData()
end

function PANEL:CheckRating(name, count)
    if self.Player:GetNW2Int("Rating." .. name, 0) > count then
        count = self.Player:GetNW2Int("Rating." .. name, 0)
        self.texRating = texRatings[name]
    end
    return count
end

-- DarkRP rank: show Star for admin, Heart for donator, else user icon
local function GetDarkRPRankIcon(ply)
    if not IsValid(ply) then return texRatings["none"] end
    if ply:IsSuperAdmin() or ply:IsAdmin() then return texRatings["star"] end
    if ULX and ply.IsUserGroup and ply:IsUserGroup("donator") then return texRatings["love"] end
    if FAdmin and ply.FAdmin_GetGlobal then
        local ok, val = pcall(function() return ply:FAdmin_GetGlobal("fadmin_donator") end)
        if ok and val then return texRatings["love"] end
    end
    return texRatings["none"]
end

function PANEL:UpdatePlayerData()
    if not self.Player or not IsValid(self.Player) then return end
    self.lblName:SetText(self.Player:Nick())
    if GM10_IsDarkRP then
        self.lblJob:SetText(team.GetName(self.Player:Team()))
        self.texRating = GetDarkRPRankIcon(self.Player)
        local gangRaw = self.Player:GetNWString("GangName", "")
        self.lblGang:SetText((gangRaw == "" or gangRaw == "None") and "" or gangRaw)
    else
        self.texRating = texRatings["none"]
        local count = 0
        count = self:CheckRating("smile", count)
        count = self:CheckRating("love", count)
        count = self:CheckRating("artistic", count)
        count = self:CheckRating("star", count)
        count = self:CheckRating("builder", count)
        count = self:CheckRating("bad", count)
    end
    self.lblFrags:SetText(self.Player:Frags())
    self.lblDeaths:SetText(self.Player:Deaths())
    self.lblPing:SetText(self.Player:Ping())
end

function PANEL:Init()
    self.Size = 24
    self:OpenInfo(false)
    self.infoCard = vgui.Create("ScorePlayerInfoCard", self)
    self.lblName = vgui.Create("DLabel", self)
    if GM10_IsDarkRP then
        self.lblJob = vgui.Create("DLabel", self)
        self.lblJob:SetMouseInputEnabled(false)
        self.lblGang = vgui.Create("DLabel", self)
        self.lblGang:SetMouseInputEnabled(false)
    end
    self.lblFrags = vgui.Create("DLabel", self)
    self.lblDeaths = vgui.Create("DLabel", self)
    self.lblPing = vgui.Create("DLabel", self)
    self.lblName:SetMouseInputEnabled(false)
    self.lblFrags:SetMouseInputEnabled(false)
    self.lblDeaths:SetMouseInputEnabled(false)
    self.lblPing:SetMouseInputEnabled(false)
end

function PANEL:ApplySchemeSettings()
    self.lblName:SetFont("ScoreboardPlayerName")
    if GM10_IsDarkRP then
        self.lblJob:SetFont("ScoreboardPlayerName")
        self.lblJob:SetTextColor(color_white)
        if self.lblGang then
            self.lblGang:SetFont("ScoreboardPlayerName")
            self.lblGang:SetTextColor(color_white)
        end
    end
    self.lblFrags:SetFont("ScoreboardPlayerName")
    self.lblDeaths:SetFont("ScoreboardPlayerName")
    self.lblPing:SetFont("ScoreboardPlayerName")
    self.lblName:SetTextColor(color_white)
    self.lblFrags:SetTextColor(color_white)
    self.lblDeaths:SetTextColor(color_white)
    self.lblPing:SetTextColor(color_white)
end

function PANEL:DoClick(x, y)
    if self.Open then
        surface.PlaySound("ui/buttonclickrelease.wav")
    else
        surface.PlaySound("ui/buttonclick.wav")
    end
    self:OpenInfo(not self.Open)
end

function PANEL:OpenInfo(bool)
    self.TargetSize = bool and 150 or 24
    self.Open = bool
end

function PANEL:Think()
    if self.Size ~= self.TargetSize then
        self.Size = math.Approach(self.Size, self.TargetSize, (math.abs(self.Size - self.TargetSize) + 1) * 10 * FrameTime())
        self:PerformLayout()
        if SCOREBOARD then SCOREBOARD:InvalidateLayout() end
    end
    if not self.PlayerUpdate or self.PlayerUpdate < CurTime() then
        self.PlayerUpdate = CurTime() + 0.5
        self:UpdatePlayerData()
    end
end

function PANEL:PerformLayout()
    self:SetSize(self:GetWide(), self.Size)
    local W = self:GetWide()
    local COL = 50
    -- Rank column: fixed width so icon sits under "Rank" header; name starts after it
    local RANK_COL_W = 28
    self.lblName:SizeToContents()
    self.lblName:SetPos(RANK_COL_W, 3)
    if GM10_IsDarkRP then
        self.lblJob:SizeToContents()
        local jobW = self.lblJob:GetWide()
        self.lblJob:SetPos(W / 2 - jobW / 2, 3)
        if self.lblGang then
            self.lblGang:SizeToContents()
            -- Use scoreboard width so Gang/Kills/Deaths/Ping line up with headers (row is 10px narrower)
            local sbW = (SCOREBOARD and IsValid(SCOREBOARD)) and SCOREBOARD:GetWide() or W
            local rowOffset = sbW - W
            self.lblGang:SetPos(sbW - COL * 4 - self.lblGang:GetWide() - rowOffset, 3)
        end
    end
    local sbW = (SCOREBOARD and IsValid(SCOREBOARD)) and SCOREBOARD:GetWide() or W
    local rowOffset = sbW - W
    self.lblPing:SetPos(sbW - COL * 1 - self.lblPing:GetWide() - rowOffset, 3)
    self.lblDeaths:SetPos(sbW - COL * 2 - self.lblDeaths:GetWide() - rowOffset, 3)
    self.lblFrags:SetPos(sbW - COL * 3 - self.lblFrags:GetWide() - rowOffset, 3)
    if self.Open or self.Size ~= self.TargetSize then
        self.infoCard:SetVisible(true)
        self.infoCard:SetPos(4, self.lblName:GetTall() + 10)
        self.infoCard:SetSize(self:GetWide() - 8, self:GetTall() - self.lblName:GetTall() - 10)
    else
        self.infoCard:SetVisible(false)
    end
end

function PANEL:HigherOrLower(row)
    if not IsValid(self.Player) or self.Player:Team() == TEAM_CONNECTING then return false end
    if not IsValid(row.Player) or row.Player:Team() == TEAM_CONNECTING then return true end
    if self.Player:Frags() == row.Player:Frags() then
        return self.Player:Deaths() < row.Player:Deaths()
    end
    return self.Player:Frags() > row.Player:Frags()
end

vgui.Register("ScorePlayerRow", PANEL, "Button")
