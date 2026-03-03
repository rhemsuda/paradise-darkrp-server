-- Simple admin system (separate from FAdmin). Ranks: superadmin, admin, sdonator, donator, member, user
if not SERVER then return end

Admin = Admin or {}
Admin.Ranks = {"superadmin", "admin", "sdonator", "donator", "member", "user"}
Admin.RankOrder = {superadmin = 6, admin = 5, sdonator = 4, donator = 3, member = 2, user = 1}
Admin.DefaultSuperAdmin = "STEAM_0:0:28182488"
-- SuperAdmin SteamIDs (set in gamemode; not obtainable in-game)
Admin.SuperAdminSteamIDs = { [Admin.DefaultSuperAdmin] = true }
Admin.Users = {}
Admin.Users[Admin.DefaultSuperAdmin] = "superadmin"

util.AddNetworkString("Admin_RequestUserList")
util.AddNetworkString("Admin_SendUserList")
util.AddNetworkString("Admin_SetRank")
util.AddNetworkString("Admin_Kick")
util.AddNetworkString("Admin_Ban")
util.AddNetworkString("Admin_Demote")
util.AddNetworkString("Admin_Spawn")
util.AddNetworkString("Admin_RequestBanList")
util.AddNetworkString("Admin_SendBanList")
util.AddNetworkString("Admin_RequestLogs")
util.AddNetworkString("Admin_SendLogs")
util.AddNetworkString("Paradise_AdminChat")
util.AddNetworkString("Admin_AddBan")
util.AddNetworkString("Admin_RankChanged")
util.AddNetworkString("Admin_RequestOnlineList")
util.AddNetworkString("Admin_SendOnlineList")

-- Helper: find online player by SteamID (must be defined before Admin.SetRank and net receivers)
local function FindPlayerBySteamID(steamid)
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:SteamID() == steamid then return p end
    end
    return nil
end

-- Load from DB
local function LoadAdminUsers()
    MySQLite.query("CREATE TABLE IF NOT EXISTS paradise_admin_users (steamid VARCHAR(40) PRIMARY KEY, rank VARCHAR(32));", function()
        MySQLite.query("SELECT steamid, rank FROM paradise_admin_users;", function(data)
            Admin.Users = {}
            if data then
                for _, row in ipairs(data) do
                    Admin.Users[row.steamid] = row.rank
                end
            end
            if not Admin.Users[Admin.DefaultSuperAdmin] then
                Admin.Users[Admin.DefaultSuperAdmin] = "superadmin"
                MySQLite.query("REPLACE INTO paradise_admin_users VALUES(" .. MySQLite.SQLStr(Admin.DefaultSuperAdmin) .. ", " .. MySQLite.SQLStr("superadmin") .. ");")
            end
        end)
    end)
end
hook.Add("DatabaseInitialized", "Admin_LoadUsers", LoadAdminUsers)

-- Ensure default superadmin exists even before DB
Admin.Users[Admin.DefaultSuperAdmin] = "superadmin"

-- Member: Steam group + mission. Stub: override or use ply:IsUserGroup("member") if you have a Steam group addon
function Admin.IsMember(ply)
    if not IsValid(ply) then return false end
    if ply.IsUserGroup and ply:IsUserGroup("member") then return true end
    return false
end

-- Permission rank: SuperAdminSteamIDs always get superadmin (cannot lock yourself out by setting rank to donator)
function Admin.GetRank(steamid)
    if not steamid then return "user" end
    if Admin.SuperAdminSteamIDs and Admin.SuperAdminSteamIDs[steamid] then return "superadmin" end
    return Admin.Users[steamid] or "user"
end

-- Effective rank for display: Admin.Users or Member (Steam group + mission) or User
function Admin.GetEffectiveRank(ply)
    if not IsValid(ply) then return "user" end
    local sid = ply:SteamID()
    local stored = Admin.Users[sid]
    if stored then return stored end
    -- Member: Steam group + mission (stub; integrate with your Steam group addon)
    if Admin.IsMember and Admin.IsMember(ply) then return "member" end
    return "user"
end

