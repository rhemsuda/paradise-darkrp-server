timer.Simple(0, function()
    AddCSLuaFile("cl_rpents.lua")
    AddCSLuaFile("sh_entities.lua")
    include("sh_entities.lua")

    print("[RPEnts Module] sv_rpents.lua loaded successfully")

    -- Ensure net messages are pooled
    util.AddNetworkString("BuyEntity")
    util.AddNetworkString("SendEntitiesData")
    util.AddNetworkString("RequestEntitiesData") -- Added this line

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
        if not IsValid(ply) then return end

        local entName = net.ReadString()
        local entData = nil

        for _, ent in ipairs(RPEnts.Entities) do
            if ent.name == entName then
                entData = ent
                break
            end
        end

        if not entData then
            DarkRP.notify(ply, 1, 4, "Entity not found!")
            print("[RPEnts Module] " .. ply:Nick() .. " attempted to buy invalid entity: " .. tostring(entName))
            return
        end

        if entData.donatorOnly and not (ULib and ULib.ucl.query(ply, "donator")) then
            DarkRP.notify(ply, 1, 4, "You must be a donator to buy this entity!")
            print("[RPEnts Module] " .. ply:Nick() .. " is not a donator, cannot buy " .. entName)
            return
        end

        local price = entData.price or 0
        if not ply:canAfford(price) then
            DarkRP.notify(ply, 1, 4, "You cannot afford to buy this entity! (Price: $" .. price .. ")")
            print("[RPEnts Module] " .. ply:Nick() .. " cannot afford " .. entName .. " (Price: $" .. price .. ")")
            return
        end

        if (entData.ent == "printer1" or entData.ent == "printer2") then
            local printerCount = GetPlayerPrinterCount(ply)
            print("[RPEnts Module] Current printer count for " .. ply:Nick() .. ": " .. printerCount)
            if printerCount >= 2 then
                DarkRP.notify(ply, 1, 4, "You have reached the maximum limit of 2 printers!")
                print("[RPEnts Module] " .. ply:Nick() .. " has reached printer limit (" .. printerCount .. "/2)")
                return
            end
        end

        ply:addMoney(-price)
        print("[RPEnts Module] Deducted $" .. price .. " from " .. ply:Nick() .. " for " .. entName)

        local trace = ply:GetEyeTrace()
        local spawnPos = trace.HitPos + Vector(0, 0, 50)
        local ent = ents.Create(entData.ent)
        if not IsValid(ent) then
            DarkRP.notify(ply, 1, 4, "Failed to spawn entity!")
            ply:addMoney(price)
            print("[RPEnts Module] Failed to spawn " .. entData.ent .. " for " .. ply:Nick())
            return
        end

        ent:SetPos(spawnPos)
        ent:Spawn()
        ent:Setowning_ent(ply)
        ent:CPPISetOwner(ply)

        if (entData.ent == "printer1" or entData.ent == "printer2") then
            local steamID = ply:SteamID()
            PlayerPrinters[steamID] = PlayerPrinters[steamID] or {}
            table.insert(PlayerPrinters[steamID], ent)
            print("[RPEnts Module] " .. ply:Nick() .. " now has " .. GetPlayerPrinterCount(ply) .. " printers")
        end

        DarkRP.notify(ply, 0, 4, "Successfully bought and spawned " .. entName .. " for $" .. price .. "!")
        print("[RPEnts Module] " .. ply:Nick() .. " successfully bought and spawned " .. entName)
    end)

    net.Receive("RequestEntitiesData", function(len, ply)
        if not IsValid(ply) then return end

        print("[RPEnts Module] Player " .. ply:Nick() .. " requested entities data")

        local isDonator = ULib and ULib.ucl.query(ply, "donator") or false
        net.Start("SendEntitiesData")
        net.WriteTable(RPEnts.Entities)
        net.WriteBool(isDonator)
        net.Send(ply)

        print("[RPEnts Module] Sent entities data to " .. ply:Nick() .. " (Donator: " .. tostring(isDonator) .. ")")
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

    print("[RPEnts Module] Server-side loaded successfully")
end)