print("[DEBUG] sh_mission_giver.lua loaded")

DEFINE_BASECLASS("npc_base")

ENT = {}
ENT.Base = "npc_base"
ENT.PrintName = "Mission Giver"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.ClassName = "npc_mission_giver"

ENT.MissionSubset = {
    ["KillThief"] = {
        name = "Kill the Thief",
        description = "Eliminate a troublesome thief.",
        levelRequired = 1,
        xpReward = 50
    },
    ["DeliverPackage"] = {
        name = "Deliver Package",
        description = "Drop off a package at the warehouse.",
        levelRequired = 3,
        xpReward = 75
    }
}

if SERVER then
    AddCSLuaFile()

    function ENT:Initialize()
        BaseClass.Initialize(self) -- Call base init
        self:SetModel("models/eli.mdl") -- Override model if desired
        self:SetNWString("NPCName", "Mission Giver Eli")
        --self:SetName("MissionGiver")
    end

    function ENT:GetMissions()
        return self.MissionSubset
    end
end

if CLIENT then
    function ENT:GetMissions() -- Client needs this for UI
        return self.MissionSubset
    end
end

scripted_ents.Register(ENT, "npc_mission_giver")