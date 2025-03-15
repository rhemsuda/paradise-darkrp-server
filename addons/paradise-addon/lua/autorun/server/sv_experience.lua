if SERVER then
    hook.Add("PlayerInitialSpawn", "InitPlayerXP", function(ply)
        if not ply:GetNWInt("Experience", false) then
            ply:SetNWInt("Experience", 0)
        end
    end)

    function AddPlayerXP(ply, amount)
        local currentXP = ply:GetNWInt("Experience", 0)
        ply:SetNWInt("Experience", currentXP + amount)
        ply:ChatPrint("You gained " .. amount .. " XP! Total: " .. ply:GetNWInt("Experience"))
    end

    -- TODO: Lock this command down to admins
    concommand.Add("give_xp", function(ply, cmd, args)
        if not args[1] then return end
        local amount = tonumber(args[1])
        if amount then
            AddPlayerXP(ply, amount)
        end
    end)

    hook.Add("PlayerDisconnected", "SavePlayerXP", function(ply)
        local steamID = ply:SteamID64() or ply:UniqueID()
        file.Write("player_xp/" .. steamID .. ".txt", ply:GetNWInt("Experience"))
    end)

    hook.Add("PlayerInitialSpawn", "LoadPlayerXP", function(ply)
        local steamID = ply:SteamID64() or ply:UniqueID()
        if file.Exists("player_xp/" .. steamID .. ".txt", "DATA") then
            local xp = tonumber(file.Read("player_xp/" .. steamID .. ".txt", "DATA")) or 0
            ply:SetNWInt("Experience", xp)
        end
    end)
end