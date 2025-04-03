ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Diamond"
ENT.Author = "Nick"
ENT.Spawnable = true
ENT.Category = "Resources"

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ResourceType")
    self:NetworkVar("Int", 0, "Amount")
end