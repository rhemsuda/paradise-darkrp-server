# Paradise DarkRP — Changelog

Summary of notable changes so you (or an AI) can pick up where things left off. See **PARADISE_STRUCTURE.md** for where code lives and how it connects; **PARADISE_PLAN.md** for the feature roadmap; **NPC_TODO.md** for NPC system tasks.

---

## [Unreleased] — Resources polish, loadout models, job label

*Diamond/Obsidian visuals, loadout icon model fixes, and donator category rename.*

### Resources (diamond / obsidian)

- **Diamond on ground:** Smoke effect only (three mist sprites); slight transparency via `RENDERMODE_TRANSALPHA` and alpha 200 (no glow/orb). Appearance alpha in `sh_resources.lua` set to 175 for cloudy look.
- **Obsidian on ground:** Unchanged: dark DynamicLight + mist sprites (no change this session).
- **Chat:** Diamond and Obsidian resource names use a luminous color in chat for all resource messages (mined, dropped, picked up): `DIAMOND_NAME_GLOW`, `OBSIDIAN_NAME_GLOW` in `cl_resources.lua`. No on-screen floating text.

### Loadout / Jobs tab model fixes

- **Physcannon error fixed:** Loadout was using `models/weapons/w_physcannon.mdl` (does not exist). Gravity Gun and Physics Gun both use **`models/weapons/w_Physics.mdl`** (GMod wiki Common_Weapon_Models).
- **`rpjobs/cl_jobs.lua`:** `loadoutModel()` known table — `weapon_physcannon` and `weapon_physgun` set to `w_Physics.mdl`; alignment fix.
- **`f4menu/cl_jobstab.lua`:** `getWeaponModel()` fallbacks — added `weapon_physcannon`, `weapon_physgun`, `gmod_tool`, `gmod_camera` with correct paths; **lockpick** fallback changed from trap lever to **`models/weapons/w_crowbar.mdl`** to match lockpick SWEP `WorldModel`.

### Config

- **Job category label:** "★ Donator Exclusive" → **"Exclusive"** in `config/jobrelated.lua` (category name and the two donator job categories).

### Files touched

| File | Change |
|------|--------|
| `gamemode/modules/resources/sh_resources.lua` | Diamond appearance alpha 175 |
| `gamemode/modules/resources/cl_resources.lua` | Diamond/Obsidian name glow colors in chat |
| `entities/entities/paradise_resource/cl_init.lua` | Diamond: smoke + alpha only; obsidian: glow + mist |
| `gamemode/modules/rpjobs/cl_jobs.lua` | Loadout physcannon/physgun → w_Physics.mdl |
| `gamemode/modules/f4menu/cl_jobstab.lua` | Fallbacks for physcannon, physgun, tool, camera, lockpick |
| `gamemode/config/jobrelated.lua` | "★ Donator Exclusive" → "Exclusive" |

---

## [Unreleased] — Major System Cleanup (pre-push to development branch)

*Comprehensive cleanup pass across all custom modules before continuing feature work. No new features — redundancy removal, bug fixes, architecture improvements.*

### Critical Bug Fixes

- **`money_printer/init.lua` — Sound stacking fixed:** `ENT:Think()` was calling `self:StartSound()` every frame, creating a new `CSoundPatch` object on each tick and stacking sound objects indefinitely (growing louder and leaking memory). Removed the call from `Think`; sound is already started once in `Initialize`. A comment was added to prevent reintroduction.
- **`sh_leveling.lua` — Server-side level checks now work:** File had `if SERVER then return end`, making `Leveling.GetLevel`, `Leveling.GetXP`, and `Leveling.GetXPNeededForNext` unavailable on the server. This would silently break any server-side job gate or level requirement check. Guard removed; functions are shared and safe on both sides (all read NWInts).

### Architecture / Major Redundancy Removal

- **New `sh_resources.lua`** — Created `gamemode/modules/resources/sh_resources.lua` as the single source of truth for:
  - `Paradise.ResourceItems` (id → name, model) — replaces `ResourceItems` global build loop on server + `resourceTemplates` on client (~40 lines each).
  - `Paradise.ResourceAppearances` (id → material, color) — replaces duplicate `ResourceAppearances` on server and `resourceAppearances` on client (identical data, different variable names).
  - `Paradise.ResourceCategories` (ordered list for UI: Minerals, Gems) — replaces the ad-hoc `categories` local in `BuildResourcesMenu`.
  - `sv_resources.lua` now includes it explicitly (with `AddCSLuaFile`) and aliases `ResourceItems = Paradise.ResourceItems` for backward compatibility. Client module loader auto-includes it before `cl_resources.lua`.
