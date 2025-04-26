-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Inventory Module] sv_inventory.lua loaded successfully")

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug") and GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Shared Logic
util.AddNetworkString("SyncInventory")
util.AddNetworkString("DropItem")
util.AddNetworkString("UseItem")
util.AddNetworkString("DeleteItem")
util.AddNetworkString("InventoryMessage") -- Keeping for backwards compatibility but won't use it
util.AddNetworkString("InventoryNotification") -- For tooltip notifications
util.AddNetworkString("UpdateInventoryPositions")
util.AddNetworkString("SyncLoadout")
util.AddNetworkString("EquipItem")
util.AddNetworkString("UnequipItem")
util.AddNetworkString("SyncResources") -- Already present in your system, ensuring it's defined
util.AddNetworkString("CraftItem") -- For crafting system

-- Include sh_items.lua
if file.Exists("modules/inventory/sh_items.lua", "LUA") then
    include("modules/inventory/sh_items.lua")
    AddCSLuaFile("modules/inventory/sh_items.lua")
end

PlayerInventories = PlayerInventories or {}

-- Utility Functions
local function GenerateUUID()
    return string.format("%08x-%04x-%04x-%04x-%12x", 
        math.random(0, 0xffffffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffffffffffff))
end

-- Weapon Type Definitions for Damage Assignment
local WeaponTypes = {
    -- Pistols
    ["weapon_pistol"] = "pistol",
    ["deagle"] = "pistol",
    ["fiveseven"] = "pistol",
    -- Assault Rifles
    ["ak47"] = "assault_rifle",
    ["m4a1"] = "assault_rifle",
    ["sg552"] = "assault_rifle",
    ["aug"] = "assault_rifle",
    ["m249"] = "assault_rifle",
    -- Shotguns
    ["weapon_shotgun"] = "shotgun",
    ["spas12"] = "shotgun",
    -- Snipers
    ["awp"] = "sniper",
    ["scout"] = "sniper",
    ["g3sg1"] = "sniper"
}

-- Function to send notification messages to the client
local function SendInventoryMessage(ply, message)
    if not IsValid(ply) then return end
    net.Start("InventoryNotification")
    net.WriteString(GenerateUUID()) -- Unique ID for the notification
    net.WriteString(message)
    net.Send(ply)
    DebugPrint("[Inventory Module] Sent notification to " .. ply:Nick() .. ": " .. message)
end

