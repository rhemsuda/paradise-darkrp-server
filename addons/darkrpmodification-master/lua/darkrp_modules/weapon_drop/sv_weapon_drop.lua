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
    print("[Weapon Drop Module] Detected drop of " .. weaponClass .. " with intended model: " .. weaponData.model)

    -- Fixed distance of 75 units (player length) along player's forward direction
    local ang = ply:EyeAngles()
    local pos = ply:EyePos() + ang:Forward() * 75 + Vector(0, 0, 20) -- Start 20 units above eye level

    -- Trace to find the ground position, avoiding player
    local groundTr = util.TraceLine({
        start = pos,
        endpos = pos - Vector(0, 0, 150), -- Extended downward trace
        filter = {ply, weapon}, -- Ignore player and original weapon
        mask = MASK_SOLID
    })
    pos = groundTr.Hit and groundTr.HitPos + groundTr.HitNormal * 5 or pos -- 5 units above ground

    -- Prevent underground spawn with robust fallback
    if not groundTr.Hit or pos.z < -100 then -- Adjusted threshold to -100
        print("[Weapon Drop Module] Invalid ground or below threshold, using safe fallback")
        pos = ply:GetPos() + ang:Forward() * 75 + Vector(0, 0, 20) -- Retry from safe height
        groundTr = util.TraceLine({
            start = pos,
            endpos = pos - Vector(0, 0, 150),
            filter = {ply, weapon},
            mask = MASK_SOLID
        })
        pos = groundTr.Hit and groundTr.HitPos + groundTr.HitNormal * 5 or pos
        if pos.z < -100 then
            pos.z = ply:GetPos().z + 10 -- Force above player height if all else fails
        end
    end
    print("[Weapon Drop Module] Final drop position: " .. tostring(pos))

    -- Spawn a custom_weapon_drop entity
    local drop = ents.Create("custom_weapon_drop")
    if not IsValid(drop) then
        print("[Weapon Drop Module] Failed to spawn custom_weapon_drop for " .. weaponClass)
        return
    end

    print("[Weapon Drop Module] Created custom_weapon_drop entity: " .. tostring(drop))

    drop:SetPos(pos)
    drop:SetWeaponClass(weaponClass)
    drop:SetWeaponName(weaponData.name)
    drop:SetWeaponModel(weaponData.model)
    print("[Weapon Drop Module] Set properties for " .. weaponData.name)

    -- Spawn immediately and set owner
    drop:Spawn()
    if drop.CPPISetOwner then
        drop:CPPISetOwner(ply)
    end
    print("[Weapon Drop Module] Spawned custom_weapon_drop for " .. weaponData.name .. " at " .. tostring(pos))

    -- Set collision group to avoid player collision
    drop:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    print("[Weapon Drop Module] Set collision group to COLLISION_GROUP_WEAPON for " .. tostring(drop))

    -- Set initial velocity to zero and ensure it stays
    local phys = drop:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(Vector(0, 0, 0))
        phys:SetAngleVelocity(Vector(0, 0, 0))
        phys:Wake()
        phys:EnableMotion(true)
        phys:Sleep() -- Force it to settle immediately
        print("[Weapon Drop Module] Set velocity to zero and forced sleep for " .. tostring(drop))
    end

    -- Remove the original dropped weapon immediately
    weapon:Remove()
    print("[Weapon Drop Module] Removed original weapon entity: " .. tostring(weapon))

    return true -- Prevent further default handling
end)

-- Override the /drop command to handle drops customly
hook.Add("PlayerSay", "HandleBBDropCommand", function(ply, text)
    if text:lower() == "/drop" then
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) then
            DarkRP.notify(ply, 1, 4, "You have no weapon to drop!")
            return ""
        end

        local weaponClass = weapon:GetClass()
        if BBWeaponClasses[weaponClass] then
            -- Manually trigger the drop logic
            ply:DropWeapon(weapon)
            return "" -- Prevent the default chat message
        end
    end
end)

print("[Weapon Drop Module] Hooks registered for BB weapon dropping")