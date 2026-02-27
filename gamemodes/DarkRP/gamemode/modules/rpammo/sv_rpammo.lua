if not SERVER then return end

-- Helper function to print debug messages conditionally (set rp_debug 1 to see)
local function DebugPrint(...)
    local cv = GetConVar("rp_debug")
    if cv and cv:GetInt() == 1 then print(...) end
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
    ["#SniperRound_ammo"] = "357",
}

-- Console command to buy ammo (uses Inventory module loadout or currently held weapon)
concommand.Add("rp_buyammo", function(ply)
    if not IsValid(ply) then return end

    local weaponsToGive = {}
    -- 1) Try Inventory module loadout (primary/sidearm weapons)
    if Inventory and Inventory.GetPlayerLoadoutWeapons then
        local loadoutWeapons = Inventory.GetPlayerLoadoutWeapons(ply)
        for _, w in ipairs(loadoutWeapons) do
            table.insert(weaponsToGive, w.class)
        end
    end
    -- 2) Fallback: add ammo for currently held weapon
    if #weaponsToGive == 0 then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then
            table.insert(weaponsToGive, wep:GetClass())
        end
    end

    if #weaponsToGive == 0 then
        SendRPAammoMessage(ply, "You don't have any equipped weapons to buy ammo for!")
        DebugPrint("[RPAammo] " .. ply:Nick() .. " tried to buy ammo but has no loadout or held weapon.")
        return
    end

    local weaponsProcessed = {}
    for _, weaponClass in ipairs(weaponsToGive) do
        local weapon = ply:GetWeapon(weaponClass)
        local ammoType
        if IsValid(weapon) then
            local ammoTypeID = weapon:GetPrimaryAmmoType()
            ammoType = game.GetAmmoName(ammoTypeID)
            DebugPrint("[RPAammo] Weapon " .. weaponClass .. " has ammo type: " .. (ammoType or "none") .. " (ID: " .. ammoTypeID .. ")")
        else
            -- Try Inventory item definition for ammo type
            if Inventory and Inventory.Items then
                for _, def in pairs(Inventory.Items) do
                    if def.class == weaponClass and def.ammoType then
                        ammoType = def.ammoType
                        break
                    end
                end
            end
        end

        if not ammoType then
            DebugPrint("[RPAammo] No ammo type for " .. weaponClass .. ".")
            continue
        end

        local correctedAmmoType = AmmoTypeMapping[ammoType] or ammoType
        if not game.GetAmmoID(correctedAmmoType) or game.GetAmmoID(correctedAmmoType) == -1 then
            DebugPrint("[RPAammo] Invalid ammo type '" .. correctedAmmoType .. "' for " .. weaponClass .. ".")
            continue
        end

        ply:GiveAmmo(300, correctedAmmoType, false)
        table.insert(weaponsProcessed, weaponClass)
        DebugPrint("[RPAammo] Added 300 " .. correctedAmmoType .. " ammo for " .. weaponClass .. " to " .. ply:Nick() .. ".")
    end

    if #weaponsProcessed == 0 then
        SendRPAammoMessage(ply, "Could not determine ammo types for your weapons.")
    else
        SendRPAammoMessage(ply, "Bought 300 ammo for: " .. table.concat(weaponsProcessed, ", ") .. ".")
        DebugPrint("[RPAammo] " .. ply:Nick() .. " bought ammo for: " .. table.concat(weaponsProcessed, ", "))
    end
end)

print("[RPAammo] Server-side loaded successfully.")
