--[[---------------------------------------------------------------------------
  Paradise RP – Leveling shared API.
  Other modules (quests, crafting, printers, drugs) grant XP via hook or Leveling.AddXP.
---------------------------------------------------------------------------]]
if SERVER then return end

-- Client can read level from NWInt; server is source of truth.
Leveling = Leveling or {}

function Leveling.GetLevel(ply)
    if not IsValid(ply) then return 0 end
    return ply:GetNWInt("DarkRP_Level", 0)
end

function Leveling.GetXP(ply)
    if not IsValid(ply) then return 0 end
    return ply:GetNWInt("DarkRP_Experience", 0)
end

function Leveling.GetXPNeededForNext(ply)
    if not IsValid(ply) then return 100 end
    return ply:GetNWInt("DarkRP_ExperienceNeeded", 100)
end
