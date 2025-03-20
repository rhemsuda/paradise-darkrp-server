-- Ensure this file is sent to clients
AddCSLuaFile()

-- Basic SWEP properties
SWEP.PrintName = "Inventory"
SWEP.Author = "Nick"
SWEP.Purpose = "Access your inventory with primary attack."

SWEP.Slot = 1          -- Weapon slot in the selection menu
SWEP.SlotPos = 1       -- Position within the slot
SWEP.Spawnable = true   -- Can be spawned or given via console/hooks

SWEP.ViewModel = Model("models/weapons/v_hands.mdl")  -- Hands-only view model
SWEP.WorldModel = Model("models/weapons/w_toolgun.mdl") -- Toolgun world model
SWEP.ViewModelFOV = 54  -- Field of view for view model
SWEP.UseHands = true    -- Use c_hands for view model

SWEP.Primary.ClipSize = -1      -- No ammo clip
SWEP.Primary.DefaultClip = -1   -- No default ammo
SWEP.Primary.Automatic = false  -- Not automatic
SWEP.Primary.Ammo = "none"      -- No ammo type

SWEP.Secondary.ClipSize = -1    -- No secondary ammo
SWEP.Secondary.DefaultClip = -1 -- No default secondary ammo
SWEP.Secondary.Automatic = false -- Not automatic
SWEP.Secondary.Ammo = "none"    -- No ammo type

SWEP.HoldType = "normal"        -- How the weapon is held

SWEP.OpenSound = Sound("items/ammopickup.wav") -- Sound when inventory opens

-- Initialize the SWEP
function SWEP:Initialize()
    self:SetHoldType(self.HoldType) -- Set the hold type (e.g., "normal")
end

-- Deploy the SWEP (called when equipped)
function SWEP:Deploy()
    return true -- Allow deployment
end

-- Setup network variables (if needed, though not critical here)
function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextIdle") -- For idle animation timing
end

-- Primary attack to open the inventory
function SWEP:PrimaryAttack()
    if SERVER then
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        -- Send network message to open inventory UI on client
        net.Start("OpenInventory")
        net.Send(owner)

        -- Play sound and animate
        self:EmitSound(self.OpenSound)
        self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
        owner:SetAnimation(PLAYER_ATTACK1)

        -- Set cooldown and idle timing
        local curtime = CurTime()
        local endtime = curtime + self:SequenceDuration()
        self:SetNextIdle(endtime)
        self:SetNextPrimaryFire(endtime + 0.5) -- 0.5-second cooldown
    end
end

-- Secondary attack (optional, left empty for now)
function SWEP:SecondaryAttack()
end

-- Reload (not needed for this SWEP)
function SWEP:Reload()
end

-- Think function for idle animation
function SWEP:Think()
    local curtime = CurTime()
    if curtime >= self:GetNextIdle() then
        self:SendWeaponAnim(ACT_VM_IDLE)
        self:SetNextIdle(curtime + self:SequenceDuration())
    end
end

-- Client-side code (only runs on client)
if CLIENT then
    -- Custom HUD display (optional)
    function SWEP:CustomAmmoDisplay()
        return { Draw = false } -- No ammo display needed
    end

    -- Draw HUD instructions
    function SWEP:DrawHUD()
        draw.SimpleText("Left-click to open inventory", "DermaDefault", ScrW() / 2, ScrH() - 50, Color(255, 255, 255), TEXT_ALIGN_CENTER)
    end
end