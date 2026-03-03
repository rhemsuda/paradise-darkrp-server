-- sh_inventory.lua  (shared core)
-- Safe to be loaded in any order.

Inventory = Inventory or {}
Inventory.Version = "v2-one"
Inventory.Items = Inventory.Items or {}

Inventory.Config = {
    GRID_W = 10,
    GRID_H = 6,
    SLOT  = 64,
    PAD   = 6,
    MAX_PAGES = 5
}

-- Rarity framework (weapons only for now; utilities/others may omit)
-- Order: Common < Rare < Unique < Epic < Legendary
Inventory.Rarities = { "Common", "Rare", "Unique", "Epic", "Legendary" }
Inventory.RarityColors = {
    Common    = Color(154,160,166),   -- #9aa0a6
    Rare      = Color(78,161,255),    -- #4ea1ff
    Epic      = Color(181,108,255),   -- #b56cff
    Legendary = Color(255,179,0),     -- #ffb300
    Unique    = Color(0,212,170),     -- #00d4aa
}
function Inventory.GetRarityColor(r)
    return (r and Inventory.RarityColors[r]) or nil
end

-- Damage multipliers per rarity (applied to baseDamage)
-- Order: Common < Rare < Unique < Epic < Legendary (Legendary = top)
Inventory.RarityDamageMul = {
    Common    = 1.00,
    Rare      = 1.25,
    Unique    = 1.40,  -- just above Rare
    Epic      = 1.65,  -- second most rare
    Legendary = 1.90,  -- most rare, highest damage
}
function Inventory.GetRarityDamageMultiplier(r)
    return (r and Inventory.RarityDamageMul[r]) or 1.0
end

-- Equip slot ids
Inventory.Slots = {
    PRIMARY = "primary",
    SIDEARM = "sidearm",
    ARMOR   = "armor",
    BOOTS   = "boots",
    UTILITY = "utility"
}

-- Register items (shared)
function Inventory.RegisterItem(id, data)
    if not id or id == "" then return end
    data = data or {}
    data.id = id
    Inventory.Items[id] = data
end

-- Minimal safe item table for clients (no server-only fields)
function Inventory.SafeItems()
    local out = {}
    for k, v in pairs(Inventory.Items) do
        out[k] = {
            id = k,
            name = v.name or k,
            desc = v.desc or "",
            icon = v.icon or "",
            category = v.category or "Misc",
            class = v.class,      -- SWEP/Entity class if any
            model = v.model or "",
            rarity = v.rarity or "",
            baseDamage = tonumber(v.baseDamage or 0) or 0,
            sidearm = v.sidearm and true or nil,  -- true = equip to sidearm slot (rare crafting option)
        }
    end
    return out
end

-- Net string names (kept in one place)
Inventory.NET = {
    RequestFull   = "INV_RequestFull",
    SyncInventory = "INV_SyncInventory",
    SyncLoadout   = "INV_SyncLoadout",
    -- Note: resource pouch sync is handled by sv_resources.lua ("SyncResources"), not here.
    ItemAction    = "INV_ItemAction",
    MoveItem      = "INV_MoveItem",
    DeleteItems   = "INV_DeleteItems",
    DeleteByUIDs  = "INV_DeleteByUIDs",
    RequestLoadout= "INV_RequestLoadout",
    Notify        = "INV_Notify",
    NotifyItem    = "INV_NotifyItem",  -- "You dropped a X" / "Picked up a X" with item name (client shows name in highlight color)
    AdminCreateItem = "INV_AdminCreateItem",
    AdminModifyItem = "INV_AdminModifyItem",
    AdminDeleteInstance = "INV_AdminDeleteInstance",
    AdminRequestPlayerInv = "INV_AdminRequestPlayerInv",
    AdminSendPlayerInv = "INV_AdminSendPlayerInv",
    AdminCreateItemFor = "INV_AdminCreateItemFor",
    ParadiseChat       = "INV_ParadiseChat",  -- unified styled chat (gray [Paradise] + message)
}

if SERVER then
    util.AddNetworkString(Inventory.NET.RequestFull)
    util.AddNetworkString(Inventory.NET.SyncInventory)
    util.AddNetworkString(Inventory.NET.SyncLoadout)
    util.AddNetworkString(Inventory.NET.ItemAction)
    util.AddNetworkString(Inventory.NET.MoveItem)
    util.AddNetworkString(Inventory.NET.DeleteItems)
    util.AddNetworkString(Inventory.NET.DeleteByUIDs)
    util.AddNetworkString(Inventory.NET.RequestLoadout)
    util.AddNetworkString(Inventory.NET.Notify)
    util.AddNetworkString(Inventory.NET.NotifyItem)
    util.AddNetworkString(Inventory.NET.AdminCreateItem)
    util.AddNetworkString(Inventory.NET.AdminModifyItem)
    util.AddNetworkString(Inventory.NET.AdminDeleteInstance)
    util.AddNetworkString(Inventory.NET.AdminRequestPlayerInv)
    util.AddNetworkString(Inventory.NET.AdminSendPlayerInv)
    util.AddNetworkString(Inventory.NET.AdminCreateItemFor)
    util.AddNetworkString(Inventory.NET.ParadiseChat)
end

