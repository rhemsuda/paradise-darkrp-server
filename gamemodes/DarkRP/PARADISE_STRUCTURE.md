# Paradise DarkRP — Structure & Module Map

**Purpose:** Give an AI (or developer) enough context to work on this gamemode after a context switch. Read this + **PARADISE_PLAN.md** to know where things live and how they connect.

---

## 1. Repo layout (skeletal)

```
gamemodes/DarkRP/
├── PARADISE_PLAN.md      ← Feature phases & todo (Phase 1–10). Master plan.
├── PARADISE_STRUCTURE.md ← This file: where things are, how they interact.
├── CHANGELOG.md          ← What changed and when.
├── README.md / ROADMAP.md
└── gamemode/
    ├── init.lua          ← Server: loads config, libraries, then modules (sv_ then sh_).
    ├── cl_init.lua       ← Client: LoadModules() loads sh_* then cl_* per module folder.
    ├── config/           ← config.lua, jobrelated.lua, addentities.lua, ammotypes.lua, etc.
    ├── libraries/        ← modificationloader, mysqlite, simplerr, fn, etc.
    └── modules/          ← One folder per feature (admin, Inventory, chat, …).
```

**Loading order:** Server `init.lua` adds CSLuaFiles and includes `sv_*.lua` then `sh_*.lua` per module. Client `cl_init.lua` runs `LoadModules()`: for each folder under `gamemode/modules/`, it includes `sh_*.lua` then `cl_*.lua` (skips `*_interface.lua`). Config (`jobrelated.lua`, etc.) is loaded after modules.

---

## 2. Module folders (where things live)

| Module        | Path (under `gamemode/modules/`) | Role |
|---------------|-----------------------------------|------|
| **admin**     | `admin/`                          | Paradise admin: ranks, panel UI, Kick/Ban/Goto/Bring/Freeze, Demote (job), Ban list, Logs, /a, /commands. Uses `Admin` global; net names `Admin_*`, `Paradise_*`. |
| **Inventory** | `Inventory/`                      | Item storage, loadout, give/take. `sh_inventory.lua` defines `Inventory.NET` and item config; `sv_inventory.lua` persistence (SQLite/file), nets; `cl_inventory.lua` UI + `INV_ParadiseChat` for unified chat. |
| **resources** | `resources/`                      | Mining/dropping resources (rock, copper, iron, diamond, etc.). Server: `sv_resources.lua` (ResourceItems, AddResourceToInventory, ResourcesMessage). Client: `cl_resources.lua` (BuildResourcesMenu, ResourcesMessage → gray + colored name, no parens). Dropped entity `paradise_resource` (cl_init) draws diamond with smoke + alpha, obsidian with glow + mist. |
| **chat**      | `chat/`                           | DarkRP chat. `sv_chat.lua` (PlayerSay, RP_ActualDoSay); `cl_chat.lua` receives `DarkRP_Chat`, adds **(DEAD)** in red when sender is dead. |
| **deathsystem** | `deathsystem/`                  | Ghost/death: blocks job change, inventory, spawns; respawn hooks. `sv_deathsystem.lua` / `cl_deathsystem.lua`. |
| **rpjobs**    | `rpjobs/`                         | Jobs UI and server job switch. `sv_jobs.lua` (e.g. `ply:changeTeam`), `cl_jobs.lua`. Jobs defined in `config/jobrelated.lua` (TEAM_CITIZEN, etc.). |
| **leveling**  | `leveling/`                       | XP/levels. `sv_leveling.lua`, `sh_leveling.lua`. Used by jobs/entities for requirements. |
| **logging**   | `logging/`                        | DarkRP.log(), file + admin console. |
| **police**    | `police/`                         | Arrest, warrants, jail, gun license. |
| **money**     | `money/`                          | Wallet, pay, drop. |
| **fadmin**    | `fadmin/`                         | FAdmin: Voicemute (voice mute), Chatmute (chat gag), etc. Paradise admin panel calls these for Mute/Gag. |
| **f4menu**    | `f4menu/`                         | F4 menu (jobs, entities, etc.). |
| **scoreboard** | `scoreboard/`                    | Scoreboard UI. |
| **rpmenu**    | `rpmenu/`                         | RP menu, gang upgrades. |
| **rpents**    | `rpents/`                         | Entities (buy, job restrictions). |
| **rp_props**  | `rp_props/`                       | Prop ownership / damage. |
| **rp_perks**  | `rp_perks/`                       | Perks. |
| **rpcraft**   | `rpcraft/`                        | (Legacy) Crafting. |
| **npcs**      | `npcs/`                           | NPC menu (Missions/Shop). Crafter: sh_crafting (recipes), sv_crafting (staged, Craft/AddResources/SetBlueprint), cl_npcs (blueprint list, drop zone, materials, Fill, Craft button at bottom, result popup). Nets: Crafter_*. |
| **POC**       | `POC/`                            | Printer ownership/cleanup (Phase 2). |
| **base**      | `base/`                           | GM functions, spawn, death logging, `sv_gamemode_functions.lua`, `sv_util.lua` (DarkRP.talkToPerson, talkToRange). |
| **positions** | `positions/`                      | Spawn/jail positions. |
| **voting**    | `voting/`                         | Votes. |
| **sleep**     | `sleep/`                          | AFK/sleep. |
| **workarounds** | `workarounds/`                   | ULX/CAC workarounds. |

