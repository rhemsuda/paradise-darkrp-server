print("[Inventory Module] sv_inventory.lua loaded successfully")

-- Define network strings
util.AddNetworkString("OpenInventory")
util.AddNetworkString("SyncInventory")
util.AddNetworkString("DropItem")
util.AddNetworkString("UseItem")
util.AddNetworkString("DeleteItem")
util.AddNetworkString("InventoryMessage")
util.AddNetworkString("RequestOpenInventory")
util.AddNetworkString("OpenResourcesMenu")
util.AddNetworkString("SyncResources")
util.AddNetworkString("DropResource")

AddCSLuaFile("modules/inventory/cl_resources.lua")

local PlayerInventories = {}
local PickupCooldown = {}

-- Include shared items if defined separately
if file.Exists("modules/inventory/sh_items.lua", "LUA") then
    include("modules/inventory/sh_items.lua")
end

hook.Add("DarkRPDBInitialized", "InitCustomInventoryTable", function()
    MySQLite.begin()
    MySQLite.queueQuery([[
        CREATE TABLE IF NOT EXISTS darkrp_custom_inventory (
            steamid VARCHAR(20) NOT NULL PRIMARY KEY,
            items TEXT NOT NULL,
            resources TEXT NOT NULL DEFAULT '{}'
        );
    ]])
    -- Add resources column if it doesn’t exist
    MySQLite.queueQuery([[
        ALTER TABLE darkrp_custom_inventory ADD COLUMN resources TEXT NOT NULL DEFAULT '{}'
        WHERE NOT EXISTS (SELECT 1 FROM pragma_table_info('darkrp_custom_inventory') WHERE name = 'resources');
    ]])
    MySQLite.commit(function()
        print("[Custom Inventory] Table 'darkrp_custom_inventory' initialized or updated successfully!")
    end)
end)

local function SendInventoryMessage(ply, message)
    if not IsValid(ply) then return end
    net.Start("InventoryMessage")
    net.WriteString(message)
    net.Send(ply)
    print("[Inventory Log] " .. ply:Nick() .. " (" .. ply:SteamID() .. "): " .. message)
end

local function LoadPlayerInventory(ply)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    MySQLite.query([[
        SELECT items, resources FROM darkrp_custom_inventory WHERE steamid = ]] .. MySQLite.SQLStr(steamID) .. [[
    ]], function(data)
        if data and data[1] then
            PlayerInventories[steamID] = {
                items = util.JSONToTable(data[1].items or "{}") or {},
                resources = util.JSONToTable(data[1].resources or "{}") or {}
            }
        else
            PlayerInventories[steamID] = { items = {}, resources = {} }
        end
        net.Start("SyncInventory")
        net.WriteTable(PlayerInventories[steamID].items)
        net.Send(ply)
        net.Start("SyncResources")
        net.WriteTable(PlayerInventories[steamID].resources)
        net.Send(ply)
    end, function(err)
        print("[Custom Inventory] Error loading inventory for " .. steamID .. ": " .. err)
        PlayerInventories[steamID] = { items = {}, resources = {} }
    end)
end

local function SavePlayerInventory(ply)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
    local itemsJson = util.TableToJSON(inv.items)
    local resourcesJson = util.TableToJSON(inv.resources)
    MySQLite.query([[
        REPLACE INTO darkrp_custom_inventory (steamid, items, resources) VALUES (]] .. 
        MySQLite.SQLStr(steamID) .. [[, ]] .. MySQLite.SQLStr(itemsJson) .. [[, ]] .. MySQLite.SQLStr(resourcesJson) .. [[)
    ]], nil, function(err)
        print("[Custom Inventory] Error saving inventory for " .. steamID .. ": " .. err)
    end)
end

function AddResourceToInventory(ply, resourceID, amount)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
    inv.resources[resourceID] = (inv.resources[resourceID] or 0) + (amount or 1)
    PlayerInventories[steamID] = inv
    net.Start("SyncResources")
    net.WriteTable(inv.resources)
    net.Send(ply)
    SavePlayerInventory(ply)
    SendInventoryMessage(ply, "Added " .. amount .. " " .. resourceID .. " to your resources.")
end

function RemoveResourceFromInventory(ply, resourceID, amount)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
    if not inv.resources[resourceID] or inv.resources[resourceID] < amount then return end

    inv.resources[resourceID] = inv.resources[resourceID] - amount
    if inv.resources[resourceID] <= 0 then
        inv.resources[resourceID] = nil
    end

    PlayerInventories[steamID] = inv
    net.Start("SyncResources")
    net.WriteTable(inv.resources)
    net.Send(ply)
    SavePlayerInventory(ply)
    SendInventoryMessage(ply, "Dropped " .. amount .. " " .. resourceID .. ".")
end

function AddItemToInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
    local maxStack = InventoryItems[itemID].maxStack or 64
    local newAmount = math.min((inv.items[itemID] or 0) + (amount or 1), maxStack)

    inv.items[itemID] = newAmount
    PlayerInventories[steamID] = inv
    net.Start("SyncInventory")
    net.WriteTable(inv.items)
    net.Send(ply)
    SavePlayerInventory(ply)
    SendInventoryMessage(ply, "Added " .. amount .. " " .. InventoryItems[itemID].name .. "(s) to your inventory.")
