-- Printer module (placeholder). Can be extended to connect to printers for bonuses.
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Printer Module"
ENT.Author = "Paradise DarkRP"
ENT.Spawnable = false

-- Cooler can cool up to 8 printers; owner's printers are prioritized
function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "owning_ent")
    self:NetworkVar("Bool", 1, "Active")
    self:NetworkVar("Float", 1, "TimeLeft")
    self:NetworkVar("Entity", 2, "ConnectedPrinter")   -- slot 1 (legacy name kept)
    self:NetworkVar("Entity", 3, "ConnectedPrinter2")
    self:NetworkVar("Entity", 4, "ConnectedPrinter3")
    self:NetworkVar("Entity", 5, "ConnectedPrinter4")
    self:NetworkVar("Entity", 6, "ConnectedPrinter5")
    self:NetworkVar("Entity", 7, "ConnectedPrinter6")
    self:NetworkVar("Entity", 8, "ConnectedPrinter7")
    self:NetworkVar("Entity", 9, "ConnectedPrinter8")
end
