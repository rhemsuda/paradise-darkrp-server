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
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {} }
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
                slots = 0,
                rarity = nil,
                slotType = nil,
                crafter = ply:Nick()
            }
            if isWeaponOrArmor then
                local rarityRoll = math.random(1, 500)
                stats.rarity = rarityRoll == 1 and "Legendary" or rarityRoll <= 3 and "Epic" or rarityRoll <= 10 and "Rare" or rarityRoll <= 50 and "Uncommon" or "Common"
                local slotCaps = { Common = 2, Uncommon = 3, Rare = 4, Epic = 5, Legendary = 6 }
                stats.slots = math.random(0, slotCaps[stats.rarity] or 2)

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
            slots = stats.slots, 
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
    MySQLite.query("SELECT items, positions, maxPages, loadout FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
        local inv = { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {} }
        if data and data[1] then
            inv.items = util.JSONToTable(data[1].items or '{"1":[]}') or { [1] = {} }
            inv.positions = util.JSONToTable(data[1].positions or '{"1":{}}') or { [1] = {} }
            inv.maxPages = tonumber(data[1].maxPages) or 1
            inv.loadout = util.JSONToTable(data[1].loadout or '{}') or {}
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
        DebugPrint("[Inventory Module] Loaded inventory for " .. ply:Nick() .. " with loadout: " .. table.ToString(inv.loadout, "Loadout", true))
    end, function(err)
        print("[Inventory Module] Error loading inventory for " .. steamID .. ": " .. err)
    end)
end

function SavePlayerInventory(ply)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {} }
    DebugPrint("[Inventory Module] Saving inventory for " .. ply:Nick() .. " with loadout: " .. table.ToString(inv.loadout, "Loadout", true))
    -- Fetch resources separately to preserve them in the database
    local resources = {}
    MySQLite.query("SELECT resources FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
        if data and data[1] then
            resources = util.JSONToTable(data[1].resources or "{}") or {}
        end
        MySQLite.query("REPLACE INTO darkrp_custom_inventory (steamid, items, resources, positions, maxPages, loadout) VALUES (" .. 
            MySQLite.SQLStr(steamID) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.items)) .. ", " .. 
            MySQLite.SQLStr(util.TableToJSON(resources)) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.positions)) .. ", " .. 
            inv.maxPages .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.loadout)) .. ")", nil, function(err)
            if err then 
                print("[Inventory Module] Error saving inventory for " .. steamID .. ": " .. err)
            else
                DebugPrint("[Inventory Module] Saved inventory for " .. ply:Nick())
            end
        end)
    end, function(err)
        print("[Inventory Module] Error fetching resources for saving inventory for " .. steamID .. ": " .. err)
        -- Fallback: Save with empty resources to avoid data loss
        MySQLite.query("REPLACE INTO darkrp_custom_inventory (steamid, items, resources, positions, maxPages, loadout) VALUES (" .. 
            MySQLite.SQLStr(steamID) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.items)) .. ", " .. 
            MySQLite.SQLStr(util.TableToJSON({})) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.positions)) .. ", " .. 
            inv.maxPages .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.loadout)) .. ")", nil, function(err2)
            if err2 then print("[Inventory Module] Fallback error saving inventory for " .. steamID .. ": " .. err2) end
        end)
    end)
end

local function SyncInventoryFromSQL(ply, page)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    MySQLite.query("SELECT items, positions FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
        if data and data[1] then
            local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {} }
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
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {} }
    page = page or 1
    inv.items[page] = inv.items[page] or {}
    inv.positions[page] = inv.positions[page] or {}

    for i, item in ipairs(inv.items[page]) do
        if item.id == uniqueID then
            local itemData = InventoryItems[item.itemID]
            table.remove(inv.items[page], i)
            inv.positions[page][uniqueID] = nil
            PlayerInventories[steamID] = inv
            SavePlayerInventory(ply)
            SyncInventoryFromSQL(ply, page)
            DebugPrint("[Inventory Module] Removed item " .. uniqueID .. " from " .. ply:Nick() .. "'s inventory on page " .. page)
            return item, itemData
        end
    end
    DebugPrint("[Inventory Module] Item " .. uniqueID .. " not found in " .. ply:Nick() .. "'s inventory on page " .. page)
end

net.Receive("UpdateInventoryPositions", function(len, ply)
    local page = net.ReadUInt(8)
    local steamID = ply:SteamID()
    local newPositions = net.ReadTable()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {} }
    inv.positions[page] = newPositions
    PlayerInventories[steamID] = inv
    SavePlayerInventory(ply)
    SyncInventoryFromSQL(ply, page)
    DebugPrint("[Inventory Module] Updated inventory positions for " .. ply:Nick() .. " on page " .. page)
