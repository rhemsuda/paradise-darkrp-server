AddCSLuaFile()

SWEP.PrintName = "Inventory"
SWEP.Author = "Nicknmb"
SWEP.Purpose = "Open your inventory"
SWEP.Category = "Inventory"

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
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/v_hands.mdl"
SWEP.WorldModel = ""

function SWEP:PrimaryAttack()
    if SERVER then
        net.Start("RequestOpenInventory")
        net.Send(self:GetOwner())
    end
    self:SetNextPrimaryFire(CurTime() + 0.5) -- Cooldown to prevent spamming
end

function SWEP:SecondaryAttack() end

if CLIENT then
    function SWEP:DrawHUD()
        draw.SimpleText("Left-click to open inventory", "DermaDefault", ScrW() / 2, ScrH() - 50, Color(255, 255, 255), TEXT_ALIGN_CENTER)
    end
end