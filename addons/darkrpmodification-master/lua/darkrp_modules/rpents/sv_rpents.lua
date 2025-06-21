AddCSLuaFile("darkrp_modules/rpents/cl_rpents.lua")
AddCSLuaFile("darkrp_modules/rpents/sh_entities.lua")
include("darkrp_modules/rpents/sh_entities.lua")

print("[RPEnts Module] sv_rpents.lua loaded successfully")

util.AddNetworkString("BuyEntity")
util.AddNetworkString("SendEntitiesData")
util.AddNetworkString("RequestEntitiesData")
print("[RPEnts Module] Network strings registered: BuyEntity, SendEntitiesData, RequestEntitiesData")

-- Define the list of single weapons using bb_ CSS weapons (excluding hand grenades and auto snipers)
-- Make SingleWeapons global so other modules can access it
_G.SingleWeapons = {
    -- Pistols
    { name = "Deagle", ent = "bb_deagle", model = "models/weapons/w_pist_deagle.mdl", price = 600, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "Dual Elites", ent = "bb_dualelites", model = "models/weapons/w_pist_elite.mdl", price = 600, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "Five-SeveN", ent = "bb_fiveseven", model = "models/weapons/w_pist_fiveseven.mdl", price = 600, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "Glock", ent = "bb_glock", model = "models/weapons/w_pist_glock18.mdl", price = 600, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "P228", ent = "bb_p228", model = "models/weapons/w_pist_p228.mdl", price = 600, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "USP", ent = "bb_usp", model = "models/weapons/w_pist_usp.mdl", price = 600, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    -- SMGs
    { name = "MAC-10", ent = "bb_mac10", model = "models/weapons/w_smg_mac10.mdl", price = 800, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "MP5", ent = "bb_mp5", model = "models/weapons/w_smg_mp5.mdl", price = 800, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "P90", ent = "bb_p90", model = "models/weapons/w_smg_p90.mdl", price = 800, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "TMP", ent = "bb_tmp", model = "models/weapons/w_smg_tmp.mdl", price = 800, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "UMP45", ent = "bb_ump45", model = "models/weapons/w_smg_ump45.mdl", price = 800, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    -- Rifles
    { name = "AK47", ent = "bb_ak47", model = "models/weapons/w_rif_ak47.mdl", price = 1000, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "AUG", ent = "bb_aug", model = "models/weapons/w_rif_aug.mdl", price = 1000, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "FAMAS", ent = "bb_famas", model = "models/weapons/w_rif_famas.mdl", price = 1000, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "Galil", ent = "bb_galil", model = "models/weapons/w_rif_galil.mdl", price = 1000, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "M4A1", ent = "bb_m4a1", model = "models/weapons/w_rif_m4a1.mdl", price = 1000, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "SG552", ent = "bb_sg552", model = "models/weapons/w_rif_sg552.mdl", price = 1000, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    -- Sniper (excluding auto snipers like G3SG1 and SG550)
    { name = "Scout", ent = "bb_scout", model = "models/weapons/w_snip_scout.mdl", price = 1000, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "AWP", ent = "bb_awp", model = "models/weapons/w_snip_awp.mdl", price = 1500, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    -- Shotguns
    { name = "M3", ent = "bb_m3", model = "models/weapons/w_shot_m3super90.mdl", price = 700, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    { name = "XM1014", ent = "bb_xm1014", model = "models/weapons/w_shot_xm1014.mdl", price = 700, category = "Single Weapons", donatorOnly = false, jobRestricted = true },
    -- Machine Gun
    { name = "M249", ent = "bb_m249", model = "models/weapons/w_mach_m249para.mdl", price = 2000, category = "Single Weapons", donatorOnly = true, jobRestricted = true },
}

print("[RPEnts Module] SingleWeapons table defined with " .. #SingleWeapons .. " entries")

-- Precache all weapon models and validate them at server start
hook.Add("InitPostEntity", "RPEnts_PrecacheWeaponModels", function()
    print("[RPEnts Module] Precaching and validating weapon models:")
    for _, weapon in ipairs(SingleWeapons) do
        if util.IsValidModel(weapon.model) then
            util.PrecacheModel(weapon.model)
            print("[RPEnts Module] Model is valid and precached: " .. weapon.model .. " for " .. weapon.name)
        else
            print("[RPEnts Module] Model " .. weapon.model .. " is INVALID for " .. weapon.name .. " (Check if CS:S is mounted!) Fallback will be handled in custom_weapon_drop.")
        end
    end
end)

-- Check which weapons are available on the server
hook.Add("InitPostEntity", "RPEnts_CheckWeapons", function()
    print("[RPEnts Module] Checking available weapons:")
    for _, weapon in ipairs(SingleWeapons) do
        local weaponExists = weapons.Get(weapon.ent) and true or false
        print("[RPEnts Module] Weapon " .. weapon.ent .. " (" .. weapon.name .. ") is " .. (weaponExists and "available" or "not available"))
    end
end)

-- Register the RequestEntitiesData handler
net.Receive("RequestEntitiesData", function(len, ply)
    if not IsValid(ply) then return end

    print("[RPEnts Module] Player " .. ply:Nick() .. " requested entities data")

    local isDonator = ULib and ULib.ucl.query(ply, "donator") or false
    local isGunDealer = ply:Team() == TEAM_GUN or (RPExtraTeams[ply:Team()] and RPExtraTeams[ply:Team()].name == "Gun Dealer")
    print("[RPEnts Module] Job check for " .. ply:Nick() .. ": Team = " .. ply:Team() .. ", IsGunDealer = " .. tostring(isGunDealer))

    local entitiesToSend = table.Copy(RPEnts.Entities or {})

    -- Add all single weapons if the player is a Gun Dealer
    if isGunDealer then
        for _, weapon in ipairs(SingleWeapons) do
            table.insert(entitiesToSend, weapon)
            print("[RPEnts Module] Added single weapon " .. weapon.name .. " for " .. ply:Nick())
        end
    end

    print("[RPEnts Module] Sending " .. #entitiesToSend .. " entities to " .. ply:Nick())
    for _, ent in ipairs(entitiesToSend) do
        print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. ent.category .. ", JobRestricted: " .. tostring(ent.jobRestricted or false) .. ")")
    end

    net.Start("SendEntitiesData")
    net.WriteTable(entitiesToSend)
    net.WriteBool(isDonator)
    net.WriteBool(isGunDealer)
    net.Send(ply)

    print("[RPEnts Module] Sent entities data to " .. ply:Nick() .. " (Donator: " .. tostring(isDonator) .. ", Gun Dealer: " .. tostring(isGunDealer) .. ")")
end)
print("[RPEnts Module] Registered net.Receive handler for RequestEntitiesData")

local PlayerPrinters = {}

local function GetPlayerPrinterCount(ply)
    if not IsValid(ply) then return 0 end
    local steamID = ply:SteamID()
    local count = 0
    local printerData = PlayerPrinters[steamID] or {}
    for i, printer in pairs(printerData) do
        if IsValid(printer) then
            count = count + 1
        else
            printerData[i] = nil
        end
    end
    PlayerPrinters[steamID] = printerData
    return count
end

hook.Add("PlayerDisconnected", "RPEnts_CleanUpPrinters", function(ply)
    local steamID = ply:SteamID()
    if PlayerPrinters[steamID] then
        for i, printer in pairs(PlayerPrinters[steamID]) do
            if IsValid(printer) then
                printer:Remove()
                print("[RPEnts Module] Removed printer " .. tostring(printer) .. " for " .. ply:Nick())
            end
        end
        PlayerPrinters[steamID] = nil
        print("[RPEnts Module] Cleaned up printers for " .. ply:Nick() .. " (" .. steamID .. ")")
    end
end)

hook.Add("Think", "RPEnts_CleanUpInvalidPrinters", function()
    for steamID, printers in pairs(PlayerPrinters) do
        local countBefore = #printers
        for i = #printers, 1, -1 do
            local printer = printers[i]
            if not IsValid(printer) then
                table.remove(printers, i)
                print("[RPEnts Module] Removed invalid printer entry for SteamID " .. steamID)
            end
        end
        if #printers == 0 then
            PlayerPrinters[steamID] = nil
        elseif countBefore != #printers then
            print("[RPEnts Module] Updated printer count for SteamID " .. steamID .. ": " .. #printers)
        end
    end
end)

net.Receive("BuyEntity", function(len, ply)
    local entName = net.ReadString()
    print("[RPEnts Module] Attempting to buy entity: " .. entName)

    -- Combine RPEnts.Entities and SingleWeapons for lookup
    local allEntities = table.Copy(RPEnts.Entities or {})
    for _, weapon in ipairs(SingleWeapons) do
        table.insert(allEntities, weapon)
    end

    for _, ent in ipairs(allEntities) do
        if ent.name == entName then
            if not ply:canAfford(ent.price) then
                DarkRP.notify(ply, 1, 4, "You cannot afford to buy this entity!")
                print("[RPEnts Module] " .. ply:Nick() .. " cannot afford " .. entName)
                return
            end

            if ent.donatorOnly and not ply:IsDonator() then
                DarkRP.notify(ply, 1, 4, "You must be a donator to buy this entity!")
                print("[RPEnts Module] " .. ply:Nick() .. " is not a donator for " .. entName)
                return
            end

            if ent.jobRestricted and ply:Team() ~= TEAM_GUN then
                DarkRP.notify(ply, 1, 4, "You must be a Gun Dealer to buy this entity!")
                print("[RPEnts Module] " .. ply:Nick() .. " is not a Gun Dealer for " .. entName)
                return
            end

            ply:addMoney(-ent.price)
            print("[RPEnts Module] Deducted $" .. ent.price .. " from " .. ply:Nick() .. " for " .. entName)

            -- Calculate spawn position
            local eyePos = ply:GetShootPos()
            local aimVec = ply:GetAimVector()
            local trace = util.TraceLine({
                start = eyePos,
                endpos = eyePos + aimVec * 100,
                filter = ply
            })
            local spawnPos = trace.HitPos + Vector(0, 0, 30)
            if not trace.Hit then
                spawnPos = ply:GetPos() + aimVec * 50 + Vector(0, 0, 30)
            end

            -- Ensure spawn position is above ground
            local groundTrace = util.TraceLine({
                start = spawnPos + Vector(0, 0, 50),
                endpos = spawnPos - Vector(0, 0, 1000),
                filter = ply
            })
            if groundTrace.Hit then
                spawnPos = groundTrace.HitPos + Vector(0, 0, 60)
                print("[RPEnts Module] Adjusted spawn position to ground: " .. tostring(spawnPos))
            else
                print("[RPEnts Module] Warning: No ground found, using default spawn position: " .. tostring(spawnPos))
            end

            print("[RPEnts Module] Calculated spawn position: " .. tostring(spawnPos))

            -- Create the appropriate entity
            local entityClass = ent.ent == "custom_empty_shipment" and "custom_empty_shipment" or "custom_weapon_drop"
            local drop = ents.Create(entityClass)
            if not IsValid(drop) then
                print("[RPEnts Module] Error: Failed to create " .. entityClass .. " for " .. entName)
                DarkRP.notify(ply, 1, 4, "Failed to spawn entity!")
                ply:addMoney(ent.price) -- Refund
                return
            end

            drop:SetPos(spawnPos)
            if entityClass == "custom_weapon_drop" then
                drop:SetWeaponClass(ent.ent)
                drop:SetWeaponName(ent.name)
                local model = ent.model or "models/props_junk/cardboard_box001a.mdl"
                print("[RPEnts Module] Setting model directly to: " .. model)
                drop:SetModel(model)
                drop:SetWeaponModel(model)
            else
                drop:SetModel(ent.model or "models/Items/ammocrate_smg1.mdl")
            end
            drop:Spawn()

            -- Debug entity properties
            print("[RPEnts Module] Spawned " .. entityClass .. " for " .. entName)
            print("[RPEnts Module] - Position: " .. tostring(drop:GetPos()))
            print("[RPEnts Module] - Model: " .. tostring(drop:GetModel()))
            print("[RPEnts Module] - Class: " .. tostring(ent.ent))
            print("[RPEnts Module] - IsValid: " .. tostring(IsValid(drop)))

            DarkRP.notify(ply, 0, 4, "Successfully bought and dropped " .. entName .. " for $" .. ent.price .. "! Press E to interact.")
            return
        end
    end
    print("[RPEnts Module] Entity not found: " .. entName)
    DarkRP.notify(ply, 1, 4, "Entity not found!")
end)


hook.Add("InitPostEntity", "RPEnts_CheckEntities", function()
    print("[RPEnts Module] Running delayed entity check (after InitPostEntity):")
    if not RPEnts or not RPEnts.Entities then
        print("[RPEnts Module] Error: RPEnts.Entities is nil after InitPostEntity")
        return
    end

    print("[RPEnts Module] Found " .. #RPEnts.Entities .. " custom entities after InitPostEntity:")
    for _, ent in ipairs(RPEnts.Entities) do
        print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. ent.category .. ")")
    end
end)

timer.Simple(5, function()
    print("[RPEnts Module] Running fallback entity check (5 seconds after load):")
    if not RPEnts or not RPEnts.Entities then
        print("[RPEnts Module] Error: RPEnts.Entities is nil in fallback check")
        return
    end

    print("[RPEnts Module] Found " .. #RPEnts.Entities .. " custom entities in fallback check:")
    for _, ent in ipairs(RPEnts.Entities) do
        print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. ent.category .. ")")
    end
end)

-- Debug hook to list all registered entities
hook.Add("InitPostEntity", "Debug_ListEntities", function()
    print("[Debug] Listing all registered entities (InitPostEntity):")
    local entityList = list.Get("SpawnableEntities")
    for entName, entData in pairs(entityList) do
        print("[Debug] Entity: " .. entName .. " (PrintName: " .. (entData.PrintName or "N/A") .. ")")
    end
    if entityList["custom_empty_shipment"] then
        print("[Debug] custom_empty_shipment is registered!")
    else
        print("[Debug] custom_empty_shipment is NOT registered!")
    end
    if entityList["custom_weapon_drop"] then
        print("[Debug] custom_weapon_drop is registered!")
    else
        print("[Debug] custom_weapon_drop is NOT registered!")
    end
end)

print("[RPEnts Module] Server-side loaded successfully")