end)

net.Receive("DropItem", function(len, ply)
    local uniqueID = net.ReadString()
    local page = net.ReadUInt(8)
    local item, itemData = RemoveItemFromInventory(ply, uniqueID, page)
    if not item or not itemData then 
        DebugPrint("[Inventory Module] Failed to drop item " .. uniqueID .. " for " .. ply:Nick() .. " on page " .. page)
        return 
    end

    if itemData.category == "Weapons" or itemData.category == "Armor" then
        SendInventoryMessage(ply, "Cannot drop weapons or armor!")
        AddItemToInventory(ply, item.itemID, 1, { id = item.id, damage = item.damage, slots = item.slots, rarity = item.rarity, slotType = item.slotType, crafter = item.crafter }, page, true)
        DebugPrint("[Inventory Module] Prevented " .. ply:Nick() .. " from dropping " .. itemData.name .. " (category: " .. itemData.category .. ")")
        return
    end

    SendInventoryMessage(ply, "You dropped your " .. itemData.name .. " from page " .. page .. ".")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " dropped 1 " .. itemData.name .. " from page " .. page)
    local ent = ents.Create("prop_physics")
    if IsValid(ent) then
        ent:SetModel(itemData.model or "models/error.mdl")
        ent:SetPos(ply:EyePos() + ply:GetForward() * 50)
        ent:Spawn()
        ent:SetNWString("UniqueID", uniqueID)
        ent:SetNWString("ItemID", item.itemID)
        ent:SetNWInt("Damage", item.damage or 0)
        ent:SetNWInt("Slots", item.slots or 0)
        ent:SetNWString("Rarity", item.rarity or "")
        ent:SetNWString("Crafter", item.crafter or "Unknown")
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then 
            phys:Wake() 
            phys:SetVelocity(Vector(0, 0, -100)) 
        end
        ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    end
end)

net.Receive("UseItem", function(len, ply)
    local uniqueID = net.ReadString()
    local page = net.ReadUInt(8)
    local item, itemData = RemoveItemFromInventory(ply, uniqueID, page)
    if not item or not itemData or not itemData.useFunction then 
        DebugPrint("[Inventory Module] Failed to use item " .. uniqueID .. " for " .. ply:Nick() .. " on page " .. page)
        return 
    end
    itemData.useFunction(ply)
    SendInventoryMessage(ply, "You used your " .. itemData.name .. " from page " .. page .. ".")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " used 1 " .. itemData.name .. " from page " .. page)
end)

net.Receive("DeleteItem", function(len, ply)
    local uniqueID = net.ReadString()
    local page = net.ReadUInt(8)
    local item, itemData = RemoveItemFromInventory(ply, uniqueID, page)
    if not item or not itemData then 
        DebugPrint("[Inventory Module] Failed to delete item " .. uniqueID .. " for " .. ply:Nick() .. " on page " .. page)
        return 
    end
    SendInventoryMessage(ply, "You deleted your " .. itemData.name .. " from page " .. page .. ".")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " deleted 1 " .. itemData.name .. " from page " .. page)
end)

