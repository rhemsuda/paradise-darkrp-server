# Paradise DarkRP — Roadmap

This doc is the **plan** for the gamemode: module cleanup, then **Level System**, **NPC System**, and **Quest Lines** that reward guns/SWEPs. We extend DarkRP only through **modules** (and optional `darkrp_modules` addon) to avoid touching core files.

---

## 1. Module overview (current state)

All live modules live under `gamemode/modules/`. Load order: **shared** (`sh_*.lua`) → **server** (`sv_*.lua`) → **client** (`cl_*.lua`). Single-file module: `chatsounds.lua` (server-only). Optional addon modules load from `darkrp_modules/` after DarkRP finishes (see `libraries/modificationloader.lua`).

| Module | Purpose |
|--------|--------|
| **afk** | AFK state, demotion, `/afk` (disabled in default) |
| **animations** | Player gestures (bow, wave, dance, etc.) |
| **base** | Core DarkRP API, DB (sv_data), player/entity helpers |
| **chat** | Chat command registration |
| **chatsounds** | Voice sounds when certain words typed (TODO: female/CP sounds) |
| **cppi** | CPPI prop-protection stub |
| **doorsystem** | Door/vehicle keys, ownership |
| **events** | Meteor storm (disabled by default) |
| **f4menu** | F4 menu UI, job tab |
| **fadmin** | In-game admin (FAdmin) |
| **fpp** | Falco's Prop Protection |
| **fspectate** | Free spectate + CAMI |
| **hitmenu** | Hitman job, hit requests (disabled by default) |
| **hobo** | Hobo job, bugbait sounds |
| **deathpov** | Death camera POV (follow ragdoll head); `GM.Config.deathpov` (default false) |
| **hud** | HUD: health, job, wallet, agenda, death notice, admin tell (disabled by default) |
| **hungermod** | Hunger, food (disabled by default) |
| **Inventory** | Custom inventory, loadout, items/SWEPs, persistence (**still in progress** — see §2b) |
| **jobs** | Job/team system |
| **language** | Phrases, language |
| **leveling** | **Currently commented out** — XP/level DB + hooks (see below) |
| **logging** | Admin/event logging |
| **medic** | Medic job interface |
| **money** | Wallet, pay/drop, money bags |
| **playerscale** | Per-job model scale |
| **police** | Arrest, warrant, jail, mayor/CP |
| **positions** | Spawn/jail positions |
| **sleep** | Sleep/wake (disabled by default) |
| **tipjar** | Tip jar entity |
| **voting** | Votes, questions (e.g. warrants) |
| **workarounds** | Compatibility, antimultirun |

**Disabled by default** (in `modificationloader.lua`): afk, hungermod, events, hitmenu, hud, sleep. Enable by setting the corresponding entry to `false` in your `darkrp_config/disabled_defaults.lua` if you use the addon.

---

## 2. Cleanup (done / to do)

### Done
- **Inventory** `sh_init.lua`: Optional include of `darkrp_modules/rp_props/sh_items.lua` so the gamemode runs even when that addon is not present (e.g. after removing darkrpmodification files).

### To do (quick wins)
- **Leveling**: Restore and wire up (see Section 3). Right now the whole of `sv_leveling.lua` is commented out.
- **chatsounds**: TODO in file (female sounds, CP sounds) — leave as-is until you want to extend it.
- **Config**: If you use `darkrp_config/disabled_defaults.lua`, ensure it overrides only what you need; the loader already merges it.

---

## 2a. Module review: Inventory, Death system, Perk system

**Inventory**  
- **State:** Clean and ready to use for current features. Optional `darkrp_modules/rp_props` is guarded; legacy `PREV-shitems.lua` is optional. No stray TODOs; debug is behind `inv_svdebug` (server) and `inv_debug` (client).
- **Dependencies:** `BuildResourcesMenu` and `BuildPropsPanel` come from `darkrp_modules/rp_props` when present; spawnmenu and main inventory UI use `pcall`/`isfunction` so missing addon does not error.
- **Still in progress:** See §2b (completing the Inventory module) for the roadmap of remaining work.

