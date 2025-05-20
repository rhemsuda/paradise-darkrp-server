include("shared.lua")

util.PrecacheModel("models/props_c17/consolebox01a.mdl") -- Updated to match init.lua

print("[Printer1] cl_init.lua loaded successfully")

net.Receive("PrinterForceClientUpdate", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then
        print("[Printer1] Received force update for invalid entity")
        return
    end
    print("[Printer1] Received force update for entity " .. tostring(ent))
    if ent.Initialize then
        ent:Initialize()
    end
end)

function ENT:Initialize()
    self.StoredMoneyWarningPrinted = false
    self.StoredMoneyFallback = 0
    self.IsInitialized = true
    self.HasDrawn = false

    -- Ensure the model is set
    if self:GetModel() != "models/props_c17/consolebox01a.mdl" then
        print("[Printer1] Warning: Model mismatch, expected models/props_c17/consolebox01a.mdl, got " .. tostring(self:GetModel()))
        self:SetModel("models/props_c17/consolebox01a.mdl")
    end

    -- Explicitly set render mode and color to ensure visibility
    self:SetRenderMode(RENDERMODE_NORMAL)
    self:SetColor(Color(255, 255, 255, 255))

    -- Debug prints to check entity state
    print("[Printer1] Initialized on client at position: " .. tostring(self:GetPos()))
    print("[Printer1] Render mode: " .. self:GetRenderMode())
    print("[Printer1] Color: " .. tostring(self:GetColor()))
    print("[Printer1] NoDraw: " .. tostring(self:GetNoDraw()))
    print("[Printer1] Effects: " .. tostring(self:GetEffects()))
end

function ENT:Draw()
    if not self.IsInitialized then
        self:Initialize()
    end

    if not self.HasDrawn then
        print("[Printer1] Drawing entity at position: " .. tostring(self:GetPos()))
        self.HasDrawn = true
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
        print("[Printer1] Warning: GetStoredMoney method not available")
        timer.Simple(10, function()
            if IsValid(self) then
                self.StoredMoneyWarningPrinted = false
            end
        end)
    end

    surface.SetFont("HUDNumber5")
    local text = "Printer"
    local moneyText = "Stored: $" .. storedMoney
    local TextWidth = surface.GetTextSize(text)
    local TextWidth2 = surface.GetTextSize(owner)
    local TextWidth3 = surface.GetTextSize(moneyText)

    Ang:RotateAroundAxis(Ang:Up(), 90)

    cam.Start3D2D(Pos + Ang:Up() * 11.5, Ang, 0.11)
        draw.WordBox(2, -TextWidth * 0.5, -30, text, "HUDNumber5", Color(140, 0, 0, 100), Color(255, 255, 255, 255))
        draw.WordBox(2, -TextWidth2 * 0.5, 18, owner, "HUDNumber5", Color(140, 0, 0, 100), Color(255, 255, 255, 255))
        draw.WordBox(2, -TextWidth3 * 0.5, 66, moneyText, "HUDNumber5", Color(140, 0, 0, 100), Color(0, 255, 0, 255))
    cam.End3D2D()
end

function ENT:Think()
end