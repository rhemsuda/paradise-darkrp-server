include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos() + Vector(0, 0, 20)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    local resourceID = self:GetNWString("ResourceType") -- Match server-side access
    local amount = self:GetNWInt("Amount")
    
    if not self.debugPrinted then
        print("[Debug] resource_steel: resourceID = " .. tostring(resourceID) .. ", amount = " .. tostring(amount))
        if not resourceID or resourceID == "" then
            print("[Debug] resource_steel: ResourceType is nil or empty!")
        end
        if not ResourceItems then
            print("[Debug] resource_steel: ResourceItems is nil!")
        elseif not ResourceItems[resourceID] then
            print("[Debug] resource_steel: ResourceItems[" .. tostring(resourceID) .. "] is nil!")
        end
        self.debugPrinted = true
    end

    local resourceData = ResourceItems and ResourceItems[resourceID] or { name = "Unknown" }
    local displayName = resourceData.name or (string.upper(resourceID:sub(1,1)) .. resourceID:sub(2))
    local labelText = displayName .. " x " .. amount

    cam.Start3D2D(pos, ang, 0.1)
        draw.RoundedBox(4, -50, -10, 100, 20, Color(0, 0, 0, 200))
        draw.SimpleText(labelText, "DermaDefault", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end