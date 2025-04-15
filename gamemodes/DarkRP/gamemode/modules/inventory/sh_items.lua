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
    baseRarity = "Common",
    ammoType = nil -- Melee weapon, no ammo required
}

InventoryItems["pistol"] = {
    name = "Pistol",
    description = "A basic handgun, upgradeable.",
    model = "models/weapons/w_pistol.mdl",
    entityClass = "weapon_pistol",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "weapon_pistol", "Pistol") end,
    baseRarity = "Common",
    ammoType = "Pistol"
}

InventoryItems["crowbar"] = {
    name = "Crowbar",
    description = "A melee weapon, can be enhanced.",
    model = "models/weapons/w_crowbar.mdl",
    entityClass = "weapon_crowbar",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "weapon_crowbar", "Crowbar") end,
    baseRarity = "Common",
    ammoType = nil -- Melee weapon, no ammo required
}

InventoryItems["glock"] = {
    name = "Glock",
    description = "A reliable pistol, upgradeable.",
    model = "models/weapons/w_pist_glock18.mdl",
    entityClass = "bb_glock",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_glock", "Glock") end,
    baseRarity = "Common",
    ammoType = "Pistol"
}

InventoryItems["usp"] = {
    name = "USP",
    description = "A silenced pistol, upgradeable.",
    model = "models/weapons/w_pist_usp.mdl",
    entityClass = "bb_usp",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_usp", "USP") end,
    baseRarity = "Uncommon",
    ammoType = "Pistol"
}

InventoryItems["p228"] = {
    name = "P228",
    description = "A compact pistol, upgradeable.",
    model = "models/weapons/w_pist_p228.mdl",
    entityClass = "bb_p228",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_p228", "P228") end,
    baseRarity = "Common",
    ammoType = "Pistol"
}

InventoryItems["deagle"] = {
    name = "Desert Eagle",
    description = "A powerful handgun, upgradeable.",
    model = "models/weapons/w_pist_deagle.mdl",
    entityClass = "bb_deagle",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_deagle", "Deagle") end,
    baseRarity = "Rare",
    ammoType = "357" -- Desert Eagle uses a more powerful ammo type
}

InventoryItems["awp"] = {
    name = "AWP",
    description = "A powerful sniper rifle, upgradeable.",
    model = "models/weapons/w_snip_awp.mdl",
    entityClass = "bb_awp",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_awp", "AWP") end,
    baseRarity = "Rare",
    ammoType = "SniperRound" -- Same ammo type as other snipers
}

InventoryItems["fiveseven"] = {
    name = "Five-SeveN",
    description = "A lightweight pistol, upgradeable.",
    model = "models/weapons/w_pist_fiveseven.mdl",
    entityClass = "bb_fiveseven",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_fiveseven", "FiveSeven") end,
    baseRarity = "Uncommon",
    ammoType = "Pistol"
}

InventoryItems["elite"] = {
    name = "Dual Elites",
    description = "Dual-wielded pistols, upgradeable.",
    model = "models/weapons/w_pist_elite.mdl",
    entityClass = "bb_elite",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_elite", "Elite") end,
    baseRarity = "Rare",
    ammoType = "Pistol"
}

InventoryItems["m3"] = {
    name = "M3 Super 90",
    description = "A pump-action shotgun, upgradeable.",
    model = "models/weapons/w_shot_m3super90.mdl",
    entityClass = "bb_m3",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_m3", "M3") end,
    baseRarity = "Common",
    ammoType = "Buckshot"
}

InventoryItems["xm1014"] = {
    name = "XM1014",
    description = "A semi-automatic shotgun, upgradeable.",
    model = "models/weapons/w_shot_xm1014.mdl",
    entityClass = "bb_xm1014",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_xm1014", "XM1014") end,
    baseRarity = "Uncommon",
    ammoType = "Buckshot"
}

InventoryItems["mac10"] = {
    name = "MAC-10",
    description = "A compact SMG, upgradeable.",
    model = "models/weapons/w_smg_mac10.mdl",
    entityClass = "bb_mac10",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_mac10", "MAC10") end,
    baseRarity = "Common",
    ammoType = "SMG1"
}

InventoryItems["tmp"] = {
    name = "TMP",
    description = "A silenced SMG, upgradeable.",
    model = "models/weapons/w_smg_tmp.mdl",
    entityClass = "bb_tmp",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_tmp", "TMP") end,
    baseRarity = "Uncommon",
    ammoType = "SMG1"
}

