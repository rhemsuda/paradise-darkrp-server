if not CLIENT then return end

-- Helper function to print debug messages conditionally (set rp_debug 1 to see)
local function DebugPrint(...)
    local cv = GetConVar("rp_debug")
    if cv and cv:GetInt() == 1 then print(...) end
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
DebugPrint("[RPAammo] Client-side loaded successfully.")