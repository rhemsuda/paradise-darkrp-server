ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Printer"
ENT.Author = "DarkRP Developers and Nicknmb"
ENT.Spawnable = false
ENT.AdminSpawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "price")
    self:NetworkVar("Entity", 0, "owning_ent")
    self:NetworkVar("Int", 1, "StoredMoney")
    print("[Printer1 Shared] NetworkVar StoredMoney registered")
end