-- gamemodes/DarkRP/entities/entities/resource_item/shared.lua

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Resource Item"
ENT.Author = "Paradise V1"
ENT.Spawnable = false
ENT.AdminSpawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ResourceType")
end