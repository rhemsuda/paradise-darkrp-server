-- Ensure this file is sent to clients and included server-side
if SERVER then
    AddCSLuaFile()
end

InventoryItems = InventoryItems or {}

-- Helper function to equip weapons
local function equipWeapon(ply, className, debugTag)
    local wep = ply:Give(className)
    if IsValid(wep) then
        print("[" .. debugTag .. " Debug] Successfully gave " .. ply:Nick() .. " " .. className)
        timer.Simple(0.2, function()
            if IsValid(ply) and ply:HasWeapon(className) then
                ply:SelectWeapon(className)
                print("[" .. debugTag .. " Debug] Equipped " .. ply:Nick() .. " with " .. className)
            else
                print("[" .. debugTag .. " Debug] Failed to equip " .. ply:Nick() .. ": " .. className .. " not in inventory")
            end
        end)
    else
        print("[" .. debugTag .. " Debug] Failed to give " .. ply:Nick() .. " " .. className .. " - SWEP not registered")
        AddItemToInventory(ply, className:gsub("bb_", ""), 1)
        SendInventoryMessage(ply, InventoryItems[className:gsub("bb_", "")].name .. " failed to equip - returned to inventory.")
    end
end

-- Weapons (Craftable, stats in SQL)
InventoryItems["shovel"] = {
    name = "Shovel",
    description = "A sturdy tool for digging, can be upgraded.",
    model = "models/props_junk/shovel01a.mdl",
    entityClass = "weapon_shovel",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "weapon_shovel", "Shovel") end,
    baseRarity = "Common"
}

InventoryItems["pistol"] = {
    name = "Pistol",
    description = "A basic handgun, upgradeable.",
    model = "models/weapons/w_pistol.mdl",
    entityClass = "weapon_pistol",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "weapon_pistol", "Pistol") end,
    baseRarity = "Common"
}

InventoryItems["crowbar"] = {
    name = "Crowbar",
    description = "A melee weapon, can be enhanced.",
    model = "models/weapons/w_crowbar.mdl",
    entityClass = "weapon_crowbar",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "weapon_crowbar", "Crowbar") end,
    baseRarity = "Common"
}

InventoryItems["glock"] = {
    name = "Glock",
    description = "A reliable pistol, upgradeable.",
    model = "models/weapons/w_pist_glock18.mdl",
    entityClass = "bb_glock",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_glock", "Glock") end,
    baseRarity = "Common"
}

InventoryItems["usp"] = {
    name = "USP",
    description = "A silenced pistol, upgradeable.",
    model = "models/weapons/w_pist_usp.mdl",
    entityClass = "bb_usp",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_usp", "USP") end,
    baseRarity = "Uncommon"
}

InventoryItems["p228"] = {
    name = "P228",
    description = "A compact pistol, upgradeable.",
    model = "models/weapons/w_pist_p228.mdl",
    entityClass = "bb_p228",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_p228", "P228") end,
    baseRarity = "Common"
}

InventoryItems["deagle"] = {
    name = "Desert Eagle",
    description = "A powerful handgun, upgradeable.",
    model = "models/weapons/w_pist_deagle.mdl",
    entityClass = "bb_deagle",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_deagle", "Deagle") end,
    baseRarity = "Rare"
}

InventoryItems["fiveseven"] = {
    name = "Five-SeveN",
    description = "A lightweight pistol, upgradeable.",
    model = "models/weapons/w_pist_fiveseven.mdl",
    entityClass = "bb_fiveseven",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_fiveseven", "FiveSeven") end,
    baseRarity = "Uncommon"
}

InventoryItems["elite"] = {
    name = "Dual Elites",
    description = "Dual-wielded pistols, upgradeable.",
    model = "models/weapons/w_pist_elite.mdl",
    entityClass = "bb_elite",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_elite", "Elite") end,
    baseRarity = "Rare"
}

InventoryItems["m3"] = {
    name = "M3 Super 90",
    description = "A pump-action shotgun, upgradeable.",
    model = "models/weapons/w_shot_m3super90.mdl",
    entityClass = "bb_m3",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_m3", "M3") end,
    baseRarity = "Common"
}

InventoryItems["xm1014"] = {
    name = "XM1014",
    description = "A semi-automatic shotgun, upgradeable.",
    model = "models/weapons/w_shot_xm1014.mdl",
    entityClass = "bb_xm1014",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_xm1014", "XM1014") end,
    baseRarity = "Uncommon"
}

InventoryItems["mac10"] = {
    name = "MAC-10",
    description = "A compact SMG, upgradeable.",
    model = "models/weapons/w_smg_mac10.mdl",
    entityClass = "bb_mac10",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_mac10", "MAC10") end,
    baseRarity = "Common"
}

InventoryItems["tmp"] = {
    name = "TMP",
    description = "A silenced SMG, upgradeable.",
    model = "models/weapons/w_smg_tmp.mdl",
    entityClass = "bb_tmp",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_tmp", "TMP") end,
    baseRarity = "Uncommon"
}

