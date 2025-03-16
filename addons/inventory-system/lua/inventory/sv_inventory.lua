util.AddNetworkString("OpenInventory")
util.AddNetworkString("SyncInventory")
util.AddNetworkString("DropItem")

local PlayerInventories = {}

-- Initialize the custom inventory table after DarkRP database is ready
hook.Add("DarkRPDBInitialized", "InitCustomInventoryTable", function()
    MySQLite.begin()
    local is_mysql = MySQLite.isMySQL()
    local ENGINE_INNODB = is_mysql and "ENGINE=InnoDB" or ""

    MySQLite.queueQuery([[
        CREATE TABLE IF NOT EXISTS darkrp_custom_inventory (
            steamid VARCHAR(20) NOT NULL PRIMARY KEY,
            items TEXT NOT NULL
        ) ]] .. ENGINE_INNODB .. [[;
    ]])

    MySQLite.commit(function()
        print("[Custom Inventory] Table 'darkrp_custom_inventory' initialized successfully!")
    end)
end)

-- Load inventory from database
local function LoadPlayerInventory(ply)
    local steamID = ply:SteamID()
    MySQLite.query([[
        SELECT items FROM darkrp_custom_inventory WHERE steamid = ]] .. MySQLite.SQLStr(steamID) .. [[
    ]], function(data)
        if data and data[1] then
            PlayerInventories[steamID] = util.JSONToTable(data[1].items) or {}
        else
            PlayerInventories[steamID] = {} -- New player, empty inventory
        end
        -- Sync with client immediately after loading
        net.Start("SyncInventory")
        net.WriteTable(PlayerInventories[steamID])
        net.Send(ply)
    end, function(err)
        print("[Custom Inventory] Error loading inventory for " .. steamID .. ": " .. err)
        PlayerInventories[steamID] = {} -- Fallback to empty inventory
    end)
end

-- Save inventory to database
local function SavePlayerInventory(ply)
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or {}
    local json = util.TableToJSON(inv)
    MySQLite.query([[
        REPLACE INTO darkrp_custom_inventory (steamid, items) VALUES (]] .. 
        MySQLite.SQLStr(steamID) .. [[, ]] .. MySQLite.SQLStr(json) .. [[)
    ]], nil, function(err)
        print("[Custom Inventory] Error saving inventory for " .. steamID .. ": " .. err)
    end)
end

-- Initialize inventory for a player
hook.Add("PlayerInitialSpawn", "InitInventory", function(ply)
    LoadPlayerInventory(ply)
end)

-- Save inventory when player disconnects
hook.Add("PlayerDisconnected", "SaveInventoryOnDisconnect", function(ply)
    SavePlayerInventory(ply)
end)

-- Add an item to a player's inventory
function AddItemToInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or {}
    inv[itemID] = (inv[itemID] or 0) + (amount or 1)

    PlayerInventories[steamID] = inv

    -- Sync inventory with client
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)

    -- Save to database
    SavePlayerInventory(ply)
end

-- Remove an item from a player's inventory
local function RemoveItemFromInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or {}
    if not inv[itemID] or inv[itemID] < amount then return end

    inv[itemID] = inv[itemID] - amount
    if inv[itemID] <= 0 then
        inv[itemID] = nil
    end

    PlayerInventories[steamID] = inv

    -- Sync inventory with client
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)

    -- Save to database
    SavePlayerInventory(ply)
end

-- Handle opening the inventory
net.Receive("OpenInventory", function(len, ply)
    local inv = PlayerInventories[ply:SteamID()] or {}
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
end)

-- Handle drop request from client
net.Receive("DropItem", function(len, ply)
    local itemID = net.ReadString()
    local amount = net.ReadUInt(8)

    if not InventoryItems[itemID] or amount < 1 then return end

    -- Remove item from inventory
    RemoveItemFromInventory(ply, itemID, amount)

    -- Spawn the item in the world
    local ent = ents.Create("prop_physics")
    if IsValid(ent) then
        ent:SetModel(InventoryItems[itemID].model)
        ent:SetPos(ply:GetPos() + ply:GetForward() * 50)
        ent:Spawn()
    end
end)

-- Example command to test adding items
concommand.Add("additem", function(ply, cmd, args)
    local itemID = args[1]
    local amount = tonumber(args[2]) or 1
    AddItemToInventory(ply, itemID, amount)
end)