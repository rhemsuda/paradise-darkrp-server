AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_c17/consolebox01a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(true)
        phys:SetMass(100)
        phys:EnableDrag(false)
        phys:EnableGravity(true)
        print("[Printer1] Physics object initialized successfully")
        print("[Printer1] Mass: " .. phys:GetMass())
        print("[Printer1] Drag enabled: " .. tostring(phys:IsDragEnabled()))
        print("[Printer1] Gravity enabled: " .. tostring(phys:IsGravityEnabled()))
    else
        print("[Printer1] Error: Failed to initialize physics object")
    end

    local mins, maxs = self:GetCollisionBounds()
    local startPos = self:GetPos() + Vector(0, 0, 10)
    local tr = util.TraceHull({
        start = startPos,
        endpos = startPos + Vector(0, 0, -1010),
        mins = mins,
        maxs = maxs,
        filter = self
    })
    if tr.Hit then
        self:SetPos(tr.HitPos + Vector(0, 0, 1))
        print("[Printer1] Adjusted position to ground at: " .. tostring(self:GetPos()))
        print("[Printer1] Trace hit entity: " .. (IsValid(tr.Entity) and tr.Entity:GetClass() or "none"))
        print("[Printer1] Trace hit position: " .. tostring(tr.HitPos))
    else
        print("[Printer1] Warning: Trace failed to find ground!")
        print("[Printer1] Start position: " .. tostring(startPos))
        print("[Printer1] End position: " .. tostring(startPos + Vector(0, 0, -1010)))
    end

    self.sparking = false
    self:SetStoredMoney(0)
    print("[Printer1] Spawned at position: " .. tostring(self:GetPos()))
    print("[Printer1] Initialized with StoredMoney: " .. self:GetStoredMoney())
    print("[Printer1] Transmit state set to: " .. self:UpdateTransmitState())

    -- Start money generation timer (first print after 60 seconds, then every 60 seconds)
    timer.Create("PrintMoney_" .. self:EntIndex(), 60, 0, function()
        if not IsValid(self) then return end
        self:CreateMoneybag()
    end)
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local storedMoney = self:GetStoredMoney()
    if storedMoney <= 0 then
        DarkRP.notify(activator, 1, 4, "This printer has no money to collect!")
        return
    end

    activator:addMoney(storedMoney)
    DarkRP.notify(activator, 0, 4, "You collected $" .. storedMoney .. " from the printer!")
    self:EmitSound("items/ammocrate_open.wav")
    self:SetStoredMoney(0)

    net.Start("PrinterForceClientUpdate")
    net.WriteEntity(self)
    net.Send(activator)
end

function ENT:OnTakeDamage(dmg)
    self:TakePhysicsDamage(dmg)
    if self.health <= 0 then return end
    self.health = (self.health or 100) - dmg:GetDamage()
    if self.health <= 0 then
        self:Remove()
        local explosion = ents.Create("env_explosion")
        explosion:SetPos(self:GetPos())
        explosion:SetKeyValue("iMagnitude", "100")
        explosion:Spawn()
        explosion:Fire("Explode", 0, 0)
    end
end

function PrintMore(ent)
    if not IsValid(ent) then return end

    ent:CreateMoneybag()
end

function ENT:CreateMoneybag()
    if not IsValid(self) or self:IsOnFire() then return end

    if GAMEMODE.Config.printeroverheat then
        local overheatchance
        if GAMEMODE.Config.printeroverheatchance <= 3 then
            overheatchance = 22
        else
            overheatchance = GAMEMODE.Config.printeroverheatchance or 22
        end
        if math.random(1, overheatchance) == 3 then self:BurstIntoFlames() end
    end

    local amount = GAMEMODE.Config.mprintamount
    if amount == 0 then
        amount = 250
    end

    self:SetStoredMoney(self:GetStoredMoney() + amount)
    DarkRP.notify(self:Getowning_ent(), 0, 4, "Printer has generated $" .. amount .. ". Total stored: $" .. self:GetStoredMoney())

    local effect = EffectData()
    effect:SetOrigin(self:GetPos() + Vector(0, 0, 15))
    effect:SetMagnitude(1)
    effect:SetScale(1)
    effect:SetRadius(1)
    util.Effect("ManhackSparks", effect)

    self.sparking = false
    -- Removed timer.Simple; now handled by timer.Create in Initialize
end

function ENT:BurstIntoFlames()
    if not IsValid(self) or self:IsOnFire() then return end
    self:Ignite(10, 0)
    self.sparking = true
    timer.Create("FireDamage_" .. self:EntIndex(), 1, 10, function()
        if not IsValid(self) then return end
        local dmg = DamageInfo()
        dmg:SetDamage(10)
        dmg:SetDamageType(DMG_BURN)
        dmg:SetAttacker(self)
        dmg:SetInflictor(self)
        self:TakeDamageInfo(dmg)
    end)
end

function ENT:Think()
    if self.sparking then
        local effect = EffectData()
        effect:SetOrigin(self:GetPos())
        effect:SetMagnitude(1)
        effect:SetScale(1)
        effect:SetRadius(2)
        util.Effect("Sparks", effect)
    end
end

function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then return end

    local SpawnPos = tr.HitPos + tr.HitNormal * 1
    local ent = ents.Create(ClassName)
    ent:SetPos(SpawnPos)
    ent:Spawn()
    ent:Activate()
    ent:Setowning_ent(ply)

    return ent
end