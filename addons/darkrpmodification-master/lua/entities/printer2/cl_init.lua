--[[---------------------------------------------------------------------------
Client-side rendering for Donator Printer (formerly printer2).
---------------------------------------------------------------------------]]
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
    self:SetRenderMode(RENDERMODE_TRANSCOLOR)
    self.StoredMoneyWarningPrinted = false
    self.StoredMoneyFallback = 0
    self.IsInitialized = true
    print("[Printer2] Initialized on client at position: " .. tostring(self:GetPos()))
    if self:GetModel() != "models/props_c17/consolebox01a.mdl" then
        print("[Printer2] Warning: Model mismatch, expected models/props_c17/consolebox01a.mdl, got " .. tostring(self:GetModel()))
        self:SetModel("models/props_c17/consolebox01a.mdl")
    end
end

function ENT:Draw()
    if not self.IsInitialized then
        self:Initialize()
    end

    print("[Printer2] Drawing entity at position: " .. tostring(self:GetPos()))

    render.SetColorModulation(1, 0.8, 0)
    render.SetBlend(1)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)
    render.SetBlend(1)

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
    local baseText = "Printer"
    local donatorText = "Donator"
    local combinedText = "Donator Printer"
    local moneyText = "Stored: $" .. storedMoney
    local TextWidthBase = surface.GetTextSize(baseText)
    local TextWidthDonator = surface.GetTextSize(donatorText)
    local TextWidthCombined = surface.GetTextSize(combinedText)
    local TextWidth2 = surface.GetTextSize(owner)
    local TextWidth3 = surface.GetTextSize(moneyText)

    Ang:RotateAroundAxis(Ang:Up(), 90)

    cam.Start3D2D(Pos + Ang:Up() * 11.5, Ang, 0.11)
        draw.WordBox(2, -TextWidthCombined * 0.5, -30, "", "HUDNumber5", Color(140, 0, 0, 100), Color(255, 255, 255, 255))
        draw.SimpleText(baseText, "HUDNumber5", -TextWidthCombined * 0.5 + TextWidthBase * 0.5, -30, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(donatorText, "HUDNumber5", -TextWidthCombined * 0.5 + TextWidthBase + TextWidthDonator * 0.5, -30, Color(255, 215, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.WordBox(2, -TextWidth2 * 0.5, 18, owner, "HUDNumber5", Color(140, 0, 0, 100), Color(255, 255, 255, 255))
        draw.WordBox(2, -TextWidth3 * 0.5, 66, moneyText, "HUDNumber5", Color(140, 0, 0, 100), Color(0, 255, 0, 255))
    cam.End3D2D()
end

function ENT:Think()
end