InventoryItems["mp5navy"] = {
    name = "MP5 Navy",
    description = "A versatile SMG, upgradeable.",
    model = "models/weapons/w_smg_mp5.mdl",
    entityClass = "bb_mp5navy",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_mp5navy", "MP5") end,
    baseRarity = "Common",
    ammoType = "SMG1"
}

InventoryItems["ump45"] = {
    name = "UMP-45",
    description = "A sturdy SMG, upgradeable.",
    model = "models/weapons/w_smg_ump45.mdl",
    entityClass = "bb_ump45",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_ump45", "UMP45") end,
    baseRarity = "Common",
    ammoType = "SMG1"
}

InventoryItems["p90"] = {
    name = "P90",
    description = "A high-capacity SMG, upgradeable.",
    model = "models/weapons/w_smg_p90.mdl",
    entityClass = "bb_p90",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_p90", "P90") end,
    baseRarity = "Rare",
    ammoType = "SMG1"
}

InventoryItems["ak47"] = {
    name = "AK-47",
    description = "A powerful assault rifle, upgradeable.",
    model = "models/weapons/w_rif_ak47.mdl",
    entityClass = "bb_ak47",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_ak47", "AK47") end,
    baseRarity = "Uncommon",
    ammoType = "AR2"
}

InventoryItems["m4a1"] = {
    name = "M4A1",
    description = "A versatile assault rifle, upgradeable.",
    model = "models/weapons/w_rif_m4a1.mdl",
    entityClass = "bb_m4a1",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_m4a1", "M4A1") end,
    baseRarity = "Uncommon",
    ammoType = "AR2"
}

InventoryItems["sg552"] = {
    name = "SG 552",
    description = "An assault rifle with a scope, upgradeable.",
    model = "models/weapons/w_rif_sg552.mdl",
    entityClass = "bb_sg552",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_sg552", "SG552") end,
    baseRarity = "Rare",
    ammoType = "AR2"
}

InventoryItems["aug"] = {
    name = "AUG",
    description = "A bullpup rifle with a scope, upgradeable.",
    model = "models/weapons/w_rif_aug.mdl",
    entityClass = "bb_aug",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_aug", "AUG") end,
    baseRarity = "Rare",
    ammoType = "AR2"
}

InventoryItems["scout"] = {
    name = "Scout",
    description = "A lightweight sniper rifle, upgradeable.",
    model = "models/weapons/w_snip_scout.mdl",
    entityClass = "bb_scout",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_scout", "Scout") end,
    baseRarity = "Uncommon",
    ammoType = "SniperRound" -- Custom ammo type for snipers (adjust if needed)
}

InventoryItems["g3sg1"] = {
    name = "G3SG1",
    description = "A semi-automatic sniper rifle, upgradeable.",
    model = "models/weapons/w_snip_g3sg1.mdl",
    entityClass = "bb_g3sg1",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_g3sg1", "G3SG1") end,
    baseRarity = "Rare",
    ammoType = "SniperRound" -- Custom ammo type for snipers (adjust if needed)
}

InventoryItems["sg550"] = {
    name = "SG 550",
    description = "A semi-automatic sniper rifle, upgradeable.",
    model = "models/weapons/w_snip_sg550.mdl",
    entityClass = "bb_sg550",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_sg550", "SG550") end,
    baseRarity = "Rare",
    ammoType = "SniperRound" -- Custom ammo type for snipers (adjust if needed)
}

InventoryItems["m249"] = {
    name = "M249",
    description = "A heavy machine gun, upgradeable.",
    model = "models/weapons/w_mach_m249para.mdl",
    entityClass = "bb_m249",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_m249", "M249") end,
    baseRarity = "Epic",
    ammoType = "AR2" -- Using AR2 for heavy machine gun (adjust if needed)
}

InventoryItems["knife"] = {
    name = "Knife",
    description = "A sharp blade, upgradeable.",
    model = "models/weapons/w_knife_t.mdl",
    entityClass = "bb_css_knife",
    maxStack = 1,
    category = "Weapons",
    useFunction = function(ply) equipWeapon(ply, "bb_css_knife", "Knife") end,
    baseRarity = "Common",
    ammoType = nil -- Melee weapon, no ammo required
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

-- Props (Added for the props panel in sv_props.lua and cl_props.lua)
InventoryItems["weapon_stripper"] = {
    name = "Weapon Stripper",
    model = "models/props_combine/weaponstripper.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150, -- DarkRP money cost for "Buy" mode
    health = 1500
}

InventoryItems["slotted_door"] = {
    name = "Slotted Door",
    model = "models/props_doors/door03_slotted_left.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 2500
}

InventoryItems["metal_plate_1x1"] = {
    name = "Metal Plate 1x1",
    model = "models/props_phx/construct/metal_plate1.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1000
}

InventoryItems["metal_plate_1x2"] = {
    name = "Metal Plate 1x2",
    model = "models/props_phx/construct/metal_plate1x2.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1001
}

InventoryItems["metal_plate_2x2"] = {
    name = "Metal Plate 2x2",
    model = "models/props_phx/construct/metal_plate2x2.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1001
}

InventoryItems["metal_plate_2x4"] = {
    name = "Metal Plate 2x4",
    model = "models/props_phx/construct/metal_plate2x4.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1001
}

InventoryItems["metal_plate_4x4"] = {
    name = "Metal Plate 4x4",
    model = "models/props_phx/construct/metal_plate4x4.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1001
}

InventoryItems["metal_tube"] = {
    name = "Metal Tube",
    model = "models/props_phx/construct/metal_tube.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1001
}

InventoryItems["metal_tube_2x"] = {
    name = "Metal Tube 2x",
    model = "models/props_phx/construct/metal_tubex2.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1001
}

InventoryItems["i_beam_2x8"] = {
    name = "I-Beam 2x8",
    model = "models/mechanics/solid_steel/i_beam2_8.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1001
}

InventoryItems["i_beam_2x16"] = {
    name = "I-Beam 2x16",
    model = "models/mechanics/solid_steel/i_beam2_16.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1001
}

InventoryItems["i_beam_2x32"] = {
    name = "I-Beam 2x32",
    model = "models/mechanics/solid_steel/i_beam2_32.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1001
}

InventoryItems["billboard"] = {
    name = "Billboard",
    model = "models/props/cs_assault/billboard.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 5000
}

InventoryItems["wooden_shelves"] = {
    name = "Wooden Shelves",
    model = "models/props/CS_militia/shelves_wood.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1000
}

InventoryItems["gear_60t1"] = {
    name = "Gear 60T1",
    model = "models/Mechanics/gears2/gear_60t1.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 9000
}

InventoryItems["blast_door_c"] = {
    name = "Blast Door C",
    model = "models/props_lab/blastdoor001c.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 4000
}

InventoryItems["blast_door_b"] = {
    name = "Blast Door B",
    model = "models/props_lab/blastdoor001b.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 4000
}

InventoryItems["storefront_bars"] = {
    name = "Storefront Bars",
    model = "models/props_building_details/Storefront_Template001a_Bars.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 7500
}

InventoryItems["interior_fence_002d"] = {
    name = "Interior Fence 002D",
    model = "models/props_wasteland/interior_fence002d.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1500
}

InventoryItems["fence_03a"] = {
    name = "Fence 03A",
    model = "models/props_c17/fence03a.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1500
}

InventoryItems["interior_fence_001g"] = {
    name = "Interior Fence 001G",
    model = "models/props_wasteland/interior_fence001g.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 1500
}

InventoryItems["concrete_barrier"] = {
    name = "Concrete Barrier",
    model = "models/props_c17/concrete_barrier001a.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 10000
}

InventoryItems["vending_machine"] = {
    name = "Vending Machine",
    model = "models/props_interiors/VendingMachineSoda01a.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 3500
}

InventoryItems["kitchen_fridge"] = {
    name = "Kitchen Fridge",
    model = "models/props_wasteland/kitchen_fridge001a.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 3500
}

InventoryItems["covered_bridge_bottom"] = {
    name = "Covered Bridge Bottom",
    model = "models/props/cs_militia/coveredbridge01_bottom.mdl",
    category = "Props",
    resources = { rock = 10, copper = 0, iron = 0, steel = 0 },
    price = 150,
    health = 4500
}

-- Define props for the admin panel
AdminProps = AdminProps or {}
AdminProps = {
    { model = "models/props_combine/weaponstripper.mdl" },
    { model = "models/props_doors/door03_slotted_left.mdl" },
    { model = "models/props_c17/FurnitureTable001a.mdl" },
    { model = "models/props_junk/wood_crate001a.mdl" },
    { model = "models/props_junk/wood_pallet001a.mdl" },
    { model = "models/props_junk/TrashBin01a.mdl" },
    { model = "models/props_vehicles/tire001c_car.mdl" },
    { model = "models/props_junk/TrafficCone001a.mdl" },
    { model = "models/props_debris/metal_panel01a.mdl" },
    { model = "models/props_junk/sawblade001a.mdl" }
}

print("[Inventory Module] sh_items.lua loaded successfully")