print("[Inventory Module] sv_inventory.lua loaded successfully")

-- Define network strings
util.AddNetworkString("OpenInventory")
util.AddNetworkString("SyncInventory")
util.AddNetworkString("DropItem")
util.AddNetworkString("UseItem")
util.AddNetworkString("DeleteItem")
util.AddNetworkString("InventoryMessage")

-- Include shared items if defined separately
if file.Exists("modules/inventory/sh_items.lua", "LUA") then
    include("modules/inventory/sh_items.lua")
end

local PlayerInventories = {}
local PickupCooldown = {}

-- Define LoadPlayerInventory BEFORE hooks
local function LoadPlayerInventory(ply)
    if not IsValid(ply) then return end
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

local function SendInventoryMessage(ply, message)
    if not IsValid(ply) then return end
    net.Start("InventoryMessage")
    net.WriteString(message)
    net.Send(ply)
    print("[Inventory Log] " .. ply:Nick() .. " (" .. ply:SteamID() .. "): " .. message)
end

local function SavePlayerInventory(ply)
    if not IsValid(ply) then return end
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

hook.Add("PlayerInitialSpawn", "Inventory_InitInventory", function(ply)
    if not IsValid(ply) then return end
    LoadPlayerInventory(ply)
    ply:Give("weapon_inventory")
    print("[Debug] Gave " .. ply:Nick() .. " weapon_inventory in Inventory_InitInventory")
    local weapons = {}
    for k, v in pairs(ply:GetWeapons()) do weapons[k] = v:GetClass() end
    print("[Debug] Weapons after Init: " .. table.concat(weapons, ", "))
end)

hook.Add("PlayerSpawn", "Inventory_SetupTeam", function(ply)
    if not IsValid(ply) then return end
    local currentTeam = ply:Team()
    if not RPExtraTeams[currentTeam] then
        local defaultTeam = TEAM_CITIZEN or 1
        if RPExtraTeams[defaultTeam] then
            ply:changeTeam(defaultTeam, true)
            print("[Debug] Forced " .. ply:Nick() .. " to TEAM_CITIZEN (Team " .. defaultTeam .. ")")
        else
            print("[Error] No valid TEAM_CITIZEN found for " .. ply:Nick())
        end
    end
    print("[Debug] Team after spawn: " .. ply:Team() .. " (" .. team.GetName(ply:Team()) .. ")")
end)

hook.Add("PlayerLoadout", "Inventory_GiveInventorySWEP", function(ply)
    if not IsValid(ply) then return end
    local weaponsBefore = {}
    for k, v in pairs(ply:GetWeapons()) do weaponsBefore[k] = v:GetClass() end
    print("[Debug] Before Loadout: " .. table.concat(weaponsBefore, ", "))
    for k, v in pairs(GAMEMODE.Config.DefaultWeapons) do
        ply:Give(v)
    end
    local team = ply:Team()
    if RPExtraTeams[team] and RPExtraTeams[team].weapons then
        for k, v in pairs(RPExtraTeams[team].weapons) do
            ply:Give(v)
        end
    end
    ply:Give("weapon_inventory")
    ply:SelectWeapon("weapon_inventory")
    local weaponsAfter = {}
    for k, v in pairs(ply:GetWeapons()) do weaponsAfter[k] = v:GetClass() end
    print("[Debug] After Loadout: " .. table.concat(weaponsAfter, ", "))
end)

hook.Add("PlayerDisconnected", "SaveInventoryOnDisconnect", function(ply)
    SavePlayerInventory(ply)
end)

function AddItemToInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or {}
    local maxStack = InventoryItems[itemID].maxStack or 64
    local newAmount = math.min((inv[itemID] or 0) + (amount or 1), maxStack)

    inv[itemID] = newAmount
    PlayerInventories[steamID] = inv
    net.Start("SyncInventory")
    net.WriteTable(inv)
    net.Send(ply)
    SavePlayerInventory(ply)

    SendInventoryMessage(ply, "Added " .. amount .. " " .. InventoryItems[itemID].name .. "(s) to your inventory.")
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
    SendInventoryMessage(ply, "Dropped " .. amount .. " " .. InventoryItems[itemID].name .. "(s).")

    local itemData = InventoryItems[itemID]
    local entClass = itemData.entityClass or "prop_physics"
    for i = 1, amount do
        local ent = ents.Create(entClass)
        if IsValid(ent) then
            ent:SetModel(itemData.model)
            ent:SetPos(ply:GetPos() + ply:GetForward() * 50 + Vector(0, 0, i * 10))
            ent:Spawn()
            ent:SetNWString("ItemID", itemID)
            if entClass == "weapon_pistol" then
                ent.AmmoAmount = 30
            elseif entClass == "item_healthkit" then
                ent:SetHealthAmount(25)
            end
        end
    end
end)

net.Receive("UseItem", function(len, ply)
    local itemID = net.ReadString()
    local itemData = InventoryItems[itemID]
    if not itemData or not itemData.useFunction then return end

    itemData.useFunction(ply)
    RemoveItemFromInventory(ply, itemID, 1)
    SendInventoryMessage(ply, "Used 1 " .. itemData.name .. ".")
end)

net.Receive("DeleteItem", function(len, ply)
    local itemID = net.ReadString()
    local amount = net.ReadUInt(8)
    if not InventoryItems[itemID] or amount < 1 then return end

    RemoveItemFromInventory(ply, itemID, amount)
    SendInventoryMessage(ply, "Deleted " .. amount .. " " .. InventoryItems[itemID].name .. "(s).")
end)

concommand.Add("additem", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        SendInventoryMessage(ply, "You must be a superadmin to use this command.")
        return
    end
    local itemID = args[1]
    local amount = tonumber(args[2]) or 1
    AddItemToInventory(ply, itemID, amount)
end)

hook.Add("PlayerUse", "PickupInventoryItem", function(ply, ent)
    local itemID = ent:GetNWString("ItemID")
    if itemID and InventoryItems[itemID] then
        AddItemToInventory(ply, itemID, 1)
        ent:Remove()
        SendInventoryMessage(ply, "Picked up 1 " .. InventoryItems[itemID].name .. ".")
        return true
    else
        local entIndex = ent:EntIndex()
        local steamID = ply:SteamID()
        PickupCooldown[steamID] = PickupCooldown[steamID] or {}
        local lastMessageTime = PickupCooldown[steamID][entIndex] or 0
        if CurTime() - lastMessageTime > 5 then
            SendInventoryMessage(ply, "You cannot pick up this item.")
            PickupCooldown[steamID][entIndex] = CurTime()
        end
    end
end)