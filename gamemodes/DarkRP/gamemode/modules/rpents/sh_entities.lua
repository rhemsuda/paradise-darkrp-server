--[[---------------------------------------------------------------------------
  Paradise RP – Entity list. Six printer tiers; level required per tier.
  Models: base + comic/printer-ish props. Rework payout/XP per tier later.
---------------------------------------------------------------------------]]
print("[RPEnts Module] sh_entities.lua loaded successfully")

RPEnts = RPEnts or {}
RPEnts.Entities = {
    -- Tier 1 (Level 1) – base money printer model
    { name = "Printer",              ent = "printer1", model = "models/props_c17/consolebox01a.mdl",              price = 1000,   category = "Printers", level = 1,   donatorOnly = false, jobRestricted = false },
    -- Tier 2 (Level 20)
    { name = "Advanced Printer",     ent = "printer2", model = "models/props_lab/reciever01b.mdl",                 price = 5000,   category = "Printers", level = 20,  donatorOnly = false, jobRestricted = false },
    -- Tier 3 (Level 40)
    { name = "Improved Printer",     ent = "printer3", model = "models/props_lab/reciever01a.mdl",                 price = 15000,  category = "Printers", level = 40,  donatorOnly = false, jobRestricted = false },
    -- Tier 4 (Level 60)
    { name = "Professional Printer", ent = "printer4", model = "models/props_c17/consolebox03a.mdl",               price = 40000,  category = "Printers", level = 60,  donatorOnly = false, jobRestricted = false },
    -- Tier 5 (Level 80)
    { name = "Elite Printer",        ent = "printer5", model = "models/props_wasteland/laundry_washer003.mdl",     price = 100000, category = "Printers", level = 80,  donatorOnly = false, jobRestricted = false },
    -- Tier 6 (Level 100)
    { name = "Paradise Printer",     ent = "printer6", model = "models/props_wasteland/laundry_washer001a.mdl",     price = 250000, category = "Printers", level = 100, donatorOnly = false, jobRestricted = false },
    -- Tools (anyone can buy; miners get shovel in loadout)
    { name = "Shovel",               ent = "weapon_shovel", model = "models/props_junk/shovel01a.mdl",             price = 5000,   category = "Tools", level = 0, donatorOnly = false, jobRestricted = false },
}

print("[RPEnts Module] Defined " .. #RPEnts.Entities .. " custom entities from lua/entities")
for _, ent in ipairs(RPEnts.Entities) do
    print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. ent.category .. ")")
end