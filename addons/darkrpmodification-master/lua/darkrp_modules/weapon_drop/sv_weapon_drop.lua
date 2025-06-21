print("[Weapon Drop Module] sv_weapon_drop.lua loaded successfully")

-- List of BB weapon classes for quick lookup (to be populated after SingleWeapons is defined)
local BBWeaponClasses = {}

-- Populate BBWeaponClasses after the server initializes
hook.Add("InitPostEntity", "PopulateBBWeaponClasses", function()
    if not _G.SingleWeapons then
        print("[Weapon Drop Module] Error: SingleWeapons table is nil! Ensure sv_rpents.lua is loaded before this module.")
        return
    end

    for _, weapon in ipairs(_G.SingleWeapons) do
        BBWeaponClasses[weapon.ent] = weapon
    end
    print("[Weapon Drop Module] Populated BBWeaponClasses with " .. table.Count(BBWeaponClasses) .. " BB weapons")
end)

-- Hook into the weapon drop process
hook.Add("PlayerDroppedWeapon", "ConvertBBDropToCustomWeaponDrop", function(ply, weapon)
    if not IsValid(ply) or not IsValid(weapon) then return end

    local weaponClass = weapon:GetClass()
    local weaponData = BBWeaponClasses[weaponClass]

    -- Check if the dropped weapon is a BB weapon
    if not weaponData then return end

    -- Log the model being used
    print("[Weapon Drop Module] Dropping weapon " .. weaponClass .. " with intended model: " .. weaponData.model)

    -- Get the position where the weapon was dropped (slightly above the player to avoid ground clipping)
    local pos = ply:GetPos() + Vector(0, 0, 50)

    -- Spawn a custom_weapon_drop entity
    local drop = ents.Create("custom_weapon_drop")
    if not IsValid(drop) then
        print("[Weapon Drop Module] Failed to spawn custom_weapon_drop for " .. weaponClass)
        return
    end

    print("[Weapon Drop Module] Created custom_weapon_drop entity: " .. tostring(drop))

    drop:SetPos(pos)

    -- Ensure SetWeaponClass exists before calling
    if not drop.SetWeaponClass then
        print("[Weapon Drop Module] Error: SetWeaponClass method not found on custom_weapon_drop for " .. ply:Nick())
        drop:Remove()
        return
    end

    drop:SetWeaponClass(weaponClass)
    drop:SetWeaponName(weaponData.name)
    drop:SetWeaponModel(weaponData.model)
    print("[Weapon Drop Module] Set WeaponModel to " .. weaponData.model .. " for " .. weaponData.name)

    -- Delay the spawn to ensure networked variables are set
    timer.Simple(0.1, function()
        if not IsValid(drop) then return end
        drop:Spawn()
        if drop.CPPISetOwner then
            drop:CPPISetOwner(ply)
        end
        print("[Weapon Drop Module] Spawned custom_weapon_drop for " .. weaponData.name .. " with model " .. weaponData.model)
    end)

    print("[Weapon Drop Module] Player " .. ply:Nick() .. " dropped " .. weaponClass .. " as custom_weapon_drop at " .. tostring(pos))

    -- Remove the original dropped weapon entity
    weapon:Remove()
end)

-- Override the /drop command to ensure consistency
hook.Add("PlayerSay", "HandleBBDropCommand", function(ply, text)
    if text:lower() == "/drop" then
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) then return end

        local weaponClass = weapon:GetClass()
        if BBWeaponClasses[weaponClass] then
            -- Let the default drop happen, and the PlayerDroppedWeapon hook will handle conversion
            return
        end
    end
end)

print("[Weapon Drop Module] Hooks registered for BB weapon dropping")