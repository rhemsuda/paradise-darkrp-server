-- Ensure this file is sent to clients and included server-side
if SERVER then
    AddCSLuaFile()
end

InventoryItems = InventoryItems or {}

-- Helper function to reduce repetition
local function equipWeapon(ply, className, debugTag)
    local wep = ply:Give(className)
    if IsValid(wep) then
        print("["..debugTag.." Debug] Successfully gave "..ply:Nick().." "..className)
        timer.Simple(0.2, function()
            if IsValid(ply) and ply:HasWeapon(className) then
                ply:SelectWeapon(className)
                print("["..debugTag.." Debug] Equipped "..ply:Nick().." with "..className)
            else
                print("["..debugTag.." Debug] Failed to equip "..ply:Nick()..": "..className.." not in inventory")
            end
        end)
    else
        print("["..debugTag.." Debug] Failed to give "..ply:Nick().." "..className.." - SWEP not registered")
        AddItemToInventory(ply, className:gsub("bb_", ""), 1)
        SendInventoryMessage(ply, InventoryItems[className:gsub("bb_", "")].name.." failed to equip - returned to inventory.")
    end
end

-- Existing Items
InventoryItems["pistol"] = {
    name = "Pistol",
    model = "models/weapons/w_pistol.mdl",
    entityClass = "weapon_pistol",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "weapon_pistol", "Pistol") end
}

InventoryItems["healthkit1"] = {
    name = "Small Medkit",
    model = "models/items/healthkit.mdl",
    entityClass = "item_healthkit",
    maxStack = 5,
    useFunction = function(ply)
        ply:SetHealth(math.min(ply:Health() + 25, ply:GetMaxHealth()))
    end
}

InventoryItems["healthkit2"] = {
    name = "Medkit",
    model = "models/items/healthkit.mdl",
    entityClass = "item_healthkit",
    maxStack = 5,
    useFunction = function(ply)
        ply:SetHealth(math.min(ply:Health() + 50, ply:GetMaxHealth()))
    end
}

InventoryItems["healthkit3"] = {
    name = "Health and Armor",
    model = "models/items/healthkit.mdl",
    entityClass = "item_healthkit",
    maxStack = 5,
    useFunction = function(ply)
        ply:SetHealth(math.min(ply:Health() + 100, ply:GetMaxHealth()))
        ply:SetArmor(100)
    end
}

InventoryItems["crowbar"] = {
    name = "Crowbar",
    model = "models/weapons/w_crowbar.mdl",
    entityClass = "weapon_crowbar",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "weapon_crowbar", "Crowbar") end
}

InventoryItems["shovel"] = {
    name = "Shovel",
    model = "models/props_junk/shovel01a.mdl",
    entityClass = "weapon_shovel",
    maxStack = 5,
    category = "Tools",
    useFunction = function(ply) equipWeapon(ply, "weapon_shovel", "Shovel") end
}

-- CS:S Pistols
InventoryItems["glock"] = {
    name = "Glock",
    model = "models/weapons/w_pist_glock18.mdl",
    entityClass = "bb_glock",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_glock", "Glock") end
}

InventoryItems["usp"] = {
    name = "USP",
    model = "models/weapons/w_pist_usp.mdl",
    entityClass = "bb_usp",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_usp", "USP") end
}

InventoryItems["p228"] = {
    name = "P228",
    model = "models/weapons/w_pist_p228.mdl",
    entityClass = "bb_p228",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_p228", "P228") end
}

InventoryItems["deagle"] = {
    name = "Desert Eagle",
    model = "models/weapons/w_pist_deagle.mdl",
    entityClass = "bb_deagle",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_deagle", "Deagle") end
}

InventoryItems["fiveseven"] = {
    name = "Five-SeveN",
    model = "models/weapons/w_pist_fiveseven.mdl",
    entityClass = "bb_fiveseven",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_fiveseven", "FiveSeven") end
}

InventoryItems["elite"] = {
    name = "Dual Elites",
    model = "models/weapons/w_pist_elite.mdl",
    entityClass = "bb_elite",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_elite", "Elite") end
}

-- CS:S Shotguns
InventoryItems["m3"] = {
    name = "M3 Super 90",
    model = "models/weapons/w_shot_m3super90.mdl",
    entityClass = "bb_m3",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_m3", "M3") end
}

InventoryItems["xm1014"] = {
    name = "XM1014",
    model = "models/weapons/w_shot_xm1014.mdl",
    entityClass = "bb_xm1014",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_xm1014", "XM1014") end
}

-- CS:S SMGs
InventoryItems["mac10"] = {
    name = "MAC-10",
    model = "models/weapons/w_smg_mac10.mdl",
    entityClass = "bb_mac10",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_mac10", "MAC10") end
}

InventoryItems["tmp"] = {
    name = "TMP",
    model = "models/weapons/w_smg_tmp.mdl",
    entityClass = "bb_tmp",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_tmp", "TMP") end
}

InventoryItems["mp5navy"] = {
    name = "MP5 Navy",
    model = "models/weapons/w_smg_mp5.mdl",
    entityClass = "bb_mp5navy",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_mp5navy", "MP5") end
}

InventoryItems["ump45"] = {
    name = "UMP-45",
    model = "models/weapons/w_smg_ump45.mdl",
    entityClass = "bb_ump45",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_ump45", "UMP45") end
}

InventoryItems["p90"] = {
    name = "P90",
    model = "models/weapons/w_smg_p90.mdl",
    entityClass = "bb_p90",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_p90", "P90") end
}

-- CS:S Rifles
InventoryItems["ak47"] = {
    name = "AK-47",
    model = "models/weapons/w_rif_ak47.mdl",
    entityClass = "bb_ak47",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_ak47", "AK47") end
}

InventoryItems["m4a1"] = {
    name = "M4A1",
    model = "models/weapons/w_rif_m4a1.mdl",
    entityClass = "bb_m4a1",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_m4a1", "M4A1") end
}

InventoryItems["sg552"] = {
    name = "SG 552",
    model = "models/weapons/w_rif_sg552.mdl",
    entityClass = "bb_sg552",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_sg552", "SG552") end
}

InventoryItems["aug"] = {
    name = "AUG",
    model = "models/weapons/w_rif_aug.mdl",
    entityClass = "bb_aug",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_aug", "AUG") end
}

InventoryItems["scout"] = {
    name = "Scout",
    model = "models/weapons/w_snip_scout.mdl",
    entityClass = "bb_scout",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_scout", "Scout") end
}

InventoryItems["g3sg1"] = {
    name = "G3SG1",
    model = "models/weapons/w_snip_g3sg1.mdl",
    entityClass = "bb_g3sg1",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_g3sg1", "G3SG1") end
}

InventoryItems["sg550"] = {
    name = "SG 550",
    model = "models/weapons/w_snip_sg550.mdl",
    entityClass = "bb_sg550",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_sg550", "SG550") end
}

-- CS:S Machine Gun
InventoryItems["m249"] = {
    name = "M249",
    model = "models/weapons/w_mach_m249para.mdl",
    entityClass = "bb_m249",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_m249", "M249") end
}

-- CS:S Knife
InventoryItems["knife"] = {
    name = "Knife",
    model = "models/weapons/w_knife_t.mdl",
    entityClass = "bb_css_knife",
    maxStack = 5,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_css_knife", "Knife") end
}

print("[Inventory Module] sh_items.lua loaded successfully")