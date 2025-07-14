AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    -- Delay initialization to ensure network variables are synced
    timer.Simple(0, function()
        if not IsValid(self) then
            print("[Custom Weapon Drop] Error: Entity invalid during delayed init")
            return
        end

        -- Get the weapon model
        local weaponModel = self:GetWeaponModel()
        print("[Custom Weapon Drop] Raw WeaponModel value: " .. tostring(weaponModel))

        -- Fallback to weapon class model if WeaponModel is empty
        if not weaponModel or weaponModel == "" then
            local weaponClass = self:GetWeaponClass()
            if weaponClass and weapons.Get(weaponClass) then
                weaponModel = weapons.Get(weaponClass).WorldModel or "models/props_junk/cardboard_box001a.mdl"
                print("[Custom Weapon Drop] WeaponModel empty, using weapon class model: " .. weaponModel)
            else
                weaponModel = "models/props_junk/cardboard_box001a.mdl"
                print("[Custom Weapon Drop] Error: No weapon model or valid weapon class, using fallback: " .. weaponModel)
            end
        end

        -- Precache the model
        util.PrecacheModel(weaponModel)
        print("[Custom Weapon Drop] Precached model: " .. weaponModel)

        -- Set the model
        self:SetModel(weaponModel)
        print("[Custom Weapon Drop] Set model to: " .. tostring(self:GetModel()))

        -- Initialize physics
        local success = self:PhysicsInit(SOLID_VPHYSICS)
        if not success then
            print("[Custom Weapon Drop] Error: Failed to initialize physics for " .. tostring(self) .. " with model " .. weaponModel)
        end

        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:SetCollisionGroup(COLLISION_GROUP_WEAPON) -- Avoid player collision

        -- Validate physics object and set initial state
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(10)
            phys:EnableMotion(true)
            phys:SetVelocity(Vector(0, 0, 0))
            phys:SetAngleVelocity(Vector(0, 0, 0))
            phys:Sleep() -- Force it to settle
            print("[Custom Weapon Drop] Physics object initialized successfully")
        else
            print("[Custom Weapon Drop] Error: Physics object invalid for " .. tostring(self))
        end

        -- Debug entity properties
        print("[Custom Weapon Drop] Initialized with:")
        print("[Custom Weapon Drop] - Entity: " .. tostring(self))
        print("[Custom Weapon Drop] - Model: " .. tostring(self:GetModel()))
        print("[Custom Weapon Drop] - WeaponClass: " .. tostring(self:GetWeaponClass()))
        print("[Custom Weapon Drop] - WeaponName: " .. tostring(self:GetWeaponName()))
        print("[Custom Weapon Drop] - Position: " .. tostring(self:GetPos()))
    end)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local weaponClass = self:GetWeaponClass()
    if not weaponClass or not weapons.Get(weaponClass) then
        print("[Custom Weapon Drop] Error: Invalid weapon class " .. tostring(weaponClass))
        DarkRP.notify(activator, 1, 4, "Cannot pick up: Invalid weapon!")
        return
    end

    activator:Give(weaponClass)
    DarkRP.notify(activator, 0, 4, "Picked up " .. (self:GetWeaponName() or weaponClass) .. "!")
    print("[Custom Weapon Drop] " .. activator:Nick() .. " picked up " .. weaponClass)

    self:Remove()
end