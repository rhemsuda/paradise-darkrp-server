--[[---------------------------------------------------------------------------
  Paradise RP – Leveling shared API.
  Other modules (quests, crafting, printers, drugs, job gates) may call these
  on both client AND server. The server is the source of truth; NWInts keep
  the client in sync. Do NOT add a server guard here.
---------------------------------------------------------------------------]]
Leveling = Leveling or {}

-- Returns the player's current level (reads NWInt set by sv_leveling.lua).
function Leveling.GetLevel(ply)
    if not IsValid(ply) then return 0 end
    return ply:GetNWInt("DarkRP_Level", 0)
end

-- Returns total XP accumulated by the player.
function Leveling.GetXP(ply)
    if not IsValid(ply) then return 0 end
    return ply:GetNWInt("DarkRP_Experience", 0)
end

-- Returns the XP threshold for the NEXT level (used for the progress bar).
function Leveling.GetXPNeededForNext(ply)
    if not IsValid(ply) then return 100 end
    return ply:GetNWInt("DarkRP_ExperienceNeeded", 100)
end
