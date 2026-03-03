--[[---------------------------------------------------------------------------
  Paradise Crafting — Server. Staged resources per player, Add Resources / Craft / Close.
---------------------------------------------------------------------------]]
if not SERVER then return end

if Crafting and Crafting.BuildRecipes then Crafting.BuildRecipes() end

util.AddNetworkString("Crafter_StagedUpdate")
util.AddNetworkString("Crafter_CraftResult")
util.AddNetworkString("Crafter_Open")
util.AddNetworkString("Crafter_Close")
util.AddNetworkString("Crafter_AddResources")
util.AddNetworkString("Crafter_Craft")
util.AddNetworkString("Crafter_SetBlueprint")

-- Staged resources when player has a blueprint in the crafting square. On menu close we return these to pouch.
local CrafterStaged = {}

local function getStaged(ply)
    if not IsValid(ply) then return nil end
    local sid = ply:SteamID()
    if not CrafterStaged[sid] then CrafterStaged[sid] = { blueprintId = "", resources = {} } end
    return CrafterStaged[sid]
end

local function sendStagedUpdate(ply)
    local st = getStaged(ply)
    if not st then return end
    net.Start("Crafter_StagedUpdate")
    net.WriteString(st.blueprintId or "")
    net.WriteTable(st.resources or {})
    net.Send(ply)
end

net.Receive("Crafter_Open", function(len, ply)
    if not IsValid(ply) then return end
    sendStagedUpdate(ply)
end)