**Death system**  
- **In gamemode:** Death behaviour lives in **base** (`DoPlayerDeath`, `PlayerDeath`, death fee, drop weapon, respawn/jail) and **deathpov** (client: death camera following ragdoll head; off by default via `GM.Config.deathpov`).
- **No standalone “Death system” module** in the gamemode. The old **darkrpmodification** addon had a DeathSystem (custom respawn/death screen, etc.); that was addon-only (see `CLEANUP_NOTES.md`). If you want custom death flow (e.g. death screen, respawn timer, penalties), add a new module or restore that addon logic into a gamemode module.
- **Verdict:** Current death-related code is consistent; deathpov is optional and clean.

**Perk system**  
- **Not in gamemode.** The addon had **rp_perks** (client + server + shared); it is not present under `gamemode/modules/`.
- **Verdict:** To have perks, either create a new **perks** module (define perks, server validation, client UI) or restore/port from the addon. No cleanup needed until you add it.

---

## 2b. Completing the Inventory module (in progress)

The Inventory module is large; the following keeps it “ready to go” for what’s there and sets the plan for the rest.

**Done and stable**
- Shared core: `sh_inventory.lua`, `sh_items.lua` (rarity, slots, net names, item defs).
- Server: persistence (SQLite/file), load/save on spawn/disconnect, move/equip/use/drop, damage scaling, admin nets, `inv_giveitem` concommand, optional rp_props include.
- Client: main inventory UI (`cl_inventory.lua`), loadout window (`cl_inventory_loadout.lua`), spawnmenu tab (“Inventory & Resources”) with guarded Resources/Props panels (`cl_inventory_spawnmenu.lua`).
- Death: equipped weapons cleared on death; loadout slots cleared as per current design.

**Still in progress / roadmap**
- **Resources tab:** Fully works only when `darkrp_modules/rp_props` (or equivalent) provides `resourceTemplates` and `BuildResourcesMenu`. Completing = either ship a minimal in-gamemode resources definition or document/addon expectation.
- **Props tab:** Same: depends on `BuildPropsPanel` from addon. Optional in-gamemode fallback or doc.
- **Crafting:** Not implemented; can be added as server + client logic and item definitions (e.g. recipes in shared, server grants items on craft).
- **Durability / item state:** Not implemented; extend item instances and UI if desired.
- **More item actions:** “Use” is implemented for medkit and similar; extend in `ItemAction` net handler and `sh_items` as needed.
- **New HUD:** When you add a new HUD (§2c), consider a small “inventory summary” (e.g. item count or key bind) so the Inventory module stays visible in play.

---

## 2c. New HUD (gameplan)

**Current HUD** (module **hud**, disabled by default in `modificationloader.lua`): health, job, wallet, agenda, gun license icon, voice chat, lockdown, arrested text, admin tell, death notice, and player info above heads. Configurable via ConVars (e.g. `HudW`, `HudH`, color convars).

**New HUD — add to gameplan**
- **Goal:** A refreshed, readable HUD that fits Paradise and can show level/XP, inventory hint, and other future systems (perks, quests) without cluttering the screen.
- **Suggested approach (module-friendly):**
  1. Either **extend** the existing `hud` module (new elements, optional ConVars to toggle them) or **add a new module** (e.g. `hud_paradise` or `hud_new`) that draws over/alongside the default. Keeping it in a module avoids touching base.
  2. **Elements to consider:** Health/armor (keep or restyle), job/money (compact or repositioned), **level/XP bar** (once leveling is live), **inventory key hint** (e.g. “Press X for Inventory”), optional **quest reminder** or **perk icons** later.
  3. **Style:** Match the Inventory UI (e.g. ParadiseUI theme if used) for consistency; keep HUDShouldDraw hooks so other addons can hide elements.
  4. **Order:** Implement after leveling has NWInts for level/XP so the new HUD can display them; can start with a stub that only shows health/job/money, then add level bar.

---

## 3. Level system — path to completion

