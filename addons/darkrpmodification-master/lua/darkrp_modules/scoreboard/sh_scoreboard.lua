-- Delay module registration until DarkRP is fully loaded
hook.Add("DarkRPFinishedLoading", "RegisterScoreboardModule", function()
    DarkRP.registerDarkRPModule({
        name = "scoreboard",
        author = "Nick",
        version = "1.0",
        loadOnStart = true,
    })
    print("[SCOREBOARD MODULE] Registered scoreboard module - VERSION 1")
end)

-- Include client-side files
if CLIENT then
    include("darkrp_modules/scoreboard/client/cl_init.lua")
end

-- Include server-side files
if SERVER then
    AddCSLuaFile("darkrp_modules/scoreboard/client/cl_init.lua")
    AddCSLuaFile("darkrp_modules/scoreboard/client/cl_scoreboard.lua")
    AddCSLuaFile("darkrp_modules/scoreboard/client/admin_buttons.lua")
    AddCSLuaFile("darkrp_modules/scoreboard/client/player_frame.lua")
    AddCSLuaFile("darkrp_modules/scoreboard/client/player_infocard.lua")
    AddCSLuaFile("darkrp_modules/scoreboard/client/player_row.lua")

    include("darkrp_modules/scoreboard/server/sv_scoreboard.lua")
end

print("[SCOREBOARD MODULE] Loaded sh_scoreboard.lua - VERSION 1")