end

local function RemoveItemFromInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
    if not inv.items[itemID] or inv.items[itemID] < amount then return end

    inv.items[itemID] = inv.items[itemID] - amount
    if inv.items[itemID] <= 0 then
        inv.items[itemID] = nil
    end

    PlayerInventories[steamID] = inv
    net.Start("SyncInventory")
    net.WriteTable(inv.items)
    net.Send(ply)
    SavePlayerInventory(ply)
end

concommand.Add("addresource", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        SendInventoryMessage(ply, "You must be a superadmin to use this command.")
        return
    end
    local resourceID = args[1]
    local amount = tonumber(args[2]) or 1
    if not resourceID then
        SendInventoryMessage(ply, "Specify a resource ID (e.g., 'addresource Rock 10').")
        return
    end
    AddResourceToInventory(ply, resourceID, amount)
end)

concommand.Add("open_resources", function(ply)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
    net.Start("SyncResources")
    net.WriteTable(inv.resources)
    net.Send(ply)
    net.Start("OpenResourcesMenu")
    net.Send(ply)
end)

net.Receive("RequestOpenInventory", function(len, ply)
    if not IsValid(ply) or ply:GetActiveWeapon():GetClass() ~= "weapon_inventory" then return end
    local inv = PlayerInventories[ply:SteamID()] or { items = {}, resources = {} }
    net.Start("SyncInventory")
    net.WriteTable(inv.items)
    net.Send(ply)
    net.Start("OpenInventory")
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

net.Receive("DropResource", function(len, ply)
    local resourceID = net.ReadString()
    local amount = net.ReadUInt(16)
    if amount < 1 then return end
    RemoveResourceFromInventory(ply, resourceID, amount)
end)

-- Hooks
hook.Add("PlayerInitialSpawn", "Inventory_InitInventory", function(ply)
    if not IsValid(ply) then return end
    LoadPlayerInventory(ply)
    -- Force valid team on initial spawn
    local currentTeam = ply:Team()
    local defaultTeam = TEAM_CITIZEN or 1
    if not RPExtraTeams[currentTeam] or currentTeam == TEAM_UNASSIGNED then
        if RPExtraTeams[defaultTeam] then
            ply:changeTeam(defaultTeam, true)
            print("[Debug] Forced " .. ply:Nick() .. " to TEAM_CITIZEN (Team " .. defaultTeam .. ") in InitialSpawn")
        else
            for teamID, job in pairs(RPExtraTeams) do
                if job and teamID then
                    ply:changeTeam(teamID, true)
                    print("[Debug] Forced " .. ply:Nick() .. " to fallback team " .. teamID .. " (" .. job.name .. ") in InitialSpawn")
                    break
                end
            end
        end
    end
    if not ply:HasWeapon("weapon_inventory") then
        ply:Give("weapon_inventory")
    end
end)

hook.Add("PlayerSpawn", "Inventory_SetupTeam", function(ply)
    if not IsValid(ply) then return end
    local currentTeam = ply:Team()
    local defaultTeam = TEAM_CITIZEN or 1 -- Fallback to 1 if TEAM_CITIZEN isn’t defined

    if not RPExtraTeams[currentTeam] or currentTeam == TEAM_UNASSIGNED then
        if RPExtraTeams[defaultTeam] then
            ply:changeTeam(defaultTeam, true)
            print("[Debug] Forced " .. ply:Nick() .. " to TEAM_CITIZEN (Team " .. defaultTeam .. ")")
        else
            -- If TEAM_CITIZEN isn’t valid, find any valid team
            for teamID, job in pairs(RPExtraTeams) do
                if job and teamID then
                    ply:changeTeam(teamID, true)
                    print("[Debug] Forced " .. ply:Nick() .. " to fallback team " .. teamID .. " (" .. job.name .. ")")
                    break
                end
            end
        end
    end
    print("[Debug] Team after spawn: " .. ply:Team() .. " (" .. team.GetName(ply:Team()) .. ")")
end)

hook.Add("PlayerLoadout", "Inventory_GiveInventorySWEP", function(ply)
    if not IsValid(ply) then return end
    for k, v in pairs(GAMEMODE.Config.DefaultWeapons) do
        ply:Give(v)
    end
    local team = ply:Team()
    if RPExtraTeams[team] then -- Only proceed if team is valid
        if RPExtraTeams[team].weapons then
            for k, v in pairs(RPExtraTeams[team].weapons) do
                ply:Give(v)
            end
        end
    else
        print("[Warning] " .. ply:Nick() .. " has invalid team " .. team .. " in PlayerLoadout")
    end
    if not ply:HasWeapon("weapon_inventory") then
        ply:Give("weapon_inventory")
    end
    ply:SelectWeapon("weapon_inventory")
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

concommand.Add("additem", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        SendInventoryMessage(ply, "You must be a superadmin to use this command.")
        return
    end
    local itemID = args[1]
    local amount = tonumber(args[2]) or 1
    AddItemToInventory(ply, itemID, amount)
end)