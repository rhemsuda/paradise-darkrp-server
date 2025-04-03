AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_junk/rock001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
    self:SetNWInt("Amount", 1) -- Default amount
end

function ENT:SetResourceType(resourceID)
    self:SetNWString("ResourceType", resourceID)
end

function ENT:SetAmount(amount)
    self:SetNWInt("Amount", amount)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    local resourceID = self:GetNWString("ResourceType") -- Direct access for debugging
    local amount = self:GetNWInt("Amount")
    print("[Debug] resource_sapphire: Use called with resourceID = " .. tostring(resourceID) .. ", amount = " .. tostring(amount))
    if resourceID and resourceID != "" and amount > 0 then
        if SERVER then
            if AddResourceToInventory then
                print("[Debug] resource_sapphire: Calling AddResourceToInventory for " .. activator:Nick() .. " with " .. resourceID .. " x" .. amount)
                AddResourceToInventory(activator, resourceID, amount, true)
                activator:EmitSound("items/ammopickup.wav")
                local resourceData = ResourceItems[resourceID] or { name = resourceID }
                local displayName = resourceData.name or (string.upper(resourceID:sub(1,1)) .. resourceID:sub(2))
                activator:ChatPrint("[Inventory] Picked up " .. amount .. " " .. displayName .. ".")
                self:Remove()
            else
                print("[ERROR] AddResourceToInventory is not defined!")
            end
        end
    else
        print("[Debug] resource_sapphire: Invalid resourceID or amount!")
    end
end