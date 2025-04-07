-- Initial Setup
print("[Inventory Module] sh_inventory.lua loaded successfully")

if SERVER then
    util.AddNetworkString("SyncInventory")
    util.AddNetworkString("DropItem")
    util.AddNetworkString("UseItem")
    util.AddNetworkString("DeleteItem")
    util.AddNetworkString("InventoryMessage")
    util.AddNetworkString("SyncResources")
    util.AddNetworkString("DropResource")
    util.AddNetworkString("UpdateInventoryPositions")
    util.AddNetworkString("SyncLoadout")
    util.AddNetworkString("EquipItem")
    util.AddNetworkString("UnequipItem")
end

-- Resource Definitions
ResourceItems = ResourceItems or {}
local resourceTemplates = {
    minerals = {
        { id = "rock", name = "Rock", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "copper", name = "Copper", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "iron", name = "Iron", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "steel", name = "Steel", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "titanium", name = "Titanium", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" }
    },
    gems = {
        { id = "emerald", name = "Emerald", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "ruby", name = "Ruby", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "sapphire", name = "Sapphire", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "obsidian", name = "Obsidian", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "diamond", name = "Diamond", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" }
    },
    lumber = {
        { id = "ash", name = "Ash", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "birch", name = "Birch", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "oak", name = "Oak", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "mahogany", name = "Mahogany", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "yew", name = "Yew", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" }
    }
}
for _, category in pairs(resourceTemplates) do
    for _, data in ipairs(category) do
        ResourceItems[data.id] = { name = data.name, icon = data.icon, model = data.model }
    end
end

if file.Exists("modules/inventory/sh_items.lua", "LUA") then
    include("modules/inventory/sh_items.lua")
    if SERVER then AddCSLuaFile("modules/inventory/sh_items.lua") end
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

-- Inventory Management
function AddResourceToInventory(ply, resourceID, amount, silent)
    if not IsValid(ply) or not ResourceItems[resourceID] then 
        print("[Debug] AddResourceToInventory failed: Invalid ply or resourceID " .. tostring(resourceID))
        return 
    end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
    inv.resources[resourceID] = (inv.resources[resourceID] or 0) + (amount or 1)
    PlayerInventories[steamID] = inv
    if SERVER then
        net.Start("SyncResources")
        net.WriteTable(inv.resources)
        net.Send(ply)
        SavePlayerInventory(ply)
        if not silent then SendInventoryMessage(ply, "Mined a " .. ResourceItems[resourceID].name) end
    end
end

function AddItemToInventory(ply, itemID, amount, stats, page)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
    page = tonumber(page) or 1
    inv.maxPages = inv.maxPages or 1
    if page < 1 or page > inv.maxPages then 
        print("[Debug] Invalid page " .. page .. " for " .. steamID .. ", maxPages: " .. inv.maxPages)
        return 
    end
    inv.items[page] = inv.items[page] or {}
    inv.positions[page] = inv.positions[page] or {}
    for i = 1, (amount or 1) do
        local uniqueID = stats and stats.id or GenerateUUID()
        local isWeaponOrArmor = InventoryItems[itemID].category == "Weapons" or InventoryItems[itemID].category == "Armor"
        stats = stats or {
            damage = isWeaponOrArmor and math.random(10, 80) or 0,
            slots = 0, -- Will be set based on rarity
            rarity = nil, -- Will be set below
            slotType = nil, -- Will be set for weapons
            crafter = ply:Nick()
        }

        if isWeaponOrArmor then
            -- Determine rarity with weighted probabilities
            local rarityRoll = math.random(1, 500)
            if rarityRoll == 1 then
                stats.rarity = "Legendary" -- 1/500 chance (0.2%)
            elseif rarityRoll <= 3 then
                stats.rarity = "Epic" -- 1/200 chance (0.5%)
            elseif rarityRoll <= 10 then
                stats.rarity = "Rare" -- 1/50 chance (2%)
            elseif rarityRoll <= 50 then
                stats.rarity = "Uncommon" -- 1/10 chance (10%)
            else
                stats.rarity = "Common" -- Default (88.8%)
            end

            -- Set slot count based on rarity
            local slotCaps = {
                Common = 2,
                Uncommon = 3,
                Rare = 4,
                Epic = 5,
                Legendary = 6
            }
            local maxSlots = slotCaps[stats.rarity] or 2
            stats.slots = math.random(0, maxSlots)

            -- For weapons, determine slot type (Primary or Sidearm)
            if InventoryItems[itemID].category == "Weapons" then
                local slotTypeRoll = math.random(1, 100)
                stats.slotType = (slotTypeRoll <= 10) and "Sidearm" or "Primary" -- 10% chance for Sidearm
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
        for row = 1, 6 do
            for col = 1, 10 do
                local slotTaken = false
                for _, pos in pairs(inv.positions[page]) do
                    if pos[1] == row and pos[2] == col then slotTaken = true break end
                end
                if not slotTaken then
                    inv.positions[page][uniqueID] = {row, col}
                    print("[Debug] Assigned " .. uniqueID .. " (" .. itemID .. ") to " .. row .. "," .. col .. " on page " .. page)
                    break
                end
            end
            if inv.positions[page][uniqueID] then break end
        end
    end
    PlayerInventories[steamID] = inv
    if SERVER then
        net.Start("SyncInventory")
        net.WriteUInt(page, 8)
        net.WriteTable(inv.items[page])
        net.WriteTable(inv.positions[page])
        net.Send(ply)
        SavePlayerInventory(ply)
        SendInventoryMessage(ply, "Added " .. (amount or 1) .. " " .. InventoryItems[itemID].name .. "(s) to your inventory on page " .. page .. ".")
    end
end

-- Server-Side Logic
if SERVER then
    local PickupCooldown = {}
    local allowedTools = { "button", "fading_door", "keypad_willox", "camera", "nocollide", "remover", "stacker" }

    -- Initialize or update the database schema
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
            -- Attempt to add the loadout column if it doesn't exist
            MySQLite.query("ALTER TABLE darkrp_custom_inventory ADD COLUMN loadout TEXT NOT NULL DEFAULT '{}'", function()
                print("[Custom Inventory] Added loadout column to darkrp_custom_inventory (or it already exists)")
            end, function(err)
                print("[Custom Inventory] Loadout column already exists or failed to add: " .. err)
            end)
        end, function(err)
            print("[Custom Inventory] Failed to initialize table: " .. err)
        end)
    end)

    function SendInventoryMessage(ply, message)
        if not IsValid(ply) then return end
        net.Start("InventoryMessage")
        net.WriteString(message)
        net.Send(ply)
        print("[Inventory Log] " .. ply:Nick() .. " (" .. ply:SteamID() .. "): " .. message)
    end

    local function LoadPlayerInventory(ply)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        MySQLite.query("SELECT items, resources, positions, maxPages, loadout FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
            local inv = { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
            if data and data[1] then
                inv.items = util.JSONToTable(data[1].items or '{"1":[]}') or { [1] = {} }
                inv.resources = util.JSONToTable(data[1].resources or "{}") or {}
                inv.positions = util.JSONToTable(data[1].positions or '{"1":{}}') or { [1] = {} }
                inv.maxPages = tonumber(data[1].maxPages) or 1
                inv.loadout = util.JSONToTable(data[1].loadout or '{}') or {}
            end
            inv.items[1] = inv.items[1] or {}
            inv.positions[1] = inv.positions[1] or {}
            PlayerInventories[steamID] = inv
            net.Start("SyncInventory")
            net.WriteUInt(1, 8)
            net.WriteTable(inv.items[1])
            net.WriteTable(inv.positions[1])
            net.Send(ply)
            net.Start("SyncResources")
            net.WriteTable(inv.resources)
            net.Send(ply)
            net.Start("SyncLoadout")
            net.WriteTable(inv.loadout)
            net.Send(ply)
        end, function(err)
            print("[Custom Inventory] Error loading inventory for " .. steamID .. ": " .. err)
            local inv = { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
            PlayerInventories[steamID] = inv
            net.Start("SyncInventory")
            net.WriteUInt(1, 8)
            net.WriteTable(inv.items[1])
            net.WriteTable(inv.positions[1])
            net.Send(ply)
            net.Start("SyncResources")
            net.WriteTable(inv.resources)
            net.Send(ply)
            net.Start("SyncLoadout")
            net.WriteTable(inv.loadout)
            net.Send(ply)
        end)
    end

    function SavePlayerInventory(ply)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
        MySQLite.query("REPLACE INTO darkrp_custom_inventory (steamid, items, resources, positions, maxPages, loadout) VALUES (" .. 
            MySQLite.SQLStr(steamID) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.items)) .. ", " .. 
            MySQLite.SQLStr(util.TableToJSON(inv.resources)) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.positions)) .. ", " .. 
            inv.maxPages .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.loadout)) .. ")", nil, function(err)
            if err then print("[Custom Inventory] Error saving inventory for " .. steamID .. ": " .. err) end
        end)
    end

    local function SyncInventoryFromSQL(ply, page)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        MySQLite.query("SELECT items, positions FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
            if data and data[1] then
                local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
                local items = util.JSONToTable(data[1].items or '{"1":[]}') or { [1] = {} }
                local positions = util.JSONToTable(data[1].positions or '{"1":{}}') or { [1] = {} }
                inv.items = items
                inv.positions = positions
                PlayerInventories[steamID] = inv
                net.Start("SyncInventory")
                net.WriteUInt(page, 8)
                net.WriteTable(items[page] or {})
                net.WriteTable(positions[page] or {})
                net.Send(ply)
            end
        end, function(err)
            print("[Custom Inventory] Error syncing inventory for " .. steamID .. ": " .. err)
        end)
    end

    local function RemoveItemFromInventory(ply, uniqueID, page)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
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
                return item, itemData
            end
        end
    end

    net.Receive("UpdateInventoryPositions", function(len, ply)
        local page = net.ReadUInt(8)
        local steamID = ply:SteamID()
        local newPositions = net.ReadTable()
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
        inv.positions[page] = newPositions
        PlayerInventories[steamID] = inv
        SavePlayerInventory(ply)
        SyncInventoryFromSQL(ply, page)
        print("[Debug] Updated positions for " .. steamID .. " on page " .. page .. ": " .. table.ToString(newPositions))
    end)

    net.Receive("DropItem", function(len, ply)
        local uniqueID = net.ReadString()
        local page = net.ReadUInt(8)
        local item, itemData = RemoveItemFromInventory(ply, uniqueID, page)
        if not item or not itemData then return end
        if itemData.category == "Weapons" or itemData.category == "Armor" then
            SendInventoryMessage(ply, "Cannot drop weapons or armor!")
            AddItemToInventory(ply, item.itemID, 1, { id = item.id, damage = item.damage, slots = item.slots, rarity = item.rarity, slotType = item.slotType, crafter = item.crafter }, page)
            return
        end
        SendInventoryMessage(ply, "Dropped 1 " .. itemData.name .. " from page " .. page .. ".")
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
            if IsValid(phys) then phys:Wake() phys:SetVelocity(Vector(0, 0, -100)) end
            ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        end
    end)

    net.Receive("UseItem", function(len, ply)
        local uniqueID = net.ReadString()
        local page = net.ReadUInt(8)
        local item, itemData = RemoveItemFromInventory(ply, uniqueID, page)
        if not item or not itemData or not itemData.useFunction then return end
        itemData.useFunction(ply)
        SendInventoryMessage(ply, "Used 1 " .. itemData.name .. " from page " .. page .. ".")
    end)

    net.Receive("DeleteItem", function(len, ply)
        local uniqueID = net.ReadString()
        local page = net.ReadUInt(8)
        local item, itemData = RemoveItemFromInventory(ply, uniqueID, page)
        if not item or not itemData then return end
        SendInventoryMessage(ply, "Deleted 1 " .. itemData.name .. " from page " .. page .. ".")
    end)

    net.Receive("DropResource", function(len, ply)
        local resourceID = net.ReadString()
        local amount = net.ReadUInt(16)
        if not ResourceItems[resourceID] or amount < 1 then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
        if not inv.resources[resourceID] or inv.resources[resourceID] < amount then return end
        inv.resources[resourceID] = inv.resources[resourceID] - amount
        if inv.resources[resourceID] <= 0 then inv.resources[resourceID] = nil end
        PlayerInventories[steamID] = inv
        net.Start("SyncResources")
        net.WriteTable(inv.resources)
        net.Send(ply)
        SavePlayerInventory(ply)
        SendInventoryMessage(ply, "Dropped " .. amount .. " " .. ResourceItems[resourceID].name .. ".")
        local ent = ents.Create("prop_physics")
        if IsValid(ent) then
            ent:SetModel(ResourceItems[resourceID].model or "models/props_junk/rock001a.mdl")
            ent:SetPos(ply:GetEyeTrace().HitPos + Vector(0, 0, 10))
            ent:Spawn()
            ent:GetPhysicsObject():SetVelocity(ply:GetAimVector() * 100)
        end
    end)

    net.Receive("EquipItem", function(len, ply)
        local uniqueID = net.ReadString()
        local page = net.ReadUInt(8)
        local slot = net.ReadString()
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
        local item, itemData

        -- Find and remove the item from inventory
        for i, it in ipairs(inv.items[page] or {}) do
            if it.id == uniqueID then
                item = it
                itemData = InventoryItems[it.itemID]
                table.remove(inv.items[page], i)
                inv.positions[page][uniqueID] = nil
                break
            end
        end
        if not item or not itemData then return end

        -- Validate the slot
        local validSlots = {["Armor"] = true, ["Weapon"] = true, ["Sidearm"] = true, ["Boots"] = true, ["Utility"] = true}
        if not validSlots[slot] then return end

        -- Check category compatibility
        if (slot == "Weapon" or slot == "Sidearm") and itemData.category ~= "Weapons" then
            SendInventoryMessage(ply, "Only weapons can be equipped to " .. slot .. "!")
            AddItemToInventory(ply, item.itemID, 1, { id = item.id, damage = item.damage, slots = item.slots, rarity = item.rarity, slotType = item.slotType, crafter = item.crafter }, page)
            return
        end
        if slot == "Utility" and itemData.category ~= "Utility" then
            SendInventoryMessage(ply, "Only utility items can be equipped to Utility!")
            AddItemToInventory(ply, item.itemID, 1, { id = item.id, damage = item.damage, slots = item.slots, rarity = item.rarity, slotType = item.slotType, crafter = item.crafter }, page)
            return
        end

        -- Check slot type compatibility for weapons
        if slot == "Weapon" or slot == "Sidearm" then
            local requiredSlotType = (slot == "Weapon") and "Primary" or "Sidearm"
            if item.slotType and item.slotType ~= requiredSlotType then
                SendInventoryMessage(ply, "This weapon is a " .. item.slotType .. " and cannot be equipped to " .. slot .. "!")
                AddItemToInventory(ply, item.itemID, 1, { id = item.id, damage = item.damage, slots = item.slots, rarity = item.rarity, slotType = item.slotType, crafter = item.crafter }, page)
                return
            end
        end

        -- Check if the target slot is already occupied
        local existingItem = inv.loadout[slot]
        if existingItem and InventoryItems[existingItem.itemID] then
            -- Unequip the existing item in the slot
            local existingItemData = InventoryItems[existingItem.itemID]
            if existingItemData.category == "Weapons" then
                local weaponClass = existingItemData.entityClass or existingItem.itemID
                ply:StripWeapon(weaponClass)
                print("[Debug] Stripped " .. ply:Nick() .. " of weapon " .. weaponClass .. " from " .. slot)
            end
            AddItemToInventory(ply, existingItem.itemID, 1, { 
                id = existingItem.id, 
                damage = existingItem.damage, 
                slots = existingItem.slots, 
                rarity = existingItem.rarity, 
                slotType = existingItem.slotType, 
                crafter = existingItem.crafter 
            }, 1)
            inv.loadout[slot] = nil
            SendInventoryMessage(ply, "Unequipped " .. existingItemData.name .. " from " .. slot .. " to equip new item.")
        end

        -- Equip the new item
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
        SendInventoryMessage(ply, "Equipped " .. itemData.name .. " to " .. slot .. ".")
        if itemData.category == "Weapons" then
            local weaponClass = itemData.entityClass or item.itemID -- Fallback to itemID if entityClass not defined
            local slotNum = (slot == "Weapon") and 1 or (slot == "Sidearm") and 2 or 1
            ply:Give(weaponClass)
            ply:SelectWeapon(weaponClass)
            print("[Debug] Gave " .. ply:Nick() .. " weapon " .. weaponClass .. " in slot " .. slotNum)
        end
    end)

    net.Receive("UnequipItem", function(len, ply)
        local slot = net.ReadString()
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
        local item = inv.loadout[slot]
        if not item or not InventoryItems[item.itemID] then return end
        local itemData = InventoryItems[item.itemID]
        inv.loadout[slot] = nil
        AddItemToInventory(ply, item.itemID, 1, { id = item.id, damage = item.damage, slots = item.slots, rarity = item.rarity, slotType = item.slotType, crafter = item.crafter }, 1)
        PlayerInventories[steamID] = inv
        SavePlayerInventory(ply)
        net.Start("SyncLoadout")
        net.WriteTable(inv.loadout)
        net.Send(ply)
        SendInventoryMessage(ply, "Unequipped " .. itemData.name .. " from " .. slot .. ".")
        if itemData.category == "Weapons" then
            local weaponClass = itemData.entityClass or item.itemID
            ply:StripWeapon(weaponClass)
            print("[Debug] Stripped " .. ply:Nick() .. " of weapon " .. weaponClass)
        end
    end)

    hook.Add("PlayerInitialSpawn", "Inventory_InitInventory", LoadPlayerInventory)
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
        if InventoryThrows[itemID].category == "Weapons" or InventoryItems[itemID].category == "Armor" then return end
        AddItemToInventory(ply, itemID, 1, stats, 1)
        ent:Remove()
        SendInventoryMessage(ply, "Picked up 1 " .. InventoryItems[itemID].name .. ".")
        return true
    end)

    concommand.Add("addresource", function(ply, _, args)
        if not ply:IsSuperAdmin() then return SendInventoryMessage(ply, "Superadmin only.") end
        AddResourceToInventory(ply, args[1], tonumber(args[2]) or 1)
    end)

    concommand.Add("additem", function(ply, _, args)
        if not ply:IsSuperAdmin() then return SendInventoryMessage(ply, "Superadmin only.") end
        AddItemToInventory(ply, args[1], tonumber(args[2]) or 1, nil, 1)
    end)

    concommand.Add("open_resources", function(ply)
        if not IsValid(ply) then return end
        net.Start("SyncResources")
        net.WriteTable(PlayerInventories[ply:SteamID()] and PlayerInventories[ply:SteamID()].resources or {})
        net.Send(ply)
    end)