net.Receive("EquipItem", function(len, ply)
    local uniqueID = net.ReadString()
    local page = net.ReadUInt(8)
    local slot = net.ReadString()
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {} }
    local item, itemData

    for i, it in ipairs(inv.items[page] or {}) do
        if it.id == uniqueID then
            item = it
            itemData = InventoryItems[it.itemID]
            table.remove(inv.items[page], i)
            inv.positions[page][uniqueID] = nil
            break
        end
    end

    if not item or not itemData then 
        DebugPrint("[Inventory Module] Failed to equip item " .. uniqueID .. " for " .. ply:Nick() .. " on page " .. page)
        return 
    end

    local validSlots = {["Armor"] = true, ["Weapon"] = true, ["Sidearm"] = true, ["Boots"] = true, ["Utility"] = true}
    local canEquip = true
    local failMessage = "You cannot equip this item to this slot!"

    if not validSlots[slot] then
        canEquip = false
    elseif (slot == "Weapon" or slot == "Sidearm") and itemData.category != "Weapons" then
        canEquip = false
    elseif slot == "Utility" and itemData.category != "Utility" then
        canEquip = false
    elseif slot == "Weapon" or slot == "Sidearm" then
        local requiredSlotType = (slot == "Weapon") and "Primary" or "Sidearm"
        if item.slotType and item.slotType != requiredSlotType then
            canEquip = false
        end
    end

    if not canEquip then
        SendInventoryMessage(ply, failMessage)
        AddItemToInventory(ply, item.itemID, 1, { id = item.id, damage = item.damage, slots = item.slots, rarity = item.rarity, slotType = item.slotType, crafter = item.crafter }, page, true)
        DebugPrint("[Inventory Module] " .. ply:Nick() .. " cannot equip " .. itemData.name .. " to slot " .. slot)
        return
    end

    local existingItem = inv.loadout[slot]
    if existingItem and InventoryItems[existingItem.itemID] then
        local existingItemData = InventoryItems[existingItem.itemID]
        if existingItemData.category == "Weapons" then
            local weaponClass = existingItemData.entityClass or existingItem.itemID
            ply:StripWeapon(weaponClass)
        end
        AddItemToInventory(ply, existingItem.itemID, 1, { 
            id = existingItem.id, 
            damage = existingItem.damage, 
            slots = existingItem.slots, 
            rarity = existingItem.rarity, 
            slotType = existingItem.slotType, 
            crafter = existingItem.crafter 
        }, 1, true)
        inv.loadout[slot] = nil
        SendInventoryMessage(ply, "You unequipped your " .. existingItemData.name .. " from " .. slot .. " to equip new item.")
        DebugPrint("[Inventory Module] " .. ply:Nick() .. " unequipped " .. existingItemData.name .. " from " .. slot .. " to equip new item")
    end

    inv.loadout[slot] = item
    PlayerInventories[steamID] = inv
    SavePlayerInventory(ply)
    net.Start("SyncLoadout")
    net.WriteTable(inv.loadout)
    net.Send(ply)
    net.Start("SyncInventory")
    net.WriteUInt(page, 8)
    net.WriteTable(inv.items[page])
    net.WriteTable(inv.positions[page])
    net.Send(ply)
    SendInventoryMessage(ply, "You equipped your " .. itemData.name .. " to " .. slot .. " slot.")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " equipped " .. itemData.name .. " to " .. slot)

    if itemData.category == "Weapons" then
        local weaponClass = itemData.entityClass or item.itemID
        ply:Give(weaponClass)
        ply:SelectWeapon(weaponClass)
        local weapon = ply:GetWeapon(weaponClass)
        if IsValid(weapon) then
            weapon:SetNWInt("CustomDamage", item.damage)
            weapon:SetNWString("WeaponType", WeaponTypes[item.itemID] or "unknown")
            weapon:SetNWString("Rarity", item.rarity or "Common")
        end
    end
end)

net.Receive("UnequipItem", function(len, ply)
    local slot = net.ReadString()
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {} }
    local item = inv.loadout[slot]
    if not item or not InventoryItems[item.itemID] then 
        DebugPrint("[Inventory Module] Failed to unequip item from slot " .. slot .. " for " .. ply:Nick())
        return 
    end

    local itemData = InventoryItems[item.itemID]
    inv.loadout[slot] = nil
    -- Add the item back to the inventory while preserving all stats
    AddItemToInventory(ply, item.itemID, 1, { id = item.id, damage = item.damage, slots = item.slots, rarity = item.rarity, slotType = item.slotType, crafter = item.crafter }, 1, true)
    PlayerInventories[steamID] = inv
    SavePlayerInventory(ply)
    net.Start("SyncLoadout")
    net.WriteTable(inv.loadout)
    net.Send(ply)
    SendInventoryMessage(ply, "You unequipped your " .. itemData.name .. " from " .. slot .. " slot.")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " unequipped " .. itemData.name .. " from " .. slot)

    if itemData.category == "Weapons" then
        local weaponClass = itemData.entityClass or item.itemID
        ply:StripWeapon(weaponClass)
    end
end)

hook.Add("PlayerInitialSpawn", "Inventory_InitInventory", function(ply)
    if not IsValid(ply) then return end
    LoadPlayerInventory(ply)
end)

hook.Add("PlayerSetTeam", "Inventory_EquipLoadoutAfterJobSet", function(ply)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID]
    if not inv or not inv.loadout then return end

    DebugPrint("[Inventory Module] Equipping loadout items for " .. ply:Nick() .. " after job set.")

    for slot, item in pairs(inv.loadout) do
        if item and InventoryItems[item.itemID] and InventoryItems[item.itemID].category == "Weapons" then
            local weaponClass = InventoryItems[item.itemID].entityClass or item.itemID
            ply:Give(weaponClass)
            local weapon = ply:GetWeapon(weaponClass)
            if IsValid(weapon) then
                weapon:SetNWInt("CustomDamage", item.damage or 0)
                weapon:SetNWString("WeaponType", WeaponTypes[item.itemID] or "unknown")
                weapon:SetNWString("Rarity", item.rarity or "Common")
                DebugPrint("[Inventory Module] Equipped " .. weaponClass .. " for " .. ply:Nick() .. " with damage: " .. (item.damage or 0))
            end
        end
    end
