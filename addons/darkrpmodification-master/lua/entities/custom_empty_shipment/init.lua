AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    util.PrecacheModel("models/Items/item_item_crate.mdl")
    self:SetModel("models/Items/item_item_crate.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(150)
        phys:SetDragCoefficient(5)
        phys:EnableMotion(true)
    end

    local tr = util.TraceEntity({
        start = self:GetPos(),
        endpos = self:GetPos() - Vector(0, 0, 100),
        filter = self
    }, self)
    if tr.Hit then
        self:SetPos(tr.HitPos + Vector(0, 0, self:OBBMaxs().z))
    end

    self.Weapons = {}
    self.MaxWeapons = 10
    self.AbsorptionActive = false
    self:SetupDataTables()
    self:SetTotalWeapons(0)
    self:SetWeaponClass("")
    self:SetName("Empty Shipment")
    self:SetNWString("Name", "Empty Shipment")
    self.UseCooldown = 0
    print("[Custom Empty Shipment] Initialized shipment entity: " .. tostring(self))
end

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "TotalWeapons")
    self:NetworkVar("String", 0, "WeaponClass")
    self:NetworkVar("String", 1, "Name")
    self:NetworkVar("Entity", 0, "gunModel")
    self:NetworkVar("Float", 0, "gunspawn")
    print("[Custom Empty Shipment] SetupDataTables called - networked variables initialized")
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() or self.AbsorptionActive then return end
    if CurTime() < self.UseCooldown then return end

    local ply = activator
    local totalWeapons = self:GetTotalWeapons()

    if totalWeapons > 0 then
        local weaponClass = self:GetWeaponClass()
        local nearbyEnts = ents.FindInSphere(self:GetPos(), 30)
        local hasMatchingWeapon = false
        for _, ent in ipairs(nearbyEnts) do
            local dropClass = ent:GetClass() == "custom_weapon_drop" and ent:GetWeaponClass()
            if dropClass and dropClass == weaponClass then
                hasMatchingWeapon = true
                break
            end
        end

        if hasMatchingWeapon then
            self:AddNearbyWeapons(ply)
        else
            self:DropStoredWeapon(ply)
        end
    elseif totalWeapons < self.MaxWeapons then
        self:AddNearbyWeapons(ply)
    else
        self:SpawnDefaultWeapon(ply)
    end

    self.UseCooldown = CurTime() + 1.5
end

function ENT:AddNearbyWeapons(ply)
    if self.AbsorptionActive then return end
    self.AbsorptionActive = true

    local pos = self:GetPos()
    local radius = 50
    local foundWeapons = 0
    local totalWeapons = self:GetTotalWeapons()

    print("[Custom Empty Shipment] Checking nearby weapons within " .. radius .. " units at " .. tostring(pos))
    local nearbyEnts = ents.FindInSphere(pos, radius)
    for _, ent in ipairs(nearbyEnts) do
        local weaponClass = nil
        print("[Custom Empty Shipment] Found entity: " .. ent:GetClass() .. " at " .. tostring(ent:GetPos()))
        if ent:GetClass() == "custom_weapon_drop" and IsValid(ent) then
            weaponClass = ent:GetWeaponClass()
            print("[Custom Empty Shipment] Detected custom_weapon_drop with class: " .. (weaponClass or "nil"))
        elseif ent:GetClass() == "spawned_weapon" and IsValid(ent) then
            local model = ent:GetModel()
            if model then
                weaponClass = "bb_" .. string.lower(model:match("w_rif_(%a+)") or model:match("w_mach_(%a+)") or model:match("w_pist_(%a+)") or model:match("w_snip_(%a+)") or model:match("w_shot_(%a+)") or ent:GetClass())
                if weaponClass == "bb_m" and model:find("w_mach_m249para") then
                    weaponClass = "bb_m249"
                end
            end
            print("[Custom Empty Shipment] Detected spawned_weapon with derived class: " .. (weaponClass or "nil"))
        end

        if weaponClass and totalWeapons + 1 <= self.MaxWeapons then
            local weaponData = self:GetWeaponData(weaponClass)
            if weaponData then
                if totalWeapons == 0 then
                    self:SetWeaponClass(weaponClass)
                    print("[Custom Empty Shipment] Set initial weapon class to: " .. weaponClass)
                end
                if self:GetWeaponClass() == weaponClass then
                    self:PreAbsorbSparks()
                    timer.Simple(1.5, function()
                        if IsValid(ent) and IsValid(self) then
                            if not ent:IsPlayerHolding() then
                                ent:Remove()
                                self.Weapons[weaponClass] = (self.Weapons[weaponClass] or 0) + 1
                                self:SetTotalWeapons(totalWeapons + 1)
                                local newName = weaponData.name
                                self:SetName(newName)
                                self:SetNWString("Name", newName)
                                print("[Custom Empty Shipment] Absorbed " .. weaponData.name .. ", new count: " .. (totalWeapons + 1) .. ", Set name to: " .. newName)
                                foundWeapons = foundWeapons + 1
                                self:SparkEffect()
                            end
                        end
                        self.AbsorptionActive = false
                        self:UpdateShipmentState()
                    end)
                else
                    DarkRP.notify(ply, 1, 4, "This weapon cannot be added to the shipment! (Mismatch with " .. self:GetWeaponClass() .. ")")
                end
            else
                DarkRP.notify(ply, 1, 4, "This weapon cannot be added to the shipment! (Invalid data for " .. weaponClass .. ")")
            end
        elseif totalWeapons >= self.MaxWeapons then
            DarkRP.notify(ply, 1, 4, "Shipment is full! Maximum capacity reached.")
            break
        end
    end

    if foundWeapons == 0 then
        self.AbsorptionActive = false
    end
