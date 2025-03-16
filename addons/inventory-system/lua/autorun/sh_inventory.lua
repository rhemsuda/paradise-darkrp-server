if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("inventory/cl_inventory.lua")
    include("inventory/sv_inventory.lua")
else
    include("inventory/cl_inventory.lua")
end

-- Define some example items
InventoryItems = {
    ["healthkit"] = { name = "Health Kit", model = "models/items/healthkit.mdl" },
    ["pistol"] = { name = "Pistol", model = "models/weapons/w_pistol.mdl" }
}