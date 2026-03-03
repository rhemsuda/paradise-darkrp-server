AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
    self:SetModel(self:GetModel() ~= "models/error.mdl" and self:GetModel() or "models/mossman.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetNPCType(self:GetNPCType() or "generic")
    -- Standing collision (feet on ground). Slight negative Z so entity sits on ground.
    self:SetCollisionBounds(Vector(-14, -14, -2), Vector(14, 14, 70))
    -- Idle pose: run next tick after SetModel (wiki). Try multiple sequence names, then ACT_IDLE, then first non-ragdoll.
    local selfEnt = self
    timer.Simple(0, function()
        if not IsValid(selfEnt) then return end
        local seq = selfEnt:LookupSequence("idle")
        if not seq or seq <= 0 then seq = selfEnt:LookupSequence("idle_all_01") end
        if not seq or seq <= 0 then seq = selfEnt:LookupSequence("idle_subtle") end
        if (not seq or seq <= 0) and selfEnt.SelectWeightedSequence then
            seq = selfEnt:SelectWeightedSequence(ACT_IDLE)
        end
        if not seq or seq <= 0 then
            local list = selfEnt:GetSequenceList()
            if list then
                for i = 0, 40 do
                    local name = list[i]
                    if name and name ~= "ragdoll" and name ~= "reference" then seq = i break end
                end
            end
        end
        if seq and seq > 0 then
            selfEnt:ResetSequence(seq)
            selfEnt:SetPlaybackRate(1)
        end
    end)
end

function ENT:SetNPCType(t)
    self:SetNWString("NPCType", t or "generic")
end

function ENT:GetNPCType()
    return self:GetNWString("NPCType", "generic")
end

local HELLO_COOLDOWN = 120

-- Wanted players are refused except by drugdealer, gang, blackmarket, mechanic.
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    local dist = activator:GetPos():Distance(self:GetPos())
    if dist > 120 then return end
    local npcType = self:GetNPCType()
    if activator.isWanted and activator:isWanted() then
        if not (Paradise.NPCs and Paradise.NPCs.DealsWithWantedType and Paradise.NPCs.DealsWithWantedType(npcType)) then
            DarkRP.notify(activator, 1, 4, "This NPC refuses to deal with wanted criminals.")
            return
        end
    end
    local sid = activator:SteamID()
    -- Hello audio on E only (2 min cooldown per player to avoid spam).
    self._lastGreet = self._lastGreet or {}
    local last = self._lastGreet[sid] or 0
    if CurTime() - last >= HELLO_COOLDOWN then
        self._lastGreet[sid] = CurTime()
        self:EmitSound("vo/npc/male01/hi01.wav", 60, 100)
    end
    net.Start("Paradise_NPCOpenMenu")
    net.WriteString(npcType)
    net.WriteEntity(self)
    local accepted = (Paradise.NPCs and Paradise.NPCs.PlayerAcceptedMissions and Paradise.NPCs.PlayerAcceptedMissions[sid]) or {}
    local ids = {}
    for id, _ in pairs(accepted) do table.insert(ids, id) end
    net.WriteUInt(#ids, 16)
    for _, id in ipairs(ids) do net.WriteString(id) end
    local completed = (Paradise.NPCs and Paradise.NPCs.PlayerCompletedMissions and Paradise.NPCs.PlayerCompletedMissions[sid]) or {}
    local compList = {}
    for id, ntype in pairs(completed) do table.insert(compList, { id = id, npcType = ntype }) end
    net.WriteUInt(#compList, 16)
    for _, e in ipairs(compList) do net.WriteString(e.id) net.WriteString(e.npcType or "generic") end
    net.Send(activator)
end