end)

hook.Add("PlayerSpawn", "Inventory_EquipLoadoutOnSpawn", function(ply)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID]
    if not inv or not inv.loadout then return end

    DebugPrint("[Inventory Module] Equipping loadout items for " .. ply:Nick() .. " on spawn.")

    for slot, item in pairs(inv.loadout) do
        if item and InventoryItems[item.itemID] and InventoryItems[item.itemID].category == "Weapons" then
            local weaponClass = InventoryItems[item.itemID].entityClass or item.itemID
            ply:Give(weaponClass)
            local weapon = ply:GetWeapon(weaponClass)
            if IsValid(weapon) then
                weapon:SetNWInt("CustomDamage", item.damage or 0)
                weapon:SetNWString("WeaponType", WeaponTypes[item.itemID] or "unknown")
                weapon:SetNWString("Rarity", item.rarity or "Common")
                DebugPrint("[Inventory Module] Equipped " .. weaponClass .. " for " .. ply:Nick() .. " with damage: " .. (item.damage or 0))
            end
        end
    end
end)

hook.Add("PlayerDisconnected", "SaveInventoryOnDisconnect", SavePlayerInventory)

hook.Add("PlayerUse", "PickupInventoryItem", function(ply, ent)
    local uniqueID = ent:GetNWString("UniqueID")
    if not uniqueID or uniqueID == "" then return end
    local itemID = ent:GetNWString("ItemID")
    if not InventoryItems[itemID] then return end
    local stats = {
        damage = ent:GetNWInt("Damage", 0),
        slots = ent:GetNWInt("Slots", 0),
        rarity = ent:GetNWString("Rarity", ""),
        slotType = ent:GetNWString("SlotType", ""),
        crafter = ent:GetNWString("Crafter", "Unknown")
    }
    if InventoryItems[itemID].category == "Weapons" or InventoryItems[itemID].category == "Armor" then return end
    AddItemToInventory(ply, itemID, 1, stats, 1)
    ent:Remove()
    SendInventoryMessage(ply, "You picked up 1 " .. InventoryItems[itemID].name .. ".")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " picked up 1 " .. InventoryItems[itemID].name)
    return true
end)

hook.Add("EntityTakeDamage", "ApplyCustomWeaponDamage", function(target, dmginfo)
    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsPlayer() then return end

    local weapon = attacker:GetActiveWeapon()
    if not IsValid(weapon) then return end

    local customDamage = weapon:GetNWInt("CustomDamage", -1)
    if customDamage == -1 then return end

    local weaponType = weapon:GetNWString("WeaponType", "unknown")
    local rarity = weapon:GetNWString("Rarity", "Common")
    local damageToApply = customDamage

    if weaponType == "shotgun" then
        local numPellets = 6
        damageToApply = customDamage * numPellets
        dmginfo:SetDamage(damageToApply / numPellets)
    else
        dmginfo:SetDamage(damageToApply)
    end

    DebugPrint(string.format("[Weapon Damage Test] %s (%s, %s) dealt %d damage to %s with %s (Base Damage: %d)",
        attacker:Nick(), weaponType, rarity, damageToApply, target:GetClass(), weapon:GetClass(), customDamage))
end)

concommand.Add("test_weapon_damage", function(ply)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then
        SendInventoryMessage(ply, "Superadmin only.")
        return
    end

    local npc = ents.Create("npc_zombie")
    if not IsValid(npc) then
        SendInventoryMessage(ply, "Failed to spawn test NPC (npc_zombie).")
        return
    end

    local pos = ply:GetEyeTrace().HitPos + Vector(0, 0, 50)
    npc:SetPos(pos)
    npc:Spawn()
    npc:SetHealth(1000)

    SendInventoryMessage(ply, "Spawned a test NPC (npc_zombie) with 1000 health. Shoot it to test damage.")
    DebugPrint("[Inventory Module] " .. ply:Nick() .. " spawned a test NPC for weapon damage testing")
end)

concommand.Add("additem", function(ply, _, args)
    if not ply:IsSuperAdmin() then 
        SendInventoryMessage(ply, "Superadmin only.")
        return 
    end
    AddItemToInventory(ply, args[1], tonumber(args[2]) or 1, nil, 1)
end)

-- This print will always show to confirm successful load
print("[Inventory Module] Server-side loaded successfully.")