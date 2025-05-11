print("[F4Menu Module] sv_f4menu.lua loaded successfully")

-- Override DarkRP.openF4Menu if it exists
if DarkRP and DarkRP.openF4Menu then
    DarkRP.openF4Menu = function() end
    print("[F4Menu Module] Overrode DarkRP.openF4Menu to prevent F4 menu from opening")
end

-- Add a high-priority hook to block the F4 menu
hook.Add("ShowSpare2", "F4Menu_DisableDarkRPF4Menu", function(ply)
    return true -- Returning true prevents the default F4 menu from opening
end, -100) -- High priority

print("[F4Menu Module] Set up server-side hooks to disable DarkRP F4 menu")

-- Placeholder for future expansion (e.g., custom F4 menu system)
-- function F4Menu_OpenCustomMenu(ply)
--     -- Add custom menu logic here in the future
-- end

print("[F4Menu Module] Server-side loaded successfully")