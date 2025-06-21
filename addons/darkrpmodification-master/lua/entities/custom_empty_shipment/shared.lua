ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Custom Empty Shipment"
ENT.Author = "Your Name"
ENT.Spawnable = true
ENT.AdminSpawnable = false
ENT.Model = "models/Items/item_item_crate.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "TotalWeapons")
    self:NetworkVar("String", 0, "WeaponClass")
    self:NetworkVar("String", 1, "Name")
    self:NetworkVar("Entity", 0, "gunModel")
    self:NetworkVar("Float", 0, "gunspawn")
    print("[Custom Empty Shipment] SetupDataTables called - networked variables initialized")
end

print("[Custom Empty Shipment] shared.lua loaded successfully")