-- Inventory Management Functions
function AddItemToInventory(ply, itemID, amount, stats, page, silent)
    if not IsValid(ply) or not InventoryItems[itemID] then 
        DebugPrint("[Inventory Module] Invalid player or itemID: " .. tostring(itemID))
        return 
    end

    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {}, resources = { rock = 0, copper = 0, iron = 0, steel = 0 } }
    page = tonumber(page) or 1
    inv.maxPages = inv.maxPages or 1

    if page < 1 or page > inv.maxPages then 
        DebugPrint("[Inventory Module] Invalid page " .. page .. " for " .. ply:Nick() .. " (maxPages: " .. inv.maxPages .. ")")
        return 
    end

    inv.items[page] = inv.items[page] or {}
    inv.positions[page] = inv.positions[page] or {}

    for i = 1, (amount or 1) do
        local uniqueID = stats and stats.id or GenerateUUID()
        local isWeaponOrArmor = InventoryItems[itemID].category == "Weapons" or InventoryItems[itemID].category == "Armor"
        -- Only generate stats if none are provided (i.e., new item)
        if not stats then
            stats = {
                damage = 0, -- Will be set below for weapons
                rarity = nil,
                slotType = nil,
                crafter = ply:Nick()
            }
            if isWeaponOrArmor then
                local rarityRoll = math.random(1, 200)
                if rarityRoll == 1 then
                    stats.rarity = "Legendary" -- 1/200 or 0.5%
                elseif rarityRoll <= 6 then
                    stats.rarity = "Epic" -- 2-6, 5/200 or 2.5%
                elseif rarityRoll <= 16 then
                    stats.rarity = "Rare" -- 7-16, 10/200 or 5%
                elseif rarityRoll <= 36 then
                    stats.rarity = "Uncommon" -- 17-36, 20/200 or 10%
                else
                    stats.rarity = "Common" -- 37-200, 164/200 or 82%
                end

                if InventoryItems[itemID].category == "Weapons" then
                    stats.slotType = math.random(1, 500) == 1 and "Sidearm" or "Primary"
                    local weaponType = WeaponTypes[itemID] or "unknown"
                    if weaponType == "pistol" then
                        stats.damage = stats.rarity == "Legendary" and math.random(6, 20) or math.random(6, 15)
                    elseif weaponType == "assault_rifle" then
                        stats.damage = stats.rarity == "Legendary" and math.random(15, 25) or math.random(12, 20)
                    elseif weaponType == "shotgun" then
                        stats.damage = stats.rarity == "Legendary" and math.random(5, 15) or math.random(5, 10)
                    elseif weaponType == "sniper" then
                        stats.damage = stats.rarity == "Legendary" and math.random(50, 100) or math.random(25, 50)
                    else
                        stats.damage = math.random(10, 80)
                    end
                end
            end
        end

        local itemInstance = { 
            id = uniqueID, 
            itemID = itemID, 
            damage = stats.damage, 
            rarity = stats.rarity, 
            slotType = stats.slotType, 
            crafter = stats.crafter 
        }
        table.insert(inv.items[page], itemInstance)

        -- Assign a position in the inventory grid
        local positionAssigned = false
        for row = 1, 6 do
            for col = 1, 10 do
                local slotTaken = false
                for _, pos in pairs(inv.positions[page]) do
                    if pos[1] == row and pos[2] == col then 
                        slotTaken = true 
                        break 
                    end
                end
                if not slotTaken then
                    inv.positions[page][uniqueID] = {row, col}
                    positionAssigned = true
                    break
                end
            end
            if positionAssigned then break end
        end
    end

    PlayerInventories[steamID] = inv
    net.Start("SyncInventory")
    net.WriteUInt(page, 8)
    net.WriteTable(inv.items[page])
    net.WriteTable(inv.positions[page])
    net.Send(ply)
    SavePlayerInventory(ply)
    if not silent then
        SendInventoryMessage(ply, "Added " .. (amount or 1) .. " " .. InventoryItems[itemID].name .. "(s) to your inventory on page " .. page .. ".")
        DebugPrint("[Inventory Module] Added " .. (amount or 1) .. " " .. InventoryItems[itemID].name .. " to " .. ply:Nick() .. "'s inventory on page " .. page)
    end
end

-- Server-Side Logic
hook.Add("DarkRPDBInitialized", "InitCustomInventoryTable", function()
    MySQLite.begin()
    MySQLite.queueQuery([[
        CREATE TABLE IF NOT EXISTS darkrp_custom_inventory (
            steamid VARCHAR(20) NOT NULL PRIMARY KEY,
            items TEXT NOT NULL DEFAULT '{"1":[]}',
            resources TEXT NOT NULL DEFAULT '{}',
            positions TEXT NOT NULL DEFAULT '{"1":{}}',
            maxPages INTEGER NOT NULL DEFAULT 1,
            loadout TEXT NOT NULL DEFAULT '{}'
        )
    ]])
    MySQLite.commit(function()
        print("[Custom Inventory] Table 'darkrp_custom_inventory' initialized or updated successfully!")
        MySQLite.query("ALTER TABLE darkrp_custom_inventory ADD COLUMN loadout TEXT NOT NULL DEFAULT '{}'", function()
            print("[Custom Inventory] Added loadout column to darkrp_custom_inventory (or it already exists)")
        end, function(err)
            print("[Custom Inventory] Loadout column already exists or failed to add: " .. err)
        end)
    end, function(err)
        print("[Custom Inventory] Failed to initialize table: " .. err)
    end)
end)

local function LoadPlayerInventory(ply)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    MySQLite.query("SELECT items, positions, maxPages, loadout, resources FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
        local inv = { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {}, resources = { rock = 0, copper = 0, iron = 0, steel = 0 } }
        if data and data[1] then
            inv.items = util.JSONToTable(data[1].items or '{"1":[]}') or { [1] = {} }
            inv.positions = util.JSONToTable(data[1].positions or '{"1":{}}') or { [1] = {} }
            inv.maxPages = tonumber(data[1].maxPages) or 1
            inv.loadout = util.JSONToTable(data[1].loadout or '{}') or {}
            inv.resources = table.Merge({ rock = 0, copper = 0, iron = 0, steel = 0 }, util.JSONToTable(data[1].resources or '{}') or {})
        end
        PlayerInventories[steamID] = inv
        net.Start("SyncInventory")
        net.WriteUInt(1, 8)
        net.WriteTable(inv.items[1])
        net.WriteTable(inv.positions[1])
        net.Send(ply)
        net.Start("SyncLoadout")
        net.WriteTable(inv.loadout)
        net.Send(ply)
        net.Start("SyncResources")
        net.WriteTable(inv.resources)
        net.Send(ply)
        DebugPrint("[Inventory Module] Loaded inventory for " .. ply:Nick() .. " with loadout: " .. table.ToString(inv.loadout, "Loadout", true))
    end, function(err)
        print("[Inventory Module] Error loading inventory for " .. steamID .. ": " .. err)
    end)
