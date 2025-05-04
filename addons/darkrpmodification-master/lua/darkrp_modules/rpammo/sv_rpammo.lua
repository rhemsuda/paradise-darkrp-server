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

-- Table to track the last time each player used the command
local playerCooldowns = {}

-- Console command to buy ammo
concommand.Add("rp_buyammo", function(ply)
    if not IsValid(ply) then return end

    -- Check cooldown
    local steamID = ply:SteamID()
    local currentTime = CurTime()
    if playerCooldowns[steamID] and (currentTime - playerCooldowns[steamID]) < 3 then
        return -- Silently ignore if within cooldown
    end

    -- Check if the player has enough money (100 DarkRP currency)
    if not ply:canAfford(100) then
        SendRPAammoMessage(ply, "You need 100 currency to buy ammo!")
        DebugPrint("[RPAammo] " .. ply:Nick() .. " tried to buy ammo but lacks funds.")
        return
    end

    -- Track if any weapons were found
    local weaponsFound = false

    -- Get all weapons the player currently has equipped
    local weapons = ply:GetWeapons()
    if not weapons or #weapons == 0 then
        SendRPAammoMessage(ply, "You don't have any equipped weapons to buy ammo for!")
        DebugPrint("[RPAammo] " .. ply:Nick() .. " tried to buy ammo but has no equipped weapons.")
        return
    end

    -- Process each equipped weapon
    for _, weapon in ipairs(weapons) do
        if not IsValid(weapon) then continue end

        local weaponClass = weapon:GetClass()
        DebugPrint("[RPAammo] Processing equipped weapon: " .. weaponClass)

        -- Dynamically get the weapon's actual ammo type
        local ammoTypeID = weapon:GetPrimaryAmmoType()
        if ammoTypeID == -1 then
            DebugPrint("[RPAammo] Weapon " .. weaponClass .. " has no ammo type (melee?). Skipping.")
            continue
        end

        local ammoType = game.GetAmmoName(ammoTypeID)
        if not ammoType then
            DebugPrint("[RPAammo] Weapon " .. weaponClass .. " has an invalid ammo type ID: " .. ammoTypeID)
            continue
        end
        DebugPrint("[RPAammo] Weapon " .. weaponClass .. " has ammo type: " .. ammoType .. " (ID: " .. ammoTypeID .. ")")

        -- Check if the ammo type needs mapping
        local correctedAmmoType = AmmoTypeMapping[ammoType] or ammoType
        if AmmoTypeMapping[ammoType] then
            DebugPrint("[RPAammo] Mapped ammo type '" .. ammoType .. "' to '" .. correctedAmmoType .. "' for " .. weaponClass)
        end

        -- Validate the ammo type
        if not game.GetAmmoID(correctedAmmoType) or game.GetAmmoID(correctedAmmoType) == -1 then
            DebugPrint("[RPAammo] Invalid ammo type '" .. correctedAmmoType .. "' for " .. weaponClass .. ".")
            continue
        end

        -- Add 300 ammo to the player's reserve for this ammo type
        local ammoBefore = ply:GetAmmoCount(correctedAmmoType)
        ply:GiveAmmo(300, correctedAmmoType, false)
        local ammoAfter = ply:GetAmmoCount(correctedAmmoType)
        DebugPrint("[RPAammo] Added 300 " .. correctedAmmoType .. " ammo for " .. weaponClass .. " to " .. ply:Nick() .. ". Ammo before: " .. ammoBefore .. ", after: " .. ammoAfter)
        weaponsFound = true
    end

    -- Notify the player of the result
    if not weaponsFound then
        SendRPAammoMessage(ply, "You don't have any equipped weapons that require ammo!")
        DebugPrint("[RPAammo] " .. ply:Nick() .. " tried to buy ammo but has no ammo-requiring weapons.")
    else
        -- Deduct 100 DarkRP currency
        ply:addMoney(-100)
        DebugPrint("[RPAammo] Deducted 100 currency from " .. ply:Nick() .. " for buying ammo.")

        -- Set cooldown
        playerCooldowns[steamID] = currentTime

        -- Send generalized message
        SendRPAammoMessage(ply, "Purchased ammo for weapons.")
        DebugPrint("[RPAammo] " .. ply:Nick() .. " bought ammo for equipped weapons.")
    end
end)

-- This print will always show to confirm successful load
print("[RPAammo] Server-side loaded successfully.")