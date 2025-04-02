-- gamemodes/darkrp/entities/entities/resource_item/cl_init.lua

include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    -- Draw a 3D label above the entity
    local pos = self:GetPos() + Vector(0, 0, 20) -- Adjust height above the entity
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    local resourceID = self:GetNWString("ResourceID", "Unknown")
    local amount = self:GetNWInt("ResourceAmount", 1)
    local resourceData = ResourceItems[resourceID] or { name = resourceID }
    local displayName = resourceData.name or (string.upper(resourceID:sub(1,1)) .. resourceID:sub(2))
    local labelText = displayName .. " x " .. amount

    cam.Start3D2D(pos, ang, 0.1)
        draw.RoundedBox(4, -50, -10, 100, 20, Color(0, 0, 0, 200))
        draw.SimpleText(labelText, "DermaDefault", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end