- **Dead `INV_SyncResources` net removed:** `sv_inventory.lua`'s `sendFull` was sending `INV_SyncResources` with 5 hardcoded mineral values (rock, iron, copper, steel, titanium — omitting all gems). No client `net.Receive` handler existed for it — the real resource sync is `SyncResources` from `sv_resources.lua` via `net.WriteTable`. Removed the send block, removed the `resources` field from `defaultState()`, and removed `SyncResources` from `Inventory.NET` and its `AddNetworkString` call in `sh_inventory.lua`. The pouch is now exclusively owned by `sv_resources.lua`.

### Duplicate Code / Helper Extraction

- **`sv_inventory.lua` — `findPlayerBySteamID(steamid)`:** Three separate inline `for _, p in ipairs(player.GetAll())` loops (in `AdminRequestPlayerInv`, `AdminCreateItemFor`, `inv_giveitem_to`) replaced with a single local helper.
- **`sv_inventory.lua` — `makeItemInstance(s, id, def, opts)`:** `AdminCreateItem` and `AdminCreateItemFor` had nearly identical 10-line instance-construction blocks. Extracted into one local function; both handlers now call it.
- **`sv_resources.lua` — duplicate `EntityRemoved` hook removed:** Two hooks (`Resources_ForgetDropped` at line 206, `Resources_CleanDropList` at line 231) did identically the same thing (find entity in cap list, remove it). The second was a stale copy added later. Removed the second hook; the first is now registered directly: `hook.Add("EntityRemoved", "Resources_ForgetDropped", forgetResourceEntity)`.
- **`money_printer/init.lua` — `IsProtectedByModule` hoisted:** Was defined as a local function closure inside `ENT:CreateMoneybag`, creating a new function object on every money print tick. Moved to file-level local so it is created once at load time.

### Dead Code Removal

- **`sh_npc_content.lua` — Legacy dialog tree removed:** `Paradise.NPCs.Missions` (5 NPC type dialog trees) and `Paradise.NPCs.GetMissions()` were never called anywhere in the codebase — the NPC UI uses `MissionLines` (the DListView quest system), not the dialog tree. Removed ~22 lines and the unused helper. Added a TODO note for the Shop purchase server-side net handler.
- **`sv_resources.lua` — `open_resources` debug concommand removed:** Debug-only concommand that resent the player's resources table (already happens on spawn and any change). Not needed in production.
- **`sv_inventory.lua` — Incorrect auto-request after AdminCreateItemFor removed:** After giving a player an item, the handler sent `AdminRequestPlayerInv` *from server to client* — the wrong direction. `sendFull(tgt)` already updates the target's view; removed the stale round-trip.

### Code Quality

- **`paradise_npc/init.lua` — Duplicate `local sid` fixed:** `local sid = activator:SteamID()` was declared twice in `ENT:Use` (lines 65 and 73). Second declaration removed; `sid` is now declared once before the greeting cooldown block.
- **`sv_inventory.lua` — Variable name `weapons` → `result`:** In `Inventory.GetPlayerLoadoutWeapons`, the local accumulator was named `weapons`, shadowing the GMod global `weapons` table (for SWEP lookups). Renamed to `result`.
- **`cl_resources.lua` — `getResourceName` loop removed:** Replaced with direct lookup from `Paradise.ResourceDisplay[id].name` (set during module init). The old function iterated all categories on every chat message.
- **`cl_resources.lua` — `resourceChatLine` helper:** Extracted from three near-identical `chat.AddText` blocks in `ResourcesMessage` handler into one `resourceChatLine(prefix, resourceID)` function. Handles `nil` display entries gracefully.
- **`BuildResourcesMenu` (cl_resources.lua) — Uses shared categories:** Now iterates `Paradise.ResourceCategories` instead of a local `categories` table. Loop variable `i` replaced by `ipairs` index over `cat.ids`; model/icon/name all sourced from `Paradise.ResourceItems` and `Paradise.ResourceDisplay`.

### sh_leveling.lua Clarification

- Added comments explaining that `GetLevel/GetXP/GetXPNeededForNext` are shared (client reads for HUD, server reads for job gates and item requirements). The old `if SERVER then return end` guard was incorrect.

### Files Changed

