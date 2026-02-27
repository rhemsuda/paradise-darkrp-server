AddCSLuaFile()
if SERVER then
    AddCSLuaFile("cl_init.lua")
end

-- Register Taser ammo type (must run on both client and server at load time)
game.AddAmmoType({
    name = "Taser",
    dmgtype = DMG_SHOCK,
    tracer = TRACER_NONE,
    plydmg = 0,
    npcdmg = 0,
    force = 0,
    maxcarry = 60,
})

-- Use keypadchecker as base: it overrides PrimaryAttack/SecondaryAttack and does NOT inherit weapon_base's AR2/Shotgun
SWEP.Base = "weapon_keypadchecker"

SWEP.PrintName = "Taser Scanner"
SWEP.Author = "DarkRP Developers"
SWEP.Instructions = "Left click: Taser (only affects wanted players)\nRight click: Scan for contraband"
SWEP.Slot = 1
SWEP.SlotPos = 2
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.Category = "DarkRP (Utility)"

SWEP.HoldType = "pistol"
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.UseHands = true

-- Override keypadchecker: single-shot taser, not keypad
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Ammo = "Taser"
SWEP.Primary.Delay = 0.5
SWEP.Primary.Sound = Sound("weapons/stunstick/stunstick_fleshhit1.wav")

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"

-- Scanner config
local SCAN_DURATION = 5
local SCAN_RADIUS = 100 * 39.37
local TASER_RAGDOLL_TIME = 10
local TASER_SLOW_TIME = 15

SWEP.NextScanTime = 0

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Scanning")
    self:NetworkVar("Float", 0, "ScanStartTime")
end

function SWEP:Initialize()
    self:SetClip1(1)
    self:SetClip2(-1)
end

function SWEP:Deploy()
    if self:Clip1() > 1 then self:SetClip1(1) end
    return true
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    local Owner = self:GetOwner()
    if not IsValid(Owner) or not Owner:isCP() then return end

    if self:Clip1() <= 0 then
        self:EmitSound("Weapon_Pistol.Empty")
        self:SetNextPrimaryFire(CurTime() + 0.5)
        return
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

    self:EmitSound(self.Primary.Sound)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    Owner:SetAnimation(PLAYER_ATTACK1)
    self:TakePrimaryAmmo(1)

    if SERVER then self:DoTaserTrace() end
end

function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    local Owner = self:GetOwner()
    if not IsValid(Owner) or not Owner:isCP() then return end
    if self:GetScanning() then return end
    if CurTime() < self.NextScanTime then return end

    self:SetNextPrimaryFire(CurTime() + 0.3)
    self:SetNextSecondaryFire(CurTime() + 0.3)

    if SERVER then self:StartScan() end
end

function SWEP:Reload()
    if self:Clip1() >= 1 then return end
    if self:GetOwner():GetAmmoCount(self:GetPrimaryAmmoType()) <= 0 then return end
    self:DefaultReload(ACT_VM_RELOAD)
    self:SetNextPrimaryFire(CurTime() + 1.5)
    self:SetNextSecondaryFire(CurTime() + 1.5)
end

-- Explicitly set list so spawn menu / weapon display finds our PrintName
list.Set("Weapon", "weapon_taser_scanner", {
    ClassName = "weapon_taser_scanner",
    PrintName = "Taser Scanner",
    Category = "DarkRP (Utility)",
})

if SERVER then
    util.AddNetworkString("TaserScanner_PlayScanSound")
    util.AddNetworkString("TaserScanner_TaseHit")

    function SWEP:DoTaserTrace()
        local Owner = self:GetOwner()
        if not IsValid(Owner) then return end
        Owner:LagCompensation(true)
        local trace = util.TraceLine({
            start = Owner:EyePos(),
            endpos = Owner:EyePos() + Owner:GetAimVector() * 10000,
            filter = Owner,
        })
        Owner:LagCompensation(false)
        local ent = trace.Entity
        if not IsValid(ent) or not ent:IsPlayer() then return end
        if not ent:isWanted() then return end
        self:ApplyTaserEffect(ent)
    end

    function SWEP:ApplyTaserEffect(victim)
        if not IsValid(victim) or not victim:IsPlayer() or not victim:Alive() then return end
        local doll = ents.Create("prop_ragdoll")
        doll:SetModel(victim:GetModel())
        doll:SetPos(victim:GetPos())
        doll:SetAngles(victim:GetAngles())
        doll:SetColor(victim:GetColor())
        doll:Spawn()
        victim.TaserRagdoll = doll
        victim:SetNWBool("Tased", true)
        victim:SetNWEntity("TaserRagdoll", doll)
        victim:Spectate(OBS_MODE_CHASE)
        victim:SpectateEntity(doll)
        net.Start("TaserScanner_TaseHit")
        net.WriteEntity(victim)
        net.Broadcast()
        timer.Simple(TASER_RAGDOLL_TIME, function()
            if not IsValid(victim) then return end
            victim:SetNWBool("Tased", false)
            victim:SetNWEntity("TaserRagdoll", nil)
            victim:UnSpectate()
            if IsValid(doll) then victim:SetPos(doll:GetPos()) doll:Remove() end
            victim.TaserRagdoll = nil
            victim:SetNWFloat("TaseSlowEnd", CurTime() + TASER_SLOW_TIME)
        end)
    end

    function SWEP:StartScan()
        local Owner = self:GetOwner()
        if not IsValid(Owner) or not Owner:isCP() then return end
        self:SetScanning(true)
        self:SetScanStartTime(CurTime())
        net.Start("TaserScanner_PlayScanSound")
        net.WriteVector(Owner:GetPos())
        net.Broadcast()
        timer.Simple(SCAN_DURATION, function()
            if not IsValid(self) or not IsValid(Owner) then return end
            self:CompleteScan()
        end)
    end

    function SWEP:CompleteScan()
        local Owner = self:GetOwner()
        if not IsValid(Owner) then self:SetScanning(false) return end
        self:SetScanning(false)
        self.NextScanTime = CurTime() + SCAN_DURATION + 2
        local wantedPlayers = {}
        for _, ent in ipairs(ents.FindInSphere(Owner:GetPos(), SCAN_RADIUS)) do
            if not IsValid(ent) then continue end
            if DarkRP and DarkRP.IsContraband and DarkRP.IsContraband(ent:GetClass()) then
                local owner = ent.CPPIGetOwner and ent:CPPIGetOwner() or (ent.Getowning_ent and ent:Getowning_ent()) or (ent.SID and Player(ent.SID))
                if IsValid(owner) and owner:IsPlayer() and not owner:isWanted() then
                    wantedPlayers[owner] = true
                end
            end
        end
        for ply, _ in pairs(wantedPlayers) do
            if IsValid(ply) then ply:wanted(Owner, "Contraband detected in vicinity", nil) end
        end
    end
end
