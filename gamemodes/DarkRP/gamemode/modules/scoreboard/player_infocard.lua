-- Panel: ScorePlayerInfoCard (admin_buttons + vote_button already loaded by cl_scoreboard)
-- Shows DarkRP-style info: Rank (Player/Donator/Admin), money, Endurance level.
local PANEL = {}

surface.CreateFont("ScoreboardInfoKey",   { font = "Tahoma", size = 13, weight = 700, antialias = true })
surface.CreateFont("ScoreboardInfoValue", { font = "Tahoma", size = 13, weight = 700, antialias = true })

-- Get display rank from admin mod: Player, Donator, or Admin (Admin+SuperAdmin both show as Admin)
local function GetScoreboardRank(ply)
    if not IsValid(ply) then return "Player" end
    if ply:IsSuperAdmin() or ply:IsAdmin() then return "Admin" end
    if ply.IsUserGroup and (ply:IsUserGroup("donator") or ply:IsUserGroup("vip")) then return "Donator" end
    if ply.GetUserGroup then
        local ug = ply:GetUserGroup()
        if ug == "donator" or ug == "vip" then return "Donator" end
    end
    if FAdmin and ply.FAdmin_GetGlobal then
        local ok, val = pcall(function() return ply:FAdmin_GetGlobal("fadmin_donator") end)
        if ok and val then return "Donator" end
    end
    return "Player"
end

function PANEL:Init()
    self.InfoLabels = {}
    self.InfoLabels[1] = {}
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

function PANEL:SetInfo(column, k, v)
    -- If v is nil and we explicitly don't want to show (e.g. no gang), hide or remove that row
    if v == nil then
        if self.InfoLabels[column] and self.InfoLabels[column][k] then
            self.InfoLabels[column][k].Key:SetVisible(false)
            self.InfoLabels[column][k].Value:SetVisible(false)
        end
        return true
    end
    if not v or v == "" then v = "N/A" end
    if not self.InfoLabels[column][k] then
        self.InfoLabels[column][k] = {}
        self.InfoLabels[column][k].Key = vgui.Create("DLabel", self)
        self.InfoLabels[column][k].Value = vgui.Create("DLabel", self)
        self.InfoLabels[column][k].Key:SetFont("ScoreboardInfoKey")
        self.InfoLabels[column][k].Value:SetFont("ScoreboardInfoValue")
        self.InfoLabels[column][k].Key:SetText(k)
        self:InvalidateLayout()
    end
    self.InfoLabels[column][k].Value:SetText(tostring(v))
    if self.InfoLabels[column][k].Key then self.InfoLabels[column][k].Key:SetVisible(true) end
    if self.InfoLabels[column][k].Value then self.InfoLabels[column][k].Value:SetVisible(true) end
    local isAdmin = (k == "Rank:" and v == "Admin")
    local isDonator = (k == "Rank:" and v == "Donator")
    self.InfoLabels[column][k]._isAdmin = isAdmin
    self.InfoLabels[column][k]._isDonator = isDonator
    if isAdmin then
        self.InfoLabels[column][k].Value.Paint = function(panel)
            local pulse = 0.7 + 0.3 * math.sin(CurTime() * 3)
            local glowCol = Color(255, 50, 50, math.floor(100 * pulse))
            draw.SimpleTextOutlined("Admin", panel:GetFont(), 0, 0, Color(255, 80, 80, 255),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, glowCol)
        end
    elseif isDonator then
        self.InfoLabels[column][k].Value.Paint = function(panel)
            local pulse = 0.7 + 0.3 * math.sin(CurTime() * 3)
            local glowCol = Color(50, 255, 100, math.floor(100 * pulse))
            draw.SimpleTextOutlined("Donator", panel:GetFont(), 0, 0, Color(100, 255, 150, 255),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, glowCol)
        end
    else
        self.InfoLabels[column][k].Value.Paint = nil
    end
    return true
end

function PANEL:SetPlayer(ply)
    self.Player = ply
    self:UpdatePlayerData()
end

