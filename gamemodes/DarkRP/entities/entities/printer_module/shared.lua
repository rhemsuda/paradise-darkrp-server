-- Printer module (placeholder). Can be extended to connect to printers for bonuses.
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Printer Module"
ENT.Author = "Paradise DarkRP"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "owning_ent")
end
