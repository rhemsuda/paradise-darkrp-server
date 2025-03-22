if SERVER then
    local Missions = {
        ["KillThief"] = {
            name = "Kill the Thief",
            description = "Eliminate a troublesome thief.",
            levelRequired = 1,
            xpReward = 50,
            onStart = function(ply)
                ply:SetNWString("ActiveMission", "KillThief")
                ply:ChatPrint("Mission started: Kill the Thief.")
            end,
            onComplete = function(ply)
                local xp = ply:GetNWInt("Experience", 0) + 50
                ply:SetNWInt("Experience", xp)
                ply:SetNWString("ActiveMission", "")
                ply:ChatPrint("Mission completed! +50 XP")
            end
        }
    }

    net.Receive("StartMission", function(len, ply)
        local missionId = net.ReadString()
        local mission = Missions[missionId]
        if not mission then return end

        local uid = ply:UniqueID()
        local currentLevel = ply:GetNWInt("Level", 0)
        if currentLevel < mission.levelRequired then
            DarkRP.notify(ply, 1, 4, "You need level " .. mission.levelRequired .. " for this mission.")
            return
        end

        MySQLite.query("SELECT missionId FROM missions WHERE uid = " .. uid .. ";", function(data)
            if data and data[1] then
                DarkRP.notify(ply, 1, 4, "You already have an active mission!")
                return
            end
            MySQLite.query("INSERT INTO missions (uid, missionId) VALUES (" .. uid .. ", '" .. missionId .. "')")
            mission.onStart(ply)
        end)
    end)

    -- Example completion trigger (e.g., killing an NPC)
    hook.Add("OnNPCKilled", "CheckMissionCompletion", function(npc, attacker, inflictor)
        if not IsValid(attacker) or not attacker:IsPlayer() then return end
        local uid = attacker:UniqueID()
        MySQLite.query("SELECT missionId FROM missions WHERE uid = " .. uid .. ";", function(data)
            if not data or not data[1] then return end
            local missionId = data[1].missionId
            if missionId == "KillThief" then
                Missions[missionId].onComplete(attacker)
                MySQLite.query("DELETE FROM missions WHERE uid = " .. uid .. ";")
            end
        end)
    end)
end