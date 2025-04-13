print("[DEBUG] sh_npc_base.lua loaded")

ENT = {}
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Base NPC"
ENT.Author = "Kyle"
ENT.Spawnable = false
ENT.ClassName = "npc_base"

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("OpenNPCDialog")
    util.AddNetworkString("StartMission")
    util.PrecacheModel("models/eli.mdl")

    function ENT:Initialize()
        self:SetModel("models/eli.mdl")
        self:PhysicsInit(SOLID_BBOX)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetUseType(SIMPLE_USE)
        timer.Simple(0, function()
            if IsValid(self) then
                self:DropToFloor()
                print("[DEBUG] Server: NPC " .. self:EntIndex() .. " (" .. self:GetClass() .. ") spawned at " .. tostring(self:GetPos()))
            end
        end)
    end

    function ENT:Use(activator, caller)
        print("[DEBUG] Server: Attempting to interact with the NPC")
        if not IsValid(caller) or not caller:IsPlayer() then return end
        net.Start("OpenNPCDialog")
        net.WriteEntity(self)
        net.Send(caller)
    end

    function ENT:UpdateTransmitState()
        return TRANSMIT_ALWAYS
    end
end

if CLIENT then
    ENT.RenderGroup = RENDERGROUP_OPAQUE

    function ENT:Initialize()
        self:SetupBones()
        self:SetRenderMode(RENDERMODE_NORMAL)
        print("[DEBUG] Client: NPC " .. self:EntIndex() .. " (" .. self:GetClass() .. ") initialized with model " .. (self:GetModel() or "nil"))
    end

    function ENT:Draw()
        self:DrawModel()
    end
end

scripted_ents.Register(ENT, "npc_base2")