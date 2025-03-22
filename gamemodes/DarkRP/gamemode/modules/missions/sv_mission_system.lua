if SERVER then
    AddCSLuaFile("modules/npc/cl_npc_dialog.lua")
    include("modules/npc/sh_mission_giver.lua") -- Ensure mission giver is loaded

    local function StartMission(ply, npc, missionId)
        local missions = npc:GetMissions()
        local mission = missions[missionId]
        if not mission then return end

        local level = ply:GetNWInt("Level", 0)
        if level < mission.levelRequired then
            DarkRP.notify(ply, 1, 4, "You need level " .. mission.levelRequired .. " for this mission.")
            return
        end

        if ply:GetNWString("ActiveMission", "") ~= "" then
            DarkRP.notify(ply, 1, 4, "You already have an active mission!")
            return
        end

        ply:SetNWString("ActiveMission", missionId)
        ply:SetNWEntity("MissionNPC", npc)
        DarkRP.notify(ply, 0, 4, "Mission started: " .. mission.name)
    end

    net.Receive("StartMission", function(len, ply)
        local missionId = net.ReadString()
        local npc = ply:GetNWEntity("MissionNPC")
        if not IsValid(npc) or npc:GetClass() ~= "npc_mission_giver" then return end
        StartMission(ply, npc, missionId)
    end)

    hook.Add("OnNPCKilled", "CheckMissionCompletion", function(npc, attacker, inflictor)
        if not IsValid(attacker) or not attacker:IsPlayer() then return end
        local missionId = attacker:GetNWString("ActiveMission", "")
        if missionId == "KillThief" then
            local missionNPC = attacker:GetNWEntity("MissionNPC")
            if not IsValid(missionNPC) then return end
            local missions = missionNPC:GetMissions()
            local mission = missions[missionId]
            local xp = attacker:GetNWInt("Experience", 0) + mission.xpReward
            attacker:SetNWInt("Experience", xp)
            attacker:SetNWString("ActiveMission", "")
            attacker:SetNWEntity("MissionNPC", nil)
            DarkRP.notify(attacker, 0, 4, "Mission completed! +" .. mission.xpReward .. " XP")
        end
    end)
end