---

## 3. Key globals and contracts

- **Admin** (server + client): `Admin.Ranks`, `Admin.Users` (steamid → rank), `Admin.GetRank(steamid)`, `Admin.SetRank(steamid, rank)`. Server: `Admin.DefaultSuperAdmin`, `FindPlayerBySteamID(steamid)`.
- **Paradise** (server): `Paradise.AdminLog` (ring buffer for Logs tab), `Paradise.AdminLogEntry(category, message, extra)`, `Paradise.Frozen[ply]` (freeze state). Used by admin module and inventory (item give logging).
- **Inventory** (shared): `Inventory.NET` (net names), `Inventory.Config`, `Inventory.Items` (from `sh_items.lua`). Client: `Inventory.Client.Items`, `Inventory.Client.ItemsCatalog`. Server: persistence in `sv_inventory.lua`, `PlayerInv[sid64]`, `sendFull(ply)`.
- **DarkRP**: `DarkRP.findPlayer(nameOrSteamid)`, `DarkRP.notify(ply, type, len, msg)`, `DarkRP.log(text, colour)`, `DarkRP.talkToPerson(receiver, col1, text1, col2, text2, sender)`, `DarkRP.defineChatCommand`, `DarkRP.definePrivilegedChatCommand`, `GAMEMODE.DefaultTeam` (e.g. TEAM_CITIZEN).
- **RPExtraTeams**, **team.GetName**, **team.GetColor**: jobs (from `config/jobrelated.lua`). `ply:changeTeam(teamId, force)` in `modules/jobs/sv_jobs.lua`.

---

## 4. Net messages (Paradise / Admin / Inventory)

- **Admin:** `Admin_RequestUserList` / `Admin_SendUserList`, `Admin_Kick`, `Admin_Ban`, `Admin_Demote`, `Admin_Spawn`, `Admin_RequestBanList` / `Admin_SendBanList`, `Admin_RequestLogs` / `Admin_SendLogs`, `Admin_AddBan`, `Paradise_AdminChat`.
- **Inventory:** `INV_*` (see `sh_inventory.lua`: SyncInventory, Notify, AdminCreateItemFor, **ParadiseChat** for unified admin give messages).
- **Resources:** `ResourcesMessage` (mined, dropped, plain; server sends, client formats gray + colored resource name).
- **Crafter (npcs):** `Crafter_Open`, `Crafter_Close`, `Crafter_SetBlueprint`, `Crafter_AddResources`, `Crafter_Craft`, `Crafter_StagedUpdate`, `Crafter_CraftResult`.

---

## 5. How modules interact

