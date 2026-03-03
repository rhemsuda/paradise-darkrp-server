--[[---------------------------------------------------------------------------
  Paradise NPCs — Server. Net strings, spawn-from-locations, and admin NPC spawn editor (persisted to file).
---------------------------------------------------------------------------]]
if not SERVER then return end

util.AddNetworkString("Paradise_NPCOpenMenu")
util.AddNetworkString("Paradise_NPCNotify")
util.AddNetworkString("Paradise_NPCAcceptMission")
util.AddNetworkString("Paradise_NPCCancelMission")
util.AddNetworkString("Paradise_NPCCompleteMission")
util.AddNetworkString("Admin_RequestNPCSpawns")
util.AddNetworkString("Admin_SendNPCSpawns")
util.AddNetworkString("Admin_AddNPCSpawn")
util.AddNetworkString("Admin_RemoveNPCSpawn")

local NPC_SPAWNS_FILE = "paradise_npc_spawns.txt"
local NPC_ACCEPTED_FILE = "paradise_npc_accepted_missions.txt"
local NPC_COMPLETED_FILE = "paradise_npc_completed_missions.txt"

local function loadAcceptedAndCompletedMissionsFromFile()
    Paradise.NPCs.PlayerAcceptedMissions = Paradise.NPCs.PlayerAcceptedMissions or {}
    local raw = file.Read(NPC_ACCEPTED_FILE, "DATA")
    if raw and raw ~= "" then
        for _, line in ipairs(string.Explode("\n", raw)) do
            line = line:Trim()
            if line ~= "" then
                local sid, rest = line:match("^([^\t]+)\t(.+)$")
                if sid and rest then
                    Paradise.NPCs.PlayerAcceptedMissions[sid] = {}
                    for _, id in ipairs(string.Explode(",", rest)) do
                        id = id:Trim()
                        if id ~= "" then Paradise.NPCs.PlayerAcceptedMissions[sid][id] = true end
                    end
                end
            end
        end
    end
    Paradise.NPCs.PlayerCompletedMissions = Paradise.NPCs.PlayerCompletedMissions or {}
    raw = file.Read(NPC_COMPLETED_FILE, "DATA")
    if raw and raw ~= "" then
        for _, line in ipairs(string.Explode("\n", raw)) do
            line = line:Trim()
            if line ~= "" then
                local sid, rest = line:match("^([^\t]+)\t(.+)$")
                if sid and rest then
                    Paradise.NPCs.PlayerCompletedMissions[sid] = {}
                    for _, part in ipairs(string.Explode(",", rest)) do
                        part = part:Trim()
                        local id, ntype = part:match("^([^:]+):(.+)$")
                        if id and ntype then Paradise.NPCs.PlayerCompletedMissions[sid][id] = ntype end
                    end
                end
            end
        end
    end
end

local function saveAcceptedMissionsToFile()
    if not Paradise.NPCs.PlayerAcceptedMissions then return end
    local lines = {}
    for sid, tbl in pairs(Paradise.NPCs.PlayerAcceptedMissions) do
        local ids = {}
        for id, _ in pairs(tbl) do table.insert(ids, id) end
        if #ids > 0 then table.insert(lines, sid .. "\t" .. table.concat(ids, ",")) end
    end
    file.Write(NPC_ACCEPTED_FILE, table.concat(lines, "\n"))
end

local function saveCompletedMissionsToFile()
    if not Paradise.NPCs.PlayerCompletedMissions then return end
    local lines = {}
    for sid, tbl in pairs(Paradise.NPCs.PlayerCompletedMissions) do
        local parts = {}
        for id, ntype in pairs(tbl) do table.insert(parts, id .. ":" .. (ntype or "generic")) end
        if #parts > 0 then table.insert(lines, sid .. "\t" .. table.concat(parts, ",")) end
    end
    file.Write(NPC_COMPLETED_FILE, table.concat(lines, "\n"))
end

