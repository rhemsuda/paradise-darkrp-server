include("admin_buttons.lua")
include("vote_button.lua")

local PANEL = {}

/*---------------------------------------------------------
   Name: Init
---------------------------------------------------------*/
function PANEL:Init()
    self.InfoLabels = {}

    self.btnKick = vgui.Create("PlayerKickButton", self)
    self.btnBan = vgui.Create("PlayerBanButton", self)
    self.btnPBan = vgui.Create("PlayerPermBanButton", self)

    self.VoteButtons = {}

    self.VoteButtons[1] = vgui.Create("SpawnMenuVoteButton", self)
    self.VoteButtons[1]:SetUp("exclamation", "bad", "This player is naughty!")

    self.VoteButtons[2] = vgui.Create("SpawnMenuVoteButton", self)
    self.VoteButtons[2]:SetUp("emoticon_smile", "smile", "I like this player!")

    self.VoteButtons[3] = vgui.Create("SpawnMenuVoteButton", self)
    self.VoteButtons[3]:SetUp("heart", "love", "I love this player!")

    self.VoteButtons[4] = vgui.Create("SpawnMenuVoteButton", self)
    self.VoteButtons[4]:SetUp("palette", "artistic", "This player is artistic!")

    self.VoteButtons[5] = vgui.Create("SpawnMenuVoteButton", self)
    self.VoteButtons[5]:SetUp("star", "star", "Wow! Gold star for you!")

    self.VoteButtons[6] = vgui.Create("SpawnMenuVoteButton", self)
    self.VoteButtons[6]:SetUp("wrench", "builder", "Good at building!")
end

/*---------------------------------------------------------
   Name: SetInfo
---------------------------------------------------------*/
function PANEL:SetInfo(k, v)
    if (!v || v == "") then v = "N/A" end

    if (!self.InfoLabels[k]) then
        self.InfoLabels[k] = {}
        self.InfoLabels[k].Key = vgui.Create("DLabel", self)
        self.InfoLabels[k].Value = vgui.Create("DLabel", self)
        self.InfoLabels[k].Key:SetText(k)
        self:InvalidateLayout()
    end

    self.InfoLabels[k].Value:SetText(v)
    return true
end

/*---------------------------------------------------------
   Name: SetPlayer
---------------------------------------------------------*/
function PANEL:SetPlayer(ply)
    self.Player = ply
    self:UpdatePlayerData()
end

/*---------------------------------------------------------
   Name: UpdatePlayerData
---------------------------------------------------------*/
function PANEL:UpdatePlayerData()
    if (!IsValid(self.Player)) then return end

    -- SteamID
    self:SetInfo("SteamID:", self.Player:SteamID())

    -- Money (DarkRP)
    local money = self.Player:getDarkRPVar("money") or 0
    self:SetInfo("Money:", DarkRP.formatMoney(money))

    -- Perk Points (placeholder)
    self:SetInfo("Perk Points:", "0")

    -- Gang Level (if in a gang)
    local gangName = "testtest"  -- Placeholder from player_row.lua
    if (gangName and gangName ~= "testtest") then
        self:SetInfo("Gang Level:", "N/A")  -- Placeholder until gang system details are provided
    end

    -- Props (includes props, ragdolls, effects)
    self:SetInfo("Props:", self.Player:GetCount("props") + self.Player:GetCount("ragdolls") + self.Player:GetCount("effects"))

    -- Entities (SENTs)
    self:SetInfo("Entities:", self.Player:GetCount("sents"))

    self:InvalidateLayout()
end

/*---------------------------------------------------------
   Name: ApplySchemeSettings
---------------------------------------------------------*/
function PANEL:ApplySchemeSettings()
    for k, v in pairs(self.InfoLabels) do
        v.Key:SetTextColor(Color(0, 0, 0, 100))
        v.Value:SetTextColor(Color(0, 70, 0, 200))
    end
end

/*---------------------------------------------------------
   Name: Think
---------------------------------------------------------*/
function PANEL:Think()
    if (self.PlayerUpdate && self.PlayerUpdate > CurTime()) then return end
    self.PlayerUpdate = CurTime() + 0.25

    self:UpdatePlayerData()
end

/*---------------------------------------------------------
   Name: PerformLayout
---------------------------------------------------------*/
function PANEL:PerformLayout()
    local x = 5
    local y = 0

    for k, v in pairs(self.InfoLabels) do
        v.Key:SetPos(x, y)
        v.Key:SizeToContents()

        v.Value:SetPos(x + 70, y)
        v.Value:SizeToContents()

        y = y + v.Key:GetTall() + 2
    end

    if (!self.Player || self.Player == LocalPlayer() || !LocalPlayer():IsAdmin()) then
        self.btnKick:SetVisible(false)
        self.btnBan:SetVisible(false)
        self.btnPBan:SetVisible(false)
    else
        self.btnKick:SetVisible(true)
        self.btnBan:SetVisible(true)
        self.btnPBan:SetVisible(true)

        self.btnKick:SetPos(self:GetWide() - 52 * 3, 90)
        self.btnKick:SetSize(48, 20)

        self.btnBan:SetPos(self:GetWide() - 52 * 2, 90)
        self.btnBan:SetSize(48, 20)

        self.btnPBan:SetPos(self:GetWide() - 52 * 1, 90)
        self.btnPBan:SetSize(48, 20)
    end

    for k, v in ipairs(self.VoteButtons) do
        v:InvalidateLayout()
        v:SetPos(self:GetWide() - k * 25, 0)
        v:SetSize(20, 32)
    end
end

/*---------------------------------------------------------
   Name: Paint
---------------------------------------------------------*/
function PANEL:Paint()
    return true
end

vgui.Register("ScorePlayerInfoCard", PANEL, "Panel")