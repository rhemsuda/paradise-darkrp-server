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
    model = "models/props_junk/shovel01a.mdl",
    entityClass = "weapon_shovel",
    maxStack = 5,
    useFunction = function(ply)
        local wep = ply:Give("weapon_shovel")
        if IsValid(wep) then
            print("[Shovel Debug] Successfully gave "..ply:Nick().." weapon_shovel")
            timer.Simple(0.2, function()
                if IsValid(ply) and ply:HasWeapon("weapon_shovel") then
                    ply:SelectWeapon("weapon_shovel")
                    print("[Shovel Debug] Equipped "..ply:Nick().." with weapon_shovel")
                else
                    print("[Shovel Debug] Failed to equip "..ply:Nick()..": weapon_shovel not in inventory")
                end
            end)
        else
            print("[Shovel Debug] Failed to give "..ply:Nick().." weapon_shovel - SWEP not registered")
            AddItemToInventory(ply, "shovel", 1) -- Line 60: Now works with global function
            SendInventoryMessage(ply, "Shovel failed to equip - returned to inventory.")
        end
    end
}

print("[Inventory Module] sh_items.lua loaded successfully")