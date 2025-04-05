if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "Shovel"
SWEP.Author = "Nick"
SWEP.Purpose = "Mining Resources"
SWEP.Instructions = "Left-click to swing"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 1
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/props_farm/tools_shovel.mdl" -- Still crowbar hands—replace if possible
SWEP.WorldModel = "models/props_farm/tools_shovel.mdl"

SWEP.HoldType = "melee"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.9)

    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    ply:LagCompensation(true)

    local trace = ply:GetEyeTrace()
    self:EmitSound("weapons/crowbar/crowbar_swing" .. math.random(1, 3) .. ".wav")

    if trace.Hit then
        local ent = trace.Entity
        if IsValid(ent) then
            local dmginfo = DamageInfo()
            dmginfo:SetDamage(25)
            dmginfo:SetAttacker(ply)
            dmginfo:SetInflictor(self)
            dmginfo:SetDamageType(DMG_CLUB)
            ent:TakeDamageInfo(dmginfo)
            print("[Debug] Shovel hit entity: "..ent:GetClass())
        end

        if ent:IsWorld() or IsValid(ent) then
            self:DoImpactEffect(trace)
        end
    end

    ply:ViewPunch(Angle(-1, 0, 0))
    ply:SetAnimation(PLAYER_ATTACK1)

    ply:LagCompensation(false)
end

function SWEP:DoImpactEffect(trace)
    local effectdata = EffectData()
    effectdata:SetOrigin(trace.HitPos)
    effectdata:SetNormal(trace.HitNormal)
    util.Effect("Impact", effectdata)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)
    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    local trace = ply:GetEyeTrace()
    if trace.Hit and IsValid(trace.Entity) and trace.Entity:GetClass() == "ent_resource_node" then
        ply:ChatPrint("Mining coming soon!")
        print("[Debug] Shovel secondary hit resource node")
    end
end

function SWEP:Deploy()
    self:EmitSound("weapons/crowbar/crowbar_draw.wav")
    return true
end

function SWEP:Holster()
    return true
end