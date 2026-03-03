AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
    self:SetModel(self:GetModel() ~= "models/error.mdl" and self:GetModel() or "models/props_junk/rock001a.mdl")
    if DarkRP and DarkRP.ValidatedPhysicsInit then
        DarkRP.ValidatedPhysicsInit(self, SOLID_VPHYSICS)
    else
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
    end
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if self.USED then return end
    local resourceID = self:GetNWString("ResourceType", "")
    local amount = self:GetNWInt("Amount", 1)
    if resourceID == "" or amount < 1 then return end
    if not ResourceItems or not ResourceItems[resourceID] then return end
    self.USED = true
    if AddResourceToInventory then
        AddResourceToInventory(activator, resourceID, amount, true)
    end
    if SendResourcesMessagePickedUp then
        SendResourcesMessagePickedUp(activator, resourceID, amount)
    end
    self:Remove()
end
