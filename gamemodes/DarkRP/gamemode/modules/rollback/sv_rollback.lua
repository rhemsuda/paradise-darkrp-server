--[[---------------------------------------------------------------------------
  Rollback module (server) — Framework stubs.
  Creates paradise_snapshots table; implements TakeSnapshot / RestoreSnapshot stubs.
  Fill in actual snapshot/restore logic when circling back to admin systems.
  See ROLLBACK_FRAMEWORK.md.
---------------------------------------------------------------------------]]
if not SERVER then return end

Paradise.Rollback = Paradise.Rollback or {}

-- Create snapshot table when DB is ready
hook.Add("DarkRPDBInitialized", "Paradise_Rollback_CreateTable", function()
    if not MySQLite then return end
    local autoInc = MySQLite.isMySQL() and "AUTO_INCREMENT" or "AUTOINCREMENT"
    local dataType = MySQLite.isMySQL() and "LONGTEXT" or "TEXT"
    local sql = "CREATE TABLE IF NOT EXISTS paradise_snapshots (id INTEGER NOT NULL PRIMARY KEY " .. autoInc .. ", snapshot_type VARCHAR(10) NOT NULL, created_at INTEGER NOT NULL, data " .. dataType .. ");"
    MySQLite.query(sql, function()
        -- Table ready; timers and full TakeSnapshot/RestoreSnapshot to be implemented later
    end, function(err)
        print("[Rollback] Failed to create paradise_snapshots: " .. tostring(err))
    end)
end)

-- TakeSnapshot(type) — stub: to be implemented (read wallet, inv, resources, xp, perks, gangs; INSERT into paradise_snapshots).
function Paradise.Rollback.TakeSnapshot(snapshotType)
    if not Paradise.Rollback.SnapshotType then return end
    snapshotType = snapshotType or Paradise.Rollback.SnapshotType.Day
    -- TODO: gather from darkrp_player, inv2_state/darkrp_custom_inventory, player_perks, darkrp_gangs; build JSON; INSERT; prune old by retention
    hook.Run("Paradise.OnSnapshotTaken", nil, snapshotType, os.time())
end

-- RestoreSnapshot(snapshot_id, target_steamid_or_nil) — stub: nil = all players. Write back data; notify target(s) and admin; no global announcement.
function Paradise.Rollback.RestoreSnapshot(snapshotId, targetSteamIdOrNil)
    if not snapshotId or snapshotId < 1 then return false end
    -- TODO: SELECT data FROM paradise_snapshots WHERE id = snapshotId; for each target, write wallet/inv/resources/xp/perks/gangs; if online, sync and DarkRP.notify(ply, 0, 4, "Your data was rolled back to ...")
    hook.Run("Paradise.OnRollback", nil, snapshotId, targetSteamIdOrNil and { targetSteamIdOrNil } or {})
    return true
end

-- Optional: concommand for superadmin to trigger a snapshot manually (e.g. paradise_takesnapshot day)
concommand.Add("paradise_takesnapshot", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local t = (args[1] or "day"):lower()
    if t ~= "day" and t ~= "week" and t ~= "month" then t = "day" end
    Paradise.Rollback.TakeSnapshot(t)
    if IsValid(ply) then DarkRP.notify(ply, 0, 4, "Snapshot requested (" .. t .. "). Implement TakeSnapshot to save data.") end
end)
