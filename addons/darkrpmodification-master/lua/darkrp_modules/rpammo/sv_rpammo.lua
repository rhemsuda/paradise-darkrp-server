-- Debug print to confirm the file is loading
print("[RPAammo] sv_rpammo.lua loaded successfully")

-- Helper function to print debug messages conditionally (copied from sv_inventory.lua for consistency)
local function DebugPrint(...)
    if GetConVar("rp_debug") and GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Add network string for sending notifications to the client
util.AddNetworkString("RPAammoNotification")

-- Function to send a notification to the client
local function SendRPAammoMessage(ply, message)
    if not IsValid(ply) then return end
    net.Start("RPAammoNotification")
    net.WriteString(message)
    net.Send(ply)
end

-- Ammo type mapping for known incorrect or placeholder ammo types
local AmmoTypeMapping = {
    ["#SniperRound_ammo"] = "357", -- Fallback mapping, may not be needed with dynamic detection
    -- Add more mappings as needed for other weapons
}

-- Console command to buy ammo
concommand.Add("rp_buyammo", function(ply)
    if not IsValid(ply) then return end

    -- Check if the player has a loadout
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID]
    if not inv or not inv.loadout then
        SendRPAammoMessage(ply, "You don't have any equipped weapons to buy ammo for!")
        DebugPrint("[RPAammo] " .. ply:Nick() .. " tried to buy ammo but has no loadout.")
        return
    end

    -- Track if any weapons were found
    local weaponsFound = false
    local weaponsProcessed = {}

    -- Iterate through the loadout
    for slot, item in pairs(inv.loadout) do
        if item and InventoryItems[item.itemID] and InventoryItems[item.itemID].category == "Weapons" then
            weaponsFound = true
            local itemData = InventoryItems[item.itemID]
            local weaponClass = itemData.entityClass or item.itemID
            DebugPrint("[RPAammo] Processing weapon: " .. weaponClass .. " in slot: " .. slot)

            -- Check if the player has the weapon in their inventory
            local weapon = ply:GetWeapon(weaponClass)
            local ammoType
            if IsValid(weapon) then
                -- Dynamically get the weapon's actual ammo type
                local ammoTypeID = weapon:GetPrimaryAmmoType()
                ammoType = game.GetAmmoName(ammoTypeID)
                DebugPrint("[RPAammo] Weapon " .. weaponClass .. " has ammo type: " .. (ammoType or "none") .. " (ID: " .. ammoTypeID .. ")")
            else
                -- Fallback to the ammo type defined in InventoryItems
                ammoType = itemData.ammoType
                DebugPrint("[RPAammo] Weapon " .. weaponClass .. " not found on player, using InventoryItems ammo type: " .. (ammoType or "none"))
            end

            if not ammoType then
                DebugPrint("[RPAammo] No ammo type defined for " .. weaponClass .. ".")
                SendRPAammoMessage(ply, "Error: No ammo type defined for " .. itemData.name .. ".")
                continue
            end

            -- Check if the ammo type needs mapping
            local correctedAmmoType = AmmoTypeMapping[ammoType] or ammoType
            if AmmoTypeMapping[ammoType] then
                DebugPrint("[RPAammo] Mapped ammo type '" .. ammoType .. "' to '" .. correctedAmmoType .. "' for " .. weaponClass)
            end

            -- Validate the ammo type
            if not game.GetAmmoID(correctedAmmoType) or game.GetAmmoID(correctedAmmoType) == -1 then
                DebugPrint("[RPAammo] Invalid ammo type '" .. correctedAmmoType .. "' for " .. weaponClass .. ".")
                SendRPAammoMessage(ply, "Error: Invalid ammo type for " .. itemData.name .. " (" .. correctedAmmoType .. ").")
                continue
            end

            -- Add 300 ammo to the player's reserve for this ammo type
            local ammoBefore = ply:GetAmmoCount(correctedAmmoType)
            ply:GiveAmmo(300, correctedAmmoType, false)
            local ammoAfter = ply:GetAmmoCount(correctedAmmoType)
            DebugPrint("[RPAammo] Added 300 " .. correctedAmmoType .. " ammo for " .. weaponClass .. " to " .. ply:Nick() .. ". Ammo before: " .. ammoBefore .. ", after: " .. ammoAfter)
            table.insert(weaponsProcessed, itemData.name)
        end
    end

    -- Notify the player of the result
    if not weaponsFound then
        SendRPAammoMessage(ply, "You don't have any equipped weapons to buy ammo for!")
        DebugPrint("[RPAammo] " .. ply:Nick() .. " tried to buy ammo but has no equipped weapons.")
    else
        local message = "Bought 300 ammo for: " .. table.concat(weaponsProcessed, ", ") .. "."
        SendRPAammoMessage(ply, message)
        DebugPrint("[RPAammo] " .. ply:Nick() .. " bought ammo for: " .. table.concat(weaponsProcessed, ", "))
    end
end)

-- This print will always show to confirm successful load
print("[RPAammo] Server-side loaded successfully.")