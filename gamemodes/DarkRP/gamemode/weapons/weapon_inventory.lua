AddCSLuaFile()

SWEP.PrintName = "Inventory"
SWEP.Author = "Nick"
SWEP.Purpose = "Access your inventory with primary attack."

SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.Spawnable = true
SWEP.ViewModel = Model("models/weapons/v_hands.mdl")
SWEP.WorldModel = Model("models/weapons/w_toolgun.mdl")
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.HoldType = "normal"
SWEP.OpenSound = Sound("items/ammopickup.wav")

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    return true
end

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextIdle")
end

function SWEP:PrimaryAttack()
    if SERVER then
        local owner = self:GetOwner()
        if not IsValid(owner) then return end
        net.Start("OpenInventory")
        net.Send(owner)
        self:EmitSound(self.OpenSound)
        self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
        owner:SetAnimation(PLAYER_ATTACK1)
        local curtime = CurTime()
        local endtime = curtime + self:SequenceDuration()
        self:SetNextIdle(endtime)
        self:SetNextPrimaryFire(endtime + 0.5)
    end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:Think()
    local curtime = CurTime()
    if curtime >= self:GetNextIdle() then
        self:SendWeaponAnim(ACT_VM_IDLE)
        self:SetNextIdle(curtime + self:SequenceDuration())
    end
end

if CLIENT then
    function SWEP:CustomAmmoDisplay()
        return { Draw = false }
    end

    function SWEP:DrawHUD()
        draw.SimpleText("Left-click to open inventory", "DermaDefault", ScrW() / 2, ScrH() - 50, Color(255, 255, 255), TEXT_ALIGN_CENTER)
    end
end