**Current state:** `gamemode/modules/leveling/sv_leveling.lua` exists but is **fully commented out**. It expects:
- `darkrp_player.experience` — **not** in base schema (base only has `uid`, `rpname`, `salary`, `wallet`).
- Table `darkrp_levelinfo(level, experienceRequired)` — not created anywhere.

**Steps:**

1. **DB migration (module-friendly)**  
   Add a migration that runs after DarkRP DB init (e.g. in leveling, hook `DarkRPDBInitialized` or use a DB version bump in base if you prefer):
   - Add column `experience BIGINT NOT NULL DEFAULT 0` to `darkrp_player` (ALTER or new table + copy, same pattern as in `sv_data.lua`).
   - Create `darkrp_levelinfo(level INT PRIMARY KEY, experienceRequired BIGINT)` and seed rows for levels 1–50 (reuse the curve from the commented block).

2. **Uncomment and fix `sv_leveling.lua`**  
   - Use **SteamID64** (and optionally keep UniqueID for compatibility) when reading/writing `darkrp_player`, to match base (see `DarkRP.storeMoney` / `createPlayerData`).
   - Keep: load/save XP on spawn, AddXP helper, level-up detection, `PlayerDeath` XP-on-kill, `check_xp` and `give_xp` (superadmin) commands.
   - Reduce or gate debug `print`s behind a convar (e.g. `leveling_debug`).

3. **Shared API**  
   Add `sh_leveling.lua` (or `sh_interface.lua`): e.g. `Leveling.GetLevel(ply)`, `Leveling.GetXP(ply)` (or expose via NWInt and document). Lets other modules (e.g. quests, NPCs) check level without touching server impl.

4. **Client / HUD**  
   Add `cl_leveling.lua`: read `Level`/`Experience`/`NextLevel`/`NextLevelXP` from NWInts (set in sv_leveling). Draw simple level/XP bar or text on HUD (and optionally in F4 or scoreboard).

5. **Optional**  
   - XP sources: jobs (salary tick), arrests, crafting (if you add it), quest completion (Section 5).  
   - Level gates: job unlocks, quest availability, or NPC dialogue (e.g. “Come back at level 5”).

---

## 4. NPC system — path to creation

**Goal:** Placeable NPCs that players can talk to and that drive quest lines.

**Suggested structure (all in a new module, e.g. `gamemode/modules/npcs`):**

1. **Entity**  
   - New entity class (e.g. `sent_paradise_npc` or `darkrp_quest_npc`) in the module or in an entities addon.
   - Model, idle anim, optional name/title above head.
   - On Use (E): open dialogue/conversation (see below). Optionally require line-of-sight or distance.

2. **Dialogue / conversation**  
   - **Shared:** Define “conversation” as a list of lines (NPC text + optional player replies). Each reply can link to another line or to an “action” (e.g. start quest, complete objective, open shop).
   - **Server:** Track which NPC instance is which (e.g. NPC type + spawn id or net var). Validate actions (quest start/complete, give item) server-side.
   - **Client:** Menu or Derma panel showing current line and reply buttons; send chosen reply to server.

3. **Persistence (optional)**  
   - If NPCs are map-placed, no DB needed. If you want movable/spawned NPCs, store type + position in DB (similar to positions module) and spawn on map load.

4. **Integration**  
   - **Leveling:** Optional “minimum level” per NPC or per dialogue branch; check `Leveling.GetLevel(ply)` before opening dialogue.  
   - **Quests:** NPCs reference quest IDs; “Start quest” / “Turn in” actions call into the quest module (Section 5).

---

## 5. Quest lines — path to creation

**Goal:** Quest lines tied to NPCs; completion rewards include **guns / SWEPs** (and optionally money or items). Inventory already has `inv_giveitem` and server-side “give item to player” logic; quests will call the same pattern.

**Suggested structure (new module, e.g. `gamemode/modules/quests`):**

1. **Definitions (shared)**  
   - **Quest:** id, name, description, objectives (e.g. “Kill 3 zombies”, “Talk to NPC X”), optional level requirement, reward table (item IDs, weapon classes, money).  
   - **Quest line:** ordered list of quest IDs; completing one unlocks the next (e.g. “Paradise Intro” → “First Gun” → “Better Gear”).

