if not SERVER then return end

-- Load shared resource definitions (Paradise.ResourceItems, Paradise.ResourceAppearances, Paradise.ResourceCategories).
-- Explicit include + AddCSLuaFile so it is available before the rest of this file runs
-- (module loader includes sv_* before sh_*, so we must pull it in manually here).
AddCSLuaFile("sh_resources.lua")
include("sh_resources.lua")

-- Global alias kept for backward compatibility (sv_crafting etc. reference ResourceItems directly).
ResourceItems = Paradise.ResourceItems

-- Helper function to print debug messages conditionally (set rp_debug 1 to see)
local function DebugPrint(...)
    local cv = GetConVar("rp_debug")
    if cv and cv:GetInt() == 1 then print(...) end
end

-- Initialize network strings
util.AddNetworkString("SyncResources")
util.AddNetworkString("DropResource")
util.AddNetworkString("ResourcesMessage")

-- Player Resources Table (moved from PlayerInventories.resources)
PlayerResources = PlayerResources or {}

-- Function to send resource-related messages to the player
-- msgType: "mined" (resourceID), "dropped" (resourceID, amount), or "plain" (message string)
local function SendResourcesMessage(ply, message)
    if not IsValid(ply) then return end
    net.Start("ResourcesMessage")
    net.WriteString("plain")
    net.WriteString(message)
    net.Send(ply)
end
local function SendResourcesMessageMined(ply, resourceID)
    if not IsValid(ply) or not ResourceItems[resourceID] then return end
    net.Start("ResourcesMessage")
    net.WriteString("mined")
    net.WriteString(resourceID)
    net.Send(ply)
end
local function SendResourcesMessageDropped(ply, resourceID, amount)
    if not IsValid(ply) or not ResourceItems[resourceID] then return end
    net.Start("ResourcesMessage")
    net.WriteString("dropped")
    net.WriteString(resourceID)
    net.WriteUInt(amount, 16)
    net.Send(ply)
end
-- Used when a player picks up a paradise_resource entity (world drop).
function SendResourcesMessagePickedUp(ply, resourceID, amount)
    if not IsValid(ply) or not ResourceItems[resourceID] then return end
    net.Start("ResourcesMessage")
    net.WriteString("pickedup")
    net.WriteString(resourceID)
    net.WriteUInt(amount, 16)
    net.Send(ply)
end

-- Take resources from player's pouch. amounts = { resource_id = amount }. Returns true if player had enough (and deducts); false otherwise.
function TakeResourcesFromPouch(ply, amounts)
    if not IsValid(ply) or not amounts or type(amounts) ~= "table" then return false end
    local steamID = ply:SteamID()
    local resources = PlayerResources[steamID] or {}
    for resId, need in pairs(amounts) do
        if not ResourceItems[resId] or (need or 0) <= 0 then continue end
        local have = resources[resId] or 0
        if have < need then return false end
    end
    for resId, need in pairs(amounts) do
        if not ResourceItems[resId] or (need or 0) <= 0 then continue end
        resources[resId] = (resources[resId] or 0) - need
        if resources[resId] <= 0 then resources[resId] = nil end
    end
    PlayerResources[steamID] = resources
    net.Start("SyncResources")
    net.WriteTable(resources)
    net.Send(ply)
    SavePlayerResources(ply)
    return true
end

-- Return resources to player's pouch (e.g. when crafter menu closes with staged resources). amounts = { resource_id = amount }.
function ReturnResourcesToPouch(ply, amounts)
    if not IsValid(ply) or not amounts or type(amounts) ~= "table" then return end
    local steamID = ply:SteamID()
    local resources = PlayerResources[steamID] or {}
    for resId, amount in pairs(amounts) do
        if ResourceItems[resId] and (amount or 0) > 0 then
            resources[resId] = (resources[resId] or 0) + amount
        end
    end
    PlayerResources[steamID] = resources
    net.Start("SyncResources")
    net.WriteTable(resources)
    net.Send(ply)
    SavePlayerResources(ply)
end

-- Function to add resources to a player's inventory
function AddResourceToInventory(ply, resourceID, amount, silent)
    if not IsValid(ply) or not ResourceItems[resourceID] then 
        DebugPrint("[Resources Module] Invalid player or resourceID: " .. tostring(resourceID))
        return 
    end
    local steamID = ply:SteamID()
    local resources = PlayerResources[steamID] or {}
    resources[resourceID] = (resources[resourceID] or 0) + (amount or 1)
    PlayerResources[steamID] = resources
    net.Start("SyncResources")
    net.WriteTable(resources)
    net.Send(ply)
    SavePlayerResources(ply)
    if not silent then
        SendResourcesMessageMined(ply, resourceID)
        DebugPrint("[Resources Module] " .. ply:Nick() .. " mined " .. (amount or 1) .. " " .. ResourceItems[resourceID].name)
    end
end

-- Load player resources from the database
local function LoadPlayerResources(ply)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    MySQLite.query("SELECT resources FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
        local resources = {}
        if data and data[1] then
            resources = util.JSONToTable(data[1].resources or "{}") or {}
        end
        PlayerResources[steamID] = resources
        net.Start("SyncResources")
        net.WriteTable(resources)
        net.Send(ply)
        DebugPrint("[Resources Module] Loaded resources for " .. ply:Nick())
    end, function(err)
        print("[Resources Module] Error loading resources for " .. steamID .. ": " .. err)
    end)
end

