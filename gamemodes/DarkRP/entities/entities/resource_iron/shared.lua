ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Iron"
ENT.Author = "Paradise V1"
ENT.Spawnable = false
ENT.AdminSpawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ResourceType")
    self:NetworkVar("Int", 0, "Amount")
end