local function loadNPCSpawnsFromFile()
    Paradise.NPCSpawnLocations = Paradise.NPCSpawnLocations or {}
    local raw = file.Read(NPC_SPAWNS_FILE, "DATA")
    if not raw or raw == "" then return end
    for _, line in ipairs(string.Explode("\n", raw)) do
        line = line:Trim()
        if line ~= "" then
            local parts = string.Explode("\t", line)
            if #parts >= 7 then
                local x, y, z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
                local p, yaw, r = tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6])
                local npcType = parts[7] or "generic"
                local model = parts[8] or "models/mossman.mdl"
                if x and y and z then
                    table.insert(Paradise.NPCSpawnLocations, { pos = Vector(x, y, z), ang = Angle(p or 0, yaw or 0, r or 0), npc_type = npcType, model = model })
                end
            end
        end
    end
end

local function saveNPCSpawnsToFile()
    if not Paradise.NPCSpawnLocations then return end
    local lines = {}
    for _, loc in ipairs(Paradise.NPCSpawnLocations) do
        local p = loc.pos or loc
        local a = loc.ang or Angle(0, 0, 0)
        local t = loc.npc_type or loc.npcType or "generic"
        local m = loc.model or "models/mossman.mdl"
        if isvector(p) then
            table.insert(lines, string.format("%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%s\t%s", p.x, p.y, p.z, a.p, a.y, a.r, t, m))
        end
    end
    file.Write(NPC_SPAWNS_FILE, table.concat(lines, "\n"))
end

-- Optional: spawn NPCs from Paradise.NPCSpawnLocations on map load (when admin has set locations)
-- Test: spawn NPC at admin's aim position. Usage: paradise_spawnnpc [type]
concommand.Add("paradise_spawnnpc", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local npcType = args[1] or "generic"
    local tr = IsValid(ply) and ply:GetEyeTrace() or nil
    local pos = (tr and tr.HitPos) or Vector(0, 0, 0)
    local ang = (IsValid(ply) and ply:EyeAngles()) or Angle(0, 0, 0)
    ang.p = 0
    ang.r = 0
    local model = Paradise.NPCs and Paradise.NPCs.GetModelForType and Paradise.NPCs.GetModelForType(npcType) or "models/mossman.mdl"
    local ent = ents.Create("paradise_npc")
    if not IsValid(ent) then if IsValid(ply) then ply:ChatPrint("Failed to create paradise_npc") end return end
    ent:SetPos(pos + Vector(0, 0, 2))
    ent:SetAngles(ang)
    ent:SetModel(model)
    ent:Spawn()
    ent:SetNPCType(npcType)
    if IsValid(ply) then DarkRP.notify(ply, 0, 4, "Spawned " .. npcType .. " NPC. Use E to interact.") end
end)

hook.Add("Initialize", "Paradise_NPCLoadMissions", function()
    loadAcceptedAndCompletedMissionsFromFile()
end)

hook.Add("InitPostEntity", "Paradise_NPCSpawnFromLocations", function()
    loadNPCSpawnsFromFile()
    if not Paradise.NPCSpawnLocations or #Paradise.NPCSpawnLocations == 0 then return end
    for _, loc in ipairs(Paradise.NPCSpawnLocations) do
        local pos = loc.pos or loc
        local ang = loc.ang or Angle(0, 0, 0)
        local npcType = loc.npc_type or loc.npcType or "generic"
        local model = loc.model or (Paradise.NPCs and Paradise.NPCs.GetModelForType and Paradise.NPCs.GetModelForType(npcType)) or "models/mossman.mdl"
        if isvector(pos) then
            local ent = ents.Create("paradise_npc")
            if IsValid(ent) then
                ent:SetPos(pos)
                ent:SetAngles(ang)
                ent:SetModel(model)
                ent:Spawn()
                ent:SetNPCType(npcType)
            end
        end
    end
end)

