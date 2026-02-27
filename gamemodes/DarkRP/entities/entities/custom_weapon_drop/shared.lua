-- Dropped weapon from Entities menu. Player picks up with Use (E).
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Dropped Weapon"
ENT.Author = "Paradise DarkRP"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "WeaponClass")
    self:NetworkVar("String", 1, "WeaponName")
    self:NetworkVar("String", 2, "WeaponModel")
end
