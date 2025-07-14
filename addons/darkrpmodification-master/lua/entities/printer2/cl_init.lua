include("shared.lua")

util.PrecacheModel("models/props_c17/consolebox01a.mdl")

print("[Printer] cl_init.lua loaded successfully")

net.Receive("PrinterForceClientUpdate", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then
        print("[Printer] Received force update for invalid entity")
        return
    end
    print("[Printer] Received force update for entity " .. tostring(ent))
    if ent.Initialize then
        ent:Initialize()
    end
end)

function ENT:Initialize()
    self.StoredMoneyWarningPrinted = false
    self.StoredMoneyFallback = 0
    self.IsInitialized = true
    self.LastDraw = 0
    self.DisplayName = "Printer"
    self.ModuleSaveCounter = self.ModuleSaveCounter or 0
    self.ModuleMaxSaves = self.ModuleMaxSaves or 5
    self.ModuleAttached = self.ModuleAttached or false

    if self:GetModel() != "models/props_c17/consolebox01a.mdl" then
        print("[Printer] Warning: Model mismatch, expected models/props_c17/consolebox01a.mdl, got " .. tostring(self:GetModel()))
        self:SetModel("models/props_c17/consolebox01a.mdl")
    end

    self:SetRenderMode(RENDERMODE_NORMAL)
    self:SetColor(Color(255, 215, 0, 255))
    self:SetNoDraw(false)

    print("[Printer] Initialized on client at position: " .. tostring(self:GetPos()))
    print("[Printer] Render mode: " .. self:GetRenderMode())
    print("[Printer] Color: " .. tostring(self:GetColor()))
    print("[Printer] NoDraw: " .. tostring(self:GetNoDraw()))
    print("[Printer] Effects: " .. tostring(self:GetEffects()))
end

function ENT:Draw()
    if not IsValid(self) then return end
    self:SetNoDraw(false)

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
        print("[Printer] Warning: GetStoredMoney method not available")
        timer.Simple(10, function()
            if IsValid(self) then
                self.StoredMoneyWarningPrinted = false
            end
        end)
    end

    local cooledText = self.ModuleAttached and ("Cooled " .. (self.ModuleSaveCounter or 0) .. "/" .. (self.ModuleMaxSaves or 5)) or ""
    if self.ModuleTopUpPending and self.ModuleAttached then
        cooledText = cooledText .. " (Top Up Needed)"
    end

    surface.SetFont("HUDNumber5")
    local donatorText = "Donator"
    local text = self.DisplayName
    local moneyText = "Stored: $" .. storedMoney
    local DonatorWidth = surface.GetTextSize(donatorText)
    local TextWidth = surface.GetTextSize(text)
    local TextWidth2 = surface.GetTextSize(owner)
    local TextWidth3 = surface.GetTextSize(moneyText)
    local TextWidth4 = surface.GetTextSize(cooledText)

    Ang:RotateAroundAxis(Ang:Up(), 90)

    -- Uniform spacing (30 units between lines), positioned on top face
    local baseY = -60 -- Adjusted to fit stack near the bottom of the top face
    cam.Start3D2D(Pos + Ang:Up() * 11.5, Ang, 0.11)
        draw.SimpleText(donatorText, "HUDNumber5", 0, baseY + 30, Color(255, 215, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(text, "HUDNumber5", 0, baseY + 60, Color(255, 215, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(owner, "HUDNumber5", 0, baseY + 90, Color(255, 215, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if cooledText ~= "" then
            draw.SimpleText(cooledText, "HUDNumber5", 0, baseY + 120, Color(255, 215, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        draw.SimpleText(moneyText, "HUDNumber5", 0, baseY + 150, Color(0, 255, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        -- Debug wireframe to check text plane
        render.DrawWireframeBox(Pos + Ang:Up() * 11.5, Ang, Vector(-10, -10, 0), Vector(10, 10, 0), Color(0, 0, 255, 100), true)
    cam.End3D2D()
end

function ENT:Think()
end