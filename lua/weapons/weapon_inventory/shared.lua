if SERVER then
    AddCSLuaFile("shared.lua")
    AddCSLuaFile("cl_init.lua")
end

if CLIENT then
    SWEP.PrintName = "Inventory"
    SWEP.Slot = 1
    SWEP.SlotPos = 1
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = true
end

SWEP.Author = "Nick"
SWEP.Instructions = "Left-click to open your inventory."
SWEP.Purpose = "Access your items."
SWEP.Category = "Inventory"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.ClassName = "weapon_inventory"

SWEP.ViewModel = "models/weapons/v_hands.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"