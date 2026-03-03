include("shared.lua")

-- Paradise: tier colors for printer models (exciting pop per tier)
local TIER_COLORS = {
    printer1 = Color(255, 220, 100),   -- warm gold
    printer2 = Color(100, 200, 255),   -- blue
    printer3 = Color(150, 255, 150),   -- green
    printer4 = Color(255, 150, 200),   -- pink
    printer5 = Color(200, 150, 255),   -- purple
    printer6 = Color(255, 180, 80),    -- orange
}

function ENT:Initialize()
    self:initVars()
    if not self.DisplayName or self.DisplayName == "" then
        self.DisplayName = DarkRP.getPhrase("money_printer")
    end
end

local camStart3D2D = cam.Start3D2D
local camEnd3D2D = cam.End3D2D
local drawWordBox = draw.WordBox
local IsValid = IsValid

local color_red = Color(140, 0, 0, 100)
local color_white = color_white
local color_green = Color(50, 200, 50, 100)

function ENT:Draw()
    -- Paradise: tint model by tier
    local col = TIER_COLORS[self:GetClass()] or color_white
    render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
    self:DrawModel()
    render.SetColorModulation(1, 1, 1)

    local Pos = self:GetPos()
    local Ang = self:GetAngles()

    local owner = self:Getowning_ent()
    owner = (IsValid(owner) and owner:Nick()) or DarkRP.getPhrase("unknown")

    surface.SetFont("HUDNumber5")
    local printerName = self.DisplayName
    local stored = self:GetStoredMoney() or 0
    -- Format amount with commas, no double $: "$: 1,234,567"
    local function formatAmount(n)
        local s = tostring(math.floor(n))
        while true do
            local k
            s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
            if k == 0 then break end
        end
        return s
    end
    local storedText = "$: " .. formatAmount(stored)

    -- Text on the printer's side face; rotate so 2D plane faces outward
    Ang:RotateAroundAxis(Ang:Up(), 90)
    local textPos = Pos + Ang:Up() * 11.5 + Ang:Forward() * 1

    camStart3D2D(textPos, Ang, 0.11)
        -- "Cooled" at top when a cooler has this printer in any of its 8 slots (aligned center, slightly larger)
        local cooled = false
        for _, ent in ipairs(ents.FindInSphere(Pos, 120)) do
            if ent:GetClass() ~= "printer_module" or not ent.GetActive or not ent:GetActive() then continue end
            for _, getter in ipairs({"GetConnectedPrinter", "GetConnectedPrinter2", "GetConnectedPrinter3", "GetConnectedPrinter4", "GetConnectedPrinter5", "GetConnectedPrinter6", "GetConnectedPrinter7", "GetConnectedPrinter8"}) do
                local conn = ent[getter] and ent[getter](ent)
                if IsValid(conn) and conn == self then cooled = true break end
            end
            if cooled then break end
        end
        if cooled then
            surface.SetFont("DermaLarge")
            local cooledW = surface.GetTextSize("Cooled")
            drawWordBox(2, -cooledW * 0.5, -68, "Cooled", "DermaLarge", Color(80, 180, 255, 100), color_white)
            surface.SetFont("HUDNumber5")
        end
        -- Printer name (spaced below Cooled when present)
        local w1 = surface.GetTextSize(printerName)
        drawWordBox(2, -w1 * 0.5, -38, printerName, "HUDNumber5", color_red, color_white)
        -- Player name
        local w2 = surface.GetTextSize(owner)
        drawWordBox(2, -w2 * 0.5, 0, owner, "HUDNumber5", color_red, color_white)
        -- $: amount (with commas)
        local w3 = surface.GetTextSize(storedText)
        drawWordBox(2, -w3 * 0.5, 38, storedText, "HUDNumber5", color_green, color_white)
        if stored > 0 then
            local hintW = surface.GetTextSize("E to collect")
            drawWordBox(2, -hintW * 0.5, 68, "E to collect", "DermaDefault", color_green, color_white)
        end
    camEnd3D2D()
end

function ENT:Think()
end
