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

-- { id, display, worldModel [, weaponClass] } — weaponClass overrides class when it differs from id (e.g. bb_elite -> bb_dualelites)
local bbDefs = {
    {"bb_deagle", "Deagle", "models/weapons/w_pist_deagle.mdl"},
    {"bb_elite", "Dual Elites", "models/weapons/w_pist_elite.mdl", "bb_dualelites"}, -- actual SWEP class is bb_dualelites
    {"bb_fiveseven", "Five-SeveN", "models/weapons/w_pist_fiveseven.mdl"},
    {"bb_glock", "Glock", "models/weapons/w_pist_glock18.mdl"},
    {"bb_p228", "P228", "models/weapons/w_pist_p228.mdl"},
    {"bb_usp", "USP", "models/weapons/w_pist_usp.mdl"},
    {"bb_mac10", "MAC-10", "models/weapons/w_smg_mac10.mdl"},
    {"bb_mp5navy", "MP5", "models/weapons/w_smg_mp5.mdl"},
    {"bb_p90", "P90", "models/weapons/w_smg_p90.mdl"},
    {"bb_tmp", "TMP", "models/weapons/w_smg_tmp.mdl"},
    {"bb_ump45", "UMP45", "models/weapons/w_smg_ump45.mdl"},
    {"bb_ak47", "AK-47", "models/weapons/w_rif_ak47.mdl"},
    {"bb_aug", "AUG", "models/weapons/w_rif_aug.mdl"},
    {"bb_famas", "FAMAS", "models/weapons/w_rif_famas.mdl"},
    {"bb_galil", "Galil", "models/weapons/w_rif_galil.mdl"},
    {"bb_m4a1", "M4A1", "models/weapons/w_rif_m4a1.mdl"},
    {"bb_sg552", "SG552", "models/weapons/w_rif_sg552.mdl"},
    {"bb_scout", "Scout", "models/weapons/w_snip_scout.mdl"},
    {"bb_awp", "AWP", "models/weapons/w_snip_awp.mdl"},
    {"bb_m3", "M3", "models/weapons/w_shot_m3super90.mdl"},
    {"bb_xm1014", "XM1014", "models/weapons/w_shot_xm1014.mdl"},
    {"bb_m249", "M249", "models/weapons/w_mach_m249para.mdl"},
}

for _, d in ipairs(bbDefs) do
    local id, nm, mdl, wclass = d[1], d[2], d[3], d[4]
    if not Inventory.Items[id] then
        local data = { name = nm, desc = nm .. " (BB)", category = "Weapon", class = wclass or id, model = mdl or "", rarity = "Rare", baseDamage = 15 }
        Inventory.RegisterItem(id, data)
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

