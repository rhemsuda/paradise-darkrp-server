--[[---------------------------------------------------------------------------
  GMod10 Scoreboard - Server rating (moved from lua/autorun/server/rating.lua).
  Loaded as a DarkRP module (sv_*.lua); no autorun.
---------------------------------------------------------------------------]]
if not SERVER then return end

GM10_NextRatingTime = 60

if not sql.TableExists("ratings") then
    sql.Query("CREATE TABLE IF NOT EXISTS ratings ( id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, target INTEGER, rater INTEGER, rating INTEGER );")
    sql.Query("CREATE INDEX IDX_RATINGS_TARGET ON ratings ( target DESC )")
    Msg("SQL: Created ratings table!\n")
end

local ValidRatings = { "bad", "smile", "love", "artistic", "star", "builder" }

local function GetRatingID(name)
    for k, v in pairs(ValidRatings) do
        if name == v then return k end
    end
    return false
end

local function UpdatePlayerRatings(ply)
    local result = sql.Query("SELECT rating, count(*) as cnt FROM ratings WHERE target = " .. ply:SteamID64() .. " GROUP BY rating ")
    if not result then return end
    for id, row in pairs(result) do
        ply:SetNW2Int("Rating." .. ValidRatings[tonumber(row["rating"])], tonumber(row["cnt"]))
    end
end

local function CCRateUser(player, command, arguments)
    local Rater = player
    local Target = Entity(tonumber(arguments[1]))
    local Rating = arguments[2]
    if not Target:IsPlayer() then return end
    if Rater == Target then return end
    local RatingID = GetRatingID(Rating)
    local RaterID = Rater:SteamID64()
    local TargetID = Target:SteamID64()
    if not RatingID then return end
    Target.RatingTimers = Target.RatingTimers or {}
    if Target.RatingTimers[RaterID] and Target.RatingTimers[RaterID] > CurTime() - GM10_NextRatingTime then
        Rater:ChatPrint("Please wait before rating " .. Target:Nick() .. " again.\n")
        return
    end
    Target.RatingTimers[RaterID] = CurTime()
    Target:ChatPrint("You have received a new rating.\n")
    Rater:ChatPrint("Rated " .. Target:Nick() .. "!\n")
    sql.Query("INSERT INTO ratings ( target, rater, rating ) VALUES ( " .. TargetID .. ", " .. RaterID .. ", " .. RatingID .. ")")
    UpdatePlayerRatings(Target)
end

concommand.Add("rateuser", CCRateUser)

hook.Add("PlayerInitialSpawn", "PlayerRatingsRestore", function(ply)
    UpdatePlayerRatings(ply)
end)
