AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_c17/doll01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS) -- Use SOLID_VPHYSICS to ensure the entity can be detected by traces
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE) -- Use COLLISION_GROUP_INTERACTIVE to ensure traces can hit it
    self:SetNWBool("IsLightSphere", true)
    self.TimerReduction = 120 -- Seconds to reduce from the ghost timer

    -- Ensure the physics object is valid
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false) -- Prevent the entity from moving
    else
        print("[Death System] Warning: Failed to initialize physics object for Light Sphere (EntIndex=" .. self:EntIndex() .. ")")
    end

    -- Debug print to confirm collision settings
    print("[Death System] Light Sphere (EntIndex=" .. self:EntIndex() .. ") collision settings: Solid=" .. self:GetSolid() .. ", CollisionGroup=" .. self:GetCollisionGroup())

    -- Add a point light to make it glow
    local light = ents.Create("light_dynamic")
    if IsValid(light) then
        light:SetPos(self:GetPos())
        light:SetKeyValue("brightness", "8")
        light:SetKeyValue("distance", "250")
        light:SetKeyValue("style", "0")
        light:SetKeyValue("_light", "255 255 255 255") -- White light
        light:Spawn()
        light:Fire("TurnOn")
        light:SetParent(self)
        self.AttachedLight = light
    end

    print("[Death System] Initialized Light Sphere (EntIndex=" .. self:EntIndex() .. ") at " .. tostring(self:GetPos()))
end

function ENT:Think()
    -- Trigger spark effect every 2 seconds for ghosts
    if not self.NextSpark or self.NextSpark <= CurTime() then
        for _, ply in pairs(player.GetAll()) do
            if ply:GetNWBool("IsGhost", false) then
                net.Start("SphereSparkEffect")
                net.WriteVector(self:GetPos())
                net.Send(ply)
            end
        end
        self.NextSpark = CurTime() + 2
    end
end

function ENT:OnRemove()
    if IsValid(self.AttachedLight) then
        self.AttachedLight:Remove()
    end
end