end

function SavePlayerInventory(ply)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {}, resources = { rock = 0, copper = 0, iron = 0, steel = 0 } }
    DebugPrint("[Inventory Module] Saving inventory for " .. ply:Nick() .. " with loadout: " .. table.ToString(inv.loadout, "Loadout", true))
    MySQLite.query("REPLACE INTO darkrp_custom_inventory (steamid, items, resources, positions, maxPages, loadout) VALUES (" .. 
        MySQLite.SQLStr(steamID) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.items)) .. ", " .. 
        MySQLite.SQLStr(util.TableToJSON(inv.resources)) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.positions)) .. ", " .. 
        inv.maxPages .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.loadout)) .. ")", nil, function(err)
        if err then 
            print("[Inventory Module] Error saving inventory for " .. steamID .. ": " .. err)
        else
            DebugPrint("[Inventory Module] Saved inventory for " .. ply:Nick())
        end
    end)
end

local function SyncInventoryFromSQL(ply, page)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    MySQLite.query("SELECT items, positions FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
        if data and data[1] then
            local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {}, resources = { rock = 0, copper = 0, iron = 0, steel = 0 } }
            inv.items = util.JSONToTable(data[1].items or '{"1":[]}') or { [1] = {} }
            inv.positions = util.JSONToTable(data[1].positions or '{"1":{}}') or { [1] = {} }
            PlayerInventories[steamID] = inv
            net.Start("SyncInventory")
            net.WriteUInt(page, 8)
            net.WriteTable(inv.items[page] or {})
            net.WriteTable(inv.positions[page] or {})
            net.Send(ply)
            DebugPrint("[Inventory Module] Synced inventory page " .. page .. " for " .. ply:Nick())
        end
    end, function(err)
        print("[Inventory Module] Error syncing inventory for " .. steamID .. ": " .. err)
    end)
end

local function RemoveItemFromInventory(ply, uniqueID, page)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {}, resources = { rock = 0, copper = 0, iron = 0, steel = 0 } }
    page = page or 1
    inv.items[page] = inv.items[page] or {}
    inv.positions[page] = inv.positions[page] or {}

    for i, item in ipairs(inv.items[page]) do
        if item.id == uniqueID then
            local itemData = InventoryItems[item.itemID]
            table.remove(inv.items[page], i)
            inv.positions[page][uniqueID] = nil
            PlayerInventories[steamID] = inv
            net.Start("SyncInventory")
            net.WriteUInt(page, 8)
            net.WriteTable(inv.items[page])
            net.WriteTable(inv.positions[page])
            net.Send(ply)
            SavePlayerInventory(ply)
            DebugPrint("[Inventory Module] Removed item " .. uniqueID .. " from " .. ply:Nick() .. "'s inventory on page " .. page)
            return itemData
        end
    end
    return nil
end

-- Crafting System Functions
local function CanCraftItem(ply, itemID)
    if not IsValid(ply) or not InventoryItems[itemID] or not InventoryItems[itemID].craftingRequirements then
        return false, "Invalid item or no crafting requirements."
    end

    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID]
    if not inv or not inv.resources then
        return false, "Inventory not initialized."
    end

    local requirements = InventoryItems[itemID].craftingRequirements
    for resource, amount in pairs(requirements) do
        if (inv.resources[resource] or 0) < amount then
            return false, "Not enough " .. resource .. ". Need " .. amount .. ", have " .. (inv.resources[resource] or 0) .. "."
        end
    end
    return true, "Can craft."
end

local function DeductCraftingResources(ply, itemID)
    if not IsValid(ply) or not InventoryItems[itemID] or not InventoryItems[itemID].craftingRequirements then return end

    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID]
    local requirements = InventoryItems[itemID].craftingRequirements

    for resource, amount in pairs(requirements) do
        inv.resources[resource] = (inv.resources[resource] or 0) - amount
    end

    PlayerInventories[steamID] = inv
    net.Start("SyncResources")
    net.WriteTable(inv.resources)
    net.Send(ply)
    SavePlayerInventory(ply)
    DebugPrint("[Inventory Module] Deducted resources for crafting " .. itemID .. " from " .. ply:Nick())