end

-- Client-Side Logic
if CLIENT then
    local Resources, Inventory, InventoryPositions, Loadout = {}, {}, {}, {}
    local InventoryFrame, ToolSelectorFrame, inventoryTab, resourcesTab
    local isInventoryOpen, isToolSelectorOpen, isQKeyHeld = false, false, false
    local currentTooltip, currentInfoBox
    local activeMenus = {}
    local allowedTools = { "button", "fading_door", "keypad_willox", "camera", "nocollide", "remover", "stacker" }
    local currentPage = 1

    local resourceAppearances = {
        rock = { material = "", color = nil },
        copper = { material = "models/shiny", color = Color(184, 115, 51, 100) },
        iron = { material = "models/shiny", color = Color(169, 169, 169, 255) },
        steel = { material = "models/shiny", color = Color(192, 192, 192, 255) },
        titanium = { material = "models/shiny", color = Color(46, 139, 87, 255) },
        emerald = { material = "models/shiny", color = Color(0, 255, 127, 200) },
        ruby = { material = "models/shiny", color = Color(255, 36, 0, 200) },
        sapphire = { material = "models/shiny", color = Color(0, 191, 255, 200) },
        obsidian = { material = "models/shiny", color = Color(47, 79, 79, 200) },
        diamond = { material = "models/shiny", color = Color(240, 248, 255, 200) }
    }

    -- Define a custom font for tooltips
    surface.CreateFont("TooltipFont", {
        font = "DermaDefault",
        size = 14,
        weight = 500
    })

    -- Shared tooltip constants
    local TOOLTIP_LINE_HEIGHT = 18
    local TOOLTIP_PADDING_X = 10
    local TOOLTIP_PADDING_Y = 10
    local TOOLTIP_ZPOS = 32767 -- Maximum ZPos to ensure tooltip renders on top
    local TOOLTIP_SPACING = 2 -- Spacing between icon and tooltip
    local TOOLTIP_FADEOUT_DELAY = 0.2 -- Delay before removing tooltip after cursor exits
    local RARITY_COLORS = {
        common = Color(200, 200, 200),    -- Light gray for Common
        uncommon = Color(0, 255, 0),      -- Green for Uncommon
        rare = Color(0, 0, 139),          -- Dark blue for Rare
        epic = Color(255, 245, 200),      -- Yellowish white for Epic
        legendary = Color(139, 0, 0)      -- Dark red for Legendary
    }

    -- Shared function to calculate slot counts for an item
    local function CalculateSlotCounts(item, itemData)
        local isWeaponOrArmor = itemData.category == "Weapons" or itemData.category == "Armor"
        local slotCount = item.slots or 0

        -- Determine base slot count for weapons
        local baseSlotCount = 0
        if isWeaponOrArmor then
            if itemData.category == "Weapons" then
                local weaponSlots = {
                    ak47 = 2,
                    m4a1 = 2,
                    sg552 = 2,
                    aug = 2,
                    m249 = 2
                }
                baseSlotCount = weaponSlots[item.itemID] or 1
            else
                baseSlotCount = 1
            end
        end

        local displaySlotCount = isWeaponOrArmor and math.max(slotCount, baseSlotCount) or slotCount
        return slotCount, baseSlotCount, displaySlotCount
    end

    -- Shared function to create tooltip content
    local function CreateTooltipContent(item, itemData)
        local isWeaponOrArmor = itemData.category == "Weapons" or itemData.category == "Armor"
        local isUtility = itemData.category == "Utility"
        local rarity = isWeaponOrArmor and (item.rarity or itemData.baseRarity or "Common") or nil
        local rarityColor = rarity and RARITY_COLORS[rarity:lower()] or Color(255, 255, 255)
        local damage = item.damage or "N/A"
        local slotCount, baseSlotCount, displaySlotCount = CalculateSlotCounts(item, itemData)
        local slotType = item.slotType or "N/A"
        local crafter = item.crafter or "Unknown"

        -- Debug slot counts
        print("[Debug] Item " .. item.itemID .. " (uniqueID: " .. (item.id or "loadout") .. ") - slotCount: " .. slotCount .. ", baseSlotCount: " .. baseSlotCount .. ", displaySlotCount: " .. displaySlotCount)

        -- Prepare tooltip lines
        local lines = {}
        if isWeaponOrArmor then
            table.insert(lines, { text = rarity, color = rarityColor })
            table.insert(lines, { text = "Item: " .. itemData.name, color = Color(255, 255, 255) })
            if itemData.category == "Weapons" then
                table.insert(lines, { text = "Slot Type: " .. slotType, color = Color(255, 255, 255) })
            end
            table.insert(lines, { text = "Damage: " .. damage, color = Color(255, 255, 255) })
            if displaySlotCount > 0 then
                table.insert(lines, { text = "Slots:", color = Color(255, 255, 255) })
                for i = 1, displaySlotCount do
                    local slotText = (slotCount > 0) and "Empty Slot" or "No Slots"
                    table.insert(lines, { text = "  " .. slotText, color = Color(255, 255, 255) })
                end
            end
            table.insert(lines, { text = "Crafter: " .. crafter, color = Color(255, 255, 255) })
        elseif isUtility then
            table.insert(lines, { text = itemData.name, color = Color(255, 255, 255) })
            table.insert(lines, { text = "Crafter: " .. crafter, color = Color(255, 255, 255) })
        else
            table.insert(lines, { text = itemData.name, color = Color(255, 255, 255) })
            table.insert(lines, { text = "Damage: " .. damage, color = Color(255, 255, 255) })
            table.insert(lines, { text = "Crafter: " .. crafter, color = Color(255, 255, 255) })
        end
        return lines
    end

    -- Shared function to create and position a tooltip
    local function CreateTooltip(parent, tooltipParent, lines, posX, posY, adjustX, adjustY)
        -- Calculate tooltip size
        local maxWidth = 0
        for _, line in ipairs(lines) do
            surface.SetFont("TooltipFont")
            local textWidth, _ = surface.GetTextSize(line.text)
            maxWidth = math.max(maxWidth, textWidth)
        end
        local tooltipWidth = maxWidth + TOOLTIP_PADDING_X * 2
        local tooltipHeight = (#lines * TOOLTIP_LINE_HEIGHT) + (TOOLTIP_PADDING_Y * 2)

        -- Create tooltip with the specified parent
        currentTooltip = vgui.Create("DPanel", tooltipParent or parent)
        currentTooltip:SetSize(tooltipWidth, tooltipHeight)

        -- Convert position if tooltipParent is different from parent
        local finalPosX, finalPosY = posX, posY
        if tooltipParent and tooltipParent ~= parent then
            local screenX, screenY = parent:LocalToScreen(posX, posY)
            finalPosX, finalPosY = tooltipParent:ScreenToLocal(screenX, screenY)
        end

        -- Prefer right side, check screen bounds instead of parent bounds
        local preferredX = finalPosX + adjustX -- Right side
        local screenX, screenY = (tooltipParent or parent):LocalToScreen(preferredX, finalPosY)
        local screenW, screenH = ScrW(), ScrH()
        if screenX + tooltipWidth > screenW then
            preferredX = finalPosX - tooltipWidth - TOOLTIP_SPACING -- Fall back to left side
        end

        -- Ensure the tooltip doesn't go off the left edge of the screen
        screenX, screenY = (tooltipParent or parent):LocalToScreen(preferredX, finalPosY)
        if screenX < 0 then
            preferredX = preferredX - screenX -- Adjust to keep tooltip on screen
        end

        -- Adjust Y position to prevent going off the bottom of the parent
        local parentHeight = (tooltipParent or parent):GetTall()
        local adjustedY = finalPosY
        if finalPosY + tooltipHeight > parentHeight then
            adjustedY = finalPosY - tooltipHeight + adjustY
        end

        currentTooltip:SetPos(preferredX, adjustedY)
        currentTooltip:SetZPos(TOOLTIP_ZPOS)
        currentTooltip:SetVisible(true)
        currentTooltip.Lines = lines

        -- Paint the tooltip
        currentTooltip.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
            for i, line in ipairs(self.Lines) do
                draw.SimpleText(line.text, "TooltipFont", TOOLTIP_PADDING_X, TOOLTIP_PADDING_Y + (i - 1) * TOOLTIP_LINE_HEIGHT, line.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end

        -- Debug tooltip visibility with throttling
        currentTooltip.LastDebugTime = 0
        currentTooltip.Think = function(self)
            if not IsValid(self) then return end
            local currentTime = CurTime()
            if currentTime - self.LastDebugTime >= 1 then -- Print every 1 second
                local screenX, screenY = self:LocalToScreen(0, 0)
                print("[Debug] Tooltip visibility check for " .. lines[1].text .. " at " .. preferredX .. "," .. adjustedY .. " (screen: " .. screenX .. "," .. screenY .. "), visible: " .. tostring(self:IsVisible()))
                self.LastDebugTime = currentTime
            end
        end

        -- Debug tooltip creation
        local parentName = (tooltipParent or parent):GetName() or "unnamed"
        screenX, screenY = (tooltipParent or parent):LocalToScreen(preferredX, adjustedY)
        print("[Debug] Tooltip created for " .. lines[1].text .. " at " .. preferredX .. "," .. adjustedY .. " (screen: " .. (screenX or 0) .. "," .. (screenY or 0) .. "), size: " .. tooltipWidth .. "x" .. tooltipHeight .. ", adjustX: " .. adjustX .. ", parent: " .. parentName .. ", visible: " .. tostring(currentTooltip:IsVisible()))

        return currentTooltip, preferredX, adjustedY, tooltipWidth, tooltipHeight
    end

    local function OpenToolSelector()
        if isToolSelectorOpen and IsValid(ToolSelectorFrame) then return end
        gui.EnableScreenClicker(true)
        ToolSelectorFrame = vgui.Create("DFrame")
        ToolSelectorFrame:SetSize(300, 700)
        ToolSelectorFrame:SetPos(ScrW()/2 + 510, ScrH()/2 - 350)
        ToolSelectorFrame:SetTitle("Tool Selector")
        ToolSelectorFrame:SetDraggable(false)
        ToolSelectorFrame:ShowCloseButton(false)
        ToolSelectorFrame:MakePopup()
        ToolSelectorFrame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225)) end
        ToolSelectorFrame.OnClose = function() gui.EnableScreenClicker(false) isToolSelectorOpen = false ToolSelectorFrame = nil end

        local scroll = vgui.Create("DScrollPanel", ToolSelectorFrame)
        scroll:Dock(FILL)
        local cat = vgui.Create("DCollapsibleCategory", scroll)
        cat:Dock(TOP)
        cat:SetLabel("Tools")
        cat:SetExpanded(true)
        local toolList = vgui.Create("DPanelList", cat)
        toolList:EnableVerticalScrollbar(true)
        toolList:SetTall(650)
        toolList:Dock(FILL)
        cat:SetContents(toolList)

        local toolNames = { 
            button = "Button", 
            fading_door = "Fading Door", 
            keypad_willox = "Keypad", 
            camera = "Camera", 
            nocollide = "No-Collide", 
            remover = "Remover", 
            stacker = "Stacker" 
        }
        for _, toolClass in ipairs(allowedTools) do
            local toolData = list.Get("Tool")[toolClass]
            local btn = vgui.Create("DButton")
            btn:SetText(toolData and toolData.Name or toolNames[toolClass] or toolClass)
            btn:Dock(TOP)
            btn:SetHeight(25)
            btn.DoClick = function()
                RunConsoleCommand("use", "gmod_tool")
                RunConsoleCommand("gmod_toolmode", toolClass)
                RunConsoleCommand("gmod_tool", toolClass)
                surface.PlaySound("buttons/button14.wav")
            end
            btn.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(70, 70, 70, 240) or Color(50, 50, 50, 240))
            end
            toolList:AddItem(btn)
        end
        isToolSelectorOpen = true
    end

    local function BuildInventoryUI(parent, page)
        if not IsValid(parent) then return end
        for _, child in pairs(parent:GetChildren()) do child:Remove() end
        
        local tabPanel = vgui.Create("DPanel", parent)
        tabPanel:SetSize(980, 50)
        tabPanel:SetPos(5, 5)
        tabPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end
        
        local pageTab = vgui.Create("DButton", tabPanel)
        pageTab:SetSize(100, 40)
        pageTab:SetPos(10, 5)
        pageTab:SetText("Page 1")
        pageTab.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, currentPage == 1 and Color(70, 70, 70, 240) or Color(50, 50, 50, 240))
        end
        pageTab.DoClick = function() currentPage = 1 BuildInventoryUI(parent, currentPage) end
        
        local gridPanel = vgui.Create("DPanel", parent)
        gridPanel:SetSize(980, 640)
        gridPanel:SetPos(5, 55)
        gridPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end
        
        local slotWidth, slotHeight = 97, 97
        local slots = {}
        for row = 1, 6 do
            slots[row] = {}
            for col = 1, 10 do
                local slot = vgui.Create("DPanel", gridPanel)
                slot:SetSize(slotWidth, slotHeight)
                slot:SetPos((col - 1) * (slotWidth + 1), (row - 1) * (slotHeight + 1))
                slot.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150)) end
                slot:Receiver("inventory_item", function(self, panels, dropped)
                    if not dropped or not panels[1] then return end
                    local draggedUniqueID = panels[1].UniqueID
                    local newPos = {row, col}
                    local occupiedItem
                    for uniqueID, pos in pairs(InventoryPositions) do
                        if pos[1] == row and pos[2] == col and uniqueID ~= draggedUniqueID then
                            occupiedItem = uniqueID
                            break
                        end
                    end
                    if occupiedItem then
                        local oldPos = InventoryPositions[draggedUniqueID]
                        InventoryPositions[draggedUniqueID] = newPos
                        InventoryPositions[occupiedItem] = oldPos
                    else
                        InventoryPositions[draggedUniqueID] = newPos
                    end
                    net.Start("UpdateInventoryPositions")
                    net.WriteUInt(currentPage, 8)
                    net.WriteTable(InventoryPositions)
                    net.SendToServer()
                end)
                slots[row][col] = slot
            end
        end
        
        for _, item in ipairs(Inventory) do
            local itemID = item.itemID
            local uniqueID = item.id
            if not InventoryItems[itemID] or not InventoryPositions[uniqueID] then continue end
            local pos = InventoryPositions[uniqueID]
            local row, col = pos[1], pos[2]
            if not slots[row] or not slots[row][col] then continue end
        
            local panel = vgui.Create("DPanel", slots[row][col])
            panel:SetSize(slotWidth, slotHeight)
            panel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200)) end
        
            local model = vgui.Create("DModelPanel", panel)
            model:SetSize(75, 75)
            model:SetPos((slotWidth - 75) / 2, (slotHeight - 75) / 2)
            model:SetModel(InventoryItems[itemID].model or "models/error.mdl")
            model:SetFOV(30)
            model:SetCamPos(Vector(30, 30, 30))
            model:SetLookAt(Vector(0, 0, 0))
            model:SetMouseInputEnabled(true)
            model:Droppable("inventory_item")
            model.UniqueID = uniqueID
        
            model.OnCursorEntered = function(self)
                if IsValid(currentTooltip) then currentTooltip:Remove() end
                print("[Debug] OnCursorEntered triggered for " .. itemID .. " (uniqueID: " .. uniqueID .. ")")
                local itemData = InventoryItems[itemID]
                local lines = CreateTooltipContent(item, itemData)
                local slotPanel = slots[row][col]
                local slotX, slotY = IsValid(slotPanel) and slotPanel:GetPos() or 0, 0
                -- Icon is 75x75, centered in 97x97 slot. Right edge of icon: (97-75)/2 + 75 = 86. Add spacing.
                local adjustX = 86 + TOOLTIP_SPACING
                CreateTooltip(gridPanel, nil, lines, slotX, slotY, adjustX, slotHeight)
            end

            model.OnCursorExited = function(self)
                print("[Debug] OnCursorExited triggered for " .. itemID .. " (uniqueID: " .. uniqueID .. ")")
                if IsValid(currentTooltip) then
                    timer.Simple(TOOLTIP_FADEOUT_DELAY, function()
                        if IsValid(currentTooltip) and not self:IsHovered() then
                            currentTooltip:Remove()
                            print("[Debug] Tooltip removed after delay")
                        end
                    end)
                end
            end
        
            model.DoClick = function(self)
                if not isInventoryOpen then return end
                local menu = DermaMenu()
                table.insert(activeMenus, menu)
                if InventoryItems[itemID].category == "Utility" then
                    if InventoryItems[itemID].useFunction then
                        menu:AddOption("Use", function()
                            net.Start("UseItem")
                            net.WriteString(uniqueID)
                            net.WriteUInt(currentPage, 8)
                            net.SendToServer()
                        end)
                    end
                    menu:AddOption("Drop", function()
                        net.Start("DropItem")
                        net.WriteString(uniqueID)
                        net.WriteUInt(currentPage, 8)
                        net.SendToServer()
                    end)
                    menu:AddOption("Equip to Utility", function()
                        net.Start("EquipItem")
                        net.WriteString(uniqueID)
                        net.WriteUInt(currentPage, 8)
                        net.WriteString("Utility")
                        net.SendToServer()
                    end)
                elseif InventoryItems[itemID].category == "Weapons" then
                    menu:AddOption("Equip to Weapon", function()
                        net.Start("EquipItem")
                        net.WriteString(uniqueID)
                        net.WriteUInt(currentPage, 8)
                        net.WriteString("Weapon")
                        net.SendToServer()
                    end)
                    menu:AddOption("Equip to Sidearm", function()
                        net.Start("EquipItem")
                        net.WriteString(uniqueID)
                        net.WriteUInt(currentPage, 8)
                        net.WriteString("Sidearm")
                        net.SendToServer()
                    end)
                end
                menu:AddOption("Delete", function()
                    net.Start("DeleteItem")
                    net.WriteString(uniqueID)
                    net.WriteUInt(currentPage, 8)
                    net.SendToServer()
                end)
                menu:Open(self:LocalToScreen(10, 75))
                menu.OnRemove = function()
                    for i, m in ipairs(activeMenus) do
                        if m == menu then table.remove(activeMenus, i) break end
                    end
                end
            end
        end
    end

    local function BuildResourcesMenu(parent)
        if not IsValid(parent) then return end
        for _, child in pairs(parent:GetChildren()) do child:Remove() end
        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)
        local layout = vgui.Create("DIconLayout", scroll)
        layout:Dock(FILL)
        layout:SetSpaceX(10)
        layout:SetSpaceY(10)

        local categories = {
            { name = "Minerals", items = resourceTemplates.minerals },
            { name = "Gems", items = resourceTemplates.gems },
            { name = "Lumber", items = resourceTemplates.lumber }
        }
        for _, cat in ipairs(categories) do
            local catPanel = layout:Add("DPanel")
            catPanel:SetSize(300, 60 + table.Count(cat.items) * 50)
            catPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

            local catLabel = vgui.Create("DLabel", catPanel)
            catLabel:SetPos(10, 10)
            catLabel:SetText(cat.name)
            catLabel:SetSize(280, 20)
            catLabel:SetColor(Color(255, 215, 0))

            local i = 1
            for _, data in ipairs(cat.items) do
                local resourceID = data.id
                local resPanel = vgui.Create("DPanel", catPanel)
                resPanel:SetPos(10, 40 + (i - 1) * 50)
                resPanel:SetSize(280, 40)
                resPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200)) end

                local resIcon = vgui.Create("DModelPanel", resPanel)
                resIcon:SetPos(5, 0)
                resIcon:SetSize(40, 40)
                resIcon:SetModel(data.icon)
                resIcon:SetFOV(30)
                resIcon:SetCamPos(Vector(30, 30, 30))
                resIcon:SetLookAt(Vector(0, 0, 0))
                local appearance = resourceAppearances[resourceID] or { material = "models/shiny", color = Color(255, 255, 255) }
                if appearance.material != "" then resIcon.Entity:SetMaterial(appearance.material) end
                if appearance.color then resIcon:SetColor(appearance.color) end
                resIcon.OnCursorEntered = function(self)
                    if IsValid(currentTooltip) then currentTooltip:Remove() end
                    currentTooltip = vgui.Create("DLabel", resPanel)
                    currentTooltip:SetText(data.name)
                    currentTooltip:SetPos(50, 10)
                    currentTooltip:SetSize(100, 20)
                    currentTooltip:SetZPos(10000)
                    currentTooltip.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
                end
                resIcon.OnCursorExited = function(self) 
                    if IsValid(currentTooltip) then currentTooltip:Remove() currentTooltip = nil end 
                end
                resIcon.OnMousePressed = function(self, code)
                    if (Resources[resourceID] or 0) <= 0 then return end
                    if code == MOUSE_LEFT then
                        net.Start("DropResource")
                        net.WriteString(resourceID)
                        net.WriteUInt(1, 16)
                        net.SendToServer()
                    elseif code == MOUSE_RIGHT then
                        Derma_StringRequest("Drop " .. data.name, "How many to drop? (Max: " .. (Resources[resourceID] or 0) .. ")", "1",
                            function(text)
                                local amount = math.min(math.floor(tonumber(text) or 0), Resources[resourceID] or 0)
                                if amount > 0 then
                                    net.Start("DropResource")
                                    net.WriteString(resourceID)
                                    net.WriteUInt(amount, 16)
                                    net.SendToServer()
                                end
                            end, nil, "Drop", "Cancel")
                    end
                end

                local resAmount = vgui.Create("DLabel", resPanel)
                resAmount:SetPos(50, 10)
                resAmount:SetText(": " .. (Resources[resourceID] or 0))
                resAmount:SetSize(220, 20)
                resAmount.Think = function(self) self:SetText(": " .. (Resources[resourceID] or 0)) end
                i = i + 1
            end
        end
    end

    local function OpenCustomQMenu()
        if isInventoryOpen and IsValid(InventoryFrame) then return end
        gui.EnableScreenClicker(true)
        InventoryFrame = vgui.Create("DFrame")
        InventoryFrame:SetSize(1000, 700)
        InventoryFrame:SetPos(ScrW()/2 - 500, ScrH()/2 - 350)
        InventoryFrame:SetTitle("Inventory & Resources")
        InventoryFrame:SetDraggable(false)
        InventoryFrame:ShowCloseButton(false)
        InventoryFrame:MakePopup()
        InventoryFrame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225)) end
        InventoryFrame.OnClose = function()
            gui.EnableScreenClicker(false)
            isInventoryOpen = false
            if IsValid(currentTooltip) then currentTooltip:Remove() end
            for _, menu in ipairs(activeMenus) do if IsValid(menu) then menu:Remove() end end
            activeMenus = {}
            InventoryFrame = nil
            inventoryTab = nil
            resourcesTab = nil
            if isToolSelectorOpen and IsValid(ToolSelectorFrame) then ToolSelectorFrame:Close() end
        end

        local tabPanel = vgui.Create("DPropertySheet", InventoryFrame)
        tabPanel:Dock(FILL)
        inventoryTab = vgui.Create("DPanel", tabPanel)
        inventoryTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
        BuildInventoryUI(inventoryTab, currentPage)
        tabPanel:AddSheet("Inventory", inventoryTab, "icon16/briefcase.png")
        resourcesTab = vgui.Create("DPanel", tabPanel)
        resourcesTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
        BuildResourcesMenu(resourcesTab)
        tabPanel:AddSheet("Resources", resourcesTab, "icon16/box.png")
        isInventoryOpen = true
        OpenToolSelector()
    end

    local function RefreshEquipmentSlots(frame, slotsPanel)
        if not IsValid(slotsPanel) or not IsValid(frame) then return end
        for _, child in pairs(slotsPanel:GetChildren()) do child:Remove() end

        -- Get frame dimensions
        local frameW, frameH = frame:GetSize()
        local slotOrder = {"Armor", "Weapon", "Sidearm", "Boots", "Utility"}
        local slotLabels = {Armor = "Armor", Weapon = "Primary Weapon", Sidearm = "Sidearm", Boots = "Boots", Utility = "Utility"}

        -- Calculate slot dimensions based on slotsPanel size
        local slotsPanelW, slotsPanelH = slotsPanel:GetSize()
        local slotHeight = math.floor((slotsPanelH - 10 * (#slotOrder + 1)) / #slotOrder) -- 10px padding between slots
        local slotWidth = slotsPanelW - 20 -- 10px padding on each side
        local iconSize = math.min(slotWidth - 20, slotHeight - 20) -- Ensure icon fits within slot

        for i, slot in ipairs(slotOrder) do
            local slotPanel = vgui.Create("DPanel", slotsPanel)
            slotPanel:SetSize(slotWidth, slotHeight)
            slotPanel:SetPos(10, (i-1) * (slotHeight + 10) + 10)
            slotPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end

            local label = vgui.Create("DLabel", slotPanel)
            label:SetPos(5, 5)
            label:SetSize(slotWidth - 10, 20)
            label:SetText(slotLabels[slot])

            local item = Loadout[slot]
            if item and InventoryItems[item.itemID] then
                local model = vgui.Create("DModelPanel", slotPanel)
                model:SetSize(iconSize, iconSize)
                model:SetPos((slotWidth - iconSize) / 2, (slotHeight - iconSize) / 2)
                model:SetModel(InventoryItems[item.itemID].model or "models/error.mdl")
                model:SetFOV(30)
                model:SetCamPos(Vector(30, 30, 30))
                model:SetLookAt(Vector(0, 0, 0))
                model:SetMouseInputEnabled(true)
                model.Slot = slot
                model.Item = item

                model.OnCursorEntered = function(self)
                    if IsValid(currentInfoBox) then currentInfoBox:Remove() end
                    print("[Debug] OnCursorEntered triggered for " .. item.itemID .. " in loadout slot " .. slot)
                    local itemData = InventoryItems[item.itemID]
                    local lines = CreateTooltipContent(item, itemData)
                    local infoBoxHeight = (#lines * TOOLTIP_LINE_HEIGHT) + (TOOLTIP_PADDING_Y * 2)
                    currentInfoBox = vgui.Create("DPanel", frame)
                    currentInfoBox:SetSize(frame.InfoBoxWidth, infoBoxHeight)
                    currentInfoBox:SetPos(frame.InfoBoxX, frame.InfoBoxY)
                    currentInfoBox.Lines = lines
                    currentInfoBox.Paint = function(self, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
                        for j, line in ipairs(self.Lines) do
                            draw.SimpleText(line.text, "TooltipFont", TOOLTIP_PADDING_X, TOOLTIP_PADDING_Y + (j - 1) * TOOLTIP_LINE_HEIGHT, line.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        end
                    end
                end

                model.OnCursorExited = function(self)
                    print("[Debug] OnCursorExited triggered for " .. item.itemID .. " in loadout slot " .. slot)
                    if IsValid(currentInfoBox) then
                        timer.Simple(TOOLTIP_FADEOUT_DELAY, function()
                            if IsValid(currentInfoBox) and not self:IsHovered() then
                                currentInfoBox:Remove()
                                print("[Debug] Info box removed after delay")
                            end
                        end)
                    end
                end

                model.DoClick = function(self)
                    local menu = DermaMenu()
                    table.insert(activeMenus, menu)
                    menu:AddOption("Unequip", function()
                        net.Start("UnequipItem")
                        net.WriteString(slot)
                        net.SendToServer()
                    end)
                    menu:Open(self:LocalToScreen(10, iconSize))
                    menu.OnRemove = function()
                        for j, m in ipairs(activeMenus) do
                            if m == menu then table.remove(activeMenus, j) break end
                        end
                    end
                end
            end
        end
    end

    local function OpenEquipmentMenu()
        -- Calculate frame size based on screen resolution
        local screenW, screenH = ScrW(), ScrH()
        local frameWidth = math.min(screenW * 0.4, 500) -- 40% of screen width, max 500
        local baseFrameHeight = math.min(screenH * 0.6, 600) -- 60% of screen height, max 600

        -- Estimate info box height (assume max 10 lines for a Legendary item with 6 slots)
        local maxInfoBoxLines = 10 -- Rarity, Item, Slot Type, Damage, Slots label, 6 slots, Crafter
        local infoBoxHeight = (maxInfoBoxLines * TOOLTIP_LINE_HEIGHT) + (TOOLTIP_PADDING_Y * 2)
        local frameHeight = baseFrameHeight + infoBoxHeight + 20 -- Add space for info box and padding

        -- Ensure frame fits within screen
        frameWidth = math.min(frameWidth, screenW - 40) -- 20px padding on each side
        frameHeight = math.min(frameHeight, screenH - 40) -- 20px padding on top/bottom

        -- Create the frame
        local frame = vgui.Create("DFrame")
        frame:SetSize(frameWidth, frameHeight)
        frame:SetPos((screenW - frameWidth) / 2, (screenH - frameHeight) / 2)
        frame:SetTitle("Equipment Loadout")
        frame:SetDraggable(false)
        frame:MakePopup()
        frame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225)) end
        frame.OnClose = function()
            if IsValid(currentInfoBox) then currentInfoBox:Remove() end
            for _, menu in ipairs(activeMenus) do if IsValid(menu) then menu:Remove() end end
            activeMenus = {}
        end

        -- Calculate layout dimensions
        local padding = 10
        local contentHeight = frameHeight - 30 -- Account for title bar
        local leftPanelWidth = math.floor(frameWidth * 0.5) -- 50% for player model and info box
        local rightPanelWidth = frameWidth - leftPanelWidth - padding
        local playerModelHeight = math.floor(contentHeight * 0.65) -- 65% of content height for player model
        local infoBoxHeightSpace = contentHeight - playerModelHeight - padding
        local infoBoxWidth = leftPanelWidth - 2 * padding

        -- Store info box position and size for use in RefreshEquipmentSlots
        frame.InfoBoxWidth = infoBoxWidth
        frame.InfoBoxX = padding
        frame.InfoBoxY = 30 + playerModelHeight + padding

        -- Player model
        local playerModel = vgui.Create("DModelPanel", frame)
        playerModel:SetSize(leftPanelWidth - 2 * padding, playerModelHeight)
        playerModel:SetPos(padding, 30)
        playerModel:SetModel(LocalPlayer():GetModel())
        playerModel:SetFOV(30)
        playerModel:SetCamPos(Vector(70, 70, 70))
        playerModel:SetLookAt(Vector(0, 0, 40))

        -- Slots panel
        local slotsPanel = vgui.Create("DPanel", frame)
        slotsPanel:SetSize(rightPanelWidth, contentHeight)
        slotsPanel:SetPos(leftPanelWidth + padding, 30)
        slotsPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

        RefreshEquipmentSlots(frame, slotsPanel)

        -- Refresh slots only if panel is still valid
        net.Receive("SyncLoadout", function()
            Loadout = net.ReadTable()
            if IsValid(slotsPanel) then
                RefreshEquipmentSlots(frame, slotsPanel)
            end
        end)
    end

    hook.Add("PlayerBindPress", "CustomMenuBinds", function(_, bind, pressed)
        if bind == "+menu" and pressed then
            isQKeyHeld = true
            OpenCustomQMenu()
            return true
        elseif bind == "+menu_context" and pressed then
            OpenEquipmentMenu()
            return true
        end
    end)

    hook.Add("Think", "CheckQKeyRelease", function()
        if isQKeyHeld and not input.IsKeyDown(KEY_Q) then
            isQKeyHeld = false
            if IsValid(InventoryFrame) then InventoryFrame:Close() end
        end
    end)

    net.Receive("SyncInventory", function()
        local page = net.ReadUInt(8)
        Inventory = net.ReadTable()
        InventoryPositions = net.ReadTable()
        if IsValid(inventoryTab) then BuildInventoryUI(inventoryTab, page) end
    end)

    net.Receive("SyncResources", function()
        Resources = net.ReadTable()
        if IsValid(resourcesTab) then BuildResourcesMenu(resourcesTab) end
    end)

    net.Receive("InventoryMessage", function()
        local message = net.ReadString()
        chat.AddText(Color(255, 215, 0), "[Inventory] ", Color(255, 255, 255), message)
    end)

    net.Receive("SyncLoadout", function()
        Loadout = net.ReadTable()
    end)

    concommand.Add("rp_loadout", OpenEquipmentMenu)
end