| File | Change |
|------|--------|
| `gamemode/modules/resources/sh_resources.lua` | **NEW** — shared resource definitions |
| `gamemode/modules/resources/sv_resources.lua` | Use shared tables; remove duplicate loop, duplicate hook, debug cmd |
| `gamemode/modules/resources/cl_resources.lua` | Use shared tables; remove duplicate data; simplify `BuildResourcesMenu` and `ResourcesMessage` |
| `gamemode/modules/inventory/sh_inventory.lua` | Remove `SyncResources` from NET table and AddNetworkString |
| `gamemode/modules/inventory/sv_inventory.lua` | Remove dead `INV_SyncResources` send; extract helpers; fix variable shadowing; fix AdminCreateItemFor reply |
| `gamemode/modules/leveling/sh_leveling.lua` | Remove `if SERVER then return end`; add clarifying comments |
| `gamemode/modules/npcs/sh_npc_content.lua` | Remove legacy Missions table and GetMissions helper (unused) |
| `entities/entities/money_printer/init.lua` | Remove `StartSound` from Think; hoist `IsProtectedByModule` to file scope |
| `entities/entities/paradise_npc/init.lua` | Remove duplicate `local sid` declaration in `ENT:Use` |

---

## [Unreleased] — NPC Crafter (blueprint crafting, result popup, UI polish)

*Session before chat reset: Crafter NPC flow complete; craft button always visible at bottom; result popup with large model and Claim button; blueprint stays in zone until loading bar finishes.*

### Crafter NPC (modules/npcs + Inventory)

- **Crafter menu:** Use (E) on Crafter NPC opens full crafting UI: left = blueprint list (from inventory) with rarity filter ("Only show: All / Common / Rare / …"); right = drop zone, materials list, Fill button, progress bar, **Craft** button at bottom. Recipes from `Crafting.GetRecipe(blueprintId)` (sh_crafting.lua).
- **Craft button:** Always visible at **bottom** of right panel when a blueprint is in the zone (small, 24px). **Enabled** only when all materials filled; otherwise grayed out.
- **Blueprint in zone:** Drag to drop zone; client sends `Crafter_SetBlueprint` so server resets staged resources. Right-click clears; list refreshes via deferred rebuild + `Inventory_Synced` hook.
- **Craft flow:** Click Craft → progress bar 5s → server removes blueprint, gives result, sends `Crafter_CraftResult`. **Blueprint stays in zone until bar completes** (no clear on net receive) so closing menu mid-craft does not break flow. When bar completes: slot cleared, list refreshed, result popup + sound.
- **Result popup:** "Rarity Name" at top, **large weapon model** (280×240, FOV 32), "Crafted by …" at bottom, **Claim** button (no X). `showCraftResultPopup` defined before net.Receive so callback never sees nil.
- **sendFull fix:** In sv_inventory, `sendFull` was nil when called from GiveItemToPlayer/RemoveOneItemByUID (defined later). Fixed with forward declaration `local sendFull` and `sendFull = function(ply) ...`.
- **Scoreboard:** Removed gmod10_scoreboard references from comments in modules/scoreboard.

### Files touched (Crafter session)

- `gamemode/modules/npcs/cl_npcs.lua` — Crafter UI, rarity filter, Craft at bottom, result popup, Crafter_SetBlueprint, slot clear on bar complete, Inventory_Synced hook.
- `gamemode/modules/npcs/sv_crafting.lua` — Crafter_SetBlueprint, AddResources, Craft, Crafter_CraftResult.
- `gamemode/modules/npcs/sh_crafting.lua` — GetRecipe, BuildRecipes.
- `gamemode/modules/Inventory/sv_inventory.lua` — sendFull forward declaration.
- `gamemode/modules/Inventory/cl_inventory.lua` — hook.Run("Inventory_Synced") after sync.
- `gamemode/modules/scoreboard/*.lua` — Comment updates.

---

## [Unreleased] — Admin pause, UI polish, rollback & NPC prep

### Admin panel (paused for now)

- **Revive dropdown:** Single “Revive” button opens DMenu: “Revive (at body)” (rp_respawn) and “Spawn (at spawn)” (Admin_Spawn). Spawn now uses `PlayerSelectSpawn` so the target is moved to job/map spawn correctly.
- **Add to ban list dialog:** Larger frame (440×280), full labels (no cut-off), player dropdown (“Select player…” + list of online players) plus text entry for SteamID/name, “Duration (minutes) — 0 = permanent”.
- **Admin feedback:** All target-facing messages use tooltips only (`DarkRP.notify`); no FAdmin or other mod chat. Admin sees tooltips (e.g. “Kicked X”, “Moved X to spawn”). Kick/ban/demote/spawn/bring/freeze notify only the actor and target (no global announcements).
- **Rollback framework:** `ROLLBACK_FRAMEWORK.md` describes snapshot/restore (day/week/month) for money, inventory, resources, perks, level/XP, gangs. Module `rollback` with `paradise_snapshots` table and stubs `TakeSnapshot` / `RestoreSnapshot`; concommand `paradise_takesnapshot day|week|month`. Admin UI to be added when circling back.

