include("shared.lua")

util.PrecacheModel("models/props_c17/consolebox01a.mdl")

print("[Printer2] cl_init.lua loaded successfully")

net.Receive("PrinterForceClientUpdate", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then
        print("[Printer2] Received force update for invalid entity")
        return
    end
    print("[Printer2] Received force update for entity " .. tostring(ent))
    if ent.Initialize then
        ent:Initialize()
    end
end)

function ENT:Initialize()
    self.StoredMoneyWarningPrinted = false
    self.StoredMoneyFallback = 0
    self.IsInitialized = true

    if self:GetModel() != "models/props_c17/consolebox01a.mdl" then
        print("[Printer2] Warning: Model mismatch, expected models/props_c17/consolebox01a.mdl, got " .. tostring(self:GetModel()))
        self:SetModel("models/props_c17/consolebox01a.mdl")
    end

    self:SetRenderMode(RENDERMODE_NORMAL)
    self:SetColor(Color(255, 215, 0, 255))

    print("[Printer2] Initialized on client at position: " .. tostring(self:GetPos()))
    print("[Printer2] Render mode: " .. self:GetRenderMode())
    print("[Printer2] Color: " .. tostring(self:GetColor()))
    print("[Printer2] NoDraw: " .. tostring(self:GetNoDraw()))
    print("[Printer2] Effects: " .. tostring(self:GetEffects()))
end

function ENT:Draw()
    if not self.IsInitialized then
        self:Initialize()
    end

    self:DrawModel()

    local Pos = self:GetPos()
    local Ang = self:GetAngles()

    local owner = self:Getowning_ent()
    owner = (IsValid(owner) and owner:Nick()) or DarkRP.getPhrase("unknown")

    local storedMoney = self.StoredMoneyFallback
    if self.GetStoredMoney then
        storedMoney = self:GetStoredMoney() or self.StoredMoneyFallback
        self.StoredMoneyFallback = storedMoney
    elseif not self.StoredMoneyWarningPrinted then
        self.StoredMoneyWarningPrinted = true
        print("[Printer2] Warning: GetStoredMoney method not available")
        timer.Simple(10, function()
            if IsValid(self) then
                self.StoredMoneyWarningPrinted = false
            end
        end)
    end

    surface.SetFont("HUDNumber5")
    local donatorText = "Donator"
    local text = "Printer"
    local moneyText = "Stored: $" .. storedMoney
    local DonatorWidth = surface.GetTextSize(donatorText)
    local TextWidth = surface.GetTextSize(text)
    local TextWidth2 = surface.GetTextSize(owner)
    local TextWidth3 = surface.GetTextSize(moneyText)

    Ang:RotateAroundAxis(Ang:Up(), 90)

    cam.Start3D2D(Pos + Ang:Up() * 11.5, Ang, 0.11)
        draw.SimpleText(donatorText, "HUDNumber5", 0, -66, Color(255, 215, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(text, "HUDNumber5", 0, -30, Color(255, 215, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(owner, "HUDNumber5", 0, 18, Color(255, 215, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(moneyText, "HUDNumber5", 0, 66, Color(0, 255, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

function ENT:Think()
end