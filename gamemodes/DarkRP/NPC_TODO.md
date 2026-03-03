# NPC System — Todo List

Pulled from **PARADISE_PLAN.md** Phase 4 and **ROADMAP.md** §4. NPCs drive RP content, questlines, and crafting.

---

## NPC list (from plan)

| NPC | Role | Notes |
|-----|------|------|
| **Banker** | Bank, rare materials | |
| **Crafter** | Crafting recipes / station | |
| **Medic** | Healing, med supplies | |
| **Gang member** | Gang-related dialog / jobs | |
| **Police** | Law, warrants, maybe licenses | |
| **Drug Dealer** | Contraband, 2–4 slots (job link) | |
| **Dojo** | Combat / training | |
| **Miner** | Mining, shovel/pickaxe, resources | |
| **Car Dealer** | Vehicles, keys | |
| **Mechanic** | Salvage, recovery | |

---

## Todo list (order)

1. **NPC foundation** — Entity that stands still with idle pose; Use (E) opens menu. *Done.*
2. **Crafter UI & flow** — Blueprint list (from inventory), rarity filter, drop zone, materials + Fill, Craft button at bottom (always visible when blueprint set, enabled when can craft), progress bar, result popup (large model, Claim). Blueprint stays in zone until bar completes; staged resources reset when blueprint changes (Crafter_SetBlueprint). *Done.*
3. **Spawn from locations** — `Paradise.NPCSpawnLocations` loaded from file; admin Settings → "NPC spawns" opens DListView to add/remove positions (saved to `data/paradise_npc_spawns.txt`).
4. **Menu per NPC** — Two tabs: **Missions** (dialog/quest lines from file), **Shop** (items per type from file). Content in `sh_npc_content.lua` so admins cannot change it in-game.
   - **Quests** — Start / turn in when quest system exists.
   - **Reputation** — Display (and later affect prices/quests).
5. **Robbing** — Option to rob NPC at some point (later).
6. **Per-NPC types** — Add missions/shop entries in `sh_npc_content.lua` for each of the 10 NPCs.

---

---

## Phased plan: mission lines + map locations (release)

Work order: **Crafter first**, then the rest. For each NPC: (1) define/refine mission lines in `sh_npc_content.lua`, (2) set spawn positions on the release map via admin NPC spawn editor (or default spawn file).

| Phase | NPC | Mission lines | Map locations |
|-------|-----|----------------|----------------|
| **1** | **Crafter** | Refine/expand in `sh_npc_content.lua` (already has 3). | Set spawn(s) on release map. |
| **2** | **Banker** | Already has "Open an Account"; add 1–2 more if desired. | Set spawn(s) on release map. |
| **3** | **Medic** | Already has "First Aid Run"; add 1–2 more. | Set spawn(s) on release map. |
| **4** | **Miner** | Already has "Ore Sample"; add 1–2 more. | Set spawn(s) on release map. |
| **5** | **Police** | Add mission line(s) (e.g. "Report for duty", "Warrant check"). | Set spawn(s) on release map. |
| **6** | **Merchant** | Add mission line(s) + shop entries if needed. | Set spawn(s) on release map. |
| **7** | **Mechanic** | Add mission line(s) (salvage/recovery). | Set spawn(s) on release map. |
| **8** | **Black Market** | Add mission line(s); shop if applicable. | Set spawn(s) on release map. |
| **9** | **Drug Dealer** | Add mission line(s); shop if applicable. | Set spawn(s) on release map. |
| **10** | **Gang** | Add mission line(s). | Set spawn(s) on release map. |
| **11** | **Dojo** | Add mission line(s) (combat/training). | Set spawn(s) on release map. |
| **12** | **Car Dealer** | Add mission line(s) + shop/vehicle list. | Set spawn(s) on release map. |
| **13** | **Generic / Cook** | Optional: generic missions or cook-specific. | Set spawn(s) if used. |

*Map locations:* Use in-game **Settings → NPC spawns** to add positions (saved to `data/paradise_npc_spawns.txt`). For release, run once on the target map and save, or ship a default spawn file per map.

---

## Technical notes

- **Crafter nets:** `Crafter_Open`, `Crafter_Close`, `Crafter_SetBlueprint` (client sends when blueprint set/cleared; server resets staged resources), `Crafter_AddResources`, `Crafter_Craft`, `Crafter_StagedUpdate`, `Crafter_CraftResult`. Client: `Paradise.CrafterStaged` updated by StagedUpdate; `Inventory_Synced` hook refreshes blueprint list when open.
- **Entity:** `paradise_npc` in `entities/entities/paradise_npc/`. Standing idle sequence (not T-pose); `MOVETYPE_NONE`, `SOLID_BBOX`, collision bounds for feet on ground. Use → server sends net → client opens menu.
- **Module:** `gamemode/modules/npcs/` — shared types + **sh_npc_content.lua** (missions/shops per type), server nets + file persist, client menu (Missions / Shop tabs) and **OpenNPCSpawnEditor()** for Settings.
- **Quests:** Will be coded so repeatables unlock certain things; NPC "Start quest" / "Turn in" will hook into quest module when it exists.
- **Reputation:** Data structure and UI placeholder so we can gate content by reputation later.
