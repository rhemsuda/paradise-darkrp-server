include("shared.lua")

function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:DrawHUD()
    draw.SimpleText("Left-click to open inventory", "DermaDefault", ScrW() / 2, ScrH() - 50, Color(255, 255, 255), TEXT_ALIGN_CENTER)
end