### Messaging & branding

- **No [Paradise] / [Inventory] in chat:** Resource and inventory messages show “You dropped a X”, “Picked up a X” with item name in highlight color. No prefixes. `INV_NotifyItem` for drop/pickup; ParadiseChat shows message only.
- **Resource drop = pickupable:** New entity `paradise_resource`; dropping any resource spawns it. Use (E) adds resource to player and removes entity. No more non-pickupable prop fallback.
- **Display name “Plagued Paradise”:** `GM.Name = "Plagued Paradise"`; scoreboard and anywhere using `GAMEMODE.Name` show only that. `GM.Author = ""` so no “By FPtje Falco et al.” anywhere.
- **No DarkRP text for admins/players:** Notifications use our own text only; client console log for notify no longer prefixes `[DarkRP]`.

### Scoreboard & menus

- **FAdmin scoreboard never shown:** Hook removal uses `FolderName == "DarkRP"`. On Initialize and on ScoreboardShow/ScoreboardHide we call `FAdmin.ScoreBoard.HideScoreBoard()` so only the Paradise scoreboard is used; no stuck scoreboard on reload/lag.
- **Superadmin settings reference:** `SUPERADMIN_SETTINGS_REFERENCE.md` lists ConVars and `GM.Config` keys for a future Settings tab.

### Death system & locations

- **Death system Think spam removed:** No more “[Death System] Think hook: Not in ghost mode” (or use key debug) for regular users.
- **Paradise locations:** `paradise_locations` module defines `Paradise.DeathOrbLocations` and `Paradise.NPCSpawnLocations`. Death system uses DeathOrbLocations for random orb spawns when non-empty; fallback remains hardcoded coords.

### NPC system (started)

- **Base NPC:** Entity `paradise_npc` stands still; Use (E) opens interaction menu. Module `npcs` adds net and client menu (Dialog / Shop placeholder / Bye). Prep for quests, shops, reputation, robbing later.

### Files touched (recent)

- `gamemode/modules/admin/cl_admin.lua` — Revive dropdown, Add to ban dialog layout.
- `gamemode/modules/admin/sv_admin.lua` — Spawn via PlayerSelectSpawn, tooltips only, no ChatPrint.
- `gamemode/modules/resources/` — paradise_resource entity, SendResourcesMessagePickedUp, drop uses entity.
- `gamemode/modules/Inventory/` — NotifyItem, no [Paradise]/[Inventory].
- `gamemode/modules/hud/cl_hud.lua` — Notify console text no prefix.
- `gamemode/modules/scoreboard/` — FAdmin hide, name only; `init.lua`/`cl_init.lua` — Author "".
- `gamemode/modules/deathsystem/cl_deathsystem.lua` — Think debug removed.
- `gamemode/modules/deathsystem/sv_deathsystem.lua` — DeathOrbLocations used when set.
- `gamemode/modules/paradise_locations/` — New. `gamemode/modules/rollback/` — New. `gamemode/modules/npcs/` — New. `entities/entities/paradise_npc/` — New.

---

## [Unreleased] — Admin, chat, ban list, logs (session summary)

### Chat & notifications

- **Unified chat style:** One consistent look across modules. Gray base text, colored accents where needed, `[Paradise]` prefix for system messages.
- **Item give messages (admin-only):** When an admin gives items (inventory or resources), only admins see “Gave X to Y”; the target sees “Admin X gave you …”. Implemented via net `INV_ParadiseChat`; server sends only to admins and target.
- **Resources chat:** Resource messages (mined, dropped) use gray text and **colored resource name with no parentheses** (e.g. “Dropped 1 Diamond” with “Diamond” in color). Same style in `cl_resources.lua` for all `ResourcesMessage` types.
- **(DEAD) in chat:** When a dead player types in chat or OOC, their name is followed by **“(DEAD)” in red** (only that part). Implemented in `modules/chat/cl_chat.lua` in the `DarkRP_Chat` receive handler.

### Admin panel (Players tab)

