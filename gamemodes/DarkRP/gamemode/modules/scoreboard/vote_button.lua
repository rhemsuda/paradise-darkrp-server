-- Panel: SpawnMenuVoteButton (loaded by cl_scoreboard.lua)
local PANEL = {}

PANEL.VoteName = "none"
PANEL.MaterialName = "exclamation"

function PANEL:Init()
    self.Label = vgui.Create("DLabel", self)
    self:ApplySchemeSettings()
end

function PANEL:DoClick(x, y)
    local ply = self:GetParent().Player
    if not ply or not IsValid(ply) or ply == LocalPlayer() then return end
    LocalPlayer():ConCommand("rateuser " .. ply:EntIndex() .. " " .. self.VoteName .. "\n")
end

function PANEL:ApplySchemeSettings()
    self.Label:SetFont("DefaultSmall")
    self.Label:SetTextColor(Color(0, 0, 0, 150))
    self.Label:SetMouseInputEnabled(false)
end

function PANEL:PerformLayout()
    if self:GetParent().Player and self:GetParent().Player:IsValid() then
        self.Label:SetText(self:GetParent().Player:GetNW2Int("Rating." .. self.VoteName, 0))
    end
    self.Label:SizeToContents()
    self.Label:SetPos((self:GetWide() - self.Label:GetWide()) / 2, self:GetTall() - self.Label:GetTall())
end

function PANEL:SetUp(mat, votename, nicename)
    self.MaterialName = mat
    self.VoteName = votename
    self.NiceName = nicename
    self:SetToolTip(self.NiceName)
end

function PANEL:Paint()
    if not self.Material then
        self.Material = Material("icon16/" .. self.MaterialName .. ".png")
    end
    local bgColor = Color(0, 0, 0, 10)
    if self.Selected then
        bgColor = Color(0, 200, 255, 255)
    elseif self.Armed then
        bgColor = Color(255, 255, 0, 255)
    end
    draw.RoundedBox(4, 0, 0, self:GetWide(), self:GetTall(), bgColor)
    local alpha = self.Armed and 255 or 200
    surface.SetMaterial(self.Material)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawTexturedRect(self:GetWide() / 2 - 8, self:GetWide() / 2 - 8, 16, 16)
    return true
end

vgui.Register("SpawnMenuVoteButton", PANEL, "Button")
