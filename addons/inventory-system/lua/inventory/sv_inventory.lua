util.AddNetworkString("OpenInventory")
util.AddNetworkString("SyncInventory")
util.AddNetworkString("DropItem")
util.AddNetworkString("UseItem")
util.AddNetworkString("DeleteItem")

local PlayerInventories = {}

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

local function LoadPlayerInventory(ply)
    local steamID = ply:SteamID()
    MySQLite.query([[
        SELECT items FROM darkrp_custom_inventory WHERE steamid = ]] .. MySQLite.SQLStr(steamID) .. [[
    ]], function(data)
        if data and data[1] then
            PlayerInventories[steamID] = util.JSONToTable(data[1].items) or {}
        else
            PlayerInventories[steamID] = {}
        end
        net.Start("SyncInventory")
        net.WriteTable(PlayerInventories[steamID])
        net.Send(ply)
    end, function(err)
        print("[Custom Inventory] Error loading inventory for " .. steamID .. ": " .. err)
        PlayerInventories[steamID] = {}
    end)
end

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

hook.Add("PlayerInitialSpawn", "InitInventory", function(ply)
    LoadPlayerInventory(ply)
end)

hook.Add("PlayerDisconnected", "SaveInventoryOnDisconnect", function(ply)
    SavePlayerInventory(ply)
end)

function AddItemToInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or {}
    inv[itemID] = (inv[itemID] or 0) + (amount or 1)

    PlayerInventories[steamID] = inv
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
    SavePlayerInventory(ply)
end

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
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
    SavePlayerInventory(ply)
end

net.Receive("OpenInventory", function(len, ply)
    local inv = PlayerInventories[ply:SteamID()] or {}
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
end)

net.Receive("DropItem", function(len, ply)
    local itemID = net.ReadString()
    local amount = net.ReadUInt(8)
    if not InventoryItems[itemID] or amount < 1 then return end

    RemoveItemFromInventory(ply, itemID, amount)

    local itemData = InventoryItems[itemID]
    local entClass = itemData.entityClass or "prop_physics" -- Default to prop if no entity specified
    local ent = ents.Create(entClass)
    if IsValid(ent) then
        ent:SetModel(itemData.model)
        ent:SetPos(ply:GetPos() + ply:GetForward() * 50)
        ent:Spawn()

        -- Store item ID for pickup
        ent:SetNWString("ItemID", itemID)

        -- Make it usable if it’s a weapon or health kit
        if entClass == "weapon_pistol" then
            ent.AmmoAmount = 30 -- Example ammo for weapons
        elseif entClass == "item_healthkit" then
            ent:SetHealthAmount(25) -- Example health amount
        end
    end
end)

net.Receive("UseItem", function(len, ply)
    local itemID = net.ReadString()
    local itemData = InventoryItems[itemID]
    if not itemData or not itemData.useFunction then return end

    itemData.useFunction(ply)
    RemoveItemFromInventory(ply, itemID, 1)
end)

net.Receive("DeleteItem", function(len, ply)
    local itemID = net.ReadString()
    local amount = net.ReadUInt(8)
    if not InventoryItems[itemID] or amount < 1 then return end

    RemoveItemFromInventory(ply, itemID, amount)
end)

concommand.Add("additem", function(ply, cmd, args)
    local itemID = args[1]
    local amount = tonumber(args[2]) or 1
    AddItemToInventory(ply, itemID, amount)
end)

-- Pickup logic for dropped items
hook.Add("PlayerUse", "PickupInventoryItem", function(ply, ent)
    local itemID = ent:GetNWString("ItemID")
    if itemID and InventoryItems[itemID] then
        AddItemToInventory(ply, itemID, 1)
        ent:Remove()
        return true
    end
end)