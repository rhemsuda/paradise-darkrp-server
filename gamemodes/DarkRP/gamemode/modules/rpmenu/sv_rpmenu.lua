if not SERVER then return end

-- Networking messages
util.AddNetworkString("RPMenu_CreateGang")
util.AddNetworkString("RPMenu_RequestGangData")
util.AddNetworkString("RPMenu_SendGangData")
util.AddNetworkString("RPMenu_UpdateGangStatus")
util.AddNetworkString("RPMenu_UpgradeGang")
util.AddNetworkString("RPMenu_DonateToBank")
util.AddNetworkString("RPMenu_LeaveGang")
util.AddNetworkString("RPMenu_KickPlayer")
util.AddNetworkString("RPMenu_SetRank")
util.AddNetworkString("RPMenu_ChangePassword")
util.AddNetworkString("RPMenu_RequestPasswordForKick")
util.AddNetworkString("RPMenu_SubmitPasswordForKick")
util.AddNetworkString("RPMenu_InvitePlayer")
util.AddNetworkString("RPMenu_AcceptInvite")
util.AddNetworkString("RPMenu_DeclineInvite")
util.AddNetworkString("RPMenu_ReceiveInvite")

-- SQL table creation for gangs
sql.Begin()
    sql.Query([[
        CREATE TABLE IF NOT EXISTS darkrp_gangs (
            gang_name TEXT PRIMARY KEY,
            gang_level INTEGER DEFAULT 1,
            gang_color TEXT,
            gang_password TEXT,
            gang_upgrades TEXT DEFAULT '{}',
            upgrade_points INTEGER DEFAULT 0,
            members TEXT DEFAULT '[]',
            gang_bank INTEGER DEFAULT 0
        )
    ]])

    local columns = sql.Query("PRAGMA table_info(darkrp_gangs)")
    local columnExists = {}
    if columns then
        for _, column in ipairs(columns) do
            columnExists[column.name] = true
        end
    end

    if not columnExists.gang_password then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN gang_password TEXT")
    end
    if not columnExists.upgrade_points then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN upgrade_points INTEGER DEFAULT 0")
    end
    if not columnExists.members then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN members TEXT DEFAULT '[]'")
    end
    if not columnExists.gang_bank then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN gang_bank INTEGER DEFAULT 0")
    end
sql.Commit()

