if CLIENT then
    print("[DEBUG] Client: Inside cl_npc_dialog.lua")

    net.Receive("OpenNPCDialog", function()
        local npc = net.ReadEntity()
        if not IsValid(npc) then return end

        local frame = vgui.Create("DFrame")
        frame:SetSize(400, 300)
        frame:Center()
        frame:SetTitle("NPC: " .. npc:GetNWString("NPCName", "Unnamed"))
        --frame:SetTitle("NPC: " .. (npc:GetName() or "Unnamed"))
        frame:MakePopup()

        if npc:GetClass() == "npc_mission_giver" then
            local missionList = vgui.Create("DListView", frame)
            missionList:Dock(FILL)
            missionList:AddColumn("Mission")
            missionList:AddColumn("Level")
            missionList:AddColumn("XP Reward")

            local missions = npc:GetMissions()
            for id, mission in pairs(missions) do
                missionList:AddLine(mission.name, mission.levelRequired, mission.xpReward).missionId = id
            end

            missionList.OnRowSelected = function(self, rowIndex, row)
                local missionId = row.missionId
                net.Start("StartMission")
                net.WriteString(missionId)
                net.SendToServer()
                frame:Close()
            end
        else
            local label = vgui.Create("DLabel", frame)
            label:SetText("This NPC has no actions yet.")
            label:Dock(FILL)
            label:SetContentAlignment(5)
        end
    end)
end