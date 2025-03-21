AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function SWEP:Initialize()
    self:SetHoldType("normal") -- Set how the weapon is held
end

function SWEP:PrimaryAttack()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    net.Start("OpenInventory") -- Open inventory UI on left-click
    net.Send(ply)
end

function SWEP:SecondaryAttack()
end