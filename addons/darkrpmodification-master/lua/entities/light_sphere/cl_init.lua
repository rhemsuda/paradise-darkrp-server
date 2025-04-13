include("shared.lua")

function ENT:Initialize()
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMaterial("lights/white")
    self:SetColor(Color(255, 255, 255, 200))
end

function ENT:Draw()
    self:DrawModel()
end