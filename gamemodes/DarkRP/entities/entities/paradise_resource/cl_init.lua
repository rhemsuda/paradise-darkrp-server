include("shared.lua")

-- Cached material for smoke/mist (diamond and obsidian)
local mistMat = Material("particle/smokesprites_0001", "smooth")

function ENT:Draw()
    local resourceID = self:GetNWString("ResourceType", "")

    -- Diamond: slight transparency (alpha only), keep normal material
    if resourceID == "diamond" then
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:SetColor(Color(240, 248, 255, 200))
    end
    self:DrawModel()
    if resourceID == "diamond" then
        self:SetRenderMode(RENDERMODE_NORMAL)
        self:SetColor(Color(240, 248, 255, 255))
    end

    local amount = self:GetNWInt("Amount", 1)
    if resourceID == "" then return end

    local pos = self:GetPos()

    -- Diamond: smoke effect only (no glow)
    if resourceID == "diamond" then
        if mistMat and not mistMat:IsError() then
            render.SetMaterial(mistMat)
            render.DrawSprite(pos + Vector(0, 0, 3), 28, 28, Color(220, 235, 255, 36))
            render.DrawSprite(pos + Vector(0, 0, 6), 22, 22, Color(235, 245, 255, 28))
            render.DrawSprite(pos + Vector(0, 0, 10), 18, 18, Color(248, 252, 255, 18))
        end
    end

    -- Obsidian: refined dark glow + mist (turned up slightly)
    if resourceID == "obsidian" then
        local dlight = DynamicLight(self:EntIndex() + 32768)
        if dlight then
            dlight.pos = pos + Vector(0, 0, 10)
            dlight.r = 55
            dlight.g = 45
            dlight.b = 75
            dlight.brightness = 0.38
            dlight.decay = 1000
            dlight.size = 95
        end
        if mistMat and not mistMat:IsError() then
            render.SetMaterial(mistMat)
            render.DrawSprite(pos + Vector(0, 0, 3), 26, 26, Color(28, 28, 50, 38))
            render.DrawSprite(pos + Vector(0, 0, 6), 20, 20, Color(45, 38, 65, 28))
            render.DrawSprite(pos + Vector(0, 0, 10), 16, 16, Color(55, 48, 80, 18))
        end
    end

    -- Label above entity: "ResourceName x amount"
    local displayName = resourceID
    if Paradise and Paradise.ResourceDisplay and Paradise.ResourceDisplay[resourceID] then
        displayName = Paradise.ResourceDisplay[resourceID].name or resourceID
    elseif ResourceItems and ResourceItems[resourceID] then
        displayName = ResourceItems[resourceID].name or resourceID
    else
        displayName = string.upper(string.sub(resourceID, 1, 1)) .. string.sub(resourceID, 2)
    end
    local labelText = displayName .. " x " .. tostring(amount)
    local pos = self:GetPos() + Vector(0, 0, 20)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)
    cam.Start3D2D(pos, ang, 0.1)
        draw.RoundedBox(4, -50, -10, 100, 20, Color(0, 0, 0, 200))
        draw.SimpleText(labelText, "DermaDefault", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