-- Admin NPC spawn editor: request list
net.Receive("Admin_RequestNPCSpawns", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    Paradise.NPCSpawnLocations = Paradise.NPCSpawnLocations or {}
    net.Start("Admin_SendNPCSpawns")
    net.WriteUInt(#Paradise.NPCSpawnLocations, 16)
    for _, loc in ipairs(Paradise.NPCSpawnLocations) do
        local p = loc.pos or loc
        local a = loc.ang or Angle(0, 0, 0)
        if isvector(p) then
            net.WriteVector(p)
            net.WriteAngle(a)
            net.WriteString(loc.npc_type or loc.npcType or "generic")
            net.WriteString(loc.model or "models/mossman.mdl")
        end
    end
    net.Send(ply)
end)

-- Add spawn at admin's position
net.Receive("Admin_AddNPCSpawn", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    Paradise.NPCSpawnLocations = Paradise.NPCSpawnLocations or {}
    local npcType = net.ReadString() or "generic"
    net.ReadString() -- client may send model; we use GetModelForType instead
    local model = Paradise.NPCs and Paradise.NPCs.GetModelForType and Paradise.NPCs.GetModelForType(npcType) or "models/mossman.mdl"
    local pos = ply:GetPos()
    local ang = ply:EyeAngles()
    ang.p = 0
    ang.r = 0
    table.insert(Paradise.NPCSpawnLocations, { pos = pos, ang = ang, npc_type = npcType, model = model })
    saveNPCSpawnsToFile()
    -- Spawn the NPC now so it appears without map reload
    local ent = ents.Create("paradise_npc")
    if IsValid(ent) then
        ent:SetPos(pos)
        ent:SetAngles(ang)
        ent:SetModel(model)
        ent:Spawn()
        ent:SetNPCType(npcType)
    end
    DarkRP.notify(ply, 0, 4, "NPC spawn added. Reload map to persist placement.")
end)

-- Remove spawn by index (and remove entity at that position if found)
net.Receive("Admin_RemoveNPCSpawn", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    Paradise.NPCSpawnLocations = Paradise.NPCSpawnLocations or {}
    local idx = net.ReadUInt(16) + 1
    local loc = table.remove(Paradise.NPCSpawnLocations, idx)
    if not loc then return end
    saveNPCSpawnsToFile()
    local pos = loc.pos or loc
    if isvector(pos) then
        for _, ent in ipairs(ents.FindByClass("paradise_npc")) do
            if IsValid(ent) and ent:GetPos():Distance(pos) < 50 then
                ent:Remove()
                break
            end
        end
    end
    DarkRP.notify(ply, 0, 4, "NPC spawn removed.")
end)

Paradise.NPCs.PlayerAcceptedMissions = Paradise.NPCs.PlayerAcceptedMissions or {}
Paradise.NPCs.PlayerCompletedMissions = Paradise.NPCs.PlayerCompletedMissions or {}

net.Receive("Paradise_NPCAcceptMission", function(len, ply)
    if not IsValid(ply) then return end
    local id = net.ReadString()
    if not id or #id == 0 or #id > 64 then return end
    local sid = ply:SteamID()
    Paradise.NPCs.PlayerAcceptedMissions[sid] = Paradise.NPCs.PlayerAcceptedMissions[sid] or {}
    Paradise.NPCs.PlayerAcceptedMissions[sid][id] = true
    saveAcceptedMissionsToFile()
end)

net.Receive("Paradise_NPCCancelMission", function(len, ply)
    if not IsValid(ply) then return end
    local id = net.ReadString()
    if not id or #id == 0 or #id > 64 then return end
    local sid = ply:SteamID()
    if Paradise.NPCs.PlayerAcceptedMissions[sid] then
        Paradise.NPCs.PlayerAcceptedMissions[sid][id] = nil
        saveAcceptedMissionsToFile()
    end
end)

net.Receive("Paradise_NPCCompleteMission", function(len, ply)
    if not IsValid(ply) then return end
    local id = net.ReadString()
    local npcType = net.ReadString() or "generic"
    if not id or #id == 0 or #id > 64 then return end
    local sid = ply:SteamID()
    if Paradise.NPCs.PlayerAcceptedMissions[sid] then Paradise.NPCs.PlayerAcceptedMissions[sid][id] = nil end
    Paradise.NPCs.PlayerCompletedMissions[sid] = Paradise.NPCs.PlayerCompletedMissions[sid] or {}
    Paradise.NPCs.PlayerCompletedMissions[sid][id] = npcType
    saveAcceptedMissionsToFile()
    saveCompletedMissionsToFile()
end)

-- Client requests a tooltip notification (used for mission accepted/cancelled etc.).
net.Receive("Paradise_NPCNotify", function(len, ply)
    if not IsValid(ply) then return end
    local msg = net.ReadString()
    if msg and #msg > 0 and #msg <= 200 then
        DarkRP.notify(ply, 0, 4, msg)
    end
end)
