if SERVER then
    -- Ensure MySQL tables are initialized (already in sv_data.lua)
    -- Populate darkrp_levelinfo with example data if empty
    hook.Add("Initialize", "SetupLevelingSystem", function()
        MySQLite.query("SELECT COUNT(*) as count FROM darkrp_levelinfo", function(result)
            if result and tonumber(result[1].count) == 0 then
                local levelData = { 
                    {level = 1, experienceRequired = 0},
                    {level = 2, experienceRequired = 100},
                    {level = 3, experienceRequired = 210},
                    {level = 4, experienceRequired = 325},
                    {level = 5, experienceRequired = 512},
                    {level = 6, experienceRequired = 804},
                    {level = 7, experienceRequired = 1150},
                    {level = 8, experienceRequired = 1580},
                    {level = 9, experienceRequired = 2130},
                    {level = 10, experienceRequired = 2990},
                    {level = 11, experienceRequired = 3800},
                    {level = 12, experienceRequired = 5010},
                    {level = 13, experienceRequired = 6405},
                    {level = 14, experienceRequired = 7930},
                    {level = 15, experienceRequired = 9670},
                    {level = 16, experienceRequired = 11640},
                    {level = 17, experienceRequired = 13420},
                    {level = 18, experienceRequired = 16247},
                    {level = 19, experienceRequired = 20320},
                    {level = 20, experienceRequired = 24804},
                    {level = 21, experienceRequired = 29106},
                    {level = 22, experienceRequired = 36220},
                    {level = 23, experienceRequired = 43108},
                    {level = 24, experienceRequired = 51200},
                    {level = 25, experienceRequired = 60960},
                    {level = 26, experienceRequired = 71320},
                    {level = 27, experienceRequired = 83200},
                    {level = 28, experienceRequired = 96720},
                    {level = 29, experienceRequired = 112000},
                    {level = 30, experienceRequired = 129000},
                    {level = 31, experienceRequired = 147800},
                    {level = 32, experienceRequired = 168500},
                    {level = 33, experienceRequired = 191200},
                    {level = 34, experienceRequired = 216000},
                    {level = 35, experienceRequired = 243000},
                    {level = 36, experienceRequired = 272320},
                    {level = 37, experienceRequired = 304080},
                    {level = 38, experienceRequired = 338400},
                    {level = 39, experienceRequired = 375400},
                    {level = 40, experienceRequired = 415200},
                    {level = 41, experienceRequired = 457920},
                    {level = 42, experienceRequired = 503680},
                    {level = 43, experienceRequired = 552600},
                    {level = 44, experienceRequired = 604800},
                    {level = 45, experienceRequired = 660400},
                    {level = 46, experienceRequired = 719520},
                    {level = 47, experienceRequired = 782280},
                    {level = 48, experienceRequired = 848800},
                    {level = 49, experienceRequired = 919200},
                    {level = 50, experienceRequired = 993600}
                }
                for _, data in ipairs(levelData) do
                    MySQLite.query(string.format("INSERT INTO darkrp_levelinfo (level, experienceRequired) VALUES (%d, %d)", data.level, data.experienceRequired))
                end
            end
        end)
    end)

    hook.Add("PlayerInitialSpawn", "LoadPlayerLevel", function(ply)
        local uid = ply:UniqueID() -- Using UniqueID as BIGINT in MySQL
        MySQLite.query(string.format("SELECT experience FROM darkrp_player WHERE uid = %d", uid), function(data)
            if data and data[1] then
                ply:SetNWInt("Experience", tonumber(data[1].experience) or 0)
            else
                -- New player: Insert default values
                MySQLite.query(string.format(
                    "INSERT INTO darkrp_player (uid, rpname, salary, wallet, experience) VALUES (%d, %s, 30, 0, 0)",
                    uid, MySQLite.SQLStr(ply:Nick())
                ))
                ply:SetNWInt("Experience", 0)
            end

            -- Calculate level based on XP
            MySQLite.query("SELECT level, experienceRequired FROM darkrp_levelinfo ORDER BY level ASC", function(levels)
                local xp = ply:GetNWInt("Experience", 0)
                local currentLevel = 1
                for _, lvl in ipairs(levels) do
                    if xp >= tonumber(lvl.experienceRequired) then
                        currentLevel = tonumber(lvl.level)
                    else
                        break
                    end
                end
                ply:SetNWInt("Level", currentLevel)
            end)
        end)
    end)

    -- Function to add XP and handle leveling
    local function AddXP(ply, amount)
        local uid = ply:UniqueID()
        local currentXP = ply:GetNWInt("Experience", 0)
        local newXP = currentXP + amount

        -- Update XP in MySQL and on player
        MySQLite.query(string.format("UPDATE darkrp_player SET experience = %d WHERE uid = %d", newXP, uid))
        ply:SetNWInt("Experience", newXP)

        -- Check for level-up
        MySQLite.query("SELECT level, experienceRequired FROM darkrp_levelinfo ORDER BY level ASC", function(levels)
            local currentLevel = ply:GetNWInt("Level", 1)
            local newLevel = currentLevel
            for _, lvl in ipairs(levels) do
                if newXP >= tonumber(lvl.experienceRequired) then
                    newLevel = tonumber(lvl.level)
                else
                    break
                end
            end
            if newLevel > currentLevel then
                ply:SetNWInt("Level", newLevel)
                ply:ChatPrint("You’ve leveled up to Level " .. newLevel .. "!")
            end
        end)
    end

    -- Example: Gain XP on kill
    hook.Add("PlayerDeath", "XPOnKill", function(victim, inflictor, attacker)
        if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
            AddXP(attacker, 50)
            attacker:ChatPrint("You gained 50 XP for a kill!")
        end
    end)

    -- Command to check XP and level
    concommand.Add("check_xp", function(ply)
        local xp = ply:GetNWInt("Experience", 0)
        local level = ply:GetNWInt("Level", 1)
        ply:ChatPrint("Level: " .. level .. " | XP: " .. xp)
    end)
end