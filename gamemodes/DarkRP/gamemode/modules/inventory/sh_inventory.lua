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

-- Inventory Management Functions
function AddResourceToInventory(ply, resourceID, amount, silent)
    if not IsValid(ply) or not ResourceItems[resourceID] then return end
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

function AddItemToInventory(ply, itemID, amount, stats, page, silent)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
    page = tonumber(page) or 1
    inv.maxPages = inv.maxPages or 1
    if page < 1 or page > inv.maxPages then return end
    inv.items[page] = inv.items[page] or {}
    inv.positions[page] = inv.positions[page] or {}
    for i = 1, (amount or 1) do
        local uniqueID = stats and stats.id or GenerateUUID()
        local isWeaponOrArmor = InventoryItems[itemID].category == "Weapons" or InventoryItems[itemID].category == "Armor"
        stats = stats or {
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

                -- Assign damage based on weapon type and rarity
                local weaponType = WeaponTypes[itemID] or "unknown"
                if weaponType == "pistol" then
                    if stats.rarity == "Legendary" then
                        stats.damage = math.random(6, 20)
                    else
                        stats.damage = math.random(6, 15)
                    end
                elseif weaponType == "assault_rifle" then
                    if stats.rarity == "Legendary" then
                        stats.damage = math.random(15, 25)
                    else
                        stats.damage = math.random(12, 20)
                    end
                elseif weaponType == "shotgun" then
                    if stats.rarity == "Legendary" then
                        stats.damage = math.random(5, 15)
                    else
                        stats.damage = math.random(5, 10)
                    end
                elseif weaponType == "sniper" then
                    if stats.rarity == "Legendary" then
                        stats.damage = math.random(50, 100)
                    else
                        stats.damage = math.random(25, 50)
                    end
                else
                    -- Default damage for unknown weapon types
                    stats.damage = math.random(10, 80)
                end
            else
                -- Default damage for armor (if any)
                stats.damage = 0
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
        if not silent then
            SendInventoryMessage(ply, "Added " .. (amount or 1) .. " " .. InventoryItems[itemID].name .. "(s) to your inventory on page " .. page .. ".")
        end
    end
end

-- Server-Side Logic
if SERVER then
    local allowedTools = { "button", "fading_door", "keypad_willox", "camera", "nocollide", "remover", "stacker" }

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

    function SendInventoryMessage(ply, message)
        if not IsValid(ply) then return end
        net.Start("InventoryMessage")
        net.WriteString(message)
        net.Send(ply)
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
                inv.items = util.JSONToTable(data[1].items or '{"1":[]}') or { [1] = {} }
                inv.positions = util.JSONToTable(data[1].positions or '{"1":{}}') or { [1] = {} }
                PlayerInventories[steamID] = inv
                net.Start("SyncInventory")
                net.WriteUInt(page, 8)
                net.WriteTable(inv.items[page] or {})
                net.WriteTable(inv.positions[page] or {})
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
            SendInventoryMessage(ply, "Unequipped " .. existingItemData.name .. " from " .. slot .. " to equip new item.")
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
        SendInventoryMessage(ply, "Equipped " .. itemData.name .. " to " .. slot .. ".")
        if itemData.category == "Weapons" then
            local weaponClass = itemData.entityClass or item.itemID
            ply:Give(weaponClass)
            ply:SelectWeapon(weaponClass)
            -- Store the custom damage on the player's weapon
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
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1, loadout = {} }
        local item = inv.loadout[slot]
        if not item or not InventoryItems[item.itemID] then return end
        local itemData = InventoryItems[item.itemID]
        inv.loadout[slot] = nil
        AddItemToInventory(ply, item.itemID, 1, { id = item.id, damage = item.damage, slots = item.slots, rarity = item.rarity, slotType = item.slotType, crafter = item.crafter }, 1, true)
        PlayerInventories[steamID] = inv
        SavePlayerInventory(ply)
        net.Start("SyncLoadout")
        net.WriteTable(inv.loadout)
        net.Send(ply)
        SendInventoryMessage(ply, "Unequipped " .. itemData.name .. " from " .. slot .. ".")
        if itemData.category == "Weapons" then
            local weaponClass = itemData.entityClass or item.itemID
            ply:StripWeapon(weaponClass)
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
        if InventoryItems[itemID].category == "Weapons" or InventoryItems[itemID].category == "Armor" then return end
        AddItemToInventory(ply, itemID, 1, stats, 1)
        ent:Remove()
        SendInventoryMessage(ply, "Picked up 1 " .. InventoryItems[itemID].name .. ".")
        return true
    end)

    -- Hook to apply custom damage from inventory weapons
    hook.Add("EntityTakeDamage", "ApplyCustomWeaponDamage", function(target, dmginfo)
        local attacker = dmginfo:GetAttacker()
        if not IsValid(attacker) or not attacker:IsPlayer() then return end

        local weapon = attacker:GetActiveWeapon()
        if not IsValid(weapon) then return end

        local customDamage = weapon:GetNWInt("CustomDamage", -1)
        if customDamage == -1 then return end -- No custom damage set

        local weaponType = weapon:GetNWString("WeaponType", "unknown")
        local rarity = weapon:GetNWString("Rarity", "Common")
        local damageToApply = customDamage

        -- For shotguns, multiply damage by the number of pellets (assuming 6 pellets)
        if weaponType == "shotgun" then
            local numPellets = 6 -- Adjust this if your shotguns fire a different number of pellets
            damageToApply = customDamage * numPellets
            -- Since shotguns fire multiple pellets, we only want to apply the total damage once
            -- Garry's Mod applies damage per pellet, so we'll override the damage for this hit
            dmginfo:SetDamage(damageToApply / numPellets) -- Spread the total damage across pellets for display
        else
            dmginfo:SetDamage(damageToApply)
        end

        -- Debug output to console
        print(string.format("[Weapon Damage Test] %s (%s, %s) dealt %d damage to %s with %s (Base Damage: %d)",
            attacker:Nick(), weaponType, rarity, damageToApply, target:GetClass(), weapon:GetClass(), customDamage))
    end)

    -- Console command to spawn a test NPC for damage testing
    concommand.Add("test_weapon_damage", function(ply)
        if not IsValid(ply) then return end
        if not ply:IsSuperAdmin() then
            SendInventoryMessage(ply, "Superadmin only.")
            return
        end

        -- Spawn an NPC in front of the player
        local npc = ents.Create("npc_zombie")
        if not IsValid(npc) then
            SendInventoryMessage(ply, "Failed to spawn test NPC (npc_zombie).")
            return
        end

        local pos = ply:GetEyeTrace().HitPos + Vector(0, 0, 50)
        npc:SetPos(pos)
        npc:Spawn()
        npc:SetHealth(1000) -- Give the NPC high health so it doesn't die immediately

        SendInventoryMessage(ply, "Spawned a test NPC (npc_zombie) with 1000 health. Shoot it to test damage.")
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
    local InventoryFrame, ToolSelectorFrame, inventoryTab, resourcesTab, adminTab
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

    -- Tooltip Configuration
    surface.CreateFont("TooltipFont", { font = "DermaDefault", size = 14, weight = 500 })
    local TOOLTIP_LINE_HEIGHT = 18
    local TOOLTIP_PADDING_X = 10
    local TOOLTIP_PADDING_Y = 10
    local TOOLTIP_ZPOS = 1000
    local TOOLTIP_SPACING = 2
    local TOOLTIP_FADEOUT_DELAY = 0.2
    local RARITY_COLORS = {
        common = Color(200, 200, 200),
        uncommon = Color(0, 255, 0),
        rare = Color(0, 0, 139),
        epic = Color(255, 245, 200),
        legendary = Color(139, 0, 0)
    }

    local function CalculateSlotCounts(item, itemData)
        local isWeaponOrArmor = itemData.category == "Weapons" or itemData.category == "Armor"
        local slotCount = item.slots or 0
        local baseSlotCount = 0
        if isWeaponOrArmor then
            if itemData.category == "Weapons" then
                local weaponSlots = { ak47 = 2, m4a1 = 2, sg552 = 2, aug = 2, m249 = 2 }
                baseSlotCount = weaponSlots[item.itemID] or 1
            else
                baseSlotCount = 1
            end
        end
        local displaySlotCount = isWeaponOrArmor and math.max(slotCount, baseSlotCount) or slotCount
        return slotCount, baseSlotCount, displaySlotCount
    end

    local function CreateTooltipContent(item, itemData)
        local isWeaponOrArmor = itemData.category == "Weapons" or itemData.category == "Armor"
        local isUtility = itemData.category == "Utility"
        local rarity = isWeaponOrArmor and (item.rarity or itemData.baseRarity or "Common") or nil
        local rarityColor = rarity and RARITY_COLORS[rarity:lower()] or Color(255, 255, 255)
        local damage = item.damage or "N/A"
        local slotType = item.slotType or "N/A"
        local slotTypeColor = (slotType == "Sidearm") and RARITY_COLORS.epic or Color(255, 255, 255)
        local crafter = item.crafter or "Unknown"
        local slotCount, baseSlotCount, displaySlotCount = CalculateSlotCounts(item, itemData)

        local lines = {}
        if isWeaponOrArmor then
            table.insert(lines, { text = rarity, color = rarityColor })
            table.insert(lines, { text = itemData.name, color = Color(255, 255, 255) })
            if itemData.category == "Weapons" then
                table.insert(lines, { text = slotType, color = slotTypeColor })
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

    local function CreateTooltip(parent, lines, posX, posY, row, col)
        local maxWidth = 0
        for _, line in ipairs(lines) do
            surface.SetFont("TooltipFont")
            local textWidth, _ = surface.GetTextSize(line.text)
            maxWidth = math.max(maxWidth, textWidth)
        end
        local tooltipWidth = maxWidth + TOOLTIP_PADDING_X * 2
        local tooltipHeight = (#lines * TOOLTIP_LINE_HEIGHT) + (TOOLTIP_PADDING_Y * 2)

        currentTooltip = vgui.Create("DPanel", parent)
        currentTooltip:SetSize(tooltipWidth, tooltipHeight)
        currentTooltip:SetZPos(TOOLTIP_ZPOS)
        currentTooltip.Lines = lines

        -- Grid dimensions
        local slotWidth, slotHeight = 97, 97
        local isRightmost = col == 10
        local isBottomRow = row == 6
        local localX, localY

        -- Default: position to the right, aligned with the top of the slot
        localX = posX + slotWidth + TOOLTIP_SPACING
        localY = posY -- Align with the top of the slot

        -- Adjust positioning based on grid position
        if isRightmost then
            if isBottomRow then
                -- Rightmost column and bottom row: position above the item
                localX = posX - (tooltipWidth - slotWidth) / 2 -- Center horizontally
                localY = posY - tooltipHeight - TOOLTIP_SPACING
            else
                -- Rightmost column but not bottom row: position below the item
                localX = posX - (tooltipWidth - slotWidth) / 2 -- Center horizontally
                localY = posY + slotHeight + TOOLTIP_SPACING
            end
        elseif isBottomRow then
            -- Bottom row but not rightmost column: position above the item
            localX = posX + slotWidth + TOOLTIP_SPACING
            localY = posY - tooltipHeight - TOOLTIP_SPACING
        end

        -- Ensure tooltip stays within gridPanel bounds
        local gridWidth, gridHeight = parent:GetSize()
        localX = math.max(0, math.min(localX, gridWidth - tooltipWidth))
        localY = math.max(0, math.min(localY, gridHeight - tooltipHeight))

        currentTooltip:SetPos(localX, localY)
        currentTooltip.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
            for i, line in ipairs(self.Lines) do
                draw.SimpleText(line.text, "TooltipFont", TOOLTIP_PADDING_X, TOOLTIP_PADDING_Y + (i - 1) * TOOLTIP_LINE_HEIGHT, line.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end
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
                        if pos[1] == row and pos[2] == col and uniqueID != draggedUniqueID then
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
                local itemData = InventoryItems[itemID]
                local lines = CreateTooltipContent(item, itemData)
                local slotPanel = slots[row][col]
                local slotX, slotY = slotPanel:GetPos()
                CreateTooltip(gridPanel, lines, slotX, slotY, row, col)
            end

            model.OnCursorExited = function(self)
                if IsValid(currentTooltip) then
                    timer.Simple(TOOLTIP_FADEOUT_DELAY, function()
                        if IsValid(currentTooltip) and not self:IsHovered() then
                            currentTooltip:Remove()
                        end
                    end)
                end
            end
        
            model.DoClick = function(self)
                if not isInventoryOpen then return end
                local menu = DermaMenu()
                table.insert(activeMenus, menu)

                local isEquipable = false
                if InventoryItems[itemID].category == "Utility" and itemID ~= "medkit" then
                    isEquipable = true
                elseif InventoryItems[itemID].category == "Weapons" then
                    isEquipable = true
                end

                if not isEquipable and InventoryItems[itemID].useFunction then
                    menu:AddOption("Use", function()
                        net.Start("UseItem")
                        net.WriteString(uniqueID)
                        net.WriteUInt(currentPage, 8)
                        net.SendToServer()
                    end)
                end

                if not (InventoryItems[itemID].category == "Weapons" or InventoryItems[itemID].category == "Armor") then
                    menu:AddOption("Drop", function()
                        net.Start("DropItem")
                        net.WriteString(uniqueID)
                        net.WriteUInt(currentPage, 8)
                        net.SendToServer()
                    end)
                end

                if InventoryItems[itemID].category == "Utility" and itemID ~= "medkit" then
                    menu:AddOption("Equip", function()
                        net.Start("EquipItem")
                        net.WriteString(uniqueID)
                        net.WriteUInt(currentPage, 8)
                        net.WriteString("Utility")
                        net.SendToServer()
                    end)
                elseif InventoryItems[itemID].category == "Weapons" then
                    local equipSlot = (item.slotType == "Sidearm") and "Sidearm" or "Weapon"
                    menu:AddOption("Equip", function()
                        net.Start("EquipItem")
                        net.WriteString(uniqueID)
                        net.WriteUInt(currentPage, 8)
                        net.WriteString(equipSlot)
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

    local function BuildAdminPanel(parent)
        if not IsValid(parent) then return end
        for _, child in pairs(parent:GetChildren()) do child:Remove() end

        -- Create a dropdown for admin options
        local dropdown = vgui.Create("DComboBox", parent)
        dropdown:SetPos(10, 10)
        dropdown:SetSize(200, 30)
        dropdown:SetValue("Select an Option")
        dropdown:AddChoice("Item Edit")
        dropdown:AddChoice("Inventory Edit")
        dropdown:AddChoice("Props")
        dropdown:AddChoice("Events Panel")

        -- Create panels for each option (hidden by default)
        local panels = {}

        -- Item Edit Panel
        panels["Item Edit"] = vgui.Create("DPanel", parent)
        panels["Item Edit"]:SetPos(10, 50)
        panels["Item Edit"]:SetSize(970, 620)
        panels["Item Edit"]:SetVisible(false)
        panels["Item Edit"].Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
        end
        local itemEditLabel = vgui.Create("DLabel", panels["Item Edit"])
        itemEditLabel:SetPos(10, 10)
        itemEditLabel:SetSize(950, 30)
        itemEditLabel:SetText("Item Edit Panel - Add functionality here")
        itemEditLabel:SetColor(Color(255, 255, 255))

        -- Inventory Edit Panel
        panels["Inventory Edit"] = vgui.Create("DPanel", parent)
        panels["Inventory Edit"]:SetPos(10, 50)
        panels["Inventory Edit"]:SetSize(970, 620)
        panels["Inventory Edit"]:SetVisible(false)
        panels["Inventory Edit"].Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
        end
        local invEditLabel = vgui.Create("DLabel", panels["Inventory Edit"])
        invEditLabel:SetPos(10, 10)
        invEditLabel:SetSize(950, 30)
        invEditLabel:SetText("Inventory Edit Panel - Add functionality here")
        invEditLabel:SetColor(Color(255, 255, 255))

        -- Props Panel
        panels["Props"] = vgui.Create("DPanel", parent)
        panels["Props"]:SetPos(10, 50)
        panels["Props"]:SetSize(970, 620)
        panels["Props"]:SetVisible(false)
        panels["Props"].Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
        end
        local propsLabel = vgui.Create("DLabel", panels["Props"])
        propsLabel:SetPos(10, 10)
        propsLabel:SetSize(950, 30)
        propsLabel:SetText("Props Panel - Add functionality here")
        propsLabel:SetColor(Color(255, 255, 255))

        -- Events Panel
        panels["Events Panel"] = vgui.Create("DPanel", parent)
        panels["Events Panel"]:SetPos(10, 50)
        panels["Events Panel"]:SetSize(970, 620)
        panels["Events Panel"]:SetVisible(false)
        panels["Events Panel"].Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
        end
        local eventsLabel = vgui.Create("DLabel", panels["Events Panel"])
        eventsLabel:SetPos(10, 10)
        eventsLabel:SetSize(950, 30)
        eventsLabel:SetText("Events Panel - Add functionality here")
        eventsLabel:SetColor(Color(255, 255, 255))

        -- Show the selected panel when an option is chosen
        dropdown.OnSelect = function(self, index, value)
            for panelName, panel in pairs(panels) do
                panel:SetVisible(panelName == value)
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
            for _, menu in ipairs(activeMenus) do if IsValid(menu) then menu:Remove() end end
            activeMenus = {}
            if IsValid(currentTooltip) then currentTooltip:Remove() end
            InventoryFrame = nil
            inventoryTab = nil
            resourcesTab = nil
            adminTab = nil
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

        -- Add Admin Panel tab for superadmins only
        if LocalPlayer():IsSuperAdmin() then
            adminTab = vgui.Create("DPanel", tabPanel)
            adminTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
            BuildAdminPanel(adminTab)
            tabPanel:AddSheet("Admin Panel", adminTab, "icon16/shield.png")
        end

        isInventoryOpen = true
        OpenToolSelector()
    end

    local function RefreshEquipmentSlots(frame, slotsPanel)
        if not IsValid(slotsPanel) or not IsValid(frame) then return end
        for _, child in pairs(slotsPanel:GetChildren()) do child:Remove() end

        local frameW, frameH = frame:GetSize()
        local slotOrder = {"Armor", "Weapon", "Sidearm", "Boots", "Utility"}
        local slotLabels = {Armor = "Armor", Weapon = "Primary Weapon", Sidearm = "Sidearm", Boots = "Boots", Utility = "Utility"}

        local slotsPanelW, slotsPanelH = slotsPanel:GetSize()
        local slotHeight = math.floor((slotsPanelH - 10 * (#slotOrder + 1)) / #slotOrder)
        local slotWidth = slotsPanelW - 20
        local iconSize = math.min(slotWidth - 20, slotHeight - 20)

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
                    local itemData = InventoryItems[item.itemID]
                    local lines = CreateTooltipContent(item, itemData)
                    local infoBoxHeight = (#lines * TOOLTIP_LINE_HEIGHT) + (TOOLTIP_PADDING_Y * 2)
                    currentInfoBox = vgui.Create("DPanel", frame)
                    currentInfoBox:SetSize(frame.InfoBoxWidth, infoBoxHeight)
                    currentInfoBox:SetPos(frame.InfoBoxX, frame.InfoBoxY)
                    currentInfoBox:SetZPos(TOOLTIP_ZPOS)
                    currentInfoBox.Lines = lines
                    currentInfoBox.Paint = function(self, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
                        for j, line in ipairs(self.Lines) do
                            draw.SimpleText(line.text, "TooltipFont", TOOLTIP_PADDING_X, TOOLTIP_PADDING_Y + (j - 1) * TOOLTIP_LINE_HEIGHT, line.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        end
                    end
                end

                model.OnCursorExited = function(self)
                    if IsValid(currentInfoBox) then
                        timer.Simple(TOOLTIP_FADEOUT_DELAY, function()
                            if IsValid(currentInfoBox) and not self:IsHovered() then
                                currentInfoBox:Remove()
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
        local screenW, screenH = ScrW(), ScrH()
        local frameWidth = math.min(screenW * 0.4, 500)
        local baseFrameHeight = math.min(screenH * 0.6, 600)
        local maxInfoBoxLines = 10
        local infoBoxHeight = (maxInfoBoxLines * TOOLTIP_LINE_HEIGHT) + (TOOLTIP_PADDING_Y * 2)
        local frameHeight = baseFrameHeight + infoBoxHeight + 20
        frameWidth = math.min(frameWidth, screenW - 40)
        frameHeight = math.min(frameHeight, screenH - 40)

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

        local padding = 10
        local contentHeight = frameHeight - 30
        local leftPanelWidth = math.floor(frameWidth * 0.5)
        local rightPanelWidth = frameWidth - leftPanelWidth - padding
        local playerModelHeight = math.floor(contentHeight * 0.65)
        local infoBoxWidth = leftPanelWidth - 2 * padding

        frame.InfoBoxWidth = infoBoxWidth
        frame.InfoBoxX = padding
        frame.InfoBoxY = 30 + playerModelHeight + padding

        local playerModel = vgui.Create("DModelPanel", frame)
        playerModel:SetSize(leftPanelWidth - 2 * padding, playerModelHeight)
        playerModel:SetPos(padding, 30)
        playerModel:SetModel(LocalPlayer():GetModel())
        playerModel:SetFOV(30)
        playerModel:SetCamPos(Vector(70, 70, 70))
        playerModel:SetLookAt(Vector(0, 0, 40))

        local slotsPanel = vgui.Create("DPanel", frame)
        slotsPanel:SetSize(rightPanelWidth, contentHeight)
        slotsPanel:SetPos(leftPanelWidth + padding, 30)
        slotsPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

        RefreshEquipmentSlots(frame, slotsPanel)

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