2. **Server**  
   - Track active quest per player (current quest id, progress: e.g. kills, “talked to X”).  
   - Hooks: e.g. `PlayerDeath` (count kills for “kill X” objectives), custom “NPC turned in” from NPC module.  
   - On objective complete: update progress; on all objectives complete: mark quest complete, **grant rewards** (call into Inventory to add item by id, and/or `ply:Give(weapon_class)` and optionally strip if you want guns only via inventory).  
   - Unlock next quest in line.

3. **Rewards → guns/SWEPs**  
   - **Inventory path:** Use existing `Inventory.Items[id]` and server logic that adds an item instance to `PlayerInv` (same as `inv_giveitem` / AdminCreateItem). For SWEPs, item `class` is the weapon class; equipping gives the weapon. So “quest reward” = server adds one or more item IDs to the player’s inventory (optionally with fixed rarity).  
   - **Alternative:** Direct `ply:Give("weapon_xyz")` for one-off rewards; then optionally sync to loadout/inventory if you want them to persist in your system.

4. **Client**  
   - Quest log UI: current quest, objectives, progress. Optional: “Quest complete” notification and reward list.  
   - Optional: show “!” above NPCs who can start or turn in a quest.

5. **NPC ↔ Quest link**  
   - In NPC dialogue, “Start quest” sends quest id to server; server checks level/eligibility and sets active quest.  
   - “Turn in” from NPC: server checks objectives and player’s current quest; if complete, grant rewards and advance line.

---

## 6. Suggested order of work

1. **Cleanup**  
   - Inventory optional `rp_props` (done).  
   - Module review: Inventory, Death, Perks (done; see §2a).  
   - Restore leveling: migration + uncomment + shared API + client HUD.

2. **Level system**  
   - Finish steps in Section 3 so XP/level are visible and usable by other systems.

3. **New HUD**  
   - Implement or extend HUD (see §2c): health/job/money, then level/XP bar once leveling is live; optional inventory hint.  
   - Can be done in parallel with or after leveling.

4. **Completing Inventory**  
   - Pick items from §2b as needed: resources/props fallback or doc, crafting, durability, more item actions.  
   - Ongoing; can overlap with quest work (rewards use existing Inventory).

5. **NPC system**  
   - Entity + dialogue/conversation + Use key; no quest logic yet.  
   - Optional: level check at dialogue open.

6. **Quest system**  
   - Definitions, server progress, rewards via Inventory (guns/SWEPs).  
   - Then: NPC “Start quest” / “Turn in” actions.

7. **Optional: Death system / Perk system**  
   - **Death:** Add a module for custom death screen or respawn flow if desired (base + deathpov already cover basics).  
   - **Perks:** Add a **perks** module (or port from addon) when you want perk progression; can hook into leveling and HUD later.

8. **Content**  
   - Add quest lines and NPCs; balance XP and rewards.

---

## 7. Files to add (summary)

| What | Files (suggested) |
|------|--------------------|
| Leveling | Migration (in leveling or base), uncomment `sv_leveling.lua`, add `sh_leveling.lua`, `cl_leveling.lua` |
| New HUD | Extend `modules/hud/` or add e.g. `modules/hud_paradise/cl_hud.lua` (and optional sh_ for config) |
| Inventory (completion) | As needed: e.g. `sh_crafting.lua`, server craft handler, or in-gamemode resources/props fallbacks |
| NPCs | `modules/npcs/sh_npc.lua`, `sv_npc.lua`, `cl_npc.lua`; entity (or in addon) |
| Quests | `modules/quests/sh_quests.lua`, `sv_quests.lua`, `cl_quests.lua` |
| Perks (optional) | `modules/perks/sh_perks.lua`, `sv_perks.lua`, `cl_perks.lua` (or port from addon rp_perks) |
| Death system (optional) | New module e.g. `modules/deathscreen/` if you want custom death flow |

Keep all new logic in **modules** so DarkRP core stays untouched and you can disable or replace modules easily. After each step, test in-game and then move to the next.
