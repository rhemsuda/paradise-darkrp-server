-- Debug print to confirm the file is loading
print("[RPMenu] sv_rpmenu.lua file found, attempting to load")

if not SERVER then return end

-- Networking messages
util.AddNetworkString("RPMenu_CreateGang")
util.AddNetworkString("RPMenu_JobChange")
util.AddNetworkString("RPMenu_RequestGangData")
util.AddNetworkString("RPMenu_SendGangData")
util.AddNetworkString("RPMenu_UpdateGangStatus")
util.AddNetworkString("RPMenu_SendTopGangs")
util.AddNetworkString("RPMenu_UpgradeGang")
util.AddNetworkString("RPMenu_RecoverGang")

-- SQL table creation and migration for gangs
sql.Begin()
    -- Create table if it doesn't exist
    local createGangsTable = sql.Query([[
        CREATE TABLE IF NOT EXISTS darkrp_gangs (
            gang_name TEXT PRIMARY KEY,
            gang_level INTEGER DEFAULT 1,
            gang_color TEXT,
            gang_password TEXT,
            gang_upgrades TEXT DEFAULT '{}',
            upgrade_points INTEGER DEFAULT 0,
            members TEXT DEFAULT '[]'
        )
    ]])
    if createGangsTable == false then
        print("[RPMenu] Failed to create darkrp_gangs table: " .. sql.LastError())
    else
        print("[RPMenu] Created or verified darkrp_gangs table")
    end

    -- Migrate existing table to add missing columns
    local columns = sql.Query("PRAGMA table_info(darkrp_gangs)")
    local columnExists = {}
    if columns then
        for _, column in ipairs(columns) do
            columnExists[column.name] = true
        end
    end

    if not columnExists.gang_password then
        local addPassword = sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN gang_password TEXT")
        if addPassword == false then
            print("[RPMenu] Failed to add gang_password column: " .. sql.LastError())
        else
            print("[RPMenu] Added gang_password column")
        end
    end

    if not columnExists.upgrade_points then
        local addPoints = sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN upgrade_points INTEGER DEFAULT 0")
        if addPoints == false then
            print("[RPMenu] Failed to add upgrade_points column: " .. sql.LastError())
        else
            print("[RPMenu] Added upgrade_points column")
        end
    end

    if not columnExists.members then
        local addMembers = sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN members TEXT DEFAULT '[]'")
        if addMembers == false then
            print("[RPMenu] Failed to add members column: " .. sql.LastError())
        else
            print("[RPMenu] Added members column")
        end
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
    print("[RPMenu] SendGangData: Preparing data - Name: " .. gangName .. ", Level: " .. gangData.gang_level .. ", Members: " .. #members .. ", Points: " .. (gangData.upgrade_points or 0))

    net.Start("RPMenu_SendGangData")
    net.WriteString(gangName)
    net.WriteUInt(tonumber(gangData.gang_level), 8)
    net.WriteString(gangData.gang_color or util.TableToJSON({r = 255, g = 255, b = 255}))
    net.WriteTable(members)
    net.WriteString(gangData.gang_upgrades or "{}")
    net.WriteUInt(tonumber(gangData.upgrade_points or 0), 8)
    net.Send(ply)
    print("[RPMenu] SendGangData: Sent data to " .. ply:Nick())
end

-- Function to send top gangs to a player
local function SendTopGangs(ply)
    if not IsValid(ply) then
        print("[RPMenu] SendTopGangs: Invalid player")
        return
    end

    local topGangs = sql.Query("SELECT gang_name, gang_level FROM darkrp_gangs ORDER BY gang_level DESC, gang_name ASC LIMIT 5")
    if topGangs == nil then
        print("[RPMenu] Failed to fetch top gangs: " .. tostring(sql.LastError()))
        topGangs = {}
    elseif topGangs == false then
        topGangs = {}
    end

    net.Start("RPMenu_SendTopGangs")
    net.WriteTable(topGangs)
    net.Send(ply)
    print("[RPMenu] SendTopGangs: Sent top gangs to " .. ply:Nick())
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
    -- Placeholder XP calculation (1000 XP per level)
    local totalXP = (level - 1) * 1000 + xp
    local newLevel = math.min(math.floor(totalXP / 1000) + 1, 20)
    if newLevel > level then
        points = points + (newLevel - level) -- 1 point per level-up
        local updateQuery = sql.Query("UPDATE darkrp_gangs SET gang_level = " .. newLevel .. ", upgrade_points = " .. points .. " WHERE gang_name = " .. sql.SQLStr(gangName))
        if updateQuery == false then
            print("[RPMenu] Failed to update gang level and points: " .. sql.LastError())
            return
        end
        print("[RPMenu] Gang " .. gangName .. " leveled up to " .. newLevel .. " with " .. points .. " upgrade points")
    end
    -- Notify players in the gang
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNWString("GangName", "") == gangName then
            SendGangData(ply)
        end
    end
end

-- Console command for testing XP addition
concommand.Add("add_gang_xp", function(ply, cmd, args)
    if not args[1] or not args[2] then
        print("Usage: add_gang_xp <gangName> <xp>")
        return
    end
    AddGangXP(args[1], tonumber(args[2]))
end)

-- Handle gang creation
net.Receive("RPMenu_CreateGang", function(len, ply)
    local gangName = net.ReadString()
    local gangColor = net.ReadColor()
    local password = net.ReadString()
    local level = net.ReadUInt(8)

    print("[RPMenu] CreateGang: Attempt by " .. ply:Nick() .. " for gang " .. gangName .. " at level " .. level)

    -- Validate level
    if level < 1 or level > 20 then
        ply:ChatPrint("Invalid level selected! Must be between 1 and 20.")
        print("[RPMenu] CreateGang: Invalid level " .. level)
        return
    end

    -- Check if player is already in a gang
    local currentGang = ply:GetNWString("GangName", "")
    if currentGang ~= "" then
        ply:ChatPrint("You are already in a gang! Leave your current gang before creating a new one.")
        print("[RPMenu] CreateGang: Player " .. ply:Nick() .. " already in gang " .. currentGang)
        -- Refresh client to show in-gang interface
        net.Start("RPMenu_UpdateGangStatus")
        net.WriteString(currentGang)
        net.Send(ply)
        SendGangData(ply)
        return
    end

    -- Check if gang name already exists
    local existingGang = sql.Query("SELECT gang_name FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if existingGang and #existingGang > 0 then
        ply:ChatPrint("A gang with this name already exists!")
        print("[RPMenu] CreateGang: Gang name " .. gangName .. " already exists")
        return
    end

    -- Initialize members with the creator as Leader
    local members = {{steamid = ply:SteamID(), rank = "Leader"}}
    local membersJSON = util.TableToJSON(members)

    -- Insert new gang into database
    local colorJSON = util.TableToJSON({r = gangColor.r, g = gangColor.g, b = gangColor.b})
    local insertGang = sql.Query([[
        INSERT INTO darkrp_gangs (gang_name, gang_level, gang_color, gang_password, gang_upgrades, upgrade_points, members)
        VALUES (]] .. sql.SQLStr(gangName) .. [[, ]] .. level .. [[, ]] .. sql.SQLStr(colorJSON) .. [[, ]] .. sql.SQLStr(password) .. [[, '{}', ]] .. level .. [[, ]] .. sql.SQLStr(membersJSON) .. [[)
    ]])
    if insertGang == false then
        local err = sql.LastError()
        ply:ChatPrint("Failed to create gang: " .. err)
        print("[RPMenu] CreateGang: Failed to create gang " .. gangName .. ": " .. err)
        return
    end

    ply:SetNWString("GangName", gangName)
    ply:ChatPrint("Gang '" .. gangName .. "' created successfully at level " .. level .. "!")
    print("[RPMenu] CreateGang: Gang " .. gangName .. " created successfully for " .. ply:Nick())

    net.Start("RPMenu_UpdateGangStatus")
    net.WriteString(gangName)
    net.Send(ply)

    -- Send updated gang data and top gangs, with retry
    SendGangData(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            SendGangData(ply)
            print("[RPMenu] CreateGang: Retry SendGangData for " .. ply:Nick())
        end
    end)
    SendTopGangs(ply)
end)

-- Handle gang recovery
net.Receive("RPMenu_RecoverGang", function(len, ply)
    local gangName = net.ReadString()
    local password = net.ReadString()

    print("[RPMenu] RecoverGang: Attempt by " .. ply:Nick() .. " for gang " .. gangName)

    -- Check if player is already in a gang
    local currentGang = ply:GetNWString("GangName", "")
    if currentGang ~= "" then
        ply:ChatPrint("You are already in a gang! Leave your current gang first.")
        print("[RPMenu] RecoverGang: Player " .. ply:Nick() .. " already in gang " .. currentGang)
        -- Refresh client to show in-gang interface
        net.Start("RPMenu_UpdateGangStatus")
        net.WriteString(currentGang)
        net.Send(ply)
        SendGangData(ply)
        return
    end

    -- Verify gang exists and password is correct
    local gangData = sql.QueryRow("SELECT gang_password, members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang not found!")
        print("[RPMenu] RecoverGang: Gang " .. gangName .. " not found")
        return
    end
    if gangData.gang_password ~= password then
        ply:ChatPrint("Incorrect password!")
        print("[RPMenu] RecoverGang: Incorrect password for " .. gangName)
        return
    end

    -- Check if there's already a leader
    local members = util.JSONToTable(gangData.members or "[]") or {}
    for _, member in ipairs(members) do
        if member.rank == "Leader" then
            ply:ChatPrint("Gang already has a leader!")
            print("[RPMenu] RecoverGang: Gang " .. gangName .. " already has a leader")
            return
        end
    end

    -- Add player as Leader
    table.insert(members, {steamid = ply:SteamID(), rank = "Leader"})
    local membersJSON = util.TableToJSON(members)
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(membersJSON) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to recover gang: " .. sql.LastError())
        print("[RPMenu] RecoverGang: Failed to update members for " .. gangName .. ": " .. sql.LastError())
        return
    end

    ply:SetNWString("GangName", gangName)
    ply:ChatPrint("Successfully recovered gang '" .. gangName .. "' as Leader!")
    print("[RPMenu] RecoverGang: " .. ply:Nick() .. " recovered gang " .. gangName .. " as Leader")

    net.Start("RPMenu_UpdateGangStatus")
    net.WriteString(gangName)
    net.Send(ply)

    -- Send updated gang data and top gangs, with retry
    SendGangData(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            SendGangData(ply)
            print("[RPMenu] RecoverGang: Retry SendGangData for " .. ply:Nick())
        end
    end)
    SendTopGangs(ply)
end)

-- Handle job change
net.Receive("RPMenu_JobChange", function(len, ply)
    local jobTeam = net.ReadUInt(16)
    local job = RPExtraTeams[jobTeam]
    if not job then
        ply:ChatPrint("Invalid job selected!")
        print("[RPMenu] JobChange: Invalid job team " .. jobTeam .. " for " .. ply:Nick())
        return
    end

    ply:changeTeam(jobTeam, true)
    ply:ChatPrint("You have become a " .. job.name .. "!")
    print("[RPMenu] JobChange: " .. ply:Nick() .. " became " .. job.name)
end)

-- Handle upgrade request
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

-- Handle gang data request
net.Receive("RPMenu_RequestGangData", function(len, ply)
    print("[RPMenu] RequestGangData: Requested by " .. ply:Nick())
    SendGangData(ply)
    SendTopGangs(ply)
end)

-- Send gang data and top gangs on player join
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
        SendTopGangs(ply)
    end)
end)

-- This print will always show to confirm successful load
print("[RPMenu] Server-side loaded successfully")