end

function ENT:DropStoredWeapon(ply)
    local weaponClass = self:GetWeaponClass()
    if not weaponClass or self:GetTotalWeapons() == 0 then
        DarkRP.notify(ply, 1, 4, "Shipment is empty!")
        return
    end

    local weaponData = self:GetWeaponData(weaponClass)
    if not weaponData then
        DarkRP.notify(ply, 1, 4, "Invalid weapon data in shipment!")
        return
    end

    self:PreAbsorbSparks()
    timer.Simple(1.5, function()
        if IsValid(self) then
            local weaponDrop = ents.Create("custom_weapon_drop")
            if not IsValid(weaponDrop) then
                DarkRP.notify(ply, 1, 4, "Failed to spawn weapon drop!")
                print("[Custom Empty Shipment] Error: Failed to create custom_weapon_drop for " .. weaponClass)
                return
            end

            local pos = self:GetPos() + Vector(0, 0, 40)
            weaponDrop:SetPos(pos)
            weaponDrop:SetWeaponClass(weaponClass)
            weaponDrop:SetWeaponName(weaponData.name)
            weaponDrop:SetModel(weaponData.model)
            weaponDrop:Spawn()

            self.Weapons[weaponClass] = self.Weapons[weaponClass] - 1
            if self.Weapons[weaponClass] <= 0 then
                self.Weapons[weaponClass] = nil
                self:SetWeaponClass("")
                self:SetName("Empty Shipment")
                self:SetNWString("Name", "Empty Shipment")
                print("[Custom Empty Shipment] Set name to: Empty Shipment")
            end
            self:SetTotalWeapons(self:GetTotalWeapons() - 1)

            DarkRP.notify(ply, 0, 4, "Dropped " .. weaponData.name .. " from shipment!")
            print("[Custom Empty Shipment] " .. ply:Nick() .. " dropped " .. weaponData.name .. " (" .. weaponClass .. ") from shipment " .. tostring(self))
            self:SparkEffect()
            self:UpdateShipmentState()
        end
    end)
end

function ENT:SpawnDefaultWeapon(ply)
    local defaultWeaponClass = "weapon_ak47"
    local weaponData = self:GetWeaponData(defaultWeaponClass)
    if weaponData then
        local weaponDrop = ents.Create("custom_weapon_drop")
        if IsValid(weaponDrop) then
            local pos = self:GetPos() + Vector(0, 0, 40)
            weaponDrop:SetPos(pos)
            weaponDrop:SetWeaponClass(defaultWeaponClass)
            weaponDrop:SetWeaponName(weaponData.name)
            weaponDrop:SetModel(weaponData.model)
            weaponDrop:Spawn()
            DarkRP.notify(ply, 0, 4, "Spawned " .. weaponData.name .. " from shipment!")
            print("[Custom Empty Shipment] " .. ply:Nick() .. " spawned " .. weaponData.name .. " (" .. defaultWeaponClass .. ") from shipment " .. tostring(self))
        else
            DarkRP.notify(ply, 1, 4, "Failed to spawn default weapon!")
            print("[Custom Empty Shipment] Error: Failed to create default weapon drop for " .. defaultWeaponClass)
        end
    else
        DarkRP.notify(ply, 1, 4, "No default weapon available!")
    end
end

function ENT:GetTotalWeapons()
    local total = 0
    for _, count in pairs(self.Weapons) do
        total = total + count
    end
    return total
end

function ENT:GetWeaponData(weaponClass)
    for _, singleWeapon in ipairs(_G.SingleWeapons or {}) do
        if singleWeapon.ent == weaponClass then
            return singleWeapon
        end
    end
    return nil
end

function ENT:UpdateShipmentState()
    local totalWeapons = self:GetTotalWeapons()
    self:SetTotalWeapons(totalWeapons)
    self:SetNWInt("WeaponCount", totalWeapons)

    local weaponClass = next(self.Weapons) and next(self.Weapons)
    local weaponData = weaponClass and self:GetWeaponData(weaponClass)
    if weaponData and totalWeapons > 0 then
        local newName = weaponData.name
        self:SetName(newName)
        self:SetNWString("Name", newName)
        print("[Custom Empty Shipment] Updating shipment state with weaponClass: " .. tostring(weaponClass) .. ", Setting name to: " .. newName)
    else
        self:SetName("Empty Shipment")
        self:SetNWString("Name", "Empty Shipment")
        print("[Custom Empty Shipment] Updated state: Set name to Empty Shipment (" .. totalWeapons .. "/" .. self.MaxWeapons .. ")")
    end
end

function ENT:SparkEffect()
    local effectData = EffectData()
    effectData:SetOrigin(self:GetPos() + Vector(0, 0, 20))
    effectData:SetScale(1)
    effectData:SetMagnitude(2)
    util.Effect("Sparks", effectData)
end

function ENT:PreAbsorbSparks()
    local pos = self:GetPos() + Vector(0, 0, 20)
    for i = 0, 2 do
        timer.Simple(i * 0.5, function()
            if IsValid(self) then
                local effectData = EffectData()
                effectData:SetOrigin(pos)
                effectData:SetScale(1)
                effectData:SetMagnitude(2)
                util.Effect("Sparks", effectData)
            end
        end)
    end
end

hook.Add("OnEntityCreated", "CustomEmptyShipment_DebugSpawn", function(ent)
    if ent:GetClass() == "custom_empty_shipment" then
        print("[Custom Empty Shipment] Spawned shipment entity: " .. tostring(ent))
    end
end)