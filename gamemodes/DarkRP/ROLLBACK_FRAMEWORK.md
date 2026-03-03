# Plagued Paradise — Admin rollback framework

Admins can roll back player data (items, resources, money, perks, gang/level/XP) to a previous snapshot. Snapshots are taken automatically at **day**, **week**, and **month** intervals and kept for restore.

---

## 1. Data to snapshot (per player / global)

| Data | Source | Storage today | Snapshot format |
|------|--------|----------------|-----------------|
| **Money (wallet)** | `darkrp_player.wallet` (uid) | MySQLite | Copy row or (uid, wallet) |
| **Inventory (items + loadout)** | `inv2_state` (sid64, data) or file `DATA_DIR/sid64.txt` | SQL or file | JSON blob per steamid |
| **Resources** | `darkrp_custom_inventory.resources` (steamid) | MySQLite | JSON blob per steamid |
| **Level / XP** | `darkrp_player.experience` (uid) — leveling module | MySQLite | (uid, experience) |
| **Perks** | `player_perks` (steamid, all columns) | SQLite | Full row per steamid |
| **Gang membership + gang state** | `darkrp_gangs` (full table); player’s gang = NW "GangName" at runtime | SQLite | Full table copy; optionally (steamid, gang_name) if we persist membership in DB |

**Notes:**

- **darkrp_player**: `uid` = SteamID64, used by leveling; `wallet` = money. Ensure migration that adds `experience` is applied.
- **Inventory**: Module uses `inv2_state` when `USE_SQLITE` else file. Snapshot both if mixed.
- **Gang**: Restore full `darkrp_gangs` table; on player load, set `GangName` from snapshot (e.g. paradise_player_snapshot.gang_name or derived from members).

---

## 2. Snapshot schedule and retention

| Snapshot type | When taken | Retained |
|---------------|------------|----------|
| **day** | Every 24 hours (e.g. 04:00 server time) | Last 2–3 days |
| **week** | Once per week (e.g. Sunday 04:00) | Last 4 weeks |
| **month** | Once per month (e.g. 1st 04:00) | Last 3 months |

Implementation: timer or cron-style hook (e.g. `hook.Add("Think", ...)` with next-run time, or daily timer). Store snapshot **timestamp** and **type** (day/week/month) so admins can choose “Restore to yesterday 04:00” or “Restore to last week”.

---

## 3. Snapshot storage (DB table)

Suggested table:

```sql
-- One row per snapshot (full server snapshot at a point in time)
CREATE TABLE IF NOT EXISTS paradise_snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    snapshot_type VARCHAR(10) NOT NULL,  -- 'day' | 'week' | 'month'
    created_at INTEGER NOT NULL,         -- os.time() or equivalent
    data BLOB NOT NULL                  -- JSON: { players = { [steamid64] = { wallet, inventory_json, resources_json, experience, perks_row, gang_name? }, gangs = { ... } } }
);
```

- **data**: Single JSON blob containing:
  - **players**: keyed by SteamID64; each value = `{ wallet, inventory_json, resources_json, experience, perks = { ... }, gang_name }`
  - **gangs**: array or object of full `darkrp_gangs` rows (or table name + rows) so we can restore the whole table.

Alternative: separate tables `paradise_snapshot_players` and `paradise_snapshot_gangs` with `snapshot_id` and `created_at` to avoid huge blobs. Framework doc assumes one blob per snapshot for simplicity; implementation can split.

---

## 4. Rollback flow (admin)

1. Admin opens “Rollback” in admin panel (e.g. new tab or menu).
2. UI lists available snapshots: type (day/week/month) + timestamp (e.g. “2025-02-24 04:00”, “2025-02-17 04:00”).
3. Admin selects a snapshot, then either:
   - **Restore one player**: choose player (dropdown/list), confirm → restore that player’s data from snapshot.
   - **Restore all**: confirm → restore all players + gangs from snapshot (use with care).
4. Server:
   - Loads snapshot by `id` (or type+timestamp).
   - For selected player(s): writes back wallet (darkrp_player), inventory (inv2_state or file), resources (darkrp_custom_inventory), experience (darkrp_player), perks (player_perks), and gang (restore gang table and/or set player’s gang).
   - If online: refresh player (e.g. send new money/inventory/resources/level/perks/gang) and notify “Your data was rolled back to <date> by an admin.”
5. **No global announcement**; only the affected player(s) and the admin get a tooltip/notification.

---

## 5. Implementation checklist (to do when circling back)

- [ ] Create `paradise_snapshots` (and optional split tables) in DB init/migration.
- [ ] Implement **TakeSnapshot(type)** (day/week/month): gather from darkrp_player, inv2_state/file, darkrp_custom_inventory, player_perks, darkrp_gangs; build JSON; INSERT into paradise_snapshots; prune old snapshots by retention rules.
- [ ] Implement **RestoreSnapshot(snapshot_id, steamid_or_nil)** (nil = all): read snapshot; for each target, write back wallet, inventory, resources, experience, perks, gang; if player online, sync and notify.
- [ ] Timers: daily timer for “day”; weekly/monthly or next-run time for “week”/“month”.
- [ ] Admin UI: list snapshots, choose snapshot + player(s), confirm, call server Restore.
- [ ] Hooks: `Paradise.OnSnapshotTaken(snapshot_id, type, created_at)`, `Paradise.OnRollback(admin_ply, snapshot_id, target_steamids)` for logging.

---

## 6. Files to add/touch

- **Framework (this doc):** `ROLLBACK_FRAMEWORK.md`
- **Module stub:** `gamemode/modules/rollback/sh_rollback.lua` (shared API names, net names), `sv_rollback.lua` (TakeSnapshot, RestoreSnapshot stubs; DB table create; no timers yet), `cl_rollback.lua` (empty or placeholder for future admin UI).
- **Data access:** Snapshot code must read/write:
  - Money: `darkrp_player` (MySQLite)
  - Inventory: `inv2_state` (sql) or file (path from Inventory module)
  - Resources: `darkrp_custom_inventory` (MySQLite)
  - XP: `darkrp_player.experience` (MySQLite)
  - Perks: `player_perks` (sql)
  - Gangs: `darkrp_gangs` (sql)

Keep all admin feedback as tooltips (DarkRP.notify), no global chat for rollback actions.