- **Button behaviour:** Buttons (Kick, Ban, Mute, Gag, etc.) now work when a player is **left-click selected** in the list. They use `getSelectedPlayer()` which reads from `userList:GetSelectedLine()` instead of relying only on `OnRowSelected` state.
- **OnRowSelected / OnRowRightClick:** Fixed to use the two-argument GMod signature `(lineID, line)` and to validate `line` before use.
- **Layout:** Four rows of three buttons each; smaller buttons (68×24) so they don’t overflow the right panel. Rows: (Kick, Ban, Mute, Gag); (Goto, Bring, Freeze); (Demote, Spawn, Respawn); (Spectate, Give Item).
- **Demote:** Demote is **job** demote only (set target to default/Citizen via `changeTeam(GAMEMODE.DefaultTeam, true)`). Rank changes are reserved for the future Settings tab (ranks, gangs, levels, server limits).
- **Mute vs Gag:** Mute = **voice** (FAdmin Voicemute); Gag = **chat** (FAdmin chatmute). Labels and right-click menu updated accordingly.
- **Goto, Bring, Freeze:** New actions and buttons. Goto = admin teleports to target; Bring = target teleports to admin; Freeze = toggle movement freeze via `Paradise.Frozen[ply]` and `SetupMove` hook. Also available as chat commands and console commands.

### Admin panel (Ban List tab)

- **Refresh:** Loads and displays lines from `cfg/banned_user.cfg` (or `banned_user.cfg`).
- **Add ban:** “Add ban” button (Super Admin only) opens a dialog: SteamID or player name, reason, duration (minutes; 0 = permanent). Player must be online; server runs `banid`/`writeid` and kicks. Note: list/reasons/time can be exported for website via that cfg.

### Admin panel (Logs tab)

- **Paradise admin log:** Server keeps an in-memory ring buffer (`Paradise.AdminLog`, e.g. last 500 entries). Categories: `kill`, `item`, `misc`.
- **Kill logging:** `PlayerDeath` hook logs victim, killer, weapon, and position (x, y, z).
- **Item logging:** When an admin gives an item (inventory), `Paradise.AdminLogEntry("item", ...)` is called.
- **UI:** Refresh and category filter (All / kill / item / misc); list shows time, category, message.

### Chat commands & admin chat

- **/commands:** Lists Paradise-related commands. Admins see admin commands (e.g. /goto, /bring, /freeze, /spawn, /respawn, /a); everyone sees /a and /commands.
- **/a &lt;msg&gt;:** For **admins:** sends to all admins as `[A] Name: msg`. For **non-admins:** sends to all admins as `[Assistance] Name (SteamID): msg` and confirms to the sender that the request was sent.

### Server admin (sv_admin.lua)

- **Kick/Ban:** Net handlers now accept **reason** (and for Ban **duration** in minutes; 0 = permanent). Client opens dialogs for these parameters.
- **Demote:** Net handler performs **job** demote only; allowed for admin and superadmin.
- **Goto/Bring/Freeze:** Implemented as privileged chat commands and console commands (`paradise_goto`, `paradise_bring`, `paradise_freeze`).
- **Freeze:** `Paradise.Frozen[ply]` and `SetupMove` hook to block movement.

### Bug fix

- **Admin panel button error:** Fixed `attempt to index global 'self' (a nil value)` in `cl_admin.lua` button `DoClick` by using the button variable `b` in the closure instead of `self`.

### Files touched (this session)

- `gamemode/modules/admin/cl_admin.lua` — Panel layout, getSelectedPlayer, Goto/Bring/Freeze, Demote label, Mute/Gag swap, Ban List “Add ban” dialog, OnRowSelected/OnRowRightClick.
- `gamemode/modules/admin/sv_admin.lua` — Kick/Ban reason+duration, Demote job, Goto/Bring/Freeze, freeze state, /commands, /a, Admin_AddBan, Ban list and Logs nets.
- `gamemode/modules/chat/cl_chat.lua` — (DEAD) in red when sender is dead.
- `gamemode/modules/Inventory/sh_inventory.lua` — `ParadiseChat` net name.
- `gamemode/modules/Inventory/sv_inventory.lua` — Admin give uses `ParadiseChat` (admin-only/target), `Paradise.AdminLogEntry` for item gives.
- `gamemode/modules/Inventory/cl_inventory.lua` — `ParadiseChat` receive (unified style).
- `gamemode/modules/resources/cl_resources.lua` — ResourcesMessage: gray + colored resource name, no parentheses, `[Paradise]` prefix.
- `gamemode/modules/resources/sv_resources.lua` — Admin resource give uses `INV_ParadiseChat`, admin-only/target.

---

## How to use this changelog

- **Resuming work:** Read **PARADISE_STRUCTURE.md** first, then **PARADISE_PLAN.md** for the next phase/task. Use this changelog to see what’s already done.
- **Adding entries:** Keep a short “what + where” style; one section per logical release or session. List key files at the end of the section if helpful.
