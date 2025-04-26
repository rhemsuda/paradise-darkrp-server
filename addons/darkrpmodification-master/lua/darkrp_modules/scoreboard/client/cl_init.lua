-- Define global variable for DarkRP detection
GM10_IsDarkRP = false

-- Scoreboard management
local pScoreBoard = nil

-- Create or recreate the scoreboard
local function CreateGM10Scoreboard()
    if pScoreBoard then
        pScoreBoard:Remove()
        pScoreBoard = nil
    end
    print("[SCOREBOARD MODULE] Attempting to create ScoreBoard panel")
    pScoreBoard = vgui.Create("ScoreBoard")
    if not pScoreBoard then
        print("[SCOREBOARD MODULE] ERROR: Failed to create ScoreBoard panel")
        return false
    else
        print("[SCOREBOARD MODULE] Created new scoreboard")
        return true
    end
end

-- Initialize scoreboard early
hook.Add("InitPostEntity", "GM10InitializeScoreboard", function()
    CreateGM10Scoreboard()
    print("[SCOREBOARD MODULE] Scoreboard initialized on client join")
end)

-- Remove old scoreboard hooks and set up DarkRP detection
hook.Add("Initialize", "GM10RemoveOldScoreboard", function()
    GAMEMODE.ScoreboardShow = nil 
    GAMEMODE.ScoreboardHide = nil
    GAMEMODE.HUDDrawScoreBoard = nil
    
    if GAMEMODE.Name == "DarkRP" then
        hook.Remove("ScoreboardHide", "FAdmin_scoreboard")
        hook.Remove("ScoreboardShow", "FAdmin_scoreboard")        
        GM10_IsDarkRP = true
    end
    print("[SCOREBOARD MODULE] Initialized - GM10_IsDarkRP:", GM10_IsDarkRP)
end)

-- Include all client-side scoreboard files
include("darkrp_modules/scoreboard/client/player_row.lua")
include("darkrp_modules/scoreboard/client/player_frame.lua")
include("darkrp_modules/scoreboard/client/player_infocard.lua")
include("darkrp_modules/scoreboard/client/admin_buttons.lua")
include("darkrp_modules/scoreboard/client/cl_scoreboard.lua")

print("[SCOREBOARD MODULE] Loaded cl_init.lua - VERSION 1")

-- Show the scoreboard
hook.Add("ScoreboardShow", "GM10ScoreboardShow", function()
    if not pScoreBoard then
        if not CreateGM10Scoreboard() then
            print("[SCOREBOARD MODULE] Warning: Cannot show scoreboard - creation failed")
            return false
        end
    end
    pScoreBoard:Show()
    return true
end)

-- Hide the scoreboard
hook.Add("ScoreboardHide", "GM10ScoreboardHide", function()
    if pScoreBoard then
        pScoreBoard:Hide()
    else
        print("[SCOREBOARD MODULE] Warning: pScoreBoard is nil in ScoreboardHide")
    end
    return true
end)