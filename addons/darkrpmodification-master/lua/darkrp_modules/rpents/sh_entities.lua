if not RPEnts then
    RPEnts = {}
    RPEnts.Entities = {}
end

print("[RPEnts Module] sh_entities.lua loaded successfully")

-- Define custom entities
RPEnts.Entities = {
    {
        name = "Printer",
        ent = "printer1",
        model = "models/props_c17/consolebox01a.mdl",
        price = 1000,
        category = "Printers",
        donatorOnly = false,
    },
    {
        name = "Donator Printer",
        ent = "printer2",
        model = "models/props_c17/consolebox01a.mdl",
        price = 2500,
        category = "Printers",
        donatorOnly = true,
    },
}

-- Debug: Print loaded entities
print("[RPEnts Module] Defined " .. #RPEnts.Entities .. " custom entities from lua/entities")
for _, ent in ipairs(RPEnts.Entities) do
    print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. ent.category .. ")")
end