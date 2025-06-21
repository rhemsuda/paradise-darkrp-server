print("[RPEnts Module] sh_entities.lua loaded successfully")

RPEnts = RPEnts or {}
RPEnts.Entities = {
    {
        name = "Printer",
        ent = "printer1",
        model = "models/props_c17/consolebox01a.mdl",
        price = 1000,
        category = "Printers",
        donatorOnly = false,
        jobRestricted = false,
    },
    {
        name = "Donator Printer",
        ent = "printer2",
        model = "models/props_c17/consolebox01a.mdl",
        price = 2500,
        category = "Printers",
        donatorOnly = true,
        jobRestricted = false,
    },
    {
        name = "Empty Shipment",
        ent = "custom_empty_shipment",
        model = "models/Items/item_item_crate.mdl",
        price = 500,
        category = "Storage",
        donatorOnly = false,
        jobRestricted = false,
    },
}

print("[RPEnts Module] Defined " .. #RPEnts.Entities .. " custom entities from lua/entities")
for _, ent in ipairs(RPEnts.Entities) do
    print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. ent.category .. ")")
end