--[[ if CLIENT then
    print("[DEBUG] Client: Inside the CLIENT if block")
    
    local ENT = scripted_ents.GetStored("sent_mission_npc")
    if not ENT then
        print("[ERROR] Client: Could not find sent_mission_npc entity")
        return
    end

    ENT = ENT.t
    ENT.RenderGroup = RENDERGROUP_OPAQUE   

    function ENT:Initialize()
        self:SetupBones()
        print("[DEBUG] Client: NPC " .. self:EntIndex() .. " initialized with model " .. (self:GetModel() or "nil"))
    end

    function ENT:Draw()
        self:SetRenderMode(RENDERMODE_NORMAL)
        self:DrawModel()
        print("[DEBUG] Client: Drawing NPC " .. self:EntIndex() .. " with model " .. (self:GetModel() or "nil"))
    end
end ]]

if CLIENT then
    net.Receive("OpenMissionDialog", function()
        local npc = net.ReadEntity()
        if not IsValid(npc) then return end

        local frame = vgui.Create("DFrame")
        frame:SetSize(400, 300)
        frame:Center()
        frame:SetTitle("Mission NPC: " .. npc:GetName())
        frame:MakePopup()

        local missionList = vgui.Create("DListView", frame)
        missionList:Dock(FILL)
        missionList:AddColumn("Mission")
        missionList:AddColumn("Level")
        missionList:AddColumn("XP Reward")

        local missions = {
            {id = "KillThief", name = "Kill the Thief", level = 1, xp = 50}
        }
        for _, m in pairs(missions) do
            missionList:AddLine(m.name, m.level, m.xp)
        end

        missionList.OnRowSelected = function(self, rowIndex, row)
            local missionId = missions[rowIndex].id
            net.Start("StartMission")
            net.WriteString(missionId)
            net.SendToServer()
            frame:Close()
        end
    end)
end

