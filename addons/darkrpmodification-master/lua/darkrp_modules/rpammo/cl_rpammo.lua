-- Debug print to confirm the file is loading
print("[RPAammo] cl_rpammo.lua loaded successfully")

-- Helper function to print debug messages conditionally (copied from cl_inventory.lua for consistency)
local function DebugPrint(...)
    if GetConVar("rp_debug") and GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Receive notifications from the server
net.Receive("RPAammoNotification", function()
    local message = net.ReadString()
    local screenW, screenH = ScrW(), ScrH()

    -- Create a temporary panel for the notification (consistent with inventory notifications)
    local notification = vgui.Create("DPanel")
    notification:SetSize(300, 50)
    notification:SetPos(screenW - 320, 20) -- Top-right corner
    notification:SetZPos(1000)
    notification.Think = function(self)
        if self.StartTime and (CurTime() - self.StartTime) > 3 then
            self:Remove()
        end
    end
    notification.StartTime = CurTime()
    notification.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
        draw.SimpleText(message, "DermaDefaultBold", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Play DarkRP-style notification sound
    surface.PlaySound("ui/buttonclick.wav")
    DebugPrint("[RPAammo] Notification: " .. message)
end)

-- This print will always show to confirm successful load
print("[RPAammo] Client-side loaded successfully.")