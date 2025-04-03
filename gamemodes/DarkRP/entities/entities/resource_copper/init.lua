AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Copper"
ENT.Author = "Nick"
ENT.Spawnable = true
ENT.Category = "Resources"

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
    self:SetNWString("ResourceType", "copper")
    self:SetNWInt("Amount", 1)
    -- Apply material and color
    self:SetMaterial("models/shiny")
    self:SetColor(Color(184, 115, 51)) -- Copper color
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    local resourceID = self:GetNWString("ResourceType")
    local amount = self:GetNWInt("Amount")
    print("[Debug] resource_copper: Use called with resourceID = " .. tostring(resourceID) .. ", amount = " .. tostring(amount))
    if resourceID and resourceID != "" and amount > 0 then
        if SERVER then
            if AddResourceToInventory then
                print("[Debug] resource_copper: Calling AddResourceToInventory for " .. activator:Nick() .. " with " .. resourceID .. " x" .. amount)
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
        print("[Debug] resource_copper: Invalid resourceID or amount!")
    end
end