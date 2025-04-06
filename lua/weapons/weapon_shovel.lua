if SERVER then
    AddCSLuaFile()
    print("[1Shovel Debug] Server loading weapon_shovel.lua at " .. CurTime())
end

if CLIENT then
    print("[1Shovel Debug] Client loading weapon_shovel.lua at " .. CurTime())
end

SWEP.Base = "weapon_base" -- Explicitly set to GMod's default base
SWEP.PrintName = "Shovel"
SWEP.Author = "Nick"
SWEP.Purpose = "Mine resources from rock surfaces"
SWEP.Instructions = "Left-click to swing and mine rocks"

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

SWEP.ViewModel = "models/weapons/v_crowbar.mdl" -- Crowbar hands for animation
SWEP.WorldModel = "models/props_junk/shovel01a.mdl" -- Shovel in third-person

SWEP.HoldType = "melee"
SWEP.Range = 75 -- Crowbar-like range in units

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:SetWeaponHoldType(self.HoldType) -- Ensure hold type is set
    if SERVER then
        self:SetModel(self.WorldModel) -- Set world model on server
    end
    print("[Shovel Debug] Shovel SWEP initialized for " .. (SERVER and "server" or "client"))
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.9) -- Same delay as crowbar
    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    -- Swing animation and sound
    self:EmitSound("weapons/iceaxe/iceaxe_swing1.wav")
    ply:ViewPunch(Angle(-1, 0, 0))
    ply:SetAnimation(PLAYER_ATTACK1)
    self:SendWeaponAnim(ACT_VM_HITCENTER)

    if SERVER then
        ply:LagCompensation(true)
        local trace = util.TraceLine({
            start = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * self.Range,
            filter = ply,
            mask = MASK_SHOT
        })
        if trace.Hit then
            local hitType = IsValid(trace.Entity) and trace.Entity:GetClass() or "world"
            print("[Shovel Debug] Swing hit: " .. hitType .. " at " .. trace.Fraction * self.Range .. " units, Material: " .. trace.HitTexture .. " (MatType: " .. trace.MatType .. ")")
            if trace.HitWorld then
                local matType = trace.MatType
                local hitTexture = trace.HitTexture:lower()
                local isRockSurface = (matType == MAT_DIRT or matType == MAT_SAND or 
                                      hitTexture:find("nature/") or hitTexture:find("rock/") or hitTexture:find("ground/") or 
                                      hitTexture:find("dirt") or hitTexture:find("sand"))
                if isRockSurface then
                    self:EmitSound("weapons/crowbar/crowbar_impact" .. math.random(1, 2) .. ".wav")
                    AddResourceToInventory(ply, "rock", 1)
                    if math.random(1, 8) == 1 then AddResourceToInventory(ply, "copper", 1) end
                    if math.random(1, 25) == 1 then AddResourceToInventory(ply, "iron", 1) end
                    if math.random(1, 50) == 1 then AddResourceToInventory(ply, "steel", 1) end
                else
                    print("[Shovel Debug] Non-rock surface hit: " .. hitTexture)
                end
            end
        end
        ply:LagCompensation(false)
    end
end

function SWEP:Deploy()
    self:EmitSound("weapons/crowbar/crowbar_draw.wav")
    return true
end

-- Ensure the SWEP is registered correctly
if SERVER then
    print("[Shovel Debug] Registering SWEP as weapon_shovel")
end