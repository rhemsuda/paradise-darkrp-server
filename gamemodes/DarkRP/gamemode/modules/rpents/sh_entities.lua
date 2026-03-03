--[[---------------------------------------------------------------------------
  Paradise RP – Entity list. Six printer tiers; level required per tier.
  Models: base + comic/printer-ish props. Rework payout/XP per tier later.
---------------------------------------------------------------------------]]
print("[RPEnts Module] sh_entities.lua loaded successfully")

RPEnts = RPEnts or {}
RPEnts.Entities = {
    -- Tier 1–6: lower prices, modest payout increases (see money_printer initVars)
    { name = "Printer",              ent = "printer1", model = "models/props_c17/consolebox01a.mdl",              price = 400,    category = "Printers", level = 1,   donatorOnly = false, jobRestricted = false },
    { name = "Advanced Printer",     ent = "printer2", model = "models/props_lab/reciever01b.mdl",                 price = 1200,   category = "Printers", level = 20,  donatorOnly = false, jobRestricted = false },
    { name = "Improved Printer",     ent = "printer3", model = "models/props_lab/reciever01a.mdl",                 price = 2800,   category = "Printers", level = 40,  donatorOnly = false, jobRestricted = false },
    { name = "Professional Printer", ent = "printer4", model = "models/props_c17/consolebox03a.mdl",               price = 6000,   category = "Printers", level = 60,  donatorOnly = false, jobRestricted = false },
    { name = "Elite Printer",        ent = "printer5", model = "models/props_wasteland/laundry_washer003.mdl",     price = 12000,  category = "Printers", level = 80,  donatorOnly = false, jobRestricted = false },
    { name = "Paradise Printer",     ent = "printer6", model = "models/props_wasteland/laundry_washer001a.mdl",     price = 24000,  category = "Printers", level = 100, donatorOnly = false, jobRestricted = false },
    -- Tools (job-specific: only Miner can buy shovel from Entities)
    { name = "Shovel",               ent = "weapon_shovel", model = "models/props_junk/shovel01a.mdl",             price = 5000,   category = "Tools", level = 0, donatorOnly = false, jobRestricted = false, allowedJob = "Miner" },
    -- Printer Module (activate = 15 min countdown, then explodes – effect only, no damage)
    { name = "Printer Module",       ent = "printer_module", model = "models/props_lab/reciever01a.mdl",           price = 500,    category = "Printers", level = 0, donatorOnly = false, jobRestricted = false },
}

print("[RPEnts Module] Defined " .. #RPEnts.Entities .. " custom entities from lua/entities")
for _, ent in ipairs(RPEnts.Entities) do
    print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. ent.category .. ")")
end