-- Function to send gang data to a player
local function SendGangData(ply)
    if not IsValid(ply) then return end

    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then return end

    local gangData = sql.QueryRow("SELECT * FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then return end

    local gangLevel = tonumber(gangData.gang_level) or 1
    ply:SetNWInt("GangLevel", gangLevel)
    ply:SetNWString("GangColor", gangData.gang_color or util.TableToJSON({r = 255, g = 255, b = 255}))

    local members = util.JSONToTable(gangData.members or "[]") or {}
    net.Start("RPMenu_SendGangData")
    net.WriteString(gangName)
    net.WriteUInt(tonumber(gangData.gang_level), 8)
    net.WriteString(gangData.gang_color or util.TableToJSON({r = 255, g = 255, b = 255}))
    net.WriteTable(members)
    net.WriteString(gangData.gang_upgrades or "{}")
    net.WriteUInt(tonumber(gangData.upgrade_points or 0), 8)
    net.WriteUInt(tonumber(gangData.gang_bank or 0), 32)
    net.Send(ply)
end

-- Server-side Network Handlers
net.Receive("RPMenu_CreateGang", function(len, ply)
    local gangName = net.ReadString()
    local gangColor = net.ReadColor()
    local password = net.ReadString()

    if ply:GetNWString("GangName", "") != "" then
        ply:ChatPrint("You are already in a gang! Leave your current gang first.")
        SendGangData(ply)
        return
    end

    local existingGang = sql.Query("SELECT gang_name FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if existingGang and #existingGang > 0 then
        ply:ChatPrint("A gang with this name already exists!")
        return
    end

    local members = {{steamid = ply:SteamID(), rank = "Leader"}}
    local membersJSON = util.TableToJSON(members)
    local colorJSON = util.TableToJSON({r = gangColor.r, g = gangColor.g, b = gangColor.b})

    sql.Query([[
        INSERT INTO darkrp_gangs (gang_name, gang_level, gang_color, gang_password, gang_upgrades, upgrade_points, members, gang_bank)
        VALUES (]] .. sql.SQLStr(gangName) .. [[, 1, ]] .. sql.SQLStr(colorJSON) .. [[, ]] .. sql.SQLStr(password) .. [[, '{}', 1, ]] .. sql.SQLStr(membersJSON) .. [[, 0)
    ]])

    ply:SetNWString("GangName", gangName)
    ply:ChatPrint("Gang '" .. gangName .. "' created successfully!")

    net.Start("RPMenu_UpdateGangStatus")
    net.WriteString(gangName)
    net.Send(ply)

    timer.Simple(0.1, function()
        if IsValid(ply) then SendGangData(ply) end
    end)
end)

net.Receive("RPMenu_UpgradeGang", function(len, ply)
    local upgrade = net.ReadString()
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        return
    end

    local gangData = sql.QueryRow("SELECT gang_upgrades, upgrade_points FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        return
    end

    local upgrades = util.JSONToTable(gangData.gang_upgrades) or {}
    local points = tonumber(gangData.upgrade_points)
    if points < 1 then
        ply:ChatPrint("Not enough upgrade points!")
        return
    end

    local level = upgrades[upgrade] or 0
    if level >= 10 then
        ply:ChatPrint(upgrade .. " is already at max level!")
        return
    end

    upgrades[upgrade] = level + 1
    points = points - 1
    sql.Query("UPDATE darkrp_gangs SET gang_upgrades = " .. sql.SQLStr(util.TableToJSON(upgrades)) .. ", upgrade_points = " .. points .. " WHERE gang_name = " .. sql.SQLStr(gangName))

    ply:ChatPrint("Upgraded " .. upgrade .. " to level " .. (level + 1))
    SendGangData(ply)

    -- Reapply upgrades to all gang members
    ReapplyGangUpgrades(gangName)
end)

net.Receive("RPMenu_DonateToBank", function(len, ply)
    local amount = net.ReadUInt(32)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        return
    end

    local playerMoney = ply:getDarkRPVar("money") or 0
    if amount > playerMoney then
        ply:ChatPrint("You don't have enough money!")
        return
    end

    local gangData = sql.QueryRow("SELECT gang_bank FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        return
    end

    local newBank = (tonumber(gangData.gang_bank) or 0) + amount
    sql.Query("UPDATE darkrp_gangs SET gang_bank = " .. newBank .. " WHERE gang_name = " .. sql.SQLStr(gangName))

    ply:addMoney(-amount)
    ply:ChatPrint("Donated " .. amount .. " to the gang bank!")

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_LeaveGang", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        return
    end

    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    local playerRank = "Recruit"
    for _, member in ipairs(members) do
        if member.steamid == ply:SteamID() then
            playerRank = member.rank or "Recruit"
            break
        end
    end

    if playerRank == "Leader" then
        sql.Query("DELETE FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
        ply:ChatPrint("Gang '" .. gangName .. "' has been disbanded!")

        for _, p in ipairs(player.GetAll()) do
            if p:GetNWString("GangName", "") == gangName then
                p:SetNWString("GangName", "")
                p:SetNWInt("GangLevel", 0)
                p:ChatPrint("Your gang '" .. gangName .. "' has been disbanded by the leader!")
                net.Start("RPMenu_UpdateGangStatus")
                net.WriteString("")
                net.Send(p)
            end
        end
    else
        local newMembers = {}
        for _, member in ipairs(members) do
            if member.steamid != ply:SteamID() then
                table.insert(newMembers, member)
            end
        end

        sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(util.TableToJSON(newMembers)) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
        ply:SetNWString("GangName", "")
        ply:SetNWInt("GangLevel", 0)
        ply:ChatPrint("You have left the gang '" .. gangName .. "'!")

        net.Start("RPMenu_UpdateGangStatus")
        net.WriteString("")
        net.Send(ply)

        for _, p in ipairs(player.GetAll()) do
            if p:GetNWString("GangName", "") == gangName then
                SendGangData(p)
            end
        end
    end
end)

net.Receive("RPMenu_KickPlayer", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        return
    end

    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    local playerRank = "Recruit"
    for _, member in ipairs(members) do
        if member.steamid == ply:SteamID() then
            playerRank = member.rank or "Recruit"
            break
        end
    end

    if playerRank != "Leader" then
        ply:ChatPrint("Only the gang leader can kick players!")
        return
    end

    local steamID = net.ReadString()
    local targetPlayer = nil
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == steamID then
            targetPlayer = p
            break
        end
    end

    local targetRank = "Recruit"
    local targetFound = false
    for _, member in ipairs(members) do
        if member.steamid == steamID then
            targetRank = member.rank or "Recruit"
            targetFound = true
            break
        end
    end

    if not targetFound then
        ply:ChatPrint("Player not found in gang!")
        return
    end

    if targetRank == "Leader" then
        net.Start("RPMenu_RequestPasswordForKick")
        net.WriteString(steamID)
        net.WriteString(IsValid(targetPlayer) and targetPlayer:Nick() or steamID)
        net.Send(ply)
        return
    end

    local newMembers = {}
    for _, member in ipairs(members) do
        if member.steamid != steamID then
            table.insert(newMembers, member)
        end
    end

    sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(util.TableToJSON(newMembers)) .. " WHERE gang_name = " .. sql.SQLStr(gangName))

    if IsValid(targetPlayer) then
        targetPlayer:SetNWString("GangName", "")
        targetPlayer:SetNWInt("GangLevel", 0)
        targetPlayer:ChatPrint("You have been kicked from the gang '" .. gangName .. "'!")
        net.Start("RPMenu_UpdateGangStatus")
        net.WriteString("")
        net.Send(targetPlayer)
    end

    ply:ChatPrint("Player has been kicked from the gang!")

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_SubmitPasswordForKick", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        return
    end

    local gangData = sql.QueryRow("SELECT members, gang_password FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        return
    end

    local steamID = net.ReadString()
    local password = net.ReadString()
    if password != gangData.gang_password then
        ply:ChatPrint("Incorrect password!")
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    local playerRank = "Recruit"
    for _, member in ipairs(members) do
        if member.steamid == ply:SteamID() then
            playerRank = member.rank or "Recruit"
            break
        end
    end

    if playerRank != "Leader" then
        ply:ChatPrint("Only the gang leader can kick players!")
        return
    end

    local targetPlayer = nil
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == steamID then
            targetPlayer = p
            break
        end
    end

    local targetFound = false
    local newMembers = {}
    for _, member in ipairs(members) do
        if member.steamid == steamID then
            targetFound = true
        else
            table.insert(newMembers, member)
        end
    end

    if not targetFound then
        ply:ChatPrint("Player not found in gang!")
        return
    end

    sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(util.TableToJSON(newMembers)) .. " WHERE gang_name = " .. sql.SQLStr(gangName))

    if IsValid(targetPlayer) then
        targetPlayer:SetNWString("GangName", "")
        targetPlayer:SetNWInt("GangLevel", 0)
        targetPlayer:ChatPrint("You have been kicked from the gang '" .. gangName .. "'!")
        net.Start("RPMenu_UpdateGangStatus")
        net.WriteString("")
        net.Send(targetPlayer)
    end

    ply:ChatPrint("Player has been kicked from the gang!")

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_SetRank", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        return
    end

    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    local playerRank = "Recruit"
    for _, member in ipairs(members) do
        if member.steamid == ply:SteamID() then
            playerRank = member.rank or "Recruit"
            break
        end
    end

    if playerRank != "Leader" and playerRank != "Vice Leader" then
        ply:ChatPrint("Only leaders and vice leaders can set ranks!")
        return
    end

    local steamID = net.ReadString()
    local newRank = net.ReadString()
    if not (newRank == "Recruit" or newRank == "Vice Leader" or newRank == "Leader") then
        ply:ChatPrint("Invalid rank!")
        return
    end

    local targetRank = "Recruit"
    local targetFound = false
    for _, member in ipairs(members) do
        if member.steamid == steamID then
            targetRank = member.rank or "Recruit"
            targetFound = true
            break
        end
    end

    if not targetFound then
        ply:ChatPrint("Player not found in gang!")
        return
    end

    if (targetRank == "Leader" or targetRank == "Vice Leader") and playerRank != "Leader" then
        ply:ChatPrint("Only leaders can modify the rank of leaders and vice leaders!")
        return
    end

    if newRank == "Leader" and playerRank != "Leader" then
        ply:ChatPrint("Only leaders can set the Leader rank!")
        return
    end

    if newRank == "Leader" then
        for _, member in ipairs(members) do
            if member.steamid == ply:SteamID() and member.rank == "Leader" then
                member.rank = "Vice Leader"
                break
            end
        end
    end

    for _, member in ipairs(members) do
        if member.steamid == steamID then
            member.rank = newRank
            break
        end
    end

    sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(util.TableToJSON(members)) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    ply:ChatPrint("Set rank of player to " .. newRank .. "!")

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_ChangePassword", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        return
    end

    local gangData = sql.QueryRow("SELECT gang_password FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        return
    end

    local currentPassword = net.ReadString()
    local newPassword = net.ReadString()
    if currentPassword != gangData.gang_password then
        ply:ChatPrint("Incorrect current password!")
        return
    end

    sql.Query("UPDATE darkrp_gangs SET gang_password = " .. sql.SQLStr(newPassword) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    ply:ChatPrint("Gang password changed successfully!")
end)

net.Receive("RPMenu_InvitePlayer", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        return
    end

    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    local playerRank = "Recruit"
    for _, member in ipairs(members) do
        if member.steamid == ply:SteamID() then
            playerRank = member.rank or "Recruit"
            break
        end
    end

    if playerRank != "Leader" and playerRank != "Vice Leader" then
        ply:ChatPrint("Only leaders and vice leaders can invite players!")
        return
    end

    local steamID = net.ReadString()
    local targetPlayer = nil
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == steamID then
            targetPlayer = p
            break
        end
    end

    if not IsValid(targetPlayer) then
        ply:ChatPrint("Player not found or not online!")
        return
    end

    if targetPlayer:GetNWString("GangName", "") != "" then
        ply:ChatPrint("That player is already in a gang!")
        return
    end

    net.Start("RPMenu_ReceiveInvite")
    net.WriteString(gangName)
    net.Send(targetPlayer)
    ply:ChatPrint("Invite sent to " .. targetPlayer:Nick() .. "!")
end)

net.Receive("RPMenu_AcceptInvite", function(len, ply)
    if ply:GetNWString("GangName", "") != "" then
        ply:ChatPrint("You are already in a gang!")
        return
    end

    local gangName = net.ReadString()
    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang no longer exists!")
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    if #members >= 10 then
        ply:ChatPrint("This gang has reached its maximum capacity of 10 members!")
        return
    end

    table.insert(members, {steamid = ply:SteamID(), rank = "Recruit"})
    sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(util.TableToJSON(members)) .. " WHERE gang_name = " .. sql.SQLStr(gangName))

    ply:SetNWString("GangName", gangName)
    ply:ChatPrint("You have joined the gang '" .. gangName .. "'!")

    net.Start("RPMenu_UpdateGangStatus")
    net.WriteString(gangName)
    net.Send(ply)

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_DeclineInvite", function(len, ply)
    local gangName = net.ReadString()
    ply:ChatPrint("You have declined the invite from '" .. gangName .. "'.")
end)

net.Receive("RPMenu_RequestGangData", function(len, ply)
    SendGangData(ply)
end)

hook.Add("PlayerInitialSpawn", "RPMenu_SendGangDataOnJoin", function(ply)
    local gangs = sql.Query("SELECT gang_name, members FROM darkrp_gangs")
    local gangName = ""
    if gangs then
        for _, gang in ipairs(gangs) do
            local members = util.JSONToTable(gang.members or "[]") or {}
            for _, member in ipairs(members) do
                if member.steamid == ply:SteamID() then
                    gangName = gang.gang_name
                    break
                end
            end
            if gangName ~= "" then break end
        end
    end
    ply:SetNWString("GangName", gangName)

    timer.Simple(0.1, function()
        if IsValid(ply) then SendGangData(ply) end
    end)
end)