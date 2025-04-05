-- Ensure this file is sent to clients and included server-side
if SERVER then
    AddCSLuaFile()
end

InventoryItems = InventoryItems or {}

-- Define items with name, model, and entity class
InventoryItems["pistol"] = {
    name = "Pistol",
    model = "models/weapons/w_pistol.mdl",
    entityClass = "weapon_pistol",
    maxStack = 1,
    useFunction = function(ply)
        ply:Give("weapon_pistol")
        ply:SelectWeapon("weapon_pistol")
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

InventoryItems["crowbar"] = {
    name = "Crowbar",
    model = "models/weapons/w_crowbar.mdl",
    entityClass = "weapon_crowbar",
    maxStack = 1,
    useFunction = function(ply)
        ply:Give("weapon_crowbar")
        ply:SelectWeapon("weapon_crowbar")
    end
}

InventoryItems["shovel"] = {
    name = "Shovel",
    model = "models/props_farm/tools_shovel.mdl",
    entityClass = "weapon_shovel",
    maxStack = 1,
    useFunction = function(ply)
        ply:Give("weapon_shovel")
        ply:SelectWeapon("weapon_shovel")
        print("[Debug] Equipped "..ply:Nick().." with weapon_shovel")
    end
}

print("[Inventory Module] sh_items.lua loaded successfully")