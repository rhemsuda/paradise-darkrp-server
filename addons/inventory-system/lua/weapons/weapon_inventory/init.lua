AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:PrimaryAttack()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    -- Send a net message to the client to open the inventory UI
    net.Start("OpenInventory")
    net.Send(ply)
end

function SWEP:SecondaryAttack()
    -- Optional: Add secondary functionality later
end