InventoryItems["mp5navy"] = {
    name = "MP5 Navy",
    description = "A versatile SMG, upgradeable.",
    model = "models/weapons/w_smg_mp5.mdl",
    entityClass = "bb_mp5navy",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_mp5navy", "MP5") end,
    baseRarity = "Common"
}

InventoryItems["ump45"] = {
    name = "UMP-45",
    description = "A sturdy SMG, upgradeable.",
    model = "models/weapons/w_smg_ump45.mdl",
    entityClass = "bb_ump45",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_ump45", "UMP45") end,
    baseRarity = "Common"
}

InventoryItems["p90"] = {
    name = "P90",
    description = "A high-capacity SMG, upgradeable.",
    model = "models/weapons/w_smg_p90.mdl",
    entityClass = "bb_p90",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_p90", "P90") end,
    baseRarity = "Rare"
}

InventoryItems["ak47"] = {
    name = "AK-47",
    description = "A powerful assault rifle, upgradeable.",
    model = "models/weapons/w_rif_ak47.mdl",
    entityClass = "bb_ak47",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_ak47", "AK47") end,
    baseRarity = "Uncommon"
}

InventoryItems["m4a1"] = {
    name = "M4A1",
    description = "A versatile assault rifle, upgradeable.",
    model = "models/weapons/w_rif_m4a1.mdl",
    entityClass = "bb_m4a1",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_m4a1", "M4A1") end,
    baseRarity = "Uncommon"
}

InventoryItems["sg552"] = {
    name = "SG 552",
    description = "An assault rifle with a scope, upgradeable.",
    model = "models/weapons/w_rif_sg552.mdl",
    entityClass = "bb_sg552",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_sg552", "SG552") end,
    baseRarity = "Rare"
}

InventoryItems["aug"] = {
    name = "AUG",
    description = "A bullpup rifle with a scope, upgradeable.",
    model = "models/weapons/w_rif_aug.mdl",
    entityClass = "bb_aug",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_aug", "AUG") end,
    baseRarity = "Rare"
}

InventoryItems["scout"] = {
    name = "Scout",
    description = "A lightweight sniper rifle, upgradeable.",
    model = "models/weapons/w_snip_scout.mdl",
    entityClass = "bb_scout",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_scout", "Scout") end,
    baseRarity = "Uncommon"
}

InventoryItems["g3sg1"] = {
    name = "G3SG1",
    description = "A semi-automatic sniper rifle, upgradeable.",
    model = "models/weapons/w_snip_g3sg1.mdl",
    entityClass = "bb_g3sg1",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_g3sg1", "G3SG1") end,
    baseRarity = "Rare"
}

InventoryItems["sg550"] = {
    name = "SG 550",
    description = "A semi-automatic sniper rifle, upgradeable.",
    model = "models/weapons/w_snip_sg550.mdl",
    entityClass = "bb_sg550",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_sg550", "SG550") end,
    baseRarity = "Rare"
}

InventoryItems["m249"] = {
    name = "M249",
    description = "A heavy machine gun, upgradeable.",
    model = "models/weapons/w_mach_m249para.mdl",
    entityClass = "bb_m249",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_m249", "M249") end,
    baseRarity = "Epic"
}

InventoryItems["knife"] = {
    name = "Knife",
    description = "A sharp blade, upgradeable.",
    model = "models/weapons/w_knife_t.mdl",
    entityClass = "bb_css_knife",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_css_knife", "Knife") end,
    baseRarity = "Common"
}

-- Utility (Non-craftable, no rarity or slots)
InventoryItems["healthkit1"] = {
    name = "Small Medkit",
    description = "Restores a small amount of health.",
    model = "models/items/healthkit.mdl",
    entityClass = "item_healthkit",
    maxStack = 5,
    category = "Utility",
    useFunction = function(ply)
        ply:SetHealth(math.min(ply:Health() + 25, ply:GetMaxHealth()))
    end
}

InventoryItems["healthkit2"] = {
    name = "Medkit",
    description = "Restores a moderate amount of health.",
    model = "models/items/healthkit.mdl",
    entityClass = "item_healthkit",
    maxStack = 5,
    category = "Utility",
    useFunction = function(ply)
        ply:SetHealth(math.min(ply:Health() + 50, ply:GetMaxHealth()))
    end
}

InventoryItems["healthkit3"] = {
    name = "Health and Armor",
    description = "Fully restores health and provides armor.",
    model = "models/items/healthkit.mdl",
    entityClass = "item_healthkit",
    maxStack = 5,
    category = "Utility",
    useFunction = function(ply)
        ply:SetHealth(math.min(ply:Health() + 100, ply:GetMaxHealth()))
        ply:SetArmor(100)
    end
}

print("[Inventory Module] sh_items.lua loaded successfully")