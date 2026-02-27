--[[---------------------------------------------------------------------------
  GMod10 Scoreboard - Client entry (replaces lua/autorun/client/).
  Loaded as a DarkRP module (cl_*.lua). Panels are in the same folder; we include
  them in dependency order. Materials stay in materials/gui/.
---------------------------------------------------------------------------]]
if not CLIENT then return end

-- Path for includes: same module folder (no autorun subfolders)
local M = (GAMEMODE or GM).FolderName .. "/gamemode/modules/gmod10_scoreboard/"

hook.Add("Initialize", "GM10RemoveOldScoreboard", function()
    GAMEMODE.ScoreboardShow = nil
    GAMEMODE.ScoreboardHide = nil
    GAMEMODE.HUDDrawScoreBoard = nil
    if GAMEMODE.Name == "DarkRP" then
        hook.Remove("ScoreboardHide", "FAdmin_scoreboard")
        hook.Remove("ScoreboardShow", "FAdmin_scoreboard")
        GM10_IsDarkRP = true
    end
end)

-- Load panels in dependency order (no inner includes; all in this folder)
include(M .. "player_frame.lua")
include(M .. "admin_buttons.lua")
include(M .. "vote_button.lua")
include(M .. "player_infocard.lua")
include(M .. "player_row.lua")
include(M .. "scoreboard.lua")

local pScoreBoard = nil

function CreateGM10Scoreboard()
    if pScoreBoard then
        pScoreBoard:Remove()
        pScoreBoard = nil
    end
    pScoreBoard = vgui.Create("ScoreBoard")
end

hook.Add("ScoreboardShow", "GM10ScoreboardShow", function()
    GAMEMODE.ShowScoreboard = true
    gui.EnableScreenClicker(true)
    if not pScoreBoard then
        CreateGM10Scoreboard()
    end
    pScoreBoard:SetVisible(true)
    pScoreBoard:UpdateScoreboard(true)
end)

hook.Add("ScoreboardHide", "GM10ScoreboardHide", function()
    GAMEMODE.ShowScoreboard = false
    gui.EnableScreenClicker(false)
    if pScoreBoard then
        pScoreBoard:SetVisible(false)
    end
end)

-- Escape closes scoreboard so it doesn't stay open when escape/console is used
hook.Add("Think", "GM10ScoreboardEscapeClose", function()
    if input.IsKeyDown(KEY_ESCAPE) and pScoreBoard and pScoreBoard:IsVisible() then
        pScoreBoard:SetVisible(false)
        gui.EnableScreenClicker(false)
        GAMEMODE.ShowScoreboard = false
    end
end)
