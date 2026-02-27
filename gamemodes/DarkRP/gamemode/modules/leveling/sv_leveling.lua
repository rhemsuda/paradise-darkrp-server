--[[---------------------------------------------------------------------------
  Paradise RP – Leveling (100 levels). XP from: quests, crafting, printers, drugs.
  DB: darkrp_player.experience (added by base migration 20250201), darkrp_levelinfo(level, experienceRequired).
---------------------------------------------------------------------------]]
if not SERVER then return end

Leveling = Leveling or {}

local MAX_LEVEL = 100
local DEBUG = CreateConVar("leveling_debug", "0", FCVAR_ARCHIVE, "Print leveling debug to console (1=on)")

-- Build required XP for level n: level 1 = 0, level 2 = 100, then curve
local function getRequiredXPForLevel(level)
    if level <= 1 then return 0 end
    return math.floor(100 * math.pow(level - 1, 1.45) + 0.5)
end

-- Create level table and seed 100 levels after DB is ready
hook.Add("DarkRPDBInitialized", "Paradise_Leveling_Setup", function()
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS darkrp_levelinfo(
            level INTEGER NOT NULL PRIMARY KEY,
            experienceRequired BIGINT NOT NULL
        );
    ]], function()
        MySQLite.query("SELECT COUNT(*) AS cnt FROM darkrp_levelinfo", function(data)
            local count = data and data[1] and tonumber(data[1].cnt) or 0
            if count >= MAX_LEVEL then return end

            local values = {}
            for lvl = 1, MAX_LEVEL do
                local req = getRequiredXPForLevel(lvl)
                values[#values + 1] = string.format("(%d,%d)", lvl, req)
            end
            local sql
            if MySQLite.isMySQL() then
                sql = "REPLACE INTO darkrp_levelinfo(level, experienceRequired) VALUES " .. table.concat(values, ",")
            else
                sql = "INSERT OR REPLACE INTO darkrp_levelinfo(level, experienceRequired) VALUES " .. table.concat(values, ",")
            end
            MySQLite.query(sql, function()
                if DEBUG:GetBool() then print("[Leveling] Seeded " .. MAX_LEVEL .. " levels.") end
            end, function(err)
                if DEBUG:GetBool() then print("[Leveling] Seed error: " .. tostring(err)) end
            end)
        end, function(err)
            if DEBUG:GetBool() then print("[Leveling] darkrp_levelinfo count error: " .. tostring(err)) end
        end)
    end, function(err)
        if DEBUG:GetBool() then print("[Leveling] darkrp_levelinfo create error: " .. tostring(err)) end
    end)
end)

local levelCache = {}
local function refreshLevelCache(callback)
    MySQLite.query("SELECT level, experienceRequired FROM darkrp_levelinfo ORDER BY level ASC", function(rows)
        levelCache = rows or {}
        if callback then callback() end
    end)
end

-- Recompute level from XP and update NW vars (DarkRP_Level, DarkRP_Experience, DarkRP_ExperienceCurrentLevel, DarkRP_ExperienceNeeded)
local function updatePlayerLevelFromXP(ply, xp)
    if #levelCache == 0 then refreshLevelCache(function() updatePlayerLevelFromXP(ply, xp) end) return end

    local currentLevel = 1
    local currentThreshold = 0
    local nextThreshold = 0

    for _, row in ipairs(levelCache) do
        local lvl = tonumber(row.level)
        local req = tonumber(row.experienceRequired) or 0
        if xp >= req then
            currentLevel = lvl
            currentThreshold = req
        else
            nextThreshold = req
            break
        end
    end
    if nextThreshold == 0 then nextThreshold = currentThreshold end

    ply:SetNWInt("DarkRP_Level", currentLevel)
    ply:SetNWInt("DarkRP_Experience", xp)
    ply:SetNWInt("DarkRP_ExperienceCurrentLevel", currentThreshold)
    ply:SetNWInt("DarkRP_ExperienceNeeded", nextThreshold)
end

-- Add XP and optionally run level-up logic. Call from quests/crafting/printers/drugs.
function Leveling.AddXP(ply, amount, source)
    if not IsValid(ply) or not isnumber(amount) or amount < 0 then return end
    amount = math.floor(amount)
    if amount == 0 then return end

    local sid64 = ply:SteamID64()
    MySQLite.query(string.format("SELECT experience FROM darkrp_player WHERE uid = %s", sid64), function(data)
        local current = 0
        if data and data[1] then current = tonumber(data[1].experience) or 0 end

        local newXP = current + amount
        MySQLite.query(string.format("UPDATE darkrp_player SET experience = %d WHERE uid = %s", newXP, sid64))
        ply:SetNWInt("DarkRP_Experience", newXP)

        local oldLevel = ply:GetNWInt("DarkRP_Level", 1)
        updatePlayerLevelFromXP(ply, newXP)
        local newLevel = ply:GetNWInt("DarkRP_Level", 1)

        if newLevel > oldLevel then
            ply:ChatPrint("You've leveled up to Level " .. newLevel .. "!")
        end
        if DEBUG:GetBool() then
            print(string.format("[Leveling] %s +%d XP (source: %s) -> %d XP, level %d", ply:Nick(), amount, tostring(source or "?"), newXP, newLevel))
        end
    end, function(err)
        if DEBUG:GetBool() then print("[Leveling] AddXP query error: " .. tostring(err)) end
    end)
end

-- Other modules (quests, crafting, printers, drugs) grant XP by calling:
--   hook.Run("Paradise_AddXP", ply, amount, "quest")  -- or "crafting", "printer", "drugs"
-- or on server: Leveling.AddXP(ply, amount, "printer")
hook.Add("Paradise_AddXP", "Leveling_Grant", function(ply, amount, source)
    Leveling.AddXP(ply, amount, source)
end)

-- Grant XP when a money printer pays out (any tier: printer1–printer9 or base money_printer)
local PRINTER_XP_PER_PAYOUT = 3
hook.Add("moneyPrinterPrinted", "Leveling_PrinterXP", function(printer, moneybag)
    if not IsValid(printer) then return end
    local owner = printer:Getowning_ent()
    if IsValid(owner) and owner:IsPlayer() then
        Leveling.AddXP(owner, PRINTER_XP_PER_PAYOUT, "printer")
    end
end)

-- Load on spawn and set NW vars
hook.Add("PlayerInitialSpawn", "Paradise_Leveling_Load", function(ply)
    refreshLevelCache(function()
        local sid64 = ply:SteamID64()
        MySQLite.query(string.format("SELECT experience FROM darkrp_player WHERE uid = %s", sid64), function(data)
            local xp = 0
            if data and data[1] then xp = tonumber(data[1].experience) or 0 end
            updatePlayerLevelFromXP(ply, xp)
            if DEBUG:GetBool() then print("[Leveling] Loaded " .. ply:Nick() .. " XP=" .. xp) end
        end, function()
            updatePlayerLevelFromXP(ply, 0)
        end)
    end)
end)

concommand.Add("check_xp", function(ply)
    if not IsValid(ply) then return end
    local xp = ply:GetNWInt("DarkRP_Experience", 0)
    local lvl = ply:GetNWInt("DarkRP_Level", 1)
    ply:ChatPrint("Level: " .. lvl .. " | XP: " .. xp)
end)

concommand.Add("give_xp", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local amount = tonumber(args and args[1])
    if amount and amount > 0 then
        Leveling.AddXP(ply, amount, "give_xp")
        ply:ChatPrint("Granted " .. amount .. " XP.")
    end
end)
