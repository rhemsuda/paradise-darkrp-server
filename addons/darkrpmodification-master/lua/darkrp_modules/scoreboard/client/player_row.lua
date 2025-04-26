include("player_infocard.lua")

surface.CreateFont("ScoreboardPlayerName", {font = "coolvetica", size = 20, weight = 500, antialias = true})

local texGradient = surface.GetTextureID("gui/center_gradient")

-- Rank icons
local rankIcons = {}
rankIcons["admin"] = Material("icon16/star.png")
rankIcons["donator"] = Material("icon16/heart.png")
rankIcons["super_donator"] = Material("icon16/heart.png")  -- Will tint green

-- Debug helper function
local function DebugPrint(...)
    if GetConVar("rp_debug") and GetConVar("rp_debug"):GetInt() == 1 then
        print("[SCOREBOARD MODULE]", ...)
    end
end

local PANEL = {}

function PANEL:Init()
    self.Size = 24
    self:OpenInfo(false)

    self.Player = nil
    self:SetVisible(true)

    self.infoCard = vgui.Create("ScorePlayerInfoCard", self)

    self.lblName = vgui.Create("DLabel", self)
    self.lblGang = vgui.Create("DLabel", self)
    if GM10_IsDarkRP then
        self.lblJob = vgui.Create("DLabel", self)
    end
    self.lblPing = vgui.Create("DLabel", self)

    self.lblName:SetMouseInputEnabled(false)
    self.lblGang:SetMouseInputEnabled(false)
    if GM10_IsDarkRP then
        self.lblJob:SetMouseInputEnabled(false)
    end
    self.lblPing:SetMouseInputEnabled(false)

    self.rankIcon = nil
    self.rankIconColor = Color(255, 255, 255, 255)
end

function PANEL:SetPlayer(ply)
    self.Player = ply
    self.infoCard:SetPlayer(ply)
    self:UpdatePlayerData()
end

function PANEL:UpdatePlayerData()
    if not self.Player or not IsValid(self.Player) then return end

    self.lblName:SetText(self.Player:Nick())
    self.lblGang:SetText("testtest")  -- Placeholder, to be replaced with actual gang retrieval
    if GM10_IsDarkRP then
        local job = self.Player:getDarkRPVar("job") or "Unknown"
        DebugPrint("Player job for " .. self.Player:Nick() .. ": " .. tostring(job))
        job = string.gsub(job, "^Label", "")
        if string.match(job, "^Label") then
            DebugPrint("WARNING: Job still contains 'Label' after gsub: " .. tostring(job))
            job = "Citizen"
        end
        self.lblJob:SetText(job)
    end

    -- Determine rank icon
    if self.Player:IsAdmin() then
        self.rankIcon = rankIcons["admin"]
        self.rankIconColor = Color(255, 255, 255, 255)
    elseif self.Player:IsUserGroup("super_donator") then
        self.rankIcon = rankIcons["super_donator"]
        self.rankIconColor = Color(0, 255, 0, 255)  -- Green for super donator
    elseif self.Player:IsUserGroup("donator") then
        self.rankIcon = rankIcons["donator"]
        self.rankIconColor = Color(255, 255, 255, 255)
    else
        self.rankIcon = nil
        self.rankIconColor = Color(255, 255, 255, 255)
    end

    self.lblPing:SetText(self.Player:Ping())
end

function PANEL:ApplySchemeSettings()
    self.lblName:SetFont("ScoreboardPlayerName")
    self.lblGang:SetFont("ScoreboardPlayerName")
    if GM10_IsDarkRP then
        self.lblJob:SetFont("ScoreboardPlayerName")
        self.lblJob:SetTextColor(color_white)
    end
    self.lblPing:SetFont("ScoreboardPlayerName")

    self.lblName:SetTextColor(color_white)
    self.lblGang:SetTextColor(Color(255, 0, 0, 255))  -- Red for gang, matching previous screenshot
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
    if bool then
        self.TargetSize = 150
    else
        self.TargetSize = 24
    end
    self.Open = bool
end

function PANEL:Think()
    if self.Size ~= self.TargetSize then
        self.Size = math.Approach(self.Size, self.TargetSize, (math.abs(self.Size - self.TargetSize) + 1) * 10 * FrameTime())
        self:PerformLayout()
        SCOREBOARD:InvalidateLayout()
    end

    if not self.PlayerUpdate or self.PlayerUpdate < CurTime() then
        self.PlayerUpdate = CurTime() + 0.5
        self:UpdatePlayerData()
    end
end

function PANEL:Paint(w, h)
    if not IsValid(self.Player) then
        DebugPrint("Player invalid in Paint for " .. tostring(self.Player))
        return true
    end

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

    if self.Armed then
        color = Color(110, 160, 245, 255)
    end
    if self.Selected then
        color = Color(50, 100, 245, 255)
    end
    if self.Player == LocalPlayer() then
        color.r = color.r + math.sin(CurTime() * 8) * 10
        color.g = color.g + math.sin(CurTime() * 8) * 10
        color.b = color.b + math.sin(CurTime() * 8) * 10
    end

    if self.Open or self.Size ~= self.TargetSize then
        draw.RoundedBox(4, 0, 16, w, h - 16, color)
        draw.RoundedBox(4, 2, 16, w - 4, h - 16 - 2, Color(250, 250, 245, 255))
        surface.SetTexture(texGradient)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(2, 16, w - 4, h - 16 - 2)
    end

    draw.RoundedBox(4, 0, 0, w, 24, color)
    surface.SetTexture(texGradient)
    surface.SetDrawColor(255, 255, 255, 50)
    surface.DrawTexturedRect(0, 0, w, 24)

    -- Draw rank icon centered between Job and Ping
    if self.rankIcon then
        surface.SetMaterial(self.rankIcon)
        surface.SetDrawColor(self.rankIconColor)
        local iconX = 826.3 - 8  -- Center the 16x16 icon at x = 826.3 (midpoint between 581.6 and 1071)
        surface.DrawTexturedRect(iconX, 4, 16, 16)
    end

    return true
end

function PANEL:PerformLayout()
    self:SetSize(self:GetWide(), self.Size)

    -- Name (left-aligned)
    self.lblName:SizeToContents()
    self.lblName:SetPos(16, 3)

    -- Gang (centered under header at x = 431.6)
    self.lblGang:SizeToContents()
    local gangWidth = self.lblGang:GetWide()
    self.lblGang:SetPos(431.6 - gangWidth / 2, 3)

    -- Job (centered under header at x = 581.6)
    if GM10_IsDarkRP then
        self.lblJob:SizeToContents()
        local jobWidth = self.lblJob:GetWide()
        self.lblJob:SetPos(581.6 - jobWidth / 2, 3)
    end

    -- Ping (centered under header)
    local rowWidth = self:GetWide()  -- 1126
    local padding = 15
    self.lblPing:SizeToContents()
    local pingWidth = self.lblPing:GetWide()
    self.lblPing:SetPos(rowWidth - pingWidth - padding - (pingWidth / 2), 3)  -- Center under the header

    -- Info card visibility and positioning
    if self.Open or self.Size != self.TargetSize then
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