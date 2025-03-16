if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("inventory/cl_inventory.lua")
    include("inventory/sv_inventory.lua")
else
    include("inventory/cl_inventory.lua")
end

InventoryItems = InventoryItems or {}

-- Function to register an item
function RegisterInventoryItem(itemID, data)
    InventoryItems[itemID] = data
end

-- Load all item definitions from a folder
local itemFiles = file.Find("inventory/items/*.lua", "LUA")
for _, itemFile in ipairs(itemFiles) do
    if SERVER then
        AddCSLuaFile("inventory/items/" .. itemFile)
    end
    include("inventory/items/" .. itemFile)
end