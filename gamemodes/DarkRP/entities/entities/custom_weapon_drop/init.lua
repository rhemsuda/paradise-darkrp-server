AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self:GetWeaponModel() or self:GetModel() or "models/props_junk/cardboard_box001a.mdl")
    DarkRP.ValidatedPhysicsInit(self, SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    local class = self:GetWeaponClass()
    if not class or class == "" then return end
    local wep = activator:Give(class, true)
    if IsValid(wep) then
        DarkRP.notify(activator, 0, 4, "Picked up " .. (self:GetWeaponName() or class))
        self:Remove()
    end
end
