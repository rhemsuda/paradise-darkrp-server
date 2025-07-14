AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("PrinterForceClientUpdate")

function ENT:Initialize()
    self:SetModel("models/props_c17/consolebox01a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self.health = 150 -- Explicitly initialize health

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(true)
        phys:SetMass(100)
        phys:EnableDrag(false)
        phys:EnableGravity(true)
        print("[Printer2] Physics object initialized successfully")
    else
        print("[Printer2] Error: Failed to initialize physics object")
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
        print("[Printer2] Adjusted position to ground at: " .. tostring(self:GetPos()))
    else
        print("[Printer2] Warning: Trace failed to find ground!")
    end

    self.sparking = false
    self:SetStoredMoney(0)
    self.StealCounters = {}
    self.ModuleConnected = nil
    print("[Printer2] Spawned at position: " .. tostring(self:GetPos()))

    timer.Create("PrintMoney_" .. self:EntIndex(), 45, 0, function()
        if not IsValid(self) then return end
        self:CreateMoneybag()
    end)

    net.Start("PrinterForceClientUpdate")
    net.WriteEntity(self)
    net.Broadcast()
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    if self:IsOnFire() then
        self.NoMoneyCooldown = self.NoMoneyCooldown or {}
        local lastNotify = self.NoMoneyCooldown[activator:SteamID()] or 0
        if CurTime() - lastNotify > 5 then
            DarkRP.notify(activator, 1, 4, "This printer is on fire and cannot be used!")
            self.NoMoneyCooldown[activator:SteamID()] = CurTime()
        end
        return
    end

    local storedMoney = self:GetStoredMoney()
    if storedMoney <= 0 then
        self.NoMoneyCooldown = self.NoMoneyCooldown or {}
        local lastNotify = self.NoMoneyCooldown[activator:SteamID()] or 0
        if CurTime() - lastNotify > 5 then
            DarkRP.notify(activator, 1, 4, "This printer has no money to collect!")
            self.NoMoneyCooldown[activator:SteamID()] = CurTime()
        end
        return
    end

    local owner = self:Getowning_ent()
    local isOwner = IsValid(owner) and owner == activator
    self.StealCounters = self.StealCounters or {}

    if not isOwner then
        local steamID = activator:SteamID()
        self.StealCounters[steamID] = (self.StealCounters[steamID] or 0) + 1
        print("[Printer2] " .. activator:Nick() .. " collected from printer (Steal count: " .. self.StealCounters[steamID] .. ")")

        if self.StealCounters[steamID] >= 4 then
            self:Setowning_ent(activator)
            DarkRP.notify(activator, 0, 4, "You have stolen this printer by collecting from it 4 times!")
            if IsValid(owner) then
                DarkRP.notify(owner, 1, 4, activator:Nick() .. " has stolen your printer!")
            end
            self.StealCounters = {}
        else
            DarkRP.notify(activator, 0, 4, "You collected $" .. storedMoney .. " from someone else's printer! (" .. self.StealCounters[steamID] .. "/4)")
            if IsValid(owner) then
                DarkRP.notify(owner, 1, 4, activator:Nick() .. " collected $" .. storedMoney .. " from your printer!")
            end
        end
    else
        self.StealCounters = {}
        DarkRP.notify(activator, 0, 4, "You collected $" .. storedMoney .. " from your printer!")
    end

    for steamID, count in pairs(self.StealCounters) do
        if steamID != activator:SteamID() then
            self.StealCounters[steamID] = 0
        end
    end

    activator:addMoney(storedMoney)
    self:SetStoredMoney(0)

    net.Start("PrinterForceClientUpdate")
    net.WriteEntity(self)
    net.Send(activator)
end

function ENT:Explode()
    local pos = self:GetPos()
    local radius = 200
    local nearby = ents.FindInSphere(pos, radius)
    for _, ent in pairs(nearby) do
        if (ent:GetClass() == "printer1" or ent:GetClass() == "printer2") and ent != self and not ent:IsOnFire() then
            ent:BurstIntoFlames()
        end
    end

    -- Explode the connected module if it exists
    if IsValid(self.ModuleConnected) then
        self.ModuleConnected:Explode() -- Trigger module explosion
    end

    local explosion = ents.Create("env_explosion")
    explosion:SetPos(self:GetPos())
    explosion:SetKeyValue("iMagnitude", "100")
    explosion:SetKeyValue("spawnflags", "1") -- Add NoDamage flag
    explosion:Spawn()
    explosion:Fire("Explode", 0, 0)

    self:Remove()
end

function ENT:OnTakeDamage(dmg)
    if self:IsOnFire() then return end

    self:TakePhysicsDamage(dmg)
    if self.health == nil then self.health = 150 end -- Fallback if health is nil
    self.health = self.health - dmg:GetDamage()
    if self.ModuleConnected and IsValid(self.ModuleConnected) then
        if self.ModuleConnected.health == nil then self.ModuleConnected.health = self.health end -- Sync initial HP
        self.ModuleConnected.health = self.health -- Sync HP with printer
    end
    if self.health <= 0 then
        self:Explode()
    end
end

function ENT:CreateMoneybag()
    if not IsValid(self) or self:IsOnFire() then return end

    if GAMEMODE.Config.printeroverheat and not (self.ModuleConnected and IsValid(self.ModuleConnected)) then
        local overheatchance
        if GAMEMODE.Config.printeroverheatchance <= 3 then
            overheatchance = 22
        else
            overheatchance = GAMEMODE.Config.printeroverheatchance or 22
        end
        if math.random(1, overheatchance) == 3 then 
            self:BurstIntoFlames() 
        end
    elseif self.ModuleConnected and IsValid(self.ModuleConnected) then
        local module = self.ModuleConnected
        if GAMEMODE.Config.printeroverheat then
            local overheatchance
            if GAMEMODE.Config.printeroverheatchance <= 3 then
                overheatchance = 22
            else
                overheatchance = GAMEMODE.Config.printeroverheatchance or 22
            end
            if math.random(1, overheatchance) == 3 then
                module:SavePrinter()
                return -- Prevent fire/explosion
            end
        end
    end

    local amount = GAMEMODE.Config.mprintamount
    if amount == 0 then
        amount = 500
    end

    local boost = self.ModuleConnected and self.ModuleConnected:GetIsDonator() and 1.15 or 1.0
    amount = math.floor(amount * boost)
    self:SetStoredMoney(self:GetStoredMoney() + amount)
    DarkRP.notify(self:Getowning_ent(), 0, 4, "Printer has generated $" .. amount .. ". Total stored: $" .. self:GetStoredMoney() .. (self.ModuleConnected and " Infused (" .. self.ModuleConnected:GetSaveCounter() .. "/" .. self.ModuleConnected:GetMaxSaves() .. ")" or ""))

    local effect = EffectData()
    effect:SetOrigin(self:GetPos() + Vector(0, 0, 15))
    effect:SetMagnitude(1)
    effect:SetScale(1)
    effect:SetRadius(1)
    util.Effect("ManhackSparks", effect)

    self.sparking = false
end

function ENT:BurstIntoFlames()
    if not IsValid(self) or self:IsOnFire() then return end
    self:Ignite(12, 0)
    self.sparking = true
    timer.Create("FireDamage_" .. self:EntIndex(), 1, 12, function()
        if not IsValid(self) then return end
        timer.Simple(0, function()
            if IsValid(self) then
                self:Explode()
            end
        end)
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

function ENT:OnRemove()
    timer.Remove("PrintMoney_" .. self:EntIndex())
    timer.Remove("FireDamage_" .. self:EntIndex())
end