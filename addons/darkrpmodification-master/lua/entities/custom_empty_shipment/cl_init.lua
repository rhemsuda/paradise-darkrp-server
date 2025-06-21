include("shared.lua")

local matBallGlow = Material("models/props_combine/tpballglow")
function ENT:Draw()
    if not IsValid(self) then return end
    self.height = self.height or 0
    self.colr = self.colr or 1
    self.colg = self.colg or 0
    self.StartTime = self.StartTime or CurTime()

    if GAMEMODE.Config.shipmentspawntime > 0 and self.height < self:OBBMaxs().z then
        self:drawSpawning()
    else
        self:DrawModel()
    end

    self:drawFloatingGun()
    self:drawInfo()
end

net.Receive("DarkRP_shipmentSpawn", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) or not ent.IsSpawnedShipment then return end

    ent.height = 0
    ent.StartTime = CurTime()
end)

function ENT:drawSpawning()
    if not IsValid(self) then return end
    render.MaterialOverride(matBallGlow)

    render.SetColorModulation(self.colr, self.colg, 0)

    self:DrawModel()

    render.MaterialOverride()
    self.colr = 1 - ((CurTime() - self.StartTime) / GAMEMODE.Config.shipmentspawntime)
    self.colg = (CurTime() - self.StartTime) / GAMEMODE.Config.shipmentspawntime

    render.SetColorModulation(1, 1, 1)

    render.MaterialOverride()

    local normal = - self:GetAngles():Up()
    local pos = self:LocalToWorld(Vector(0, 0, self:OBBMins().z + self.height))
    local distance = normal:Dot(pos)
    self.height = self:OBBMaxs().z * ((CurTime() - self.StartTime) / GAMEMODE.Config.shipmentspawntime)
    render.EnableClipping(true)
    render.PushCustomClipPlane(normal, distance)

    self:DrawModel()

    render.PopCustomClipPlane()
end

function ENT:drawFloatingGun()
    if not IsValid(self) then return end
    local weaponClass = self:GetWeaponClass() or ""
    local contents = CustomShipments[weaponClass] or {}
    if not contents or not IsValid(self:GetgunModel()) then return end
    self:GetgunModel():SetNoDraw(true)

    local pos = self:GetPos()
    local ang = self:GetAngles()

    local gunPos = self:GetAngles():Up() * 40 + ang:Up() * (math.sin(CurTime() * 3) * 8)
    self:GetgunModel():SetPos(pos + gunPos)

    ang:RotateAroundAxis(ang:Up(), (CurTime() * 180) % 360)
    self:GetgunModel():SetAngles(ang)

    if self:Getgunspawn() < CurTime() - 2 then
        self:GetgunModel():DrawModel()
        return
    elseif self:Getgunspawn() < CurTime() then
        return
    end

    local delta = self:Getgunspawn() - CurTime()
    local min, max = self:GetgunModel():OBBMins(), self:GetgunModel():OBBMaxs()
    min, max = self:GetgunModel():LocalToWorld(min), self:GetgunModel():LocalToWorld(max)

    render.MaterialOverride(matBallGlow)
    render.SetColorModulation(1 - delta, delta, 0)
    self:GetgunModel():DrawModel()
    render.MaterialOverride()
    render.SetColorModulation(1, 1, 1)

    render.EnableClipping(true)
    local normal = -self:GetgunModel():GetAngles():Forward()
    local cutPosition = LerpVector(delta, max, min)
    local cutDistance = normal:Dot(cutPosition)

    render.PushCustomClipPlane(normal, cutDistance);
    self:GetgunModel():DrawModel()
    render.PopCustomClipPlane()

    render.EnableClipping(false)
end

local color_red = Color(140, 0, 0, 100)
local color_white = color_white

function ENT:drawInfo()
    if not IsValid(self) then return end
    local pos = self:GetPos()
    local ang = self:GetAngles()

    -- Position text on the center of the front face with horizontal adjustment
    local obbMaxs = self:OBBMaxs()
    local obbMins = self:OBBMins()
    local faceHeight = (obbMaxs.z - obbMins.z) * 0.5  -- Middle of the OBB height
    local horizontalOffset = -11.0  -- Adjust this value to move left (-ve) or right (+ve)
    local verticalOffset = faceHeight + 0  -- Vertical adjustment
    local offset = self:GetForward() * 0.0 + self:GetRight() * horizontalOffset + self:GetUp() * verticalOffset
    pos = self:LocalToWorld(self:OBBCenter()) + offset

    if not self.initialPrint then
        print("[Custom Empty Shipment] Text position: " .. tostring(pos) .. " | OBB Center: " .. tostring(self:OBBCenter()) .. " | OBB Maxs: " .. tostring(obbMaxs) .. " | OBB Mins: " .. tostring(obbMins) .. " | Ground Z: " .. tostring(self:GetPos().z))
        self.initialPrint = true
    end

    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 0)

    local weaponClass = self:GetWeaponClass() or ""
    local contents = CustomShipments[weaponClass] or {name = "Empty Shipment"}
    if not contents.name then contents.name = "Empty Shipment" end
    local amount = self:GetTotalWeapons()
    local name = self:GetNWString("Name", "Empty Shipment")  -- Use networked name

    cam.Start3D2D(pos, ang, 0.25)
        surface.SetFont("Trebuchet18")
        local nameText = (amount > 0 and name or "Empty Shipment")
        local amountText = (amount > 0 and "x " .. amount or "")
        local nameWidth = surface.GetTextSize(nameText)
        local amountWidth = amountText ~= "" and surface.GetTextSize(amountText) or 0
        -- Center both lines relative to the widest text, with fallback
        local maxWidth = math.max(nameWidth, amountWidth or 0)
        draw.SimpleTextOutlined(nameText, "Trebuchet18", -maxWidth / 2, -15, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 255))
        if amount > 0 then
            draw.SimpleTextOutlined(amountText, "Trebuchet18", -maxWidth / 2, 15, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 255))
        end
    cam.End3D2D()
end

properties.Add("splitShipment",
{
    MenuLabel   =   DarkRP.getPhrase("splitshipment"),
    Order       =   2004,
    MenuIcon    =   "icon16/arrow_divide.png",

    Filter      =   function(self, ent, ply)
                        if not IsValid(ent) then return false end
                        return ent.IsSpawnedShipment
                    end,

    Action      =   function(self, ent)
                        if not IsValid(ent) then return end
                        RunConsoleCommand("darkrp", "splitshipment", ent:EntIndex())
                    end
})