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
util.AddNetworkString("PropSpawnNotification") -- New network string for tooltip notification

-- Table of props with their models, names, resource costs, and health
local PropList = {
    { model = "models/props_c17/oildrum001.mdl", name = "Oil Drum", resources = { wood = 0, metal = 0, stone = 0 }, health = 100 },
    { model = "models/props_junk/wood_crate001a.mdl", name = "Wooden Crate", resources = { wood = 0, metal = 0, stone = 0 }, health = 100 },
    { model = "models/props_junk/metal_paintcan001a.mdl", name = "Paint Can", resources = { wood = 0, metal = 0, stone = 0 }, health = 100 },
    { model = "models/props_c17/chair02a.mdl", name = "Chair", resources = { wood = 0, metal = 0, stone = 0 }, health = 100 },
    { model = "models/props_wasteland/controlroom_desk001b.mdl", name = "Desk", resources = { wood = 0, metal = 0, stone = 0 }, health = 100 },
}

-- Function to get the prop list (can be called by client if needed)
function GetPropList()
    return PropList
end

-- Handle prop spawning request
net.Receive("SpawnProp", function(len, ply)
    -- Validate the prop index
    local propIndex = net.ReadUInt(8)
    local prop = PropList[propIndex]
    if not prop then
        DebugPrint("[Props Module] Invalid prop index " .. tostring(propIndex) .. " requested by " .. ply:Nick())
        return
    end

    -- Check if player has sufficient resources
    local playerResources = PlayerResources[ply:SteamID()] or { wood = 0, metal = 0, stone = 0 }
    local canAfford = true
    for resource, cost in pairs(prop.resources) do
        if (playerResources[resource] or 0) < cost then
            canAfford = false
            break
        end
    end

    if not canAfford then
        net.Start("InventoryMessage")
        net.WriteString("Insufficient resources to spawn " .. prop.name .. "!")
        net.Send(ply)
        DebugPrint("[Props Module] " .. ply:Nick() .. " lacks resources to spawn " .. prop.name)
        return
    end

    -- Deduct resources
    for resource, cost in pairs(prop.resources) do
        playerResources[resource] = playerResources[resource] - cost
    end
    PlayerResources[ply:SteamID()] = playerResources
    SavePlayerResources(ply)

    -- Sync updated resources to the client
    net.Start("SyncResources")
    net.WriteTable(playerResources)
    net.Send(ply)

    -- Spawn the prop as a standard prop_physics
    local ent = ents.Create("prop_physics")
    if not IsValid(ent) then
        DebugPrint("[Props Module] Failed to create prop " .. prop.name .. " for " .. ply:Nick())
        return
    end

    -- Set up the prop
    ent:SetModel(prop.model)
    ent:SetPos(ply:EyePos() + ply:GetForward() * 50)
    ent:Spawn()

    -- Ensure the prop has physics
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
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