--[[---------------------------------------------------------------------------
  Scoreboard - Shared: ensure client panel files are sent (AddCSLuaFile).
  Replaces gmod10_scoreboard. Panels in this folder.
---------------------------------------------------------------------------]]
if SERVER then
    local M = (GAMEMODE or GM).FolderName .. "/gamemode/modules/scoreboard/"
    AddCSLuaFile(M .. "player_frame.lua")
    AddCSLuaFile(M .. "admin_buttons.lua")
    AddCSLuaFile(M .. "vote_button.lua")
    AddCSLuaFile(M .. "player_infocard.lua")
    AddCSLuaFile(M .. "player_row.lua")
    AddCSLuaFile(M .. "scoreboard.lua")
end
