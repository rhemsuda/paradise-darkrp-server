print("[DEBUG] sh_npc_dialog.lua loaded")

--[[ ENT = {}
ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "Mission NPC"
ENT.Author = "Kyle"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.ClassName = "sent_mission_npc"

if SERVER then
    print("[DEBUG] Server: Inside the SERVER if block")
    util.AddNetworkString("OpenMissionDialog")
    util.AddNetworkString("StartMission")

    function ENT:Initialize()
        self:SetModel("models/Humans/Group01/male_07.mdl")
        self:SetHullType(HULL_HUMAN)
        self:SetHullSizeNormal()
        self:SetNPCState(NPC_STATE_SCRIPT)
        self:SetSolid(SOLID_BBOX)
        self:SetUseType(SIMPLE_USE)
        self:CapabilitiesAdd(bit.bor(CAP_ANIMATEDFACE, CAP_TURN_HEAD))
        self:DropToFloor()
        print("[DEBUG] Server: NPC " .. self:EntIndex() .. " spawned with model " .. self:GetModel())
    end

    function ENT:Use(activator, caller)
        if not IsValid(caller) or not caller:IsPlayer() then return end
        net.Start("OpenMissionDialog")
        net.Send(caller)
    end

    function ENT:UpdateTransmitState()
        return TRANSMIT_ALWAYS
    end
end

if CLIENT then
    print("[DEBUG] Client: Inside the CLIENT base if block")
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
end

if SERVER then
    scripted_ents.Register(ENT, "sent_mission_npc")
    print("[DEBUG] Server: Registered sent_mission_npc")
end

if CLIENT then
    scripted_ents.Register(ENT, "sent_mission_npc")
    print("[DEBUG] Client: Registered sent_mission_npc")
end ]]