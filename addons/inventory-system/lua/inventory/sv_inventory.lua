-- Define network strings for client-server communication
util.AddNetworkString("OpenInventory") -- Opens the inventory UI
util.AddNetworkString("SyncInventory") -- Syncs inventory data to client
util.AddNetworkString("DropItem") -- Handles dropping items
util.AddNetworkString("UseItem") -- Handles using items
util.AddNetworkString("DeleteItem") -- Handles deleting items
util.AddNetworkString("InventoryMessage") -- Sends player-only chat messages

local PlayerInventories = {} -- Stores each player's inventory (SteamID -> {itemID -> amount})
local PickupCooldown = {} -- Prevents spamming "cannot pick up" messages (SteamID -> EntIndex -> timestamp)

-- Hook into DarkRP's database initialization to create our inventory table
hook.Add("DarkRPDBInitialized", "InitCustomInventoryTable", function()
    MySQLite.begin() -- Start a transaction for multiple queries
    local is_mysql = MySQLite.isMySQL() -- Check if using MySQL or SQLite
    local ENGINE_INNODB = is_mysql and "ENGINE=InnoDB" or "" -- Set engine for MySQL compatibility

    -- Create the inventory table if it doesn’t exist
    MySQLite.queueQuery([[
        CREATE TABLE IF NOT EXISTS darkrp_custom_inventory (
            steamid VARCHAR(20) NOT NULL PRIMARY KEY, -- Player's SteamID
            items TEXT NOT NULL -- JSON string of inventory items
        ) ]] .. ENGINE_INNODB .. [[;
    ]])

    MySQLite.commit(function()
        print("[Custom Inventory] Table 'darkrp_custom_inventory' initialized successfully!")
    end) -- Commit the transaction and log success
end)

-- Sends a message to the player’s chat and logs it to console
local function SendInventoryMessage(ply, message)
    net.Start("InventoryMessage") -- Start the network message
    net.WriteString(message) -- Send the message text
    net.Send(ply) -- Send only to the player
    print("[Inventory Log] " .. ply:Nick() .. " (" .. ply:SteamID() .. "): " .. message) -- Log to server console
end

-- Loads a player’s inventory from the database
local function LoadPlayerInventory(ply)
    local steamID = ply:SteamID() -- Get player’s SteamID
    MySQLite.query([[
        SELECT items FROM darkrp_custom_inventory WHERE steamid = ]] .. MySQLite.SQLStr(steamID) .. [[
    ]], function(data) -- Success callback
        if data and data[1] then
            PlayerInventories[steamID] = util.JSONToTable(data[1].items) or {} -- Load JSON into table
        else
            PlayerInventories[steamID] = {} -- Empty inventory for new players
        end
        net.Start("SyncInventory") -- Sync loaded inventory to client
        net.WriteTable(PlayerInventories[steamID])
        net.Send(ply)
    end, function(err) -- Error callback
        print("[Custom Inventory] Error loading inventory for " .. steamID .. ": " .. err)
        PlayerInventories[steamID] = {} -- Fallback to empty inventory
    end)
end

-- Saves a player’s inventory to the database
local function SavePlayerInventory(ply)
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or {} -- Get current inventory
    local json = util.TableToJSON(inv) -- Convert to JSON string
    MySQLite.query([[
        REPLACE INTO darkrp_custom_inventory (steamid, items) VALUES (]] .. 
        MySQLite.SQLStr(steamID) .. [[, ]] .. MySQLite.SQLStr(json) .. [[)
    ]], nil, function(err) -- Error callback
        print("[Custom Inventory] Error saving inventory for " .. steamID .. ": " .. err)
    end)
end

-- Initialize inventory and give weapon when a player spawns
hook.Add("PlayerInitialSpawn", "InitInventory", function(ply)
    LoadPlayerInventory(ply) -- Load inventory from database
    ply:Give("weapon_inventory") -- Give the inventory SWEP
end)

-- Save inventory when a player disconnects
hook.Add("PlayerDisconnected", "SaveInventoryOnDisconnect", function(ply)
    SavePlayerInventory(ply) -- Persist inventory to database
end)

-- Adds items to a player’s inventory with stack limits
function AddItemToInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end -- Validate player and item
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or {}
    local maxStack = InventoryItems[itemID].maxStack or 64 -- Default stack limit
    local newAmount = math.min((inv[itemID] or 0) + (amount or 1), maxStack) -- Cap at max stack

    inv[itemID] = newAmount
    PlayerInventories[steamID] = inv
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
    SavePlayerInventory(ply)

    SendInventoryMessage(ply, "Added " .. amount .. " " .. InventoryItems[itemID].name .. "(s) to your inventory.")
