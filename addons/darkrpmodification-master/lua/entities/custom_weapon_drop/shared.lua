ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Custom Weapon Drop"
ENT.Author = ""
ENT.Spawnable = true
ENT.Category = "DarkRP"
ENT.Model = "models/props_junk/cardboard_box001a.mdl" -- Default model to avoid error.mdl

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "WeaponClass")
    self:NetworkVar("String", 1, "WeaponName")
    self:NetworkVar("String", 2, "WeaponModel")
end