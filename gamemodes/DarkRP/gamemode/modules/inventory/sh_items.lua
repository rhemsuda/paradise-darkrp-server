AddCSLuaFile()

InventoryItems = InventoryItems or {}

InventoryItems["pistol"] = {
    name = "Pistol",
    model = "models/weapons/w_pistol.mdl",
    entityClass = "weapon_pistol",
    maxStack = 1,
    useFunction = function(ply)
        ply:Give("weapon_pistol")
    end
}

InventoryItems["healthkit"] = {
    name = "Health Kit",
    model = "models/items/healthkit.mdl",
    entityClass = "item_healthkit",
    maxStack = 5,
    useFunction = function(ply)
        ply:SetHealth(math.min(ply:Health() + 25, ply:GetMaxHealth()))
    end
}

print("[Inventory Module] sh_items.lua loaded successfully")