end

-- Network Receivers
net.Receive("DropItem", function(len, ply)
    local uniqueID = net.ReadString()
    local page = net.ReadUInt(8)
    local itemData = RemoveItemFromInventory(ply, uniqueID, page)
    if not itemData then
        SendInventoryMessage(ply, "Item not found.")
        return
    end

    if itemData.category == "Weapons" or itemData.category == "Armor" then
        SendInventoryMessage(ply, "Cannot drop Weapons or Armor.")
        AddItemToInventory(ply, itemData.itemID, 1, { id = uniqueID, damage = itemData.damage, rarity = itemData.rarity, slotType = itemData.slotType, crafter = itemData.crafter }, page)
        return
    end

    local ent = ents.Create(itemData.entityClass or "prop_physics")
    if not IsValid(ent) then
        SendInventoryMessage(ply, "Failed to drop item: Invalid entity.")
        AddItemToInventory(ply, itemData.itemID, 1, { id = uniqueID, damage = itemData.damage, rarity = itemData.rarity, slotType = itemData.slotType, crafter = itemData.crafter }, page)
        return
    end

    local trace = ply:GetEyeTrace()
    local pos = trace.HitPos + trace.HitNormal * 10
    ent:SetModel(itemData.model or "models/error.mdl")
    ent:SetPos(pos)
    ent:Spawn()
    SendInventoryMessage(ply, "Dropped " .. itemData.name .. ".")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " dropped item " .. uniqueID .. " (" .. itemData.name .. ")")
end)

net.Receive("UseItem", function(len, ply)
    local uniqueID = net.ReadString()
    local page = net.ReadUInt(8)
    local itemData = RemoveItemFromInventory(ply, uniqueID, page)
    if not itemData then
        SendInventoryMessage(ply, "Item not found.")
        return
    end

    local itemInfo = InventoryItems[itemData.itemID]
    if itemInfo.useFunction then
        itemInfo.useFunction(ply)
        SendInventoryMessage(ply, "Used " .. itemInfo.name .. ".")
        DebugPrint("[Inventory Module] " .. ply:Nick() .. " used item " .. uniqueID .. " (" .. itemInfo.name .. ")")
    else
        SendInventoryMessage(ply, "This item cannot be used.")
        AddItemToInventory(ply, itemData.itemID, 1, { id = uniqueID, damage = itemData.damage, rarity = itemData.rarity, slotType = itemData.slotType, crafter = itemData.crafter }, page)
    end
end)

net.Receive("DeleteItem", function(len, ply)
    local uniqueID = net.ReadString()
    local page = net.ReadUInt(8)
    local itemData = RemoveItemFromInventory(ply, uniqueID, page)
    if not itemData then
        SendInventoryMessage(ply, "Item not found.")
        return
    end
    SendInventoryMessage(ply, "Deleted " .. InventoryItems[itemData.itemID].name .. ".")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " deleted item " .. uniqueID .. " (" .. InventoryItems[itemData.itemID].name .. ")")
end)

net.Receive("UpdateInventoryPositions", function(len, ply)
    local page = net.ReadUInt(8)
    local newPositions = net.ReadTable()
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {}, resources = { rock = 0, copper = 0, iron = 0, steel = 0 } }
    inv.positions[page] = newPositions
    PlayerInventories[steamID] = inv
    SavePlayerInventory(ply)
    DebugPrint("[Inventory Module] Updated positions for " .. ply:Nick() .. " on page " .. page)
end)

