--[[---------------------------------------------------------------------------
  Scoreboard - Client entry (replaces gmod10_scoreboard).
  Loaded as a DarkRP module. Panels in this folder.
---------------------------------------------------------------------------]]
if not CLIENT then return end

local M = (GAMEMODE or GM).FolderName .. "/gamemode/modules/scoreboard/"

hook.Add("Initialize", "ScoreboardRemoveOld", function()
    GAMEMODE.ScoreboardShow = nil
    GAMEMODE.ScoreboardHide = nil
    GAMEMODE.HUDDrawScoreBoard = nil
    if GAMEMODE.Name == "DarkRP" then
        hook.Remove("ScoreboardHide", "FAdmin_scoreboard")
        hook.Remove("ScoreboardShow", "FAdmin_scoreboard")
        GM10_IsDarkRP = true
    end
end)

include(M .. "player_frame.lua")
include(M .. "admin_buttons.lua")
include(M .. "vote_button.lua")
include(M .. "player_infocard.lua")
include(M .. "player_row.lua")
include(M .. "scoreboard.lua")

local pScoreBoard = nil

function CreateScoreboard()
    if pScoreBoard then
        pScoreBoard:Remove()
        pScoreBoard = nil
    end
    pScoreBoard = vgui.Create("ScoreBoard")
end

hook.Add("ScoreboardShow", "ScoreboardShow", function()
    GAMEMODE.ShowScoreboard = true
    gui.EnableScreenClicker(true)
    if not pScoreBoard then
        CreateScoreboard()
    end
    pScoreBoard:SetVisible(true)
    pScoreBoard:UpdateScoreboard(true)
end)

hook.Add("ScoreboardHide", "ScoreboardHide", function()
    GAMEMODE.ShowScoreboard = false
    gui.EnableScreenClicker(false)
    if pScoreBoard then
        pScoreBoard:SetVisible(false)
    end
end)

hook.Add("Think", "ScoreboardEscapeClose", function()
    if input.IsKeyDown(KEY_ESCAPE) and pScoreBoard and pScoreBoard:IsVisible() then
        pScoreBoard:SetVisible(false)
        gui.EnableScreenClicker(false)
        GAMEMODE.ShowScoreboard = false
    end
end)

-- Debug alignment: sb_debug_align 1 = show coords overlay, sb_scoreboard_coords = print coords to console
CreateClientConVar("sb_debug_align", "0", true, false, "Show scoreboard column position overlays (1=on)")
concommand.Add("sb_scoreboard_coords", function()
    if not IsValid(pScoreBoard) or not pScoreBoard:IsVisible() then
        print("[Scoreboard] Open the scoreboard first (TAB) then run sb_scoreboard_coords")
        return
    end
    local W = pScoreBoard:GetWide()
    local pf = pScoreBoard.PlayerFrame
    local COL_W = 50
    print("=== Scoreboard alignment coords ===")
    print("Scoreboard width: " .. W)
    if IsValid(pf) then
        print("PlayerFrame x: " .. pf.x .. " width: " .. pf:GetWide())
    end
    if pScoreBoard.lblGang and IsValid(pScoreBoard.lblGang) then
        local x, y = pScoreBoard.lblGang:GetPos()
        local lx, ly = pScoreBoard.lblGang:LocalToScreen(0, 0)
        print("Header Gang: local(" .. x .. "," .. y .. ") screen(" .. lx .. "," .. ly .. ") width=" .. pScoreBoard.lblGang:GetWide())
        print("  Expected left edge: W - 200 - gangW = " .. (W - 200 - pScoreBoard.lblGang:GetWide()))
    end
    for ply, row in pairs(pScoreBoard.PlayerRows or {}) do
        if IsValid(row) and IsValid(row.lblGang) then
            local x, y = row.lblGang:GetPos()
            local rowW = row:GetWide()
            local lx, ly = row.lblGang:LocalToScreen(0, 0)
            print("Row Gang: local(" .. x .. "," .. y .. ") rowW=" .. rowW .. " screen(" .. lx .. "," .. ly .. ") width=" .. row.lblGang:GetWide())
            break
        end
    end
    print("Column right edges (header): Ping=" .. (W-50) .. " Deaths=" .. (W-100) .. " Kills=" .. (W-150) .. " Gang=" .. (W-200))
end, nil, "Print scoreboard column coordinates to console (open scoreboard first)")
