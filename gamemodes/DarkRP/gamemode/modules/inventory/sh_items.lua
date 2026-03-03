-- sh_items.lua  (shared item definitions)
-- Load-order safe: creates RegisterItem if our core hasn't been loaded yet.

Inventory = Inventory or {}
Inventory.Items = Inventory.Items or {}
if not Inventory.RegisterItem then
    function Inventory.RegisterItem(id, data)
        data = data or {}
        data.id = id
        Inventory.Items[id] = data
    end
end

-- Example items (edit/extend freely)
Inventory.RegisterItem("medkit", {
    name = "Medkit",
    desc = "Heals a chunk of health.",
    icon = "icon16/heart.png",
    category = "Consumable",
    rarity = "", -- non-weapon: no rarity
})

Inventory.RegisterItem("lockpick", {
    name = "Lockpick",
    desc = "Open locked doors with time.",
    icon = "icon16/key.png",
    category = "Tool",
    class = "lockpick",
    rarity = "", -- non-weapon: no rarity
})

-- Keep basic examples but avoid overwriting imported legacy items if present
if not Inventory.Items["pistol"] then
Inventory.RegisterItem("pistol", {
    name = "Pistol",
    desc = "Basic sidearm.",
    icon = "icon16/gun.png",
    category = "Weapon",
    class = "weapon_pistol",
    rarity = "Common",
    baseDamage = 10,
})
end

if not Inventory.Items["ar2"] then
Inventory.RegisterItem("ar2", {
    name = "AR2",
    desc = "Combine rifle.",
    icon = "icon16/bomb.png",
    category = "Weapon",
    class = "weapon_ar2",
    rarity = "Rare",
    baseDamage = 20,
})
end

-- Integrate common BB weapons (no dependency on PREV file)
local function addBB(id, display, worldModel)
    Inventory.RegisterItem(id, {
        name = display,
        desc = display .. " (BB)",
        category = "Weapon",
        class = id,
        model = worldModel or "",
        rarity = "Rare",
        baseDamage = 15,
    })
end

-- { id, display, worldModel, weaponClass, damageMin, damageMax, craft_recipe }
-- Recipe tiers: pistols (rock/copper/iron) → SMGs (iron/steel) → rifles (steel) → snipers/LMG (titanium)
local bbDefs = {
    -- Pistols (tier 1–2: rock/copper/iron, Deagle gets steel)
    {"bb_p228", "P228", "models/weapons/w_pist_p228.mdl", nil, 7, 9, { rock = 16, copper = 10, iron = 5 }},
    {"bb_elite", "Dual Elites", "models/weapons/w_pist_elite.mdl", "bb_dualelites", 7, 9, { rock = 12, copper = 12, iron = 8 }},
    {"bb_glock", "Glock", "models/weapons/w_pist_glock18.mdl", nil, 8, 10, { copper = 14, iron = 10 }},
    {"bb_usp", "USP", "models/weapons/w_pist_usp.mdl", nil, 8, 10, { copper = 14, iron = 10 }},
    {"bb_fiveseven", "Five-SeveN", "models/weapons/w_pist_fiveseven.mdl", nil, 8, 10, { copper = 12, iron = 12 }},
    {"bb_deagle", "Deagle", "models/weapons/w_pist_deagle.mdl", nil, 9, 11, { copper = 10, iron = 14, steel = 6 }},
    -- SMGs (tier 2–3: iron/steel/copper)
    {"bb_tmp", "TMP", "models/weapons/w_smg_tmp.mdl", nil, 10, 12, { copper = 12, iron = 14, steel = 6 }},
    {"bb_mac10", "MAC-10", "models/weapons/w_smg_mac10.mdl", nil, 11, 13, { iron = 12, copper = 10, steel = 8 }},
    {"bb_mp5navy", "MP5", "models/weapons/w_smg_mp5.mdl", nil, 11, 13, { iron = 14, steel = 10, copper = 8 }},
    {"bb_ump45", "UMP45", "models/weapons/w_smg_ump45.mdl", nil, 12, 14, { iron = 12, steel = 12, copper = 8 }},
    {"bb_p90", "P90", "models/weapons/w_smg_p90.mdl", nil, 13, 15, { iron = 10, steel = 14, copper = 8 }},
    -- Rifles (tier 3–4: steel-heavy)
    {"bb_galil", "Galil", "models/weapons/w_rif_galil.mdl", nil, 18, 22, { iron = 10, steel = 16, copper = 6 }},
    {"bb_famas", "FAMAS", "models/weapons/w_rif_famas.mdl", nil, 18, 22, { iron = 10, steel = 16, copper = 6 }},
    {"bb_aug", "AUG", "models/weapons/w_rif_aug.mdl", nil, 18, 22, { iron = 10, steel = 16, copper = 6 }},
    {"bb_m4a1", "M4A1", "models/weapons/w_rif_m4a1.mdl", nil, 18, 22, { iron = 10, steel = 16, copper = 6 }},
    {"bb_sg552", "SG552", "models/weapons/w_rif_sg552.mdl", nil, 18, 22, { iron = 10, steel = 16, copper = 6 }},
    {"bb_ak47", "AK-47", "models/weapons/w_rif_ak47.mdl", nil, 20, 24, { iron = 8, steel = 18, copper = 6 }},
    -- Shotguns (tier 3–4: sturdy construction for burst damage)
    {"bb_m3", "M3", "models/weapons/w_shot_m3super90.mdl", nil, 10, 14, { iron = 12, steel = 12, copper = 8 }},
    {"bb_xm1014", "XM1014", "models/weapons/w_shot_xm1014.mdl", nil, 10, 14, { iron = 10, steel = 14, copper = 8 }},
    -- LMG (tier 4: high ammo capacity = more metal)
    {"bb_m249", "M249", "models/weapons/w_mach_m249para.mdl", nil, 18, 22, { iron = 14, steel = 16, copper = 10 }},
    -- Snipers (tier 5: titanium for precision/high damage)
    {"bb_scout", "Scout", "models/weapons/w_snip_scout.mdl", nil, 38, 44, { steel = 14, titanium = 8, copper = 6 }},
    {"bb_awp", "AWP", "models/weapons/w_snip_awp.mdl", nil, 46, 54, { steel = 12, titanium = 12, iron = 6 }},
}

