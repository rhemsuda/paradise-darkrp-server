-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Props Module] sv_props.lua is loading...")

if not SERVER then return end

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Network strings
util.AddNetworkString("SpawnProp")
util.AddNetworkString("PropSpawnNotification")
util.AddNetworkString("ToggleBuyMode")
util.AddNetworkString("SyncBuyMode")

-- Include sh_items.lua to access InventoryItems
if file.Exists("modules/inventory/sh_items.lua", "LUA") then
    include("modules/inventory/sh_items.lua")
end

-- List of prop itemIDs (in order, to match client-side PropList)
local PropItemIDs = {
    "weapon_stripper",
    "slotted_door",
    "metal_plate_1x1",
    "metal_plate_1x2",
    "metal_plate_2x2",
    "metal_plate_2x4",
    "metal_plate_4x4",
    "metal_tube",
    "metal_tube_2x",
    "i_beam_2x8",
    "i_beam_2x16",
    "i_beam_2x32",
    "billboard",
    "wooden_shelves",
    "gear_60t1",
    "blast_door_c",
    "blast_door_b",
    "storefront_bars",
    "interior_fence_002d",
    "fence_03a",
    "interior_fence_001g",
    "concrete_barrier",
    "vending_machine",
    "kitchen_fridge",
    "covered_bridge_bottom"
}

-- Function to get the prop list (can be called by client if needed)
function GetPropList()
    local propList = {}
    for _, itemID in ipairs(PropItemIDs) do
        if InventoryItems[itemID] then
            table.insert(propList, InventoryItems[itemID])
        end
    end
    return propList
end

-- Store player buy modes (true = Buy, false = Craft)
local PlayerBuyModes = {}

-- Handle prop spawning request
net.Receive("SpawnProp", function(len, ply)
    -- Validate the prop index
    local propIndex = net.ReadUInt(8)
    DebugPrint("[Props Module] Received SpawnProp request from " .. ply:Nick() .. " with index: " .. propIndex)
    local itemID = PropItemIDs[propIndex]
    local prop = InventoryItems[itemID]
    if not prop then
        DebugPrint("[Props Module] Invalid prop index " .. tostring(propIndex) .. " (itemID: " .. tostring(itemID) .. ") requested by " .. ply:Nick())
        net.Start("PropSpawnNotification")
        net.WriteString("Failed to spawn prop: Invalid prop index!")
        net.Send(ply)
        return
    end

    -- Determine buy mode for the player (default to Craft if not set)
    local buyMode = PlayerBuyModes[ply:SteamID()] or false

    if buyMode then
        -- Buy mode: Check and deduct DarkRP money
        local price = prop.price or 0
        if not ply:canAfford(price) then
            net.Start("PropSpawnNotification")
            net.WriteString("Nope, you're broke!")
            net.Send(ply)
            DebugPrint("[Props Module] " .. ply:Nick() .. " lacks money to buy " .. prop.name)
            return
        end

        -- Deduct money
        ply:addMoney(-price)
        DebugPrint("[Props Module] Deducted $" .. price .. " from " .. ply:Nick() .. " for buying " .. prop.name)
    else
        -- Craft mode: Check and deduct resources
        local steamID = ply:SteamID()
        local playerResources = {}
        
        -- Fetch player's resources from the database
        MySQLite.query("SELECT resources FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
            -- Define default resources
            local defaultResources = { rock = 0, copper = 0, iron = 0, steel = 0 }
            
            -- Parse database resources, or use an empty table if nil
            local dbResources = (data and data[1] and data[1].resources) and util.JSONToTable(data[1].resources) or {}
            
            -- Merge database resources with defaults to ensure all keys exist
            playerResources = table.Merge(defaultResources, dbResources)

            -- Check if player has sufficient resources
            local canAfford = true
            for resource, cost in pairs(prop.resources) do
                if (playerResources[resource] or 0) < cost then
                    canAfford = false
                    break
                end
            end

            if not canAfford then
                net.Start("PropSpawnNotification")
                net.WriteString("Insufficient resources to craft " .. prop.name .. "!")
                net.Send(ply)
                DebugPrint("[Props Module] " .. ply:Nick() .. " lacks resources to craft " .. prop.name)
                return
            end

            -- Deduct resources
            for resource, cost in pairs(prop.resources) do
                playerResources[resource] = playerResources[resource] - cost
            end

            -- Save updated resources back to the database
            MySQLite.query("UPDATE darkrp_custom_inventory SET resources = " .. MySQLite.SQLStr(util.TableToJSON(playerResources)) .. " WHERE steamid = " .. MySQLite.SQLStr(steamID), function()
                -- Sync updated resources to the client
                net.Start("SyncResources")
                net.WriteTable(playerResources)
                net.Send(ply)
                DebugPrint("[Props Module] Updated resources for " .. ply:Nick() .. ": " .. util.TableToJSON(playerResources))

                -- Proceed with spawning the prop
                SpawnPropEntity(ply, prop)
            end, function(err)
                DebugPrint("[Props Module] Error saving resources for " .. ply:Nick() .. ": " .. err)
                net.Start("PropSpawnNotification")
                net.WriteString("Failed to craft " .. prop.name .. ": Database error!")
                net.Send(ply)
            end)
        end, function(err)
            DebugPrint("[Props Module] Error fetching resources for " .. ply:Nick() .. ": " .. err)
            net.Start("PropSpawnNotification")
            net.WriteString("Failed to craft " .. prop.name .. ": Database error!")
            net.Send(ply)
        end)

        -- Return early since the database query is asynchronous
        if not buyMode then return end
    end

    -- If in Buy mode, proceed with spawning immediately after deducting money
    SpawnPropEntity(ply, prop)
end)

