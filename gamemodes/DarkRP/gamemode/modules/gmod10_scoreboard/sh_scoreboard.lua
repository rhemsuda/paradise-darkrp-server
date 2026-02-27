--[[---------------------------------------------------------------------------
  GMod10 Scoreboard - Shared: ensure client panel files are sent (AddCSLuaFile).
  The loader only sends cl_*.lua; our cl_scoreboard.lua include()s other files
  in this folder, so the server must send them too.
---------------------------------------------------------------------------]]
if SERVER then
    local M = (GAMEMODE or GM).FolderName .. "/gamemode/modules/gmod10_scoreboard/"
    AddCSLuaFile(M .. "player_frame.lua")
    AddCSLuaFile(M .. "admin_buttons.lua")
    AddCSLuaFile(M .. "vote_button.lua")
    AddCSLuaFile(M .. "player_infocard.lua")
    AddCSLuaFile(M .. "player_row.lua")
    AddCSLuaFile(M .. "scoreboard.lua")
end