-- Save player resources to the database
function SavePlayerResources(ply)
    if not IsValid(ply) then return end
    local steamID = ply:SteamID()
    local resources = PlayerResources[steamID] or {}
    -- Update only the resources column in the existing table
    MySQLite.query("UPDATE darkrp_custom_inventory SET resources = " .. MySQLite.SQLStr(util.TableToJSON(resources)) .. 
        " WHERE steamid = " .. MySQLite.SQLStr(steamID), nil, function(err)
        if err then 
            print("[Resources Module] Error saving resources for " .. steamID .. ": " .. err)
        else
            DebugPrint("[Resources Module] Saved resources for " .. ply:Nick())
        end
    end)
end

-- Track resource entities dropped on the ground so we can cap at 5 total (any type)
local ResourceDropEntities = {}

local function forgetResourceEntity(ent)
    if not IsValid(ent) then return end
    for i, e in ipairs(ResourceDropEntities) do
        if e == ent then
            table.remove(ResourceDropEntities, i)
            break
        end
    end
end

hook.Add("EntityRemoved", "Resources_ForgetDropped", forgetResourceEntity)

-- Cap: max 5 resource entities on the ground; remove oldest when over
local MAX_RESOURCE_ENTITIES = 5
local function enforceResourceEntityCap()
    while #ResourceDropEntities >= MAX_RESOURCE_ENTITIES do
        local oldest = ResourceDropEntities[1]
        table.remove(ResourceDropEntities, 1)
        if IsValid(oldest) then oldest:Remove() end
    end
end

-- Handle dropping resources
net.Receive("DropResource", function(len, ply)
    if IsPlayerGhost and IsPlayerGhost(ply) then return end
    local resourceID = net.ReadString()
    local amount = net.ReadUInt(16)
    if not ResourceItems[resourceID] or amount < 1 then 
        DebugPrint("[Resources Module] Invalid resource drop request by " .. ply:Nick() .. ": " .. resourceID .. ", amount: " .. amount)
        return 
    end
    local steamID = ply:SteamID()
    local resources = PlayerResources[steamID] or {}
    if not resources[resourceID] or resources[resourceID] < amount then 
        DebugPrint("[Resources Module] " .. ply:Nick() .. " attempted to drop " .. amount .. " " .. resourceID .. " but only has " .. (resources[resourceID] or 0))
        return 
    end
    resources[resourceID] = resources[resourceID] - amount
    if resources[resourceID] <= 0 then resources[resourceID] = nil end
    PlayerResources[steamID] = resources
    net.Start("SyncResources")
    net.WriteTable(resources)
    net.Send(ply)
    SavePlayerResources(ply)
    SendResourcesMessageDropped(ply, resourceID, amount)
    DebugPrint("[Resources Module] " .. ply:Nick() .. " dropped " .. amount .. " " .. ResourceItems[resourceID].name)

    enforceResourceEntityCap()

    -- Spawn a single pickupable resource entity for all resource types (paradise_resource)
    local spawnPos = ply:GetEyeTrace().HitPos + Vector(0, 0, 10)
    local ent = ents.Create("paradise_resource")
    if IsValid(ent) then
        ent:SetModel(ResourceItems[resourceID].model or "models/props_junk/rock001a.mdl")
        ent:SetPos(spawnPos)
        ent:Spawn()
        ent:Activate()
        ent:SetNWString("ResourceType", resourceID)
        ent:SetNWInt("Amount", amount)
        local app = Paradise.ResourceAppearances[resourceID] or {}
        if app.material and app.material ~= "" then ent:SetMaterial(app.material) end
        if app.color then ent:SetColor(app.color) end
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(ply:GetAimVector() * 100)
        end
        table.insert(ResourceDropEntities, ent)
    end
end)

-- Hooks for player connection/disconnection
hook.Add("PlayerInitialSpawn", "Resources_InitResources", LoadPlayerResources)
hook.Add("PlayerDisconnected", "SaveResourcesOnDisconnect", SavePlayerResources)

-- Console commands
concommand.Add("addresource", function(ply, _, args)
    if not ply:IsSuperAdmin() then 
        SendResourcesMessage(ply, "Superadmin only.")
        return 
    end
    AddResourceToInventory(ply, args[1], tonumber(args[2]) or 1)
end)


-- This print will always show to confirm successful load
-- Admin: give resources to a player. Usage: inv_giveresource <steamid> <resource_id> <amount>
concommand.Add("inv_giveresource", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local steamid = tostring(args[1] or "")
    local resourceID = tostring(args[2] or "")
    local amount = tonumber(args[3] or 1) or 1
    if steamid == "" or resourceID == "" then ply:ChatPrint("Usage: inv_giveresource <steamid> <resource_id> <amount>") return end
    if not ResourceItems[resourceID] then ply:ChatPrint("Unknown resource: " .. resourceID) return end
    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == steamid then target = p break end
    end
    if not IsValid(target) then ply:ChatPrint("Player not found (must be online)") return end
    AddResourceToInventory(target, resourceID, amount, true)
    local resName = ResourceItems[resourceID].name
    -- Target sees "Admin X gave you Nx Resource" only (no [INV] prefix to match your system)
    local targetMsg = string.format("Admin %s gave you %dx %s", ply:Nick(), amount, resName)
    if IsValid(target) then
        net.Start("INV_ParadiseChat")
        net.WriteString(targetMsg)
        net.Send(target)
    end
    for _, p in ipairs(player.GetAll()) do
        if not IsValid(p) or p == target then continue end
        if p:IsAdmin() then
            net.Start("INV_ParadiseChat")
            net.WriteString(string.format("Gave %dx %s to %s", amount, resName, target:Nick()))
            net.Send(p)
        end
    end
end)

print("[Resources Module] Loaded successfully (Server).")