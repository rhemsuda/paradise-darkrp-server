-- gamemodes/darkrp/gamemode/modules/base/cl_spawnmenu.lua

if CLIENT then
    -- Optional: Debug the available tools
    hook.Add("InitPostEntity", "DebugTools", function()
        print("[Debug] Available tools in list.Get('Tool'):")
        for k, v in pairs(list.Get("Tool")) do
            print("[Debug] Tool: " .. k .. " (Name: " .. (v.Name or "Unknown") .. ")")
        end
    end)
end