net.Receive("Crafter_Close", function(len, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    local st = CrafterStaged[sid]
    if st and st.resources and next(st.resources) then
        if ReturnResourcesToPouch then ReturnResourcesToPouch(ply, st.resources) end
    end
    CrafterStaged[sid] = { blueprintId = "", resources = {} }
    sendStagedUpdate(ply)
end)

-- When client puts a blueprint in the zone or clears it, reset staged resources so Fill must be pressed again for the new blueprint
net.Receive("Crafter_SetBlueprint", function(len, ply)
    if not IsValid(ply) then return end
    local blueprintId = net.ReadString() or ""
    local st = getStaged(ply)
    if (st.blueprintId or "") == blueprintId then return end
    if st.resources and next(st.resources) and ReturnResourcesToPouch then
        ReturnResourcesToPouch(ply, st.resources)
    end
    st.blueprintId = blueprintId
    st.resources = {}
    sendStagedUpdate(ply)
end)

net.Receive("Crafter_AddResources", function(len, ply)
    if not IsValid(ply) or IsPlayerGhost and IsPlayerGhost(ply) then return end
    local blueprintId = net.ReadString() or ""
    local recipe = Crafting and Crafting.GetRecipe and Crafting.GetRecipe(blueprintId) or {}
    if not next(recipe) then sendStagedUpdate(ply) return end

    local st = getStaged(ply)
    if (st.blueprintId or "") ~= blueprintId then
        if st.resources and next(st.resources) and ReturnResourcesToPouch then
            ReturnResourcesToPouch(ply, st.resources)
        end
        st.blueprintId = blueprintId
        st.resources = {}
    end

    -- How much more we need per resource (recipe - already staged)
    local toTake = {}
    for resId, need in pairs(recipe) do
        local have = st.resources[resId] or 0
        local missing = math.max(0, (need or 0) - have)
        if missing > 0 then toTake[resId] = missing end
    end

    -- Limit by what player has in pouch
    if not PlayerResources then sendStagedUpdate(ply) return end
    local pouch = PlayerResources[ply:SteamID()] or {}
    for resId, want in pairs(toTake) do
        local have = pouch[resId] or 0
        toTake[resId] = math.min(want, have)
        if toTake[resId] <= 0 then toTake[resId] = nil end
    end

    if not next(toTake) then sendStagedUpdate(ply) return end
    if not TakeResourcesFromPouch(ply, toTake) then sendStagedUpdate(ply) return end

    for resId, amount in pairs(toTake) do
        st.resources[resId] = (st.resources[resId] or 0) + amount
    end
    sendStagedUpdate(ply)
end)

net.Receive("Crafter_Craft", function(len, ply)
    if not IsValid(ply) or IsPlayerGhost and IsPlayerGhost(ply) then return end
    local blueprintId = net.ReadString() or ""
    local blueprintUID = net.ReadString() or ""
    local recipe = Crafting and Crafting.GetRecipe and Crafting.GetRecipe(blueprintId) or {}
    local resultId = Crafting and Crafting.GetResultItemId and Crafting.GetResultItemId(blueprintId)

    if not resultId or not next(recipe) then
        net.Start("Crafter_CraftResult")
        net.WriteBool(false)
        net.WriteString("Invalid blueprint.")
        net.Send(ply)
        return
    end

    local st = getStaged(ply)
    if (st.blueprintId or "") ~= blueprintId then
        net.Start("Crafter_CraftResult")
        net.WriteBool(false)
        net.WriteString("Blueprint not in crafting slot.")
        net.Send(ply)
        return
    end

    for resId, need in pairs(recipe) do
        if (st.resources[resId] or 0) < (need or 0) then
            net.Start("Crafter_CraftResult")
            net.WriteBool(false)
            net.WriteString("Not enough resources.")
            net.Send(ply)
            return
        end
    end

    if not Inventory.RemoveOneItemByUID(ply, blueprintUID) then
        net.Start("Crafter_CraftResult")
        net.WriteBool(false)
        net.WriteString("Blueprint not found in inventory.")
        net.Send(ply)
        return
    end

    -- Consume staged resources
    local sid = ply:SteamID()
    for resId, need in pairs(recipe) do
        st.resources[resId] = (st.resources[resId] or 0) - need
        if st.resources[resId] <= 0 then st.resources[resId] = nil end
    end
    if not next(st.resources) then st.resources = {} end
    -- Keep st.blueprintId so stacked blueprints can craft again; cleared on Crafter_SetBlueprint("") or Close

    local def = Inventory.Items[resultId]
    if not def then
        net.Start("Crafter_CraftResult")
        net.WriteBool(false)
        net.WriteString("Unknown result item.")
        net.Send(ply)
        return
    end

    -- Roll rarity: Common < Rare < Unique < Epic < Legendary (Epic 2nd most rare, Legendary rarest)
    local rarities = Inventory.Rarities or { "Common", "Rare", "Unique", "Epic", "Legendary" }
    local weights = { 55, 26, 10, 6, 3 }
    local roll = math.random(1, 100)
    local rarity = rarities[1] or "Common"
    local acc = 0
    for i = 1, math.min(#rarities, #weights) do
        acc = acc + (weights[i] or 0)
        if roll <= acc then rarity = rarities[i] break end
    end

    -- Roll baseDamage within weapon range (each craft = unique weapon, tradeable later)
    local dmgMin = def.damageMin or (def.baseDamage or 15) - 2
    local dmgMax = def.damageMax or (def.baseDamage or 15) + 2
    local rolledDamage = math.Clamp(math.random(dmgMin, dmgMax), 1, 255)

    local crafterName = ply:Nick()
    if not Inventory.GiveItemToPlayer(ply, resultId, 1, { crafter = crafterName, rarity = rarity, baseDamage = rolledDamage, slots = 0 }) then
        net.Start("Crafter_CraftResult")
        net.WriteBool(false)
        net.WriteString("Could not add item to inventory.")
        net.Send(ply)
        return
    end

    net.Start("Crafter_CraftResult")
    net.WriteBool(true)
    net.WriteString(resultId)
    net.WriteString(def.name or resultId)
    net.WriteString(rarity)
    net.WriteString(def.model or "")
    net.WriteUInt(rolledDamage, 16)
    net.WriteUInt(0, 4) -- slots
    net.WriteString(crafterName)
    net.Send(ply)
    -- Send staged update so client sees resources = 0 after craft
    sendStagedUpdate(ply)
end)

hook.Add("PlayerDisconnected", "Crafter_ReturnStaged", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    local st = CrafterStaged[sid]
    if st and st.resources and next(st.resources) and ReturnResourcesToPouch then
        ReturnResourcesToPouch(ply, st.resources)
    end
    CrafterStaged[sid] = nil
end)
