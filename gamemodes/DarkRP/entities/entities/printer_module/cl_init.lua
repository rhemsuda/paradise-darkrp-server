include("shared.lua")

local color_red_bg = Color(180, 0, 0, 200)
local color_green_bg = Color(0, 140, 0, 200)
local color_white = color_white
local laser_mat = Material("cable/redlaser")
local laser_color = Color(255, 80, 80, 220)

function ENT:Draw()
    self:DrawModel()

    -- Lasers to up to 8 connected printers (static visual; printers are protected on server)
    if self:GetActive() then
        local getters = {"GetConnectedPrinter", "GetConnectedPrinter2", "GetConnectedPrinter3", "GetConnectedPrinter4", "GetConnectedPrinter5", "GetConnectedPrinter6", "GetConnectedPrinter7", "GetConnectedPrinter8"}
        render.SetMaterial(laser_mat)
        for _, getter in ipairs(getters) do
            local conn = self[getter] and self[getter](self)
            if IsValid(conn) then
                render.DrawBeam(self:GetPos(), conn:GetPos(), 3, 0, 0, laser_color)
            end
        end
    end

    local pos = self:GetPos()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 90)

    -- "Cooler" label above the timer, closer to the face of the module
    surface.SetFont("HUDNumber5")
    cam.Start3D2D(pos + ang:Up() * 4, ang, 0.08)

    -- "Cooler" label with more space above the timer
    local coolerW = surface.GetTextSize("Cooler")
    draw.WordBox(2, -coolerW * 0.5, -58, "Cooler", "HUDNumber5", Color(60, 100, 140, 200), color_white)

    if self:GetActive() then
        local left = math.max(0, math.floor(self:GetTimeLeft() or 0))
        local m = math.floor(left / 60)
        local s = left % 60
        local text = string.format("%d:%02d", m, s)
        local w = surface.GetTextSize(text)
        draw.WordBox(2, -w * 0.5, -28, text, "HUDNumber5", color_green_bg, color_white)
    else
        local text = "ACTIVATE"
        local w = surface.GetTextSize(text)
        draw.WordBox(2, -w * 0.5, -28, text, "HUDNumber5", color_red_bg, color_white)
    end

    cam.End3D2D()
end
