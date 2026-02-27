-- Panel: SpawnMenuAdminButton + Kick/Ban (loaded by cl_scoreboard.lua)
local PANEL = {}

function PANEL:DoClick(x, y)
    if not self:GetParent().Player or LocalPlayer() == self:GetParent().Player then return end
    self:DoCommand(self:GetParent().Player)
    timer.Simple(0.1, SCOREBOARD.UpdateScoreboard, SCOREBOARD)
end

function PANEL:Paint()
    local bgColor = Color(0, 0, 0, 10)
    if self.Selected then
        bgColor = Color(0, 200, 255, 255)
    elseif self.Armed then
        bgColor = Color(255, 255, 0, 255)
    end
    draw.RoundedBox(4, 0, 0, self:GetWide(), self:GetTall(), bgColor)
    draw.SimpleText(self.Text, "DefaultSmall", self:GetWide() / 2, self:GetTall() / 2, Color(0, 0, 0, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    return true
end

vgui.Register("SpawnMenuAdminButton", PANEL, "Button")

PANEL = {}
PANEL.Text = "Kick"
function PANEL:DoCommand(ply)
    LocalPlayer():ConCommand("kickid2 " .. ply:UserID() .. "\n")
end
vgui.Register("PlayerKickButton", PANEL, "SpawnMenuAdminButton")

PANEL = {}
PANEL.Text = "PermBan"
function PANEL:DoCommand(ply)
    LocalPlayer():ConCommand("banid2 0 " .. self:GetParent().Player:UserID() .. "\n")
    LocalPlayer():ConCommand("kickid2 " .. ply:UserID() .. " \"Permabanned\"\n")
end
vgui.Register("PlayerPermBanButton", PANEL, "SpawnMenuAdminButton")

PANEL = {}
PANEL.Text = "1hr Ban"
function PANEL:DoCommand(ply)
    LocalPlayer():ConCommand("banid2 60 " .. self:GetParent().Player:UserID() .. "\n")
    LocalPlayer():ConCommand("kickid2 " .. ply:UserID() .. " \"Banned for 1 hour\"\n")
end
vgui.Register("PlayerBanButton", PANEL, "SpawnMenuAdminButton")
