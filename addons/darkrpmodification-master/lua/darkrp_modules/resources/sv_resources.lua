-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Resources Module] sv_resources.lua is loading...")

if not SERVER then return end

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Initialize network strings
util.AddNetworkString("SyncResources")
util.AddNetworkString("DropResource")
util.AddNetworkString("ResourcesMessage")

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
    --[[ Commented out lumber section for later development
    lumber = {
        { id = "ash", name = "Ash", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "birch", name = "Birch", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "oak", name = "Oak", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "mahogany", name = "Mahogany", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "yew", name = "Yew", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" }
    }
    ]]
}
for _, category in pairs(resourceTemplates) do
    for _, data in ipairs(category) do
        ResourceItems[data.id] = { name = data.name, icon = data.icon, model = data.model }
    end
end

-- Player Resources Table (moved from PlayerInventories.resources)
PlayerResources = PlayerResources or {}

-- Function to send resource-related messages to the player
local function SendResourcesMessage(ply, message)
    if not IsValid(ply) then return end
    net.Start("ResourcesMessage")
    net.WriteString(message)
    net.Send(ply)
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
        SendResourcesMessage(ply, "Mined a " .. ResourceItems[resourceID].name)
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

-- Handle dropping resources
net.Receive("DropResource", function(len, ply)
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
    SendResourcesMessage(ply, "Dropped " .. amount .. " " .. ResourceItems[resourceID].name .. ".")
    DebugPrint("[Resources Module] " .. ply:Nick() .. " dropped " .. amount .. " " .. ResourceItems[resourceID].name)

    local ent = ents.Create("prop_physics")
    if IsValid(ent) then
        ent:SetModel(ResourceItems[resourceID].model or "models/props_junk/rock001a.mdl")
        ent:SetPos(ply:GetEyeTrace().HitPos + Vector(0, 0, 10))
        ent:Spawn()
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(ply:GetAimVector() * 100)
        end
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

concommand.Add("open_resources", function(ply)
    if not IsValid(ply) then return end
    net.Start("SyncResources")
    net.WriteTable(PlayerResources[ply:SteamID()] or {})
    net.Send(ply)
end)

-- This print will always show to confirm successful load
print("[Resources Module] Loaded successfully (Server).")