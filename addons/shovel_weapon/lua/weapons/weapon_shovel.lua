if SERVER then
    AddCSLuaFile()
    print("[Shovel Debug] Server loading weapon_shovel.lua at "..CurTime())
end

if CLIENT then
    print("[Shovel Debug] Client loading weapon_shovel.lua at "..CurTime())
end

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
    self:SetModel(self.WorldModel) -- Third-person model
    print("[Shovel Debug] Shovel SWEP initialized")
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.9) -- Same delay as crowbar
    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    -- Swing animation and sound like crowbar
    self:EmitSound("weapons/iceaxe/iceaxe_swing1.wav") -- Swing sound
    ply:ViewPunch(Angle(-1, 0, 0)) -- Screen shake
    ply:SetAnimation(PLAYER_ATTACK1) -- Third-person player animation
    self:SendWeaponAnim(ACT_VM_HITCENTER) -- First-person viewmodel animation

    if SERVER then
        ply:LagCompensation(true)
        -- Crowbar-like melee trace
        local trace = util.TraceLine({
            start = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * self.Range,
            filter = ply,
            mask = MASK_SHOT
        })
        if trace.Hit then
            local hitType = IsValid(trace.Entity) and trace.Entity:GetClass() or "world"
            print("[Shovel Debug] Swing hit: "..hitType.." at "..trace.Fraction * self.Range.." units, Material: "..trace.HitTexture.." (MatType: "..trace.MatType..")")
            if trace.HitWorld then
                -- Check if the surface is a rock/ground material
                local matType = trace.MatType
                local hitTexture = trace.HitTexture:lower()
                local isRockSurface = (matType == MAT_DIRT or matType == MAT_SAND or 
                                      hitTexture:find("nature/") or hitTexture:find("rock/") or hitTexture:find("ground/") or 
                                      hitTexture:find("dirt") or hitTexture:find("sand"))
                if isRockSurface then
                    -- Play crowbar impact sound on rock hit
                    self:EmitSound("weapons/crowbar/crowbar_impact" .. math.random(1, 2) .. ".wav")
                    -- Always add rock
                    AddResourceToInventory(ply, "rock", 1)
                    -- Independent rolls for rare resources
                    if math.random(1, 8) == 1 then
                        AddResourceToInventory(ply, "copper", 1)
                    end
                    if math.random(1, 25) == 1 then
                        AddResourceToInventory(ply, "iron", 1)
                    end
                    if math.random(1, 50) == 1 then
                        AddResourceToInventory(ply, "steel", 1)
                    end
                else
                    print("[Shovel Debug] Non-rock surface hit: "..hitTexture)
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