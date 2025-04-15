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
            local ammoType = itemData.ammoType

            if not ammoType then
                DebugPrint("[RPAammo] No ammo type defined for " .. weaponClass .. " in InventoryItems.")
                SendRPAammoMessage(ply, "Error: No ammo type defined for " .. itemData.name .. ".")
                continue
            end

            -- Add 300 ammo to the player's reserve for this ammo type
            ply:GiveAmmo(300, ammoType, false)
            table.insert(weaponsProcessed, itemData.name)
            DebugPrint("[RPAammo] Added 300 " .. ammoType .. " ammo for " .. weaponClass .. " to " .. ply:Nick())
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