net.Receive("EquipItem", function(len, ply)
    local uniqueID = net.ReadString()
    local page = net.ReadUInt(8)
    local slot = net.ReadString()
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {}, resources = { rock = 0, copper = 0, iron = 0, steel = 0 } }
    local item, itemIndex

    for i, it in ipairs(inv.items[page] or {}) do
        if it.id == uniqueID then
            item = it
            itemIndex = i
            break
        end
    end

    if not item then
        SendInventoryMessage(ply, "Item not found.")
        return
    end

    local itemData = InventoryItems[item.itemID]
    if not itemData then
        SendInventoryMessage(ply, "Invalid item data.")
        return
    end

    local expectedCategory = (slot == "Utility") and "Utility" or "Weapons"
    if itemData.category ~= expectedCategory then
        SendInventoryMessage(ply, "This item cannot be equipped in this slot.")
        return
    end

    if slot == "Weapon" and item.slotType ~= "Primary" then
        SendInventoryMessage(ply, "This weapon can only be equipped as a Sidearm.")
        return
    elseif slot == "Sidearm" and item.slotType ~= "Sidearm" then
        SendInventoryMessage(ply, "This weapon can only be equipped as a Primary.")
        return
    end

    if inv.loadout[slot] then
        local oldItem = inv.loadout[slot]
        table.insert(inv.items[page], oldItem)
        inv.positions[page][oldItem.id] = inv.positions[page][uniqueID]
    end

    inv.loadout[slot] = item
    table.remove(inv.items[page], itemIndex)
    inv.positions[page][uniqueID] = nil

    PlayerInventories[steamID] = inv
    net.Start("SyncInventory")
    net.WriteUInt(page, 8)
    net.WriteTable(inv.items[page])
    net.WriteTable(inv.positions[page])
    net.Send(ply)
    net.Start("SyncLoadout")
    net.WriteTable(inv.loadout)
    net.Send(ply)
    SavePlayerInventory(ply)
    SendInventoryMessage(ply, "Equipped " .. itemData.name .. " to " .. slot .. " slot.")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " equipped item " .. uniqueID .. " to " .. slot .. " slot")
end)

net.Receive("UnequipItem", function(len, ply)
    local slot = net.ReadString()
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {}, resources = { rock = 0, copper = 0, iron = 0, steel = 0 } }
    local page = 1 -- Default to page 1 for unequipping

    if not inv.loadout[slot] then
        SendInventoryMessage(ply, "No item equipped in " .. slot .. " slot.")
        return
    end

    local item = inv.loadout[slot]
    local itemData = InventoryItems[item.itemID]
    inv.loadout[slot] = nil
    AddItemToInventory(ply, item.itemID, 1, { id = item.id, damage = item.damage, rarity = item.rarity, slotType = item.slotType, crafter = item.crafter }, page)
    PlayerInventories[steamID] = inv
    net.Start("SyncLoadout")
    net.WriteTable(inv.loadout)
    net.Send(ply)
    SavePlayerInventory(ply)
    SendInventoryMessage(ply, "Unequipped " .. itemData.name .. " from " .. slot .. " slot.")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " unequipped item from " .. slot .. " slot")
end)

net.Receive("CraftItem", function(len, ply)
    local itemID = net.ReadString()
    local page = net.ReadUInt(8)
    if not IsValid(ply) or not InventoryItems[itemID] then
        SendInventoryMessage(ply, "Invalid item.")
        return
    end

    local canCraft, reason = CanCraftItem(ply, itemID)
    if not canCraft then
        SendInventoryMessage(ply, reason)
        return
    end

    DeductCraftingResources(ply, itemID)
    AddItemToInventory(ply, itemID, 1, nil, page)
    SendInventoryMessage(ply, "Crafted " .. InventoryItems[itemID].name .. ".")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " crafted " .. itemID)
end)

hook.Add("PlayerInitialSpawn", "LoadCustomInventory", function(ply)
    LoadPlayerInventory(ply)
end)

hook.Add("PlayerDisconnected", "SaveCustomInventory", function(ply)
    SavePlayerInventory(ply)
    PlayerInventories[ply:SteamID()] = nil
end)

-- Admin command to give items
concommand.Add("rp_giveitem", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then
        SendInventoryMessage(ply, "You must be a superadmin to use this command.")
        return
    end

    if #args < 2 then
        SendInventoryMessage(ply, "Usage: rp_giveitem <SteamID> <itemID> [amount] [page]")
        return
    end

    local targetSteamID = args[1]
    local itemID = args[2]
    local amount = tonumber(args[3]) or 1
    local page = tonumber(args[4]) or 1
    local target = nil

    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == targetSteamID then
            target = p
            break
        end
    end

    if not target then
        SendInventoryMessage(ply, "Player with SteamID " .. targetSteamID .. " not found.")
        return
    end

    if not InventoryItems[itemID] then
        SendInventoryMessage(ply, "Item " .. itemID .. " does not exist.")
        return
    end

    AddItemToInventory(target, itemID, amount, nil, page)
    SendInventoryMessage(ply, "Gave " .. amount .. " " .. InventoryItems[itemID].name .. "(s) to " .. target:Nick() .. " on page " .. page .. ".")
end)

-- This print will always show to confirm successful load
print("[Inventory Module] Server-side loaded successfully.")