function Admin.SetRank(steamid, rank)
    if not steamid or not rank then return end
    if not Admin.RankOrder[rank] then return end
    if rank == "user" then
        Admin.Users[steamid] = nil
        if MySQLite and MySQLite.query then
            MySQLite.query("DELETE FROM paradise_admin_users WHERE steamid = " .. MySQLite.SQLStr(steamid))
        end
    else
        Admin.Users[steamid] = rank
        if MySQLite and MySQLite.query then
            MySQLite.query("REPLACE INTO paradise_admin_users VALUES(" .. MySQLite.SQLStr(steamid) .. ", " .. MySQLite.SQLStr(rank) .. ");")
        end
    end
    -- Sync to FAdmin/CAMI if target is online
    local target = FindPlayerBySteamID(steamid)
    if IsValid(target) then
        Admin.SyncPlayerToFAdmin(target)
    end
end

-- Sync Paradise Admin rank to FAdmin/CAMI (SteamID in SuperAdminSteamIDs always gets superadmin)
function Admin.SyncPlayerToFAdmin(ply)
    if not IsValid(ply) then return end
    local rank = Admin.GetRank(ply:SteamID())
    if rank == "user" or rank == "member" then rank = "user" end
    if ULib and ULib.ucl and ULib.ucl.addUser then
        ULib.ucl.addUser(ply:SteamID(), nil, rank)
    end
    if ply.SetUserGroup then ply:SetUserGroup(rank) end
    -- Scoreboard: show User/Member/Donator/Super Donator/Admin (admin+superadmin both as Admin)
    local displayRank = Admin.GetScoreboardRankDisplay and Admin.GetScoreboardRankDisplay(Admin.GetEffectiveRank(ply)) or "User"
    ply:SetNWString("ParadiseRankDisplay", displayRank)
end

hook.Add("PlayerInitialSpawn", "Admin_SyncRankToFAdmin", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) and Admin and Admin.SyncPlayerToFAdmin then
            Admin.SyncPlayerToFAdmin(ply)
        end
    end)
end)

-- Build user list: only players with rank above "user" (Member, Donator, SuperDonator, Admin, SuperAdmin)
local function BuildUserList()
    local list = {}
    local seen = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local steamid = ply:SteamID()
            if steamid and not seen[steamid] then
                local rank = Admin.GetEffectiveRank and Admin.GetEffectiveRank(ply) or Admin.GetRank(steamid)
                if rank and rank ~= "user" then
                    seen[steamid] = true
                    table.insert(list, {steamid = steamid, rank = rank, name = ply:Nick()})
                end
            end
        end
    end
    -- Include stored admins/donators who are offline (from Admin.Users)
    for steamid, rank in pairs(Admin.Users) do
        if rank and rank ~= "user" and not seen[steamid] then
            seen[steamid] = true
            local name = "Offline"
            table.insert(list, {steamid = steamid, rank = rank, name = name})
        end
    end
    -- Include default superadmin even if not in table
    if not Admin.Users[Admin.DefaultSuperAdmin] then
        Admin.Users[Admin.DefaultSuperAdmin] = "superadmin"
        if not seen[Admin.DefaultSuperAdmin] then
            table.insert(list, {steamid = Admin.DefaultSuperAdmin, rank = "superadmin", name = "Offline"})
        end
    end
    -- Sort: online first, then by rank
    table.sort(list, function(a, b)
        local aOnline = (a.name ~= "Offline") and 1 or 0
        local bOnline = (b.name ~= "Offline") and 1 or 0
        if aOnline ~= bOnline then return aOnline > bOnline end
        return (Admin.RankOrder[a.rank] or 0) > (Admin.RankOrder[b.rank] or 0)
    end)
    return list
end

-- Build online player list: all connected players (for Server tab Kick/Ban/etc.)
local function BuildOnlinePlayerList()
    local list = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local steamid = ply:SteamID()
            if steamid then
                local rank = Admin.GetEffectiveRank and Admin.GetEffectiveRank(ply) or Admin.GetRank(steamid)
                table.insert(list, {steamid = steamid, rank = rank, name = ply:Nick()})
            end
        end
    end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    return list
end

