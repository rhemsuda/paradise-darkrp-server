AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MODULE_TIMER = 15 * 60 -- 15 minutes in seconds

local MODULE_LINK_RANGE = 100 -- units (~couple feet); printer within this gets laser + protection

function ENT:Initialize()
    self:SetModel(self:GetModel() or "models/props_lab/reciever01a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self:SetActive(false)
    self:SetTimeLeft(0)
    self.damage = 250
end

function ENT:OnTakeDamage(dmg)
    self:TakePhysicsDamage(dmg)
    self.damage = (self.damage or 250) - dmg:GetDamage()
    if self.damage <= 0 then
        for _, setter in ipairs({"SetConnectedPrinter", "SetConnectedPrinter2", "SetConnectedPrinter3", "SetConnectedPrinter4", "SetConnectedPrinter5", "SetConnectedPrinter6", "SetConnectedPrinter7", "SetConnectedPrinter8"}) do
            self[setter](self, NULL)
        end
        self:Remove()
    end
end

function ENT:Use(activator, caller, useType, value)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator ~= self:Getowning_ent() then return end
    if self:GetActive() then return end

    self:SetActive(true)
    self._endTime = CurTime() + MODULE_TIMER
    self:SetTimeLeft(MODULE_TIMER)
    DarkRP.notify(activator, 0, 4, "Printer module activated – 15 minutes until shutdown.")
end

function ENT:Think()
    if not self:GetActive() then
        for _, setter in ipairs({"SetConnectedPrinter", "SetConnectedPrinter2", "SetConnectedPrinter3", "SetConnectedPrinter4", "SetConnectedPrinter5", "SetConnectedPrinter6", "SetConnectedPrinter7", "SetConnectedPrinter8"}) do
            self[setter](self, NULL)
        end
        self:NextThink(CurTime() + 1)
        return true
    end

    self._endTime = self._endTime or (CurTime() + MODULE_TIMER)
    local left = math.max(0, self._endTime - CurTime())
    self:SetTimeLeft(left)

    if left <= 0 then
        self:Explode()
        return
    end

    -- Find up to 8 printers in range: owner's first, then by distance (for laser + protection)
    local owner = self:Getowning_ent()
    local mypos = self:GetPos()
    local candidates = {}
    for _, ent in ipairs(ents.FindInSphere(mypos, MODULE_LINK_RANGE)) do
        if not IsValid(ent) then continue end
        if not ent.IsMoneyPrinter and not ent:GetClass():match("^printer%d+") then continue end
        local d = mypos:Distance(ent:GetPos())
        local owned = IsValid(ent:Getowning_ent()) and ent:Getowning_ent() == owner
        table.insert(candidates, { ent = ent, dist = d, owned = owned })
    end
    table.sort(candidates, function(a, b)
        if a.owned ~= b.owned then return a.owned end
        return a.dist < b.dist
    end)
    local setters = { "SetConnectedPrinter", "SetConnectedPrinter2", "SetConnectedPrinter3", "SetConnectedPrinter4",
        "SetConnectedPrinter5", "SetConnectedPrinter6", "SetConnectedPrinter7", "SetConnectedPrinter8" }
    for i = 1, 8 do
        local ent = (candidates[i] and IsValid(candidates[i].ent)) and candidates[i].ent or NULL
        self[setters[i]](self, ent)
    end

    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:Explode()
    if self._exploded then return end
    self._exploded = true
    for _, setter in ipairs({"SetConnectedPrinter", "SetConnectedPrinter2", "SetConnectedPrinter3", "SetConnectedPrinter4", "SetConnectedPrinter5", "SetConnectedPrinter6", "SetConnectedPrinter7", "SetConnectedPrinter8"}) do
        self[setter](self, NULL)
    end

    local pos = self:GetPos()
    local eff = EffectData()
    eff:SetOrigin(pos)
    eff:SetScale(1)
    eff:SetRadius(2)
    util.Effect("Explosion", eff)
    self:EmitSound("BaseGrenade.Explode", 80, 100)

    if IsValid(self:Getowning_ent()) then
        DarkRP.notify(self:Getowning_ent(), 1, 4, "Your printer module exploded!")
    end
    self:Remove()
end
