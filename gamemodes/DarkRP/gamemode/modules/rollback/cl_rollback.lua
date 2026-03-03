--[[---------------------------------------------------------------------------
  Rollback module (client) — Placeholder for future admin UI.
  Admin panel can add a "Rollback" tab that requests snapshot list and sends restore request.
---------------------------------------------------------------------------]]
if not CLIENT then return end

Paradise.Rollback = Paradise.Rollback or {}

-- Future: net.Receive(Paradise.Rollback.NET.SendSnapshotList, ...) to populate list
-- Future: button "Restore" sends Paradise.Rollback.NET.RequestRestore with snapshot_id and optional target_steamid
-- All feedback via DarkRP.notify (tooltip), no global chat.
