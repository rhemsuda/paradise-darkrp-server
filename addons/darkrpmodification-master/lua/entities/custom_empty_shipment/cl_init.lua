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
    print("[Debug] Received DarkRP_shipmentSpawn for entity: " .. tostring(ent))
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

    local normal = -self:GetAngles():Up()
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

    local obbMaxs = self:OBBMaxs()
    local obbMins = self:OBBMins()
    local faceHeight = (obbMaxs.z - obbMins.z) * 0.5
    local horizontalOffset = -11.0
    local verticalOffset = faceHeight + 0
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
    local name = self:GetNWString("Name", "Empty Shipment")

    cam.Start3D2D(pos, ang, 0.25)
        surface.SetFont("Trebuchet18")
        local nameText = (amount > 0 and name or "Empty Shipment")
        local amountText = (amount > 0 and "x " .. amount or "")
        local nameWidth = surface.GetTextSize(nameText)
        local amountWidth = amountText ~= "" and surface.GetTextSize(amountText) or 0
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

net.Receive("OpenShipmentMenuClient", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) or not ent.IsSpawnedShipment then return end
    print("[Debug] Received OpenShipmentMenuClient for entity: " .. tostring(ent))

    local menu = vgui.Create("DFrame")
    if not IsValid(menu) then
        print("[Debug] Failed to create DFrame")
        return
    end
    menu:SetSize(200, 200)
    menu:Center()
    menu:SetTitle("Shipment Menu")
    menu:SetVisible(true)
    menu:SetDraggable(true)
    menu:ShowCloseButton(true)
    menu:MakePopup()
    print("[Debug] Menu created successfully")

    local passwordButton = vgui.Create("DButton", menu)
    passwordButton:SetText("Password")
    passwordButton:SetPos(10, 30)
    passwordButton:SetSize(180, 30)
    passwordButton.DoClick = function()
        local passwordInput = vgui.Create("DFrame")
        if not IsValid(passwordInput) then
            print("[Debug] Failed to create password input frame")
            return
        end
        passwordInput:SetSize(200, 100)
        passwordInput:Center()
        passwordInput:SetTitle("Set Password")
        passwordInput:SetVisible(true)
        passwordInput:SetDraggable(true)
        passwordInput:ShowCloseButton(true)
        passwordInput:MakePopup()

        local input = vgui.Create("DTextEntry", passwordInput)
        input:SetPos(10, 30)
        input:SetSize(180, 30)
        input:SetText("")

        local submit = vgui.Create("DButton", passwordInput)
        submit:SetText("Submit")
        submit:SetPos(10, 70)
        submit:SetSize(180, 30)
        submit.DoClick = function()
            net.Start("SetShipmentPassword")
                net.WriteEntity(ent)
                net.WriteString(input:GetValue())
            net.SendToServer()
            passwordInput:Close()
            print("[Debug] Password submitted: " .. input:GetValue())
        end
    end

    local sellButton = vgui.Create("DButton", menu)
    sellButton:SetText("Sell")
    sellButton:SetPos(10, 70)
    sellButton:SetSize(180, 30)
    local totalWeapons = ent:GetTotalWeapons()
    if totalWeapons <= 0 then
        sellButton:SetEnabled(false)
        sellButton:SetTextColor(Color(100, 100, 100))
        print("[Debug] Sell button darkened, shipment is empty (total weapons: " .. totalWeapons .. ")")
    else
        sellButton:SetEnabled(true)
        sellButton:SetTextColor(color_white)
        sellButton.DoClick = function()
            net.Start("OpenSellMenu")
                net.WriteEntity(ent)
            net.SendToServer()
            print("[Debug] Sell button clicked for shipment: " .. tostring(ent))
        end
    end

    local addButton = vgui.Create("DButton", menu)
    addButton:SetText("Add")
    addButton:SetPos(10, 110)
    addButton:SetSize(180, 30)
    addButton.DoClick = function()
        net.Start("AddToShipment")
            net.WriteEntity(ent)
        net.SendToServer()
        print("[Debug] Add button clicked for shipment: " .. tostring(ent))
    end

    local removeButton = vgui.Create("DButton", menu)
    removeButton:SetText("Remove")
    removeButton:SetPos(10, 150)
    removeButton:SetSize(180, 30)
    if totalWeapons <= 0 then
        removeButton:SetEnabled(false)
        removeButton:SetTextColor(Color(100, 100, 100))
        print("[Debug] Remove button darkened, shipment is empty (total weapons: " .. totalWeapons .. ")")
    else
        removeButton:SetEnabled(true)
        removeButton:SetTextColor(color_white)
        removeButton.DoClick = function()
            net.Start("RemoveFromShipment")
                net.WriteEntity(ent)
            net.SendToServer()
            print("[Debug] Remove button clicked for shipment: " .. tostring(ent))
        end
    end
end)

net.Receive("OpenSellMenuClient", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) or not ent.IsSpawnedShipment then return end
    print("[Debug] Received OpenSellMenuClient for entity: " .. tostring(ent))

    local menu = vgui.Create("DFrame")
    menu:SetSize(250, 200)
    menu:Center()
    menu:SetTitle("Sell Items")
    menu:SetVisible(true)
    menu:SetDraggable(true)
    menu:ShowCloseButton(true)
    menu:MakePopup()

    local weaponClass = ent:GetWeaponClass()
    local weaponData = CustomShipments[weaponClass] or {}
    local amount = ent:GetTotalWeapons()
    local pricePerItem = weaponData.price and weaponData.price / weaponData.amount or nil

    if pricePerItem then
        local label = vgui.Create("DLabel", menu)
        label:SetText("Sell price per item (default: " .. pricePerItem .. "):")
        label:SetPos(10, 30)
        label:SizeToContents()

        local priceInput = vgui.Create("DTextEntry", menu)
        priceInput:SetPos(10, 50)
        priceInput:SetSize(230, 30)
        priceInput:SetText(tostring(pricePerItem))

        local sellButton = vgui.Create("DButton", menu)
        sellButton:SetText("Sell Item")
        sellButton:SetPos(10, 90)
        sellButton:SetSize(230, 30)
        sellButton.DoClick = function()
            local sellPrice = tonumber(priceInput:GetValue()) or pricePerItem
            if sellPrice and sellPrice > 0 then
                net.Start("SellShipmentItem")
                    net.WriteEntity(ent)
                    net.WriteFloat(sellPrice)
                net.SendToServer()
                menu:Close()
                print("[Debug] Sell item requested with price: " .. sellPrice)
            else
                chat.AddText(Color(255, 0, 0), "Invalid price!")
            end
        end
    else
        local label = vgui.Create("DLabel", menu)
        label:SetText("No price set for this item.")
        label:SetPos(10, 30)
        label:SizeToContents()
    end
end)