- **Unified chat:** Server sends one line; client prints with a single style. Item give messages: server sends `INV_ParadiseChat` only to admins (and target). Resources: server sends `ResourcesMessage` (type + resourceID/amount); client uses gray base + colored resource name, no parentheses. Chat (dead tag): `cl_chat.lua` adds red `(DEAD)` when `ply` is not alive.
- **Admin panel:** `BuildAdminPanel(parent)` in `admin/cl_admin.lua` builds the UI. Buttons use `getSelectedPlayer()` (reads `userList:GetSelectedLine()`). Server handlers in `admin/sv_admin.lua` (Kick/Ban/Demote/Spawn/Goto/Bring/Freeze, Ban list, Logs, Add ban).
- **Demote:** Admin “Demote” = **job** demote (`target:changeTeam(GAMEMODE.DefaultTeam, true)`). Rank changes are intended for the **Settings** tab (ranks/gangs/levels/server limits — not fully built yet).
- **Mute / Gag:** Mute = voice (FAdmin Voicemute), Gag = chat (FAdmin chatmute). Panel and right-click call the correct FAdmin commands.
- **Ban list:** Server reads `cfg/banned_user.cfg` (or `banned_user.cfg`) and sends raw lines. “Add ban” (Super Admin) sends SteamID/name + reason + duration; server finds player (must be online), runs `banid`/`writeid`, kicks. Export for website = use that cfg (reasons/time in file).
- **Logs:** Server keeps `Paradise.AdminLog` (e.g. last 500 entries). `PlayerDeath` and inventory admin give call `Paradise.AdminLogEntry`. Client Logs tab requests and displays with category filter (kill, item, misc).

---

## 6. Entry points for common tasks

- **Add a new admin action:** Add button in `admin/cl_admin.lua` (and optional right-click), then server handler or concommand in `admin/sv_admin.lua`. Use `getSelectedPlayer()` for panel; for chat, use `DarkRP.definePrivilegedChatCommand` or `defineChatCommand`.
- **Change chat appearance:** Client `chat/cl_chat.lua` (DarkRP_Chat receive). For Paradise-styled messages, use `INV_ParadiseChat` or `ResourcesMessage` pattern (gray + colored parts).
- **Add a log category:** Server calls `Paradise.AdminLogEntry("category", "message", { extra = data })`. Client Logs tab already filters by category; add the new name to the filter combo if desired.
- **Jobs / teams:** `config/jobrelated.lua` (TEAM_*), `modules/jobs/sv_jobs.lua` (`changeTeam`), `modules/rpjobs/` for UI.
- **Items / inventory:** `Inventory` in `sh_inventory.lua`, `sh_items.lua`; server `sv_inventory.lua`; client `cl_inventory.lua`, `cl_inventory_loadout.lua`.
- **NPC Crafter:** `modules/npcs/sh_crafting.lua` (Crafting.GetRecipe), `sv_crafting.lua` (staged state, Craft/AddResources/SetBlueprint), `cl_npcs.lua` (crafter tab: buildCrafterBlueprintList, drop zone, materials, Fill, Craft button, progress bar, showCraftResultPopup). Client calls `Inventory.NET.RequestFull` and hooks `Inventory_Synced` to refresh blueprint list.

---

## 7. Conventions

- **Protect-and-explain:** Don’t remove or simplify code you don’t understand; comment “APPEARS UNUSED — verify before removing” if needed. Explain what you change and why.
- **Teaching context:** This repo is used for learning; prefer clear names, short comments for non-obvious logic, and consistent patterns.
- **Chat:** One consistent style: gray base, colored accents, `[Paradise]` prefix where appropriate. Admin-only messages only to admins (and target when relevant).

---

## 8. Quick pointer for “where did we leave off?”

1. Open **PARADISE_PLAN.md** and check the phase/task you were on.
2. Open **CHANGELOG.md** for recent changes.
3. Use this file to locate the right module and globals/nets, then search or read the specific `sv_*` / `cl_*` / `sh_*` files.