-- Function to spawn the prop entity (called after cost checks)
function SpawnPropEntity(ply, prop)
    -- Spawn the prop as a standard prop_physics
    local ent = ents.Create("prop_physics")
    if not IsValid(ent) then
        DebugPrint("[Props Module] Failed to create prop " .. prop.name .. " for " .. ply:Nick() .. " (invalid entity)")
        net.Start("PropSpawnNotification")
        net.WriteString("Failed to spawn " .. prop.name .. ": Invalid prop entity!")
        net.Send(ply)
        return
    end

    -- Set up the prop
    ent:SetModel(prop.model)
    if not ent:GetModel() then
        DebugPrint("[Props Module] Failed to set model for prop " .. prop.name .. " (" .. prop.model .. ") for " .. ply:Nick())
        ent:Remove()
        net.Start("PropSpawnNotification")
        net.WriteString("Failed to spawn " .. prop.name .. ": Invalid model!")
        net.Send(ply)
        return
    end
    ent:SetPos(ply:EyePos() + ply:GetForward() * 50)
    ent:Spawn()

    -- Ensure the prop has physics
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    else
        DebugPrint("[Props Module] Failed to initialize physics for prop " .. prop.name .. " for " .. ply:Nick())
        ent:Remove()
        net.Start("PropSpawnNotification")
        net.WriteString("Failed to spawn " .. prop.name .. ": No physics object!")
        net.Send(ply)
        return
    end

    -- Set ownership for remover tool and undo system
    if CPPI then
        ent:CPPISetOwner(ply) -- Use CPPI if available (common in DarkRP)
    else
        ent:SetNWEntity("Owner", ply) -- Fallback for non-CPPI servers
    end

    -- Add to the undo system
    undo.Create("Prop")
    undo.AddEntity(ent)
    undo.SetPlayer(ply)
    undo.Finish()

    -- Set health for the prop
    ent:SetNWInt("PropHealth", prop.health)
    ent:SetNWInt("PropMaxHealth", prop.health)

    -- Send spawn confirmation as a tooltip notification
    net.Start("PropSpawnNotification")
    net.WriteString("You have spawned " .. prop.name)
    net.Send(ply)
    DebugPrint("[Props Module] " .. ply:Nick() .. " spawned prop " .. prop.name .. " with " .. prop.health .. " HP")
end

-- Handle buy mode toggle
net.Receive("ToggleBuyMode", function(len, ply)
    local steamID = ply:SteamID()
    local currentMode = PlayerBuyModes[steamID] or false
    PlayerBuyModes[steamID] = not currentMode
    net.Start("SyncBuyMode")
    net.WriteBool(PlayerBuyModes[steamID])
    net.Send(ply)
    DebugPrint("[Props Module] " .. ply:Nick() .. " toggled buy mode to " .. (PlayerBuyModes[steamID] and "Buy" or "Craft"))
end)

-- Sync buy mode on player spawn
hook.Add("PlayerInitialSpawn", "SyncPropBuyMode", function(ply)
    local steamID = ply:SteamID()
    if PlayerBuyModes[steamID] == nil then
        PlayerBuyModes[steamID] = false -- Default to Craft mode
    end
    net.Start("SyncBuyMode")
    net.WriteBool(PlayerBuyModes[steamID])
    net.Send(ply)
end)

-- Clean up buy mode on disconnect
hook.Add("PlayerDisconnected", "CleanupPropBuyMode", function(ply)
    PlayerBuyModes[ply:SteamID()] = nil
end)

-- Handle damage to props
hook.Add("EntityTakeDamage", "PropHealthSystem", function(target, dmginfo)
    -- Check if the target is a prop with health
    if target:GetClass() ~= "prop_physics" or not target:GetNWInt("PropHealth") then return end

    -- Apply damage
    local currentHealth = target:GetNWInt("PropHealth", 0)
    local damage = dmginfo:GetDamage()
    currentHealth = math.max(0, currentHealth - damage)
    target:SetNWInt("PropHealth", currentHealth)

    -- Log damage
    DebugPrint("[Props Module] Prop " .. target:GetModel() .. " took " .. damage .. " damage, health now: " .. currentHealth)

    -- Destroy prop if health reaches 0
    if currentHealth <= 0 then
        local effectData = EffectData()
        effectData:SetOrigin(target:GetPos())
        effectData:SetMagnitude(1)
        effectData:SetScale(1)
        effectData:SetRadius(1)
        util.Effect("Explosion", effectData)

        target:Remove()
        DebugPrint("[Props Module] Prop " .. target:GetModel() .. " destroyed and removed")
    end
end)

-- This print will always show to confirm successful load
print("[Props Module] Loaded successfully (Server).")