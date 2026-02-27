-- Configurable list of contraband entity classes (scanner detects these; admin settings can extend later)
-- Entities owned by wanted players are also flagged by stunstick 500 damage
DarkRP.ContrabandEntities = DarkRP.ContrabandEntities or {
    "money_printer",
    "printer1",
    "printer2",
    "printer_module",
    "drug_lab",
    -- Add more as needed; admins can modify this table or add via config
}

function DarkRP.IsContraband(class)
    if not class or class == "" then return false end
    for _, c in ipairs(DarkRP.ContrabandEntities or {}) do
        if c == class then return true end
    end
    return false
end
