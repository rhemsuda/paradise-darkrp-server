util.AddNetworkString("DropItem")
util.AddNetworkString("OpenInventory")
util.AddNetworkString("SyncInventory")

local PlayerInventories = {}

-- Initialize inventory for a player
hook.Add("PlayerInitialSpawn", "InitInventory", function(ply)
    PlayerInventories[ply:SteamID()] = PlayerInventories[ply:SteamID()] or {}
end)

-- Add an item to a player's inventory (example function)
function AddItemToInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local inv = PlayerInventories[ply:SteamID()]
    inv[itemID] = (inv[itemID] or 0) + (amount or 1)

    -- Sync inventory with client
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
end

-- Handle opening the inventory
net.Receive("OpenInventory", function(len, ply)
    local inv = PlayerInventories[ply:SteamID()] or {}
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
end)

-- Example command to test adding items
concommand.Add("additem", function(ply, cmd, args)
    local itemID = args[1]
    local amount = tonumber(args[2]) or 1
    AddItemToInventory(ply, itemID, amount)
end)

-- Remove an item from a player's inventory
local function RemoveItemFromInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local inv = PlayerInventories[ply:SteamID()]
    if not inv[itemID] or inv[itemID] < amount then return end

    inv[itemID] = inv[itemID] - amount
    if inv[itemID] <= 0 then
        inv[itemID] = nil -- Remove the item entirely if amount reaches 0
    end

    -- Sync updated inventory with client
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
end

-- Handle drop request from client
net.Receive("DropItem", function(len, ply)
    local itemID = net.ReadString()
    local amount = net.ReadUInt(8)

    if not InventoryItems[itemID] or amount < 1 then return end

    -- Remove item from inventory
    RemoveItemFromInventory(ply, itemID, amount)

    -- Optional: Spawn the item in the world
    local ent = ents.Create("prop_physics")
    if IsValid(ent) then
        ent:SetModel(InventoryItems[itemID].model)
        ent:SetPos(ply:GetPos() + ply:GetForward() * 50) -- Drop in front of player
        ent:Spawn()

        -- Optional: Add a pickup system later
    end
end)