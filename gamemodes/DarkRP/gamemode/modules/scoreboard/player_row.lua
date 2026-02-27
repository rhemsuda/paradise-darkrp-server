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

-- Most-clicked icon: Star=admin, Heart=donator, else highest rating count
local function GetMostClickedIcon(ply)
    if not IsValid(ply) then return texRatings["none"] end
    if ply:IsSuperAdmin() or ply:IsAdmin() then return texRatings["star"] end
    if ply.IsUserGroup and (ply:IsUserGroup("donator") or ply:IsUserGroup("vip")) then return texRatings["love"] end
    if ply.GetUserGroup then
        local ug = ply:GetUserGroup()
        if ug == "donator" or ug == "vip" then return texRatings["love"] end
    end
    if FAdmin and ply.FAdmin_GetGlobal then
        local ok, val = pcall(function() return ply:FAdmin_GetGlobal("fadmin_donator") end)
        if ok and val then return texRatings["love"] end
    end
    local best, bestName = 0, "none"
    for _, name in ipairs({"smile", "love", "artistic", "star", "builder", "bad"}) do
        local c = ply:GetNW2Int("Rating." .. name, 0)
        if c > best then best, bestName = c, name end
    end
    return texRatings[bestName] or texRatings["none"]
end

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
    if self.texRating then
        surface.SetMaterial(self.texRating)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(4, 4, 16, 16)
    end
    return true
end

function PANEL:SetPlayer(ply)
    self.Player = ply
    self.infoCard:SetPlayer(ply)
    self:UpdatePlayerData()
end

function PANEL:UpdatePlayerData()
    if not self.Player or not IsValid(self.Player) then return end
    self.lblName:SetText(self.Player:Nick())
    self.texRating = GetMostClickedIcon(self.Player)
    if GM10_IsDarkRP then
        self.lblJob:SetText(team.GetName(self.Player:Team()))
        local gangRaw = self.Player:GetNWString("GangName", "")
        local gangText = (gangRaw == "" or gangRaw == "None") and "" or gangRaw
        self.lblGang:SetText(gangText)
        if gangText ~= "" then
            local colorJSON = self.Player:GetNWString("GangColor", "")
            local gangCol = color_white
            if colorJSON ~= "" then
                local parsed = util.JSONToTable(colorJSON)
                if parsed then gangCol = Color(parsed.r or 255, parsed.g or 255, parsed.b or 255) end
            end
            self.lblGang:SetTextColor(gangCol)
        else
            self.lblGang:SetTextColor(color_white)
        end
    end
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
    self.lblPing = vgui.Create("DLabel", self)
    self.lblName:SetMouseInputEnabled(false)
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
    self.lblPing:SetFont("ScoreboardPlayerName")
    self.lblName:SetTextColor(color_white)
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
    local COLUMN_SIZE = 50  -- Same as original gmod10_scoreboard; row uses left-edge at column boundary
    local ICON_W = 24  -- Icon column before name
    local W = self:GetWide()
    -- Original: lblPing/Deaths/Frags at self:GetWide() - COLUMN_SIZE*n (left edge of text at column start)
    self.lblName:SizeToContents()
    self.lblName:SetPos(ICON_W, 3)
    if GM10_IsDarkRP then
        self.lblJob:SizeToContents()
        self.lblJob:SetPos(W / 2 - self.lblJob:GetWide() / 2, 3)
        if self.lblGang then
            self.lblGang:SizeToContents()
            self.lblGang:SetPos(W - COLUMN_SIZE * 3 - self.lblGang:GetWide() / 2, 3)
        end
    end
    self.lblPing:SetPos(W - COLUMN_SIZE * 1, 3)
    if self.Open or self.Size ~= self.TargetSize then
        self.infoCard:SetVisible(true)
        self.infoCard:SetPos(ICON_W, self.lblName:GetTall() + 10)
        self.infoCard:SetSize(self:GetWide() - ICON_W - 8, self:GetTall() - self.lblName:GetTall() - 10)
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
