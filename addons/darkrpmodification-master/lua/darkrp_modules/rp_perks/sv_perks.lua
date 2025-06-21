print("[Perks] Perks module loading...")

if not sql.TableExists("player_perks") then
    print("[Perks] Creating player_perks table")
    sql.Query([[
        CREATE TABLE IF NOT EXISTS player_perks (
            steamid TEXT PRIMARY KEY,
            total_points INTEGER DEFAULT 0,
            endurance_level INTEGER DEFAULT 0,
            endurance_time_played INTEGER DEFAULT 0,
            combat_attack_level INTEGER DEFAULT 0,
            combat_defence_level INTEGER DEFAULT 0,
            combat_speed_level INTEGER DEFAULT 0,
            medical_healing_level INTEGER DEFAULT 0,
            medical_revive_level INTEGER DEFAULT 0,
            contraband_printers_level INTEGER DEFAULT 0,
            contraband_drugs_level INTEGER DEFAULT 0
        )
    ]])
else
    print("[Perks] player_perks table already exists")
end

-- Function to load player perks from SQLite
local function LoadPlayerPerks(ply)
    local steamid = ply:SteamID()
    local query = "SELECT * FROM player_perks WHERE steamid = '" .. sql.SQLStr(steamid) .. "'"
    local result = sql.Query(query)
    if result then
        print("[Perks] Loaded perk data for " .. steamid)
        return result[1] -- Return the row as a table
    else
        print("[Perks] No perk data for " .. steamid .. ", inserting new record")
        -- Insert new player if not found
        sql.Query("INSERT INTO player_perks (steamid) VALUES ('" .. sql.SQLStr(steamid) .. "')")
        return {total_points = 0, endurance_level = 0, endurance_time_played = 0, combat_attack_level = 0, combat_defence_level = 0, combat_speed_level = 0, medical_healing_level = 0, medical_revive_level = 0, contraband_printers_level = 0, contraband_drugs_level = 0}
    end
end

-- Function to update player perks in SQLite
local function UpdatePlayerPerks(ply, data)
    local steamid = ply:SteamID()
    sql.Query("UPDATE player_perks SET total_points = " .. data.total_points .. ", endurance_level = " .. data.endurance_level .. ", endurance_time_played = " .. data.endurance_time_played .. ", combat_attack_level = " .. data.combat_attack_level .. ", combat_defence_level = " .. data.combat_defence_level .. ", combat_speed_level = " .. data.combat_speed_level .. ", medical_healing_level = " .. data.medical_healing_level .. ", medical_revive_level = " .. data.medical_revive_level .. ", contraband_printers_level = " .. data.contraband_printers_level .. ", contraband_drugs_level = " .. data.contraband_drugs_level .. " WHERE steamid = '" .. sql.SQLStr(steamid) .. "'")
    print("[Perks] Updated perk data for " .. steamid)
end

-- Network handling
util.AddNetworkString("RequestPerkData")
util.AddNetworkString("SendPerkData")
util.AddNetworkString("UpdatePerkData")

net.Receive("RequestPerkData", function(len, ply)
    print("[Perks] Received RequestPerkData from " .. ply:SteamID())
    local perkData = LoadPlayerPerks(ply)
    net.Start("SendPerkData")
    net.WriteTable(perkData)
    net.Send(ply)
    print("[Perks] Sent perk data to " .. ply:SteamID())
end)

-- Hook to load perks when player joins and update periodically
hook.Add("PlayerInitialSpawn", "LoadPerks", function(ply)
    print("[Perks] Player " .. ply:SteamID() .. " spawned, loading perks")
    local perkData = LoadPlayerPerks(ply)
    -- Simulate updating time played (to be replaced with actual playtime tracking)
    perkData.endurance_time_played = perkData.endurance_time_played or 0
    perkData.endurance_time_played = perkData.endurance_time_played + 1 -- Example increment
    UpdatePlayerPerks(ply, perkData)
    net.Start("UpdatePerkData")
    net.Broadcast()
    print("[Perks] Broadcasted perk update for " .. ply:SteamID())
end)

print("[Perks] Perks module loaded successfully")