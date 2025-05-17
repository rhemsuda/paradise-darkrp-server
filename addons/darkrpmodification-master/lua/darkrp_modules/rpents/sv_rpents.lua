print("[RPEnts Module] sv_rpents.lua loaded successfully")

-- Network strings
util.AddNetworkString("RequestEntitiesData")
util.AddNetworkString("SendEntitiesData")

-- Debug entity loading on server start (delayed to ensure DarkRP is fully loaded)
hook.Add("InitPostEntity", "RPEnts_DebugInitialEntities", function()
    print("[RPEnts Module] Running delayed entity check (after InitPostEntity):")
    if DarkRP and DarkRP.getEntities then
        local entities = DarkRP.getEntities()
        if table.IsEmpty(entities) then
            print("[RPEnts Module] No entities found after InitPostEntity!")
        else
            print("[RPEnts Module] Found " .. #entities .. " entities after InitPostEntity:")
            for _, ent in ipairs(entities) do
                print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. (ent.category or "None") .. ")")
            end
        end
    else
        print("[RPEnts Module] Error: DarkRP.getEntities not available after InitPostEntity!")
    end
end)

-- Fallback timer in case InitPostEntity doesn't fire
timer.Simple(5, function()
    print("[RPEnts Module] Running fallback entity check (5 seconds after load):")
    if DarkRP and DarkRP.getEntities then
        local entities = DarkRP.getEntities()
        if table.IsEmpty(entities) then
            print("[RPEnts Module] No entities found in fallback check!")
        else
            print("[RPEnts Module] Found " .. #entities .. " entities in fallback check:")
            for _, ent in ipairs(entities) do
                print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. (ent.category or "None") .. ")")
            end
        end
    else
        print("[RPEnts Module] Error: DarkRP.getEntities not available in fallback check!")
    end
end)

-- Send entity data to the client
net.Receive("RequestEntitiesData", function(len, ply)
    print("[RPEnts Module] Player " .. ply:Nick() .. " is on team " .. ply:Team() .. " (" .. team.GetName(ply:Team()) .. ")")

    -- Load DarkRP entities
    local allEntities = DarkRP.getEntities and DarkRP.getEntities() or {}
    if table.IsEmpty(allEntities) then
        print("[RPEnts Module] Warning: No entities found in DarkRP.getEntities()")
    else
        print("[RPEnts Module] Found " .. #allEntities .. " entities in DarkRP.getEntities():")
        for _, ent in ipairs(allEntities) do
            print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. (ent.category or "None") .. ")")
        end
    end

    -- Filter entities based on the player's team
    local filteredEntities = {}
    for _, entity in ipairs(allEntities) do
        local allowed = false
        if entity.allowed then
            for _, teamID in ipairs(entity.allowed) do
                if ply:Team() == teamID then
                    allowed = true
                    print("[RPEnts Module] Entity " .. entity.name .. " is allowed for team " .. ply:Team())
                    break
                end
            end
        end
        if not allowed then
            print("[RPEnts Module] Entity " .. entity.name .. " is NOT allowed for team " .. ply:Team())
        else
            table.insert(filteredEntities, {
                name = entity.name,
                ent = entity.ent,
                model = entity.model,
                price = entity.price,
                max = entity.max,
                cmd = entity.cmd,
                category = entity.customCategory or "General Entities"
            })
        end
    end

    print("[RPEnts Module] Filtered entities for " .. ply:Nick() .. " (Team " .. ply:Team() .. "):")
    print("[RPEnts Module] Debug: Contents of Filtered Entities:")
    for i, ent in ipairs(filteredEntities) do
        print("[RPEnts Module] Debug:  - [" .. i .. "]: " .. table.ToString(ent))
    end

    net.Start("SendEntitiesData")
    net.WriteTable(filteredEntities)
    net.Send(ply)

    print("[RPEnts Module] Sent entities data to " .. ply:Nick())
end)

print("[RPEnts Module] Server-side loaded successfully")