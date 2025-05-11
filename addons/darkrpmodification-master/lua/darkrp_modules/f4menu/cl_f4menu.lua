print("[F4Menu Module] cl_f4menu.lua loaded successfully")

-- Block the default DarkRP F4 menu
hook.Add("PlayerBindPress", "F4Menu_BlockDarkRPF4Menu", function(ply, bind, pressed)
    if bind == "showspare2" and pressed then
        return true -- Block the default F4 menu
    end
end)

-- Override DarkRP.openF4Menu as a fallback to ensure it doesn't open
if DarkRP and DarkRP.openF4Menu then
    DarkRP.openF4Menu = function()
        -- Do nothing (or add custom behavior in the future)
    end
end

-- Timer to close any DarkRP F4-related panels
hook.Add("Think", "F4Menu_CloseDarkRPF4Menu", function()
    -- Check for specific DarkRP F4 menu panels
    for _, panel in pairs(vgui.GetWorldPanel():GetChildren()) do
        if IsValid(panel) then
            local panelName = panel:GetName()
            if panelName == "F4MenuFrame" or panelName:find("F4Menu") then
                panel:Close()
                print("[F4Menu Module] Force-closed DarkRP F4-related panel: " .. panelName)
            end
        end
    end
end)

-- Suppress any F4-related messages in chat
local oldChatAddText = chat.AddText
chat.AddText = function(...)
    local args = {...}
    local message = ""
    for _, arg in ipairs(args) do
        if type(arg) == "string" then
            message = message .. arg
        end
    end
    if message:lower():find("f4") then
        print("[F4Menu Module] Suppressed chat message related to F4: " .. message)
        return
    end
    oldChatAddText(...)
end

print("[F4Menu Module] Set up client-side hooks to disable DarkRP F4 menu")

-- Placeholder for future expansion (e.g., custom F4 menu system)
-- function F4Menu_OpenCustomMenu()
--     -- Add custom menu logic here in the future
-- end

print("[F4Menu Module] Client-side loaded successfully")