end

-- Removes items from a player’s inventory
local function RemoveItemFromInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end -- Validate player and item
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or {}
    if not inv[itemID] or inv[itemID] < amount then return end -- Check if enough items exist

    inv[itemID] = inv[itemID] - amount
    if inv[itemID] <= 0 then
        inv[itemID] = nil -- Remove item if stack reaches 0
    end

    PlayerInventories[steamID] = inv
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
    SavePlayerInventory(ply)
end

-- Opens the inventory UI for the player
net.Receive("OpenInventory", function(len, ply)
    local inv = PlayerInventories[ply:SteamID()] or {}
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
end)

-- Handles dropping items from the inventory
net.Receive("DropItem", function(len, ply)
    local itemID = net.ReadString()
    local amount = net.ReadUInt(8)
    if not InventoryItems[itemID] or amount < 1 then return end -- Validate item and amount

    RemoveItemFromInventory(ply, itemID, amount)
    SendInventoryMessage(ply, "Dropped " .. amount .. " " .. InventoryItems[itemID].name .. "(s).")

    local itemData = InventoryItems[itemID]
    local entClass = itemData.entityClass or "prop_physics" -- Default to prop if no entity class
    for i = 1, amount do -- Spawn one entity per item dropped
        local ent = ents.Create(entClass)
        if IsValid(ent) then
            ent:SetModel(itemData.model)
            ent:SetPos(ply:GetPos() + ply:GetForward() * 50 + Vector(0, 0, i * 10)) -- Offset to avoid overlap
            ent:Spawn()
            ent:SetNWString("ItemID", itemID) -- Mark entity with item ID for pickup

            if entClass == "weapon_pistol" then
                ent.AmmoAmount = 30 -- Set ammo for weapons
            elseif entClass == "item_healthkit" then
                ent:SetHealthAmount(25) -- Set health amount for kits
            end
        end
    end
end)

-- Handles using an item from the inventory
net.Receive("UseItem", function(len, ply)
    local itemID = net.ReadString()
    local itemData = InventoryItems[itemID]
    if not itemData or not itemData.useFunction then return end -- Validate item and use function

    itemData.useFunction(ply) -- Execute the item’s use function
    RemoveItemFromInventory(ply, itemID, 1)
    SendInventoryMessage(ply, "Used 1 " .. itemData.name .. ".")
end)

-- Handles deleting items from the inventory
net.Receive("DeleteItem", function(len, ply)
    local itemID = net.ReadString()
    local amount = net.ReadUInt(8)
    if not InventoryItems[itemID] or amount < 1 then return end -- Validate item and amount

    RemoveItemFromInventory(ply, itemID, amount)
    SendInventoryMessage(ply, "Deleted " .. amount .. " " .. InventoryItems[itemID].name .. "(s).")
end)

-- Console command to add items, restricted to superadmins
concommand.Add("additem", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then -- Check if player is superadmin
        SendInventoryMessage(ply, "You must be a superadmin to use this command.")
        return
    end
    local itemID = args[1]
    local amount = tonumber(args[2]) or 1
    AddItemToInventory(ply, itemID, amount)
end)

-- Handles picking up dropped items or rejecting non-inventory entities
hook.Add("PlayerUse", "PickupInventoryItem", function(ply, ent)
    local itemID = ent:GetNWString("ItemID")
    if itemID and InventoryItems[itemID] then -- If it’s a valid inventory item
        AddItemToInventory(ply, itemID, 1)
        ent:Remove()
        SendInventoryMessage(ply, "Picked up 1 " .. InventoryItems[itemID].name .. ".")
        return true -- Allow pickup
    else -- If it’s not an inventory item
        local entIndex = ent:EntIndex()
        local steamID = ply:SteamID()
        PickupCooldown[steamID] = PickupCooldown[steamID] or {}
        local lastMessageTime = PickupCooldown[steamID][entIndex] or 0
        if CurTime() - lastMessageTime > 5 then -- 5-second cooldown to prevent spam
            SendInventoryMessage(ply, "You cannot pick up this item.")
            PickupCooldown[steamID][entIndex] = CurTime()
        end
    end
end)