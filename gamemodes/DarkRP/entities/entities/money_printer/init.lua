AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.SpawnOffset = Vector(15, 0, 15)

local function PrintMore(ent)
    if not IsValid(ent) then return end
    ent.sparking = true
    timer.Simple(3, function()
        if not IsValid(ent) then return end
        ent:CreateMoneybag()
    end)
end

-- Returns true if an active printer_module nearby has this printer in one of its cooled slots.
-- Defined at file level so it is created once, not on every CreateMoneybag call.
local function IsProtectedByModule(printer)
    for _, ent in ipairs(ents.FindInSphere(printer:GetPos(), 120)) do
        if ent:GetClass() ~= "printer_module" or not ent.GetActive or not ent:GetActive() then continue end
        for _, getter in ipairs({ "GetConnectedPrinter", "GetConnectedPrinter2", "GetConnectedPrinter3",
                                   "GetConnectedPrinter4", "GetConnectedPrinter5", "GetConnectedPrinter6",
                                   "GetConnectedPrinter7", "GetConnectedPrinter8" }) do
            local conn = ent[getter] and ent[getter](ent)
            if IsValid(conn) and conn == printer then return true end
        end
    end
    return false
end

function ENT:StartSound()
    self.sound = CreateSound(self, Sound("ambient/levels/labs/equipment_printer_loop1.wav"))
    self.sound:SetSoundLevel(52)
    self.sound:PlayEx(1, 100)
end

function ENT:PostInit()
    --Dumb things what you want to run on printer spawn
end

function ENT:Initialize()
    self:initVars()
    self:SetModel(self.model)
    DarkRP.ValidatedPhysicsInit(self, SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()

    if phys:IsValid() then
        phys:Wake()
    end

    timer.Simple(math.random(self.MinTimer, self.MaxTimer), function() PrintMore(self) end)
    self:StartSound()
    self:PostInit()
end

function ENT:OnTakeDamage(dmg)
    self:TakePhysicsDamage(dmg)

    if self.burningup then return end

    self.damage = (self.damage or 250) - dmg:GetDamage()
    if self.damage <= 0 then
        local rnd = math.random(1, 10)
        if rnd < 3 then
            self:BurstIntoFlames()
        else
            self:Destruct()
            self:Remove()
        end
    end
end

function ENT:Destruct()
    local vPoint = self:GetPos()
    local effectdata = EffectData()
    effectdata:SetStart(vPoint)
    effectdata:SetOrigin(vPoint)
    effectdata:SetScale(1)
    util.Effect("Explosion", effectdata)
    if IsValid(self:Getowning_ent()) then DarkRP.notify(self:Getowning_ent(), 1, 4, DarkRP.getPhrase("money_printer_exploded")) end
end

function ENT:BurstIntoFlames()
    if hook.Run("moneyPrinterCatchFire", self) == true then return end

    if IsValid(self:Getowning_ent()) then DarkRP.notify(self:Getowning_ent(), 0, 4, DarkRP.getPhrase("money_printer_overheating")) end
    self.burningup = true
    local burntime = math.random(8, 18)
    self:Ignite(burntime, 0)
    timer.Simple(burntime, function() self:Fireball() end)
end

function ENT:Fireball()
    if not self:IsOnFire() then self.burningup = false return end
    local dist = math.random(20, 280) -- Explosion radius
    self:Destruct()
    for k, v in ipairs(ents.FindInSphere(self:GetPos(), dist)) do
        if not v:IsPlayer() and not v:IsWeapon() and v:GetClass() ~= "predicted_viewmodel" and not v.IsMoneyPrinter then
            v:Ignite(math.random(5, 22), 0)
        elseif v:IsPlayer() then
            local distance = v:GetPos():Distance(self:GetPos())
            v:TakeDamage(distance / dist * 100, self, self)
        end
    end
    self:Remove()
end

function ENT:CreateMoneybag()
    if self:IsOnFire() then return end

    local amount = self.MoneyCount or (GAMEMODE.Config.mprintamount ~= 0 and GAMEMODE.Config.mprintamount or 250)
    local prevent, hookAmount = hook.Run("moneyPrinterPrintMoney", self, amount)
    if prevent == true then return end

    amount = hookAmount or amount

    -- Overheat check (IsProtectedByModule defined at file level above Initialize)
    if self.OverheatChance and self.OverheatChance > 0 and not IsProtectedByModule(self) then
        local overheatchance = (self.OverheatChance <= 3) and 28 or (self.OverheatChance or 28)
        if math.random(1, overheatchance) == 3 then self:BurstIntoFlames() end
    end

    -- Paradise: store money internally instead of spawning bags; owner collects with E
    local stored = self:GetStoredMoney() + amount
    self:SetStoredMoney(stored)
    self.sparking = false
    timer.Simple(math.random(self.MinTimer, self.MaxTimer), function() PrintMore(self) end)
end

-- Paradise: Use (E) to collect stored money; XP scales with amount collected + bonus for bigger takes
function ENT:Use(activator, caller, useType, value)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator ~= self:Getowning_ent() then return end
    local stored = self:GetStoredMoney()
    if stored <= 0 then return end

    activator:addMoney(stored)
    self:SetStoredMoney(0)
    DarkRP.notify(activator, 0, 4, "Collected " .. DarkRP.formatMoney(stored))

    -- XP scales with amount: base ~1 per $80, plus bonus for larger single collects (more for big takes)
    if Leveling and Leveling.AddXP then
        local base = math.floor(stored / 80)
        local bonus = math.floor(stored / 400)  -- extra XP when you let it accumulate (e.g. $400+ gives +1, $800+ gives +2)
        local xp = math.max(1, base + bonus)
        Leveling.AddXP(activator, xp, "printer")
    end
end

function ENT:Think()
    if self:WaterLevel() > 0 then
        self:Destruct()
        self:Remove()
        return
    end
    -- Sound is started once in Initialize; do NOT call StartSound() here or it
    -- creates a new CSoundPatch every frame, stacking sound objects indefinitely.
    if not self.sparking then return end

    local effectdata = EffectData()
    effectdata:SetOrigin(self:GetPos())
    effectdata:SetMagnitude(1)
    effectdata:SetScale(1)
    effectdata:SetRadius(2)
    util.Effect("Sparks", effectdata)
end

function ENT:OnRemove()
    if self.sound then
        self.sound:Stop()
    end
end