net.Receive("Admin_RequestOnlineList", function(len, ply)
    if not IsValid(ply) then return end
    local rank = Admin.GetRank(ply:SteamID())
    if not ply:IsSuperAdmin() and rank ~= "superadmin" and rank ~= "admin" then return end
    local list = BuildOnlinePlayerList()
    net.Start("Admin_SendOnlineList")
    net.WriteUInt(#list, 16)
    for _, row in ipairs(list) do
        net.WriteString(row.steamid)
        net.WriteString(row.rank or "user")
        net.WriteString(row.name)
    end
    net.Send(ply)
end)

net.Receive("Admin_RequestUserList", function(len, ply)
    if not IsValid(ply) then return end
    local rank = Admin.GetRank(ply:SteamID())
    if not ply:IsSuperAdmin() and rank ~= "superadmin" and rank ~= "admin" then return end

    local list = BuildUserList()
    net.Start("Admin_SendUserList")
    net.WriteUInt(#list, 16)
    for _, row in ipairs(list) do
        net.WriteString(row.steamid)
        net.WriteString(row.rank)
        net.WriteString(row.name)
    end
    net.Send(ply)
end)

-- Admin Kick: requires admin/superadmin; reason from client
net.Receive("Admin_Kick", function(len, ply)
    if not IsValid(ply) then return end
    local rank = Admin.GetRank(ply:SteamID())
    if rank ~= "superadmin" and rank ~= "admin" then return end
    local steamid = net.ReadString()
    local reason = net.ReadString() or ""
    if not steamid or steamid == "" then return end
    local target = FindPlayerBySteamID(steamid)
    if not IsValid(target) then
        DarkRP.notify(ply, 1, 4, "Player is not online (cannot kick).")
        return
    end
    if reason == "" then reason = "Kicked by admin (" .. ply:Nick() .. ")" end
    DarkRP.notify(target, 1, 4, "You have been kicked.")
    target:Kick(reason)
    DarkRP.notify(ply, 0, 4, "Kicked " .. target:Nick())
end)

-- /spawn (name): teleport target to their job spawn. Silent; admin gets tooltip.
local function AdminSpawnCommand(ply, arg)
    if not IsValid(ply) then return "" end
    if not ply:IsAdmin() then return "" end
    local name = (arg and arg ~= "" and arg) or nil
    if not name then
        DarkRP.notify(ply, 1, 4, "Usage: /spawn <name|steamid>")
        return ""
    end
    local target = DarkRP.findPlayer(name)
    if not IsValid(target) then
        DarkRP.notify(ply, 1, 4, "Player not found")
        return ""
    end
    -- If target is a ghost, respawn them (alive) first, then move to spawn (same as admin panel "Spawn (at spawn)")
    if IsPlayerGhost and IsPlayerGhost(target) then
        hook.Call("AdminRequestRespawn", nil, target)
    end
    local _, pos = hook.Call("PlayerSelectSpawn", GAMEMODE, target)
    if not pos then pos = target:GetPos() end
    local _, hull = target:GetHull()
    pos = DarkRP.findEmptyPos(pos, {target}, 600, 30, hull)
    target:SetPos(pos)
    DarkRP.notify(target, 0, 4, "You have been moved to spawn.")
    DarkRP.notify(ply, 0, 4, "Moved " .. target:Nick() .. " to spawn")
    return ""
end
DarkRP.definePrivilegedChatCommand("spawn", "DarkRP_AdminCommands", AdminSpawnCommand)

-- /respawn (name): revive dead player at body (uses death system). Silent; admin gets tooltip.
local function AdminRespawnCommand(ply, arg)
    if not IsValid(ply) then return "" end
    if not ply:IsAdmin() then return "" end
    local name = (arg and arg ~= "" and arg) or nil
    if not name then
        DarkRP.notify(ply, 1, 4, "Usage: /respawn <name|steamid>")
        return ""
    end
    local target = DarkRP.findPlayer(name)
    if not IsValid(target) then
        DarkRP.notify(ply, 1, 4, "Player not found")
        return ""
    end
    local ok = hook.Run("AdminRequestRespawn", target)
    if ok then
        DarkRP.notify(ply, 0, 4, "Respawned " .. target:Nick() .. " at body")
    else
        DarkRP.notify(ply, 1, 4, target:Nick() .. " is not dead")
    end
    return ""
end
DarkRP.definePrivilegedChatCommand("respawn", "DarkRP_AdminCommands", AdminRespawnCommand)

-- Goto: admin teleports to target. Bring: target teleports to admin. Freeze: freeze/unfreeze target.
local function AdminGotoCommand(ply, arg)
    if not IsValid(ply) or not ply:IsAdmin() then return "" end
    local name = (arg and arg ~= "" and arg) or nil
    if not name then DarkRP.notify(ply, 1, 4, "Usage: /goto <name|steamid>") return "" end
    local target = DarkRP.findPlayer(name)
    if not IsValid(target) then DarkRP.notify(ply, 1, 4, "Player not found") return "" end
    local pos = target:GetPos()
    local ang = target:EyeAngles()
    ply:SetPos(pos + Vector(0, 0, 50))
    ply:SetEyeAngles(ang)
    DarkRP.notify(ply, 0, 4, "Teleported to " .. target:Nick())
    return ""
end
DarkRP.definePrivilegedChatCommand("goto", "DarkRP_AdminCommands", AdminGotoCommand)

local function AdminBringCommand(ply, arg)
    if not IsValid(ply) or not ply:IsAdmin() then return "" end
    local name = (arg and arg ~= "" and arg) or nil
    if not name then DarkRP.notify(ply, 1, 4, "Usage: /bring <name|steamid>") return "" end
    local target = DarkRP.findPlayer(name)
    if not IsValid(target) then DarkRP.notify(ply, 1, 4, "Player not found") return "" end
    local _, hull = target:GetHull()
    local pos = ply:GetPos() + ply:GetForward() * 80
    pos = DarkRP.findEmptyPos(pos, {target}, 400, 30, hull)
    target:SetPos(pos)
    DarkRP.notify(ply, 0, 4, "Brought " .. target:Nick())
    DarkRP.notify(target, 0, 4, "You were brought by an admin.")
    return ""
end
DarkRP.definePrivilegedChatCommand("bring", "DarkRP_AdminCommands", AdminBringCommand)

Paradise = Paradise or {}
Paradise.Frozen = Paradise.Frozen or {}

-- Shared freeze state: true = frozen. Used by /freeze, /unfreeze, paradise_freeze (panel), and we sync FAdmin so one system.
local function SetFrozen(target, frozen)
    if not IsValid(target) then return end
    Paradise.Frozen[target] = frozen
    if frozen then
        if not target._ParadiseStoredMoveType then
            target._ParadiseStoredMoveType = target:GetMoveType()
        end
        target:SetMoveType(MOVETYPE_NONE)
    else
        if target._ParadiseStoredMoveType then
            target:SetMoveType(target._ParadiseStoredMoveType)
            target._ParadiseStoredMoveType = nil
        else
            target:SetMoveType(MOVETYPE_WALK)
        end
    end
end

local function AdminFreezeCommand(ply, arg)
    if not IsValid(ply) or not ply:IsAdmin() then return "" end
    local name = (arg and arg ~= "" and arg) or nil
    if not name then DarkRP.notify(ply, 1, 4, "Usage: /freeze <name|steamid>") return "" end
    local target = DarkRP.findPlayer(name)
    if not IsValid(target) then DarkRP.notify(ply, 1, 4, "Player not found") return "" end
    local nowFrozen = not Paradise.Frozen[target]
    SetFrozen(target, nowFrozen)
    if target.FAdmin_SetGlobal then target:FAdmin_SetGlobal("FAdmin_frozen", nowFrozen) end
    local state = nowFrozen and "frozen" or "unfrozen"
    DarkRP.notify(ply, 0, 4, target:Nick() .. " is " .. state)
    if nowFrozen then
        DarkRP.notify(target, 1, 4, "You have been frozen by an admin.")
    else
        DarkRP.notify(target, 0, 4, "You have been unfrozen by an admin.")
    end
    return ""
end
DarkRP.definePrivilegedChatCommand("freeze", "DarkRP_AdminCommands", AdminFreezeCommand)

local function AdminUnfreezeCommand(ply, arg)
    if not IsValid(ply) or not ply:IsAdmin() then return "" end
    local name = (arg and arg ~= "" and arg) or nil
    if not name then DarkRP.notify(ply, 1, 4, "Usage: /unfreeze <name|steamid>") return "" end
    local target = DarkRP.findPlayer(name)
    if not IsValid(target) then DarkRP.notify(ply, 1, 4, "Player not found") return "" end
    SetFrozen(target, false)
    if target.FAdmin_SetGlobal then target:FAdmin_SetGlobal("FAdmin_frozen", false) end
    DarkRP.notify(ply, 0, 4, target:Nick() .. " is unfrozen")
    DarkRP.notify(target, 0, 4, "You have been unfrozen by an admin.")
    return ""
end
DarkRP.definePrivilegedChatCommand("unfreeze", "DarkRP_AdminCommands", AdminUnfreezeCommand)

-- Full freeze: no movement, no look. Paradise.Frozen and FAdmin_frozen both drive the same behaviour; we keep Paradise.Frozen in sync.
hook.Add("SetupMove", "Paradise_Freeze", function(ply, mv, cmd)
    local fadminFrozen = ply.FAdmin_GetGlobal and ply:FAdmin_GetGlobal("FAdmin_frozen")
    local paradiseFrozen = Paradise.Frozen and Paradise.Frozen[ply]
    local frozen = paradiseFrozen or fadminFrozen
    if frozen then
        Paradise.Frozen[ply] = true
        if not ply._ParadiseStoredMoveType then
            ply._ParadiseStoredMoveType = ply:GetMoveType()
        end
        ply:SetMoveType(MOVETYPE_NONE)
        mv:SetVelocity(vector_origin)
        mv:SetOrigin(ply:GetPos())
        cmd:SetViewAngles(ply:EyeAngles())
        cmd:SetButtons(0)
    else
        Paradise.Frozen[ply] = nil
        if ply._ParadiseStoredMoveType then
            ply:SetMoveType(ply._ParadiseStoredMoveType)
            ply._ParadiseStoredMoveType = nil
        end
    end
end)

-- Console commands for admin panel (same as chat commands)
concommand.Add("paradise_goto", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    AdminGotoCommand(ply, args[1] or "")
end)
concommand.Add("paradise_bring", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    AdminBringCommand(ply, args[1] or "")
end)
concommand.Add("paradise_freeze", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    AdminFreezeCommand(ply, args[1] or "")
end)

-- /commands: list commands; admins see admin commands too
local function CommandsListCommand(ply, arg)
    if not IsValid(ply) then return "" end
    DarkRP.talkToPerson(ply, Color(200, 220, 255), "--- Paradise commands ---", color_white, "", ply)
    DarkRP.talkToPerson(ply, Color(200, 220, 255), "/a <msg> - Admin chat (admins) or request assistance (players)", color_white, "", ply)
    if ply:IsAdmin() then
        DarkRP.talkToPerson(ply, Color(200, 220, 255), "/goto <name> - Teleport to player", color_white, "", ply)
        DarkRP.talkToPerson(ply, Color(200, 220, 255), "/bring <name> - Bring player to you", color_white, "", ply)
        DarkRP.talkToPerson(ply, Color(200, 220, 255), "/freeze <name> - Freeze (click again to unfreeze)", color_white, "", ply)
        DarkRP.talkToPerson(ply, Color(200, 220, 255), "/unfreeze <name> - Unfreeze player", color_white, "", ply)
        DarkRP.talkToPerson(ply, Color(200, 220, 255), "/spawn <name> - Teleport player to spawn", color_white, "", ply)
        DarkRP.talkToPerson(ply, Color(200, 220, 255), "/respawn <name> - Respawn dead player", color_white, "", ply)
    end
    return ""
end
DarkRP.defineChatCommand("commands", CommandsListCommand, 0.5)

-- /a [text]: if admin -> (ADMIN): <text> to ALL players (no name). If non-admin -> assistance request to admins only.
local function AdminAChatCommand(ply, arg)
    if not IsValid(ply) then return "" end
    local msg = (arg and arg ~= "" and string.Trim(arg)) or ""
    local rank = Admin.GetRank(ply:SteamID())
    local isAdmin = (rank == "admin" or rank == "superadmin")
    if isAdmin then
        if msg == "" then DarkRP.notify(ply, 1, 4, "Usage: /a <message>") return "" end
        for _, p in ipairs(player.GetAll()) do
            if not IsValid(p) then continue end
            DarkRP.talkToPerson(p, Color(255, 200, 80), "(ADMIN)", color_white, msg, ply)
        end
    else
        if msg == "" then DarkRP.notify(ply, 1, 4, "Usage: /a <message> to request assistance from admins.") return "" end
        for _, p in ipairs(player.GetAll()) do
            if not IsValid(p) then continue end
            if Admin.GetRank(p:SteamID()) == "admin" or Admin.GetRank(p:SteamID()) == "superadmin" then
                DarkRP.talkToPerson(p, Color(255, 100, 100), "[Assistance] " .. ply:Nick() .. " (" .. ply:SteamID() .. ")", color_white, msg, ply)
            end
        end
        DarkRP.notify(ply, 0, 4, "Your assistance request was sent to admins.")
    end
    return ""
end
DarkRP.defineChatCommand("a", AdminAChatCommand, 1)

-- Admin_Spawn: teleport target to their job spawn (same logic as PlayerSelectSpawn). Used by "Spawn (at spawn)" in admin panel.
-- If target is dead (ghost), end ghost mode first so they respawn alive, then move to spawn.
net.Receive("Admin_Spawn", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local steamid = net.ReadString()
    if not steamid or steamid == "" then return end
    local target = FindPlayerBySteamID(steamid)
    if not IsValid(target) then
        DarkRP.notify(ply, 1, 4, "Player not found (must be online).")
        return
    end
    -- If target is a ghost, respawn them (alive) first; they will be at body, then we move to spawn below
    if IsPlayerGhost and IsPlayerGhost(target) then
        hook.Call("AdminRequestRespawn", nil, target)
    end
    local _, pos = hook.Call("PlayerSelectSpawn", GAMEMODE, target)
    if not pos then pos = target:GetPos() end
    local _, hull = target:GetHull()
    pos = DarkRP.findEmptyPos(pos, {target}, 600, 30, hull)
    target:SetPos(pos)
    DarkRP.notify(target, 0, 4, "You have been moved to spawn.")
    DarkRP.notify(ply, 0, 4, "Moved " .. target:Nick() .. " to spawn")
end)

-- Admin Ban: requires superadmin only; reason + duration (minutes, 0 = permanent) from client
net.Receive("Admin_Ban", function(len, ply)
    if not IsValid(ply) then return end
    if Admin.GetRank(ply:SteamID()) ~= "superadmin" then return end
    local steamid = net.ReadString()
    local reason = net.ReadString() or ""
    local duration = net.ReadUInt(16) or 0 -- minutes; 0 = permanent
    if not steamid or steamid == "" then return end
    local target = FindPlayerBySteamID(steamid)
    if not IsValid(target) then
        DarkRP.notify(ply, 1, 4, "Player is not online (cannot ban).")
        return
    end
    if reason == "" then reason = "Banned by admin (" .. ply:Nick() .. ")" end
    game.ConsoleCommand(string.format("banid %u %s %s\n", duration, target:UserID(), reason))
    game.ConsoleCommand("writeid\n")
    target:Kick(reason)
end)

-- Admin SetRank: SuperAdmin can set rank (User, Member, Donator, SuperDonator, Admin, SuperAdmin)
net.Receive("Admin_SetRank", function(len, ply)
    if not IsValid(ply) then return end
    if Admin.GetRank(ply:SteamID()) ~= "superadmin" then return end
    local targetSteamid = net.ReadString()
    local newRank = net.ReadString()
    if not targetSteamid or targetSteamid == "" or not newRank then return end
    if not Admin.RankOrder[newRank] then return end
    Admin.SetRank(targetSteamid, newRank)
    local target = FindPlayerBySteamID(targetSteamid)
    local displayRank = (Admin.RankDisplayNames and Admin.RankDisplayNames[newRank]) or newRank
    if IsValid(target) then
        DarkRP.notify(target, 0, 4, "Your rank was set to " .. displayRank .. " by an admin.")
    end
    DarkRP.notify(ply, 0, 4, "Set " .. (target and target:Nick() or targetSteamid) .. " to " .. displayRank)
    net.Start("Admin_RankChanged")
    net.Send(ply)
end)

-- Admin Demote: set target's job to default (Citizen). Admin or Superadmin. Rank changes are in Settings.
net.Receive("Admin_Demote", function(len, ply)
    if not IsValid(ply) then return end
    local rank = Admin.GetRank(ply:SteamID())
    if rank ~= "superadmin" and rank ~= "admin" then return end
    local steamid = net.ReadString()
    if not steamid or steamid == "" then return end
    local target = FindPlayerBySteamID(steamid)
    if not IsValid(target) then
        DarkRP.notify(ply, 1, 4, "Player must be online to demote.")
        return
    end
    local defaultTeam = GAMEMODE and GAMEMODE.DefaultTeam or nil
    if not defaultTeam or not RPExtraTeams or not RPExtraTeams[defaultTeam] then
        DarkRP.notify(ply, 1, 4, "Default job not configured.")
        return
    end
    target:changeTeam(defaultTeam, true)
    DarkRP.notify(target, 1, 4, "You have been demoted to Citizen.")
    DarkRP.notify(ply, 0, 4, "Demoted " .. target:Nick() .. " to Citizen.")
end)

-- Add ban from Ban List tab (SteamID or name; player must be online). Admin or Superadmin.
net.Receive("Admin_AddBan", function(len, ply)
    if not IsValid(ply) then return end
    local rank = Admin.GetRank(ply:SteamID())
    if rank ~= "superadmin" and rank ~= "admin" then return end
    local steamidOrName = net.ReadString() or ""
    local reason = net.ReadString() or ""
    local duration = net.ReadUInt(16) or 0
    if steamidOrName == "" then DarkRP.notify(ply, 1, 4, "Enter SteamID or player name.") return end
    local target = DarkRP and DarkRP.findPlayer(steamidOrName) or FindPlayerBySteamID(steamidOrName)
    if not target or not IsValid(target) then
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and (p:SteamID() == steamidOrName or p:SteamID64() == steamidOrName or string.find(string.lower(p:Nick()), string.lower(steamidOrName), 1, true)) then
                target = p
                break
            end
        end
    end
    if not IsValid(target) then
        DarkRP.notify(ply, 1, 4, "Player not found or not online.")
        return
    end
    if reason == "" then reason = "Banned by admin (" .. ply:Nick() .. ")" end
    game.ConsoleCommand(string.format("banid %u %s %s\n", duration, target:UserID(), reason))
    game.ConsoleCommand("writeid\n")
    DarkRP.notify(target, 1, 4, "You have been banned.")
    target:Kick(reason)
    DarkRP.notify(ply, 0, 4, "Added " .. target:Nick() .. " to ban list.")
end)

-- Ban List: read banned_user.cfg (Source engine format) and send to admin
net.Receive("Admin_RequestBanList", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local raw = file.Read("cfg/banned_user.cfg", "GAME") or file.Read("banned_user.cfg", "GAME") or ""
    local lines = {}
    for line in string.gmatch(raw, "[^\r\n]+") do
        line = string.Trim(line)
        if line ~= "" and not string.match(line, "^//") then
            table.insert(lines, line)
        end
    end
    net.Start("Admin_SendBanList")
    net.WriteUInt(#lines, 16)
    for _, line in ipairs(lines) do
        net.WriteString(line)
    end
    net.Send(ply)
end)

-- Paradise admin log (in-memory ring buffer) for item abuse, kills, etc.
Paradise = Paradise or {}
Paradise.AdminLog = Paradise.AdminLog or {}
local ADMIN_LOG_MAX = 500
local function paradiseLog(category, message, extra)
    local entry = { t = os.time(), cat = category or "misc", msg = message or "", extra = extra or {} }
    table.insert(Paradise.AdminLog, entry)
    while #Paradise.AdminLog > ADMIN_LOG_MAX do
        table.remove(Paradise.AdminLog, 1)
    end
end

-- Log kills (who, time, where, weapon) for admin Logs tab
hook.Add("PlayerDeath", "Paradise_AdminLogDeath", function(victim, inflictor, attacker)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    local wep = (IsValid(inflictor) and inflictor:IsWeapon()) and inflictor or (IsValid(attacker) and IsValid(attacker:GetActiveWeapon()) and attacker:GetActiveWeapon()) or inflictor
    local wepName = IsValid(wep) and (wep.GetPrintName and wep:GetPrintName() or wep:GetClass()) or "unknown"
    local killerName = "world"
    if IsValid(attacker) and attacker:IsPlayer() then
        killerName = attacker:Nick() .. " (" .. attacker:SteamID() .. ")"
    elseif IsValid(attacker) then
        killerName = attacker:GetClass() or "entity"
    end
    local pos = victim:GetPos()
    local msg = string.format("%s killed by %s with %s at (%.0f, %.0f, %.0f)",
        victim:Nick() .. " (" .. victim:SteamID() .. ")", killerName, wepName, pos.x, pos.y, pos.z)
    paradiseLog("kill", msg, { victim_steamid = victim:SteamID(), killer = killerName, weapon = wepName, x = pos.x, y = pos.y, z = pos.z })
end)

-- Expose so other modules (e.g. inventory) can add log entries
function Paradise.AdminLogEntry(category, message, extra)
    paradiseLog(category, message, extra)
end

net.Receive("Admin_RequestLogs", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local logs = Paradise.AdminLog or {}
    net.Start("Admin_SendLogs")
    net.WriteUInt(#logs, 16)
    for i = 1, #logs do
        local e = logs[i]
        net.WriteUInt(e.t or 0, 32)
        net.WriteString(e.cat or "misc")
        net.WriteString(e.msg or "")
    end
    net.Send(ply)
end)

-- Replace FAdmin's "[FAdmin] ..." notifications with Paradise tooltips only (no chat spam).
-- Runs after FAdmin has loaded so FireNotification exists.
local function paradiseOverrideFAdminNotifications()
    if not FAdmin or not FAdmin.Messages or not FAdmin.Messages.FireNotification then return end
    local oldFire = FAdmin.Messages.FireNotification
    local function toTargetList(targets)
        if istable(targets) then return targets end
        return IsValid(targets) and {targets} or {}
    end
    function FAdmin.Messages.FireNotification(name, instigator, targets, extraInfo)
        local tlist = toTargetList(targets)
        if name == "voicemute" then
            for _, t in ipairs(tlist) do if IsValid(t) then DarkRP.notify(t, 1, 4, "You have been voice muted.") end end
            return
        end
        if name == "voiceunmute" then
            for _, t in ipairs(tlist) do if IsValid(t) then DarkRP.notify(t, 0, 4, "You have been voice unmuted.") end end
            return
        end
        if name == "chatmute" then
            for _, t in ipairs(tlist) do if IsValid(t) then DarkRP.notify(t, 1, 4, "You have been chat muted.") end end
            return
        end
        if name == "chatunmute" then
            for _, t in ipairs(tlist) do if IsValid(t) then DarkRP.notify(t, 0, 4, "You have been chat unmuted.") end end
            return
        end
        if name == "freeze" then
            for _, t in ipairs(tlist) do if IsValid(t) then DarkRP.notify(t, 1, 4, "You have been frozen by an admin.") end end
            return
        end
        if name == "unfreeze" then
            for _, t in ipairs(tlist) do if IsValid(t) then DarkRP.notify(t, 0, 4, "You have been unfrozen by an admin.") end end
            return
        end
        if name == "goto" then
            if IsValid(instigator) and IsValid(targets) then DarkRP.notify(instigator, 0, 4, "Teleported to " .. targets:Nick()) end
            return
        end
        if name == "bring" then
            for _, t in ipairs(tlist) do if IsValid(t) then DarkRP.notify(t, 0, 4, "You were brought by an admin.") end end
            return
        end
        return oldFire(name, instigator, targets, extraInfo)
    end
end
hook.Add("Initialize", "Paradise_FAdminNotifyOverride", paradiseOverrideFAdminNotifications)
timer.Simple(0, paradiseOverrideFAdminNotifications)

-- Prop limit per rank (User 10, Donator 20, SuperDonator 30) - overrides sbox_maxprops
hook.Add("PlayerCheckLimit", "Admin_PropLimit", function(ply, str, count, c)
    if str ~= "props" or not IsValid(ply) or not Admin or not Admin.GetPropLimit then return end
    local rank = Admin.GetEffectiveRank and Admin.GetEffectiveRank(ply) or Admin.GetRank(ply:SteamID())
    local limit = Admin.GetPropLimit(rank) or 10
    if count >= limit then
        return false
    end
    return true -- allow, using our limit instead of sbox_maxprops
end)