function PANEL:UpdatePlayerData()
    if not IsValid(self.Player) then return end
    if GM10_IsDarkRP then
        -- Rank: Player, Donator, or Admin (from our admin mod)
        local rank = GetScoreboardRank(self.Player)
        self:SetInfo(1, "Rank:", rank)
        -- Money
        local money = self.Player.getDarkRPVar and self.Player:getDarkRPVar("money")
        local moneyStr = (money ~= nil and DarkRP and DarkRP.formatMoney) and DarkRP.formatMoney(money) or tostring(money or 0)
        self:SetInfo(1, "Money:", moneyStr)
        -- Level (from leveling module)
        local level = self.Player:GetNWInt("Level", self.Player:GetNWInt("DarkRP_Level", 1))
        self:SetInfo(1, "Level:", tostring(level))
        -- SteamID
        self:SetInfo(1, "SteamID:", self.Player:SteamID() or "N/A")
        -- Gang: Paradise (Level) - only if player has a gang
        local gangName = self.Player:GetNWString("GangName", "")
        if gangName ~= "" and gangName ~= "None" then
            local gangLevel = self.Player:GetNWInt("GangLevel", 1)
            local capitalized = gangName:sub(1, 1):upper() .. gangName:sub(2):lower()
            self:SetInfo(1, "Gang:", capitalized .. " (" .. tostring(gangLevel) .. ")")
            -- Apply gang color to the value label
            local colorJSON = self.Player:GetNWString("GangColor", "")
            if colorJSON ~= "" and self.InfoLabels[1] and self.InfoLabels[1]["Gang:"] then
                local parsed = util.JSONToTable(colorJSON)
                if parsed then
                    self.InfoLabels[1]["Gang:"].Value:SetTextColor(Color(parsed.r or 255, parsed.g or 255, parsed.b or 255))
                end
            end
        else
            self:SetInfo(1, "Gang:", nil)  -- Don't show
        end
        -- Endurance level (from rp_perks, exposed via NWInt)
        local endurance = self.Player:GetNWInt("EnduranceLevel", 0)
        self:SetInfo(1, "Endurance:", tostring(endurance))
    else
        -- Fallback for non-DarkRP
        self:SetInfo(1, "Kills:", tostring(self.Player:Frags()))
        self:SetInfo(1, "Deaths:", tostring(self.Player:Deaths()))
        self:SetInfo(1, "Ping:", tostring(self.Player:Ping()))
    end
    self:InvalidateLayout()
end

function PANEL:ApplySchemeSettings()
    for _, column in pairs(self.InfoLabels) do
        for k, v in pairs(column) do
            v.Key:SetFont("ScoreboardInfoKey")
            v.Key:SetTextColor(Color(15, 15, 15, 255))
            v.Value:SetFont("ScoreboardInfoValue")
            if not v._isDonator and not v._isAdmin then
                v.Value:SetTextColor(Color(15, 15, 15, 255))
            end
        end
    end
end

function PANEL:Think()
    if self.PlayerUpdate and self.PlayerUpdate > CurTime() then return end
    self.PlayerUpdate = CurTime() + 0.25
    self:UpdatePlayerData()
end

-- Order of keys for layout (no dead space: value right after key)
local INFO_KEYS_ORDER = { "Rank:", "Money:", "Level:", "SteamID:", "Gang:", "Endurance:" }

function PANEL:PerformLayout()
    local x = 5
    for colnum, column in pairs(self.InfoLabels) do
        local y = 0
        for _, keyName in ipairs(INFO_KEYS_ORDER) do
            local v = column[keyName]
            if not v or not v.Key or not v.Key:IsVisible() then continue end
            v.Key:SetPos(x, y)
            v.Key:SizeToContents()
            local keyW = v.Key:GetWide()
            v.Value:SetPos(x + keyW + 4, y)  -- 4px gap, no dead space
            v.Value:SizeToContents()
            y = y + math.max(v.Key:GetTall(), v.Value:GetTall()) + 2
        end
    end
    if not self.Player or self.Player == LocalPlayer() or not LocalPlayer():IsAdmin() then
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

function PANEL:Paint()
    return true
end

vgui.Register("ScorePlayerInfoCard", PANEL, "Panel")
