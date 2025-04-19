print("[RPMenu] sv_rpmenu.lua file found, attempting to load")

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
util.AddNetworkString("RPMenu_DisbandGang")

-- SQL table creation and migration for gangs
sql.Begin()
    local createGangsTable = sql.Query([[
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
    if createGangsTable == false then
        print("[RPMenu] Failed to create darkrp_gangs table: " .. sql.LastError())
    else
        print("[RPMenu] Created or verified darkrp_gangs table")
    end

    local columns = sql.Query("PRAGMA table_info(darkrp_gangs)")
    local columnExists = {}
    if columns then
        for _, column in ipairs(columns) do
            columnExists[column.name] = true
        end
    end

    if not columnExists.gang_password then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN gang_password TEXT")
        print("[RPMenu] Added gang_password column")
    end

    if not columnExists.upgrade_points then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN upgrade_points INTEGER DEFAULT 0")
        print("[RPMenu] Added upgrade_points column")
    end

    if not columnExists.members then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN members TEXT DEFAULT '[]'")
        print("[RPMenu] Added members column")
    end

    if not columnExists.gang_bank then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN gang_bank INTEGER DEFAULT 0")
        print("[RPMenu] Added gang_bank column")
    end
sql.Commit()

-- Function to send gang data to a player
local function SendGangData(ply)
    if not IsValid(ply) then
        print("[RPMenu] SendGangData: Invalid player")
        return
    end

    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        print("[RPMenu] SendGangData: No gang for " .. ply:Nick())
        return
    end

    print("[RPMenu] SendGangData: Querying for gang " .. gangName .. " for " .. ply:Nick())
    local gangData = sql.QueryRow("SELECT * FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        print("[RPMenu] SendGangData: Gang " .. gangName .. " not found in database for " .. ply:Nick())
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    -- Remove duplicates by keeping the highest rank
    local seenSteamIDs = {}
    local cleanedMembers = {}
    for _, member in ipairs(members) do
        local steamID = member.steamid
        local rank = member.rank or "Recruit"
        if not seenSteamIDs[steamID] then
            seenSteamIDs[steamID] = { rank = rank, member = member }
        else
            -- Compare ranks: Leader > Vice Leader > Recruit
            local existingRank = seenSteamIDs[steamID].rank
            local rankOrder = { Leader = 3, ["Vice Leader"] = 2, Recruit = 1 }
            if (rankOrder[rank] or 0) > (rankOrder[existingRank] or 0) then
                seenSteamIDs[steamID] = { rank = rank, member = member }
            end
        end
    end
    for steamID, data in pairs(seenSteamIDs) do
        table.insert(cleanedMembers, data.member)
    end
    members = cleanedMembers

    -- Update the database with cleaned members
    local membersJSON = util.TableToJSON(members)
    sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(membersJSON) .. " WHERE gang_name = " .. sql.SQLStr(gangName))

    print("[RPMenu] SendGangData: Preparing data - Name: " .. gangName .. ", Level: " .. gangData.gang_level .. ", Members: " .. #members .. ", Points: " .. (gangData.upgrade_points or 0))

    net.Start("RPMenu_SendGangData")
    net.WriteString(gangName)
    net.WriteUInt(tonumber(gangData.gang_level), 8)
    net.WriteString(gangData.gang_color or util.TableToJSON({r = 255, g = 255, b = 255}))
    net.WriteTable(members)
    net.WriteString(gangData.gang_upgrades or "{}")
    net.WriteUInt(tonumber(gangData.upgrade_points or 0), 8)
    net.WriteUInt(tonumber(gangData.gang_bank or 0), 32)
    net.Send(ply)
    print("[RPMenu] SendGangData: Sent data to " .. ply:Nick())
end

-- Function to add XP to a gang
function AddGangXP(gangName, xp)
    local gangData = sql.QueryRow("SELECT gang_level, upgrade_points FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        print("[RPMenu] Gang " .. gangName .. " not found for XP addition")
        return
    end
    local level = tonumber(gangData.gang_level)
    local points = tonumber(gangData.upgrade_points)
    local totalXP = (level - 1) * 1000 + xp
    local newLevel = math.min(math.floor(totalXP / 1000) + 1, 20)
    if newLevel > level then
        points = points + (newLevel - level)
        local updateQuery = sql.Query("UPDATE darkrp_gangs SET gang_level = " .. newLevel .. ", upgrade_points = " .. points .. " WHERE gang_name = " .. sql.SQLStr(gangName))
        if updateQuery == false then
            print("[RPMenu] Failed to update gang level and points: " .. sql.LastError())
            return
        end
        print("[RPMenu] Gang " .. gangName .. " leveled up to " .. newLevel .. " with " .. points .. " upgrade points")
    end
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNWString("GangName", "") == gangName then
            SendGangData(ply)
        end
    end
end

concommand.Add("add_gang_xp", function(ply, cmd, args)
    if not args[1] or not args[2] then
        print("Usage: add_gang_xp <gangName> <xp>")
        return
    end
    AddGangXP(args[1], tonumber(args[2]))
end)

-- Server-side Network Handlers
net.Receive("RPMenu_CreateGang", function(len, ply)
    local gangName = net.ReadString()
    local gangColor = net.ReadColor()
    local password = net.ReadString()

    print("[RPMenu] CreateGang: Attempt by " .. ply:Nick() .. " for gang " .. gangName)

    local currentGang = ply:GetNWString("GangName", "")
    if currentGang != "" then
        ply:ChatPrint("You are already in a gang! Leave your current gang before creating a new one.")
        print("[RPMenu] CreateGang: Player " .. ply:Nick() .. " already in gang " .. currentGang)
        net.Start("RPMenu_UpdateGangStatus")
        net.WriteString(currentGang)
        net.Send(ply)
        SendGangData(ply)
        return
    end

    local existingGang = sql.Query("SELECT gang_name FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if existingGang and #existingGang > 0 then
        ply:ChatPrint("A gang with this name already exists!")
        print("[RPMenu] CreateGang: Gang name " .. gangName .. " already exists")
        return
    end

    local members = {}
    -- Check if player is already in the members list (shouldn't be, but for safety)
    local playerExists = false
    for _, member in ipairs(members) do
        if member.steamid == ply:SteamID() then
            playerExists = true
            break
        end
    end
    if not playerExists then
        table.insert(members, {steamid = ply:SteamID(), rank = "Leader"})
    end
    local membersJSON = util.TableToJSON(members)
    local colorJSON = util.TableToJSON({r = gangColor.r, g = gangColor.g, b = gangColor.b})
    local insertGang = sql.Query([[
        INSERT INTO darkrp_gangs (gang_name, gang_level, gang_color, gang_password, gang_upgrades, upgrade_points, members, gang_bank)
        VALUES (]] .. sql.SQLStr(gangName) .. [[, 1, ]] .. sql.SQLStr(colorJSON) .. [[, ]] .. sql.SQLStr(password) .. [[, '{}', 1, ]] .. sql.SQLStr(membersJSON) .. [[, 0)
    ]])
    if insertGang == false then
        local err = sql.LastError()
        ply:ChatPrint("Failed to create gang: " .. err)
        print("[RPMenu] CreateGang: Failed to create gang " .. gangName .. ": " .. err)
        return
    end

    ply:SetNWString("GangName", gangName)
    ply:ChatPrint("Gang '" .. gangName .. "' created successfully at level 1!")
    print("[RPMenu] CreateGang: Gang " .. gangName .. " created successfully for " .. ply:Nick())

    net.Start("RPMenu_UpdateGangStatus")
    net.WriteString(gangName)
    net.Send(ply)

    SendGangData(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            SendGangData(ply)
            print("[RPMenu] CreateGang: Retry SendGangData for " .. ply:Nick())
        end
    end)
end)

net.Receive("RPMenu_UpgradeGang", function(len, ply)
    local upgrade = net.ReadString()
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        print("[RPMenu] UpgradeGang: " .. ply:Nick() .. " not in a gang")
        return
    end

    print("[RPMenu] UpgradeGang: Attempt by " .. ply:Nick() .. " for " .. upgrade .. " in gang " .. gangName)
    local gangData = sql.QueryRow("SELECT gang_upgrades, upgrade_points FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] UpgradeGang: Gang data not found for " .. gangName)
        return
    end

    local upgrades = util.JSONToTable(gangData.gang_upgrades) or {}
    local points = tonumber(gangData.upgrade_points)
    if points < 1 then
        ply:ChatPrint("Not enough upgrade points!")
        print("[RPMenu] UpgradeGang: Not enough points for " .. gangName)
        return
    end

    local level = upgrades[upgrade] or 0
    if level >= 10 then
        ply:ChatPrint(upgrade .. " is already at max level!")
        print("[RPMenu] UpgradeGang: " .. upgrade .. " already at max level for " .. gangName)
        return
    end

    upgrades[upgrade] = level + 1
    points = points - 1
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET gang_upgrades = " .. sql.SQLStr(util.TableToJSON(upgrades)) .. ", upgrade_points = " .. points .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to upgrade: " .. sql.LastError())
        print("[RPMenu] UpgradeGang: Failed to update upgrades for " .. gangName .. ": " .. sql.LastError())
        return
    end

    ply:ChatPrint("Upgraded " .. upgrade .. " to level " .. (level + 1))
    print("[RPMenu] UpgradeGang: " .. upgrade .. " upgraded to level " .. (level + 1) .. " for " .. gangName)
    SendGangData(ply)
end)

net.Receive("RPMenu_DonateToBank", function(len, ply)
    local amount = net.ReadUInt(32)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        print("[RPMenu] DonateToBank: " .. ply:Nick() .. " not in a gang")
        return
    end

    local playerMoney = ply:getDarkRPVar("money") or 0
    if amount > playerMoney then
        ply:ChatPrint("You don't have enough money!")
        print("[RPMenu] DonateToBank: " .. ply:Nick() .. " has insufficient funds (" .. amount .. " > " .. playerMoney .. ")")
        return
    end

    local gangData = sql.QueryRow("SELECT gang_bank FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] DonateToBank: Gang data not found for " .. gangName)
        return
    end

    local newBank = (tonumber(gangData.gang_bank) or 0) + amount
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET gang_bank = " .. newBank .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to donate: " .. sql.LastError())
        print("[RPMenu] DonateToBank: Failed to update bank for " .. gangName .. ": " .. sql.LastError())
        return
    end

    ply:addMoney(-amount)
    ply:ChatPrint("Donated " .. amount .. " to the gang bank!")
    print("[RPMenu] DonateToBank: " .. ply:Nick() .. " donated " .. amount .. " to " .. gangName)

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
        print("[RPMenu] LeaveGang: " .. ply:Nick() .. " not in a gang")
        return
    end

    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] LeaveGang: Gang data not found for " .. gangName)
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    local newMembers = {}
    for _, member in ipairs(members) do
        if member.steamid != ply:SteamID() then
            table.insert(newMembers, member)
        end
    end

    local membersJSON = util.TableToJSON(newMembers)
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(membersJSON) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to leave gang: " .. sql.LastError())
        print("[RPMenu] LeaveGang: Failed to update members for " .. gangName .. ": " .. sql.LastError())
        return
    end

    ply:SetNWString("GangName", "")
    ply:ChatPrint("You have left the gang '" .. gangName .. "'!")
    print("[RPMenu] LeaveGang: " .. ply:Nick() .. " left gang " .. gangName)

    net.Start("RPMenu_UpdateGangStatus")
    net.WriteString("")
    net.Send(ply)

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_KickPlayer", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        print("[RPMenu] KickPlayer: " .. ply:Nick() .. " not in a gang")
        return
    end

    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] KickPlayer: Gang data not found for " .. gangName)
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
        print("[RPMenu] KickPlayer: " .. ply:Nick() .. " is not a leader")
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

    local newMembers = {}
    local targetFound = false
    for _, member in ipairs(members) do
        if member.steamid == steamID then
            targetFound = true
        else
            table.insert(newMembers, member)
        end
    end

    if not targetFound then
        ply:ChatPrint("Player not found in gang!")
        print("[RPMenu] KickPlayer: Player " .. steamID .. " not found in gang " .. gangName)
        return
    end

    local membersJSON = util.TableToJSON(newMembers)
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(membersJSON) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to kick player: " .. sql.LastError())
        print("[RPMenu] KickPlayer: Failed to update members for " .. gangName .. ": " .. sql.LastError())
        return
    end

    if IsValid(targetPlayer) then
        targetPlayer:SetNWString("GangName", "")
        targetPlayer:ChatPrint("You have been kicked from the gang '" .. gangName .. "'!")
        net.Start("RPMenu_UpdateGangStatus")
        net.WriteString("")
        net.Send(targetPlayer)
    end

    ply:ChatPrint("Player has been kicked from the gang!")
    print("[RPMenu] KickPlayer: " .. steamID .. " kicked from gang " .. gangName .. " by " .. ply:Nick())

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
        print("[RPMenu] SetRank: " .. ply:Nick() .. " not in a gang")
        return
    end

    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] SetRank: Gang data not found for " .. gangName)
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
        print("[RPMenu] SetRank: " .. ply:Nick() .. " is not a leader or vice leader")
        return
    end

    local steamID = net.ReadString()
    local newRank = net.ReadString()
    if not (newRank == "Recruit" or newRank == "Vice Leader" or newRank == "Leader") then
        ply:ChatPrint("Invalid rank!")
        print("[RPMenu] SetRank: Invalid rank " .. newRank .. " by " .. ply:Nick())
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
        print("[RPMenu] SetRank: Player " .. steamID .. " not found in gang " .. gangName)
        return
    end

    if (targetRank == "Leader" or targetRank == "Vice Leader") and playerRank != "Leader" then
        ply:ChatPrint("Only leaders can modify the rank of leaders and vice leaders!")
        print("[RPMenu] SetRank: " .. ply:Nick() .. " cannot modify rank of " .. targetRank)
        return
    end

    if newRank == "Leader" and playerRank != "Leader" then
        ply:ChatPrint("Only leaders can set the Leader rank!")
        print("[RPMenu] SetRank: " .. ply:Nick() .. " cannot set Leader rank")
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

    local membersJSON = util.TableToJSON(members)
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(membersJSON) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to set rank: " .. sql.LastError())
        print("[RPMenu] SetRank: Failed to update members for " .. gangName .. ": " .. sql.LastError())
        return
    end

    ply:ChatPrint("Set rank of player to " .. newRank .. "!")
    print("[RPMenu] SetRank: " .. steamID .. " rank set to " .. newRank .. " in gang " .. gangName .. " by " .. ply:Nick())

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_DisbandGang", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        print("[RPMenu] DisbandGang: " .. ply:Nick() .. " not in a gang")
        return
    end

    local gangData = sql.QueryRow("SELECT gang_password, members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] DisbandGang: Gang data not found for " .. gangName)
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
        ply:ChatPrint("Only the gang leader can disband the gang!")
        print("[RPMenu] DisbandGang: " .. ply:Nick() .. " is not a leader")
        return
    end

    local password = net.ReadString()
    if gangData.gang_password != password then
        ply:ChatPrint("Incorrect password!")
        print("[RPMenu] DisbandGang: Incorrect password for " .. gangName)
        return
    end

    local deleteQuery = sql.Query("DELETE FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if deleteQuery == false then
        ply:ChatPrint("Failed to disband gang: " .. sql.LastError())
        print("[RPMenu] DisbandGang: Failed to delete gang " .. gangName .. ": " .. sql.LastError())
        return
    end

    print("[RPMenu] DisbandGang: Gang " .. gangName .. " disbanded by " .. ply:Nick())
    ply:ChatPrint("Gang '" .. gangName .. "' has been disbanded!")

    -- Notify all members and update their status
    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            p:SetNWString("GangName", "")
            p:ChatPrint("Your gang '" .. gangName .. "' has been disbanded by the leader!")
            net.Start("RPMenu_UpdateGangStatus")
            net.WriteString("")
            net.Send(p)
        end
    end
end)

net.Receive("RPMenu_RequestGangData", function(len, ply)
    print("[RPMenu] RequestGangData: Requested by " .. ply:Nick())
    SendGangData(ply)
end)

hook.Add("PlayerInitialSpawn", "RPMenu_SendGangDataOnJoin", function(ply)
    print("[RPMenu] PlayerInitialSpawn: Checking gang for " .. ply:Nick())
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
    print("[RPMenu] PlayerInitialSpawn: Set GangName to " .. gangName .. " for " .. ply:Nick())

    timer.Simple(1, function()
        if not IsValid(ply) then return end
        SendGangData(ply)
    end)
end)

print("[RPMenu] Server-side loaded successfully")