for _, d in ipairs(bbDefs) do
    local id, nm, mdl, wclass, dmgMin, dmgMax, recipe = d[1], d[2], d[3], d[4], d[5], d[6], d[7]
    local mid = math.floor(((dmgMin or 15) + (dmgMax or 15)) / 2)
    if not Inventory.Items[id] then
        local data = {
            name = nm, desc = nm .. " (BB)", category = "Weapon", class = wclass or id, model = mdl or "", rarity = "Rare",
            baseDamage = mid, damageMin = dmgMin or mid - 2, damageMax = dmgMax or mid + 2,
        }
        Inventory.RegisterItem(id, data)
    end
    local bpId = "blueprint_" .. id
    if not Inventory.Items[bpId] then
        Inventory.RegisterItem(bpId, {
            name = nm .. " Weapon Blueprint",
            desc = "Blueprint to craft " .. nm .. ". Use at the Crafter.",
            icon = "icon16/page_white_text.png",
            category = "Blueprint",
            model = "models/props_lab/binderblue.mdl",
            weapon_id = id,
            rarity = "",
            craft_recipe = recipe or { iron = 12, steel = 6, copper = 4 },
            maxStack = 20,
        })
    end
end

-- CSS weapon model helpers: if SWEP WorldModel exists, prefer that at runtime
if CLIENT then
    hook.Add("OnGamemodeLoaded", "INV_EnsureCSSModels", function()
        for id, def in pairs(Inventory.Items) do
            if isstring(id) and string.StartWith(id, "bb_") and def and def.class then
                -- Use def.class (actual SWEP name) since id may differ (e.g. bb_elite -> bb_dualelites)
                local swep = weapons and weapons.GetStored and weapons.GetStored(def.class)
                if swep and swep.WorldModel and swep.WorldModel ~= "" then
                    def.model = swep.WorldModel
                end
            end
        end
    end)
end

Inventory.RegisterItem("armor", {
    name = "Kevlar Vest",
    desc = "Reduces damage.",
    icon = "icon16/shield.png",
    category = "Armor",
    rarity = "", -- no rarity for non-weapon
})

Inventory.RegisterItem("boots", {
    name = "Boots",
    desc = "You feel lighter on your feet.",
    icon = "icon16/arrow_up.png",
    category = "Armor",
    rarity = "", -- no rarity for non-weapon
})

