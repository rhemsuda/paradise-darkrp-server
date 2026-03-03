include("shared.lua")

-- Apply standing idle sequence on client so the pose renders (server sequence may not replicate in time).
function ENT:Initialize()
    self._idleSeqSet = false
end

local function pickIdleSequence(ent)
    local seq = ent:LookupSequence("idle")
    if seq and seq > 0 then return seq end
    seq = ent:LookupSequence("idle_all_01")
    if seq and seq > 0 then return seq end
    seq = ent:LookupSequence("idle_subtle")
    if seq and seq > 0 then return seq end
    if ent.SelectWeightedSequence then
        seq = ent:SelectWeightedSequence(ACT_IDLE)
        if seq and seq > 0 then return seq end
    end
    local list = ent:GetSequenceList()
    if list then
        for i = 0, 40 do
            local name = list[i]
            if name and name ~= "ragdoll" and name ~= "reference" then return i end
        end
    end
    return 0
end

function ENT:Think()
    if not self._idleSeqSet and self:GetModel() and self:GetModel() ~= "" and self:GetModel() ~= "models/error.mdl" then
        local seq = pickIdleSequence(self)
        if seq > 0 then
            self:ResetSequence(seq)
            self:SetPlaybackRate(1)
            self._idleSeqSet = true
        end
        -- Reset non-eye flex weights once so face isn't scrunched; leave eye flexes so SetEyeTarget can drive them (pupils visible).
        local flexNum = self:GetFlexNum()
        if flexNum and flexNum > 0 then
            for i = 0, flexNum - 1 do
                local name = self:GetFlexName(i)
                if not (name and string.find(string.lower(name), "eye")) then
                    self:SetFlexWeight(i, 0)
                end
            end
        end
    end
    self:NextThink(CurTime() + 0.2)
    return true
end

function ENT:Draw()
    -- Face/eyes follow local player every frame (SetEyeTarget in Draw = every frame). Many HL2 models support this.
    local ply = LocalPlayer()
    if IsValid(ply) then
        local dist = self:GetPos():Distance(ply:GetPos())
        if dist < 500 then
            self:SetEyeTarget(ply:EyePos())
        else
            -- Look forward when no one nearby (avoids looking at 0,0,0 which can look wrong).
            local fwd = self:GetForward()
            self:SetEyeTarget(self:GetPos() + fwd * 100 + Vector(0, 0, 50))
        end
    end
    self:DrawModel()
end
