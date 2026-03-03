# Paradise RP — Feature Plan & Todo List

Ordered by dependency and efficiency. Do phases in order; within a phase you can pick tasks in any order unless noted.

---

## Phase 1 — Foundation (do first)

These unblock almost everything else.

| Done | Task |
|------|------|
| ☐ | **Levels** — Expand leveling: printers/entities give XP, level requirements for jobs and gear. (Leveling module exists; wire up and extend.) |
| ☐ | **Admin menu/system** — Complete admin tools so you can manage content and test safely. |
| ☐ | **Trading** — Replace drop/switch with a trade system; ensure **weapons don’t drop on death**. |
| ☐ | **Door system** — Raid system, building takeover, keys once the map is set. |
| ☐ | **Armor** — Armor system so jobs/items can grant and display armor. |

---

## Phase 2 — Economy & Items

| Done | Task |
|------|------|
| ☐ | **Printers** — 5 styles of printers; level-gated; tie into leveling. |
| ☐ | **POC (printers)** — Cleanup of unowned printers; internal printer money; overtaking printers. |
| ☐ | **Coolers** — New entity/item. |
| ☐ | **Swag Bags** — Contraband holder for after raids. |
| ☐ | **Job level requirements** — Higher-tier jobs/gear/tools require minimum level. |
| ☐ | **Items: Knife (low level) / Crowbar (high level)** — Prop destroyer tier. |
| ☐ | **Enhanced crowbar** — Questline reward (prop destroyer). |
| ☐ | **Utility items** — Define and hook into inventory/use. |

---

## Phase 3 — Map & Movement

| Done | Task |
|------|------|
| ☐ | **Teleporters** — Large map endpoints (so vehicles aren’t the only option). |
| ☐ | **Cars** — Keys that spawn temp/perm cars; Evocity-style if big map (e.g. Noobonic-like). |

---

## Phase 4 — NPCs (batch by role)

Implement NPCs in batches; each can use Banker/Crafter/Medic etc. once the NPC system exists (see ROADMAP.md §4). See **NPC_TODO.md** for task list. Admin menu paused; NPC system started.

| Done | Task |
|------|------|
| ☐ | **NPC system** — Dialogue, Use key, optional level check (foundation for all below). |
| ☐ | Banker |
| ☐ | Crafter |
| ☐ | Medic |
| ☐ | Gang member |
| ☐ | Police |
| ☐ | Drug Dealer |
| ☐ | Dojo (combat) |
| ☐ | Miner |
| ☐ | Car Dealer |
| ☐ | Mechanic (salvage/recovery) |

---

## Phase 5 — Jobs

| Done | Task |
|------|------|
| ☐ | **Hunger mod** — Enable/tune so Cook matters and people stay out (not just base sitting). |
| ☐ | **Paramedic** — Defib. |
| ☐ | **Miner** — Shovel/pickaxe; demotable. |
| ☐ | **Banker** — Rare random material (e.g. “banker’s diamonds”); demotable if not banking. |
| ☐ | **Drug Dealer** — 2–4 slots; demotable as needed. |
| ☐ | **Cook** — 2 slots, demotable; tie to hunger. |

---

## Phase 6 — Combat & Police

| Done | Task |
|------|------|
| ☐ | **Taser for cops** — Scanner/taser (you had taser removed from loadout; add back as intended scanner/taser behavior). |

---

## Phase 7 — Quests & Missions

| Done | Task |
|------|------|
| ☐ | **Quest system** — Missions for blueprints/unlockables; NPC start/turn-in (see ROADMAP.md §5). |
| ☐ | **Quest lines** — Blueprints, unlockables, enhanced crowbar, etc. |
| ☐ | **Bank robbery mission** — Noobonic-style. |

---

## Phase 8 — Progression & Content

| Done | Task |
|------|------|
| ☐ | **Perks** — Tune and add tree (rp_perks or new perks module). |
| ☐ | **Drug growing / farming** — Mechanics and integration. |
| ☐ | **Parties / equipment viewing** — Party system and viewing others’ gear. |

---

## Phase 9 — Events

Boostable by job sizes etc.

| Done | Task |
|------|------|
| ☐ | Zombies |
| ☐ | Ant Lion (Noobonic-style) |
| ☐ | Mining meteors (big rocks) |
| ☐ | Job bonuses |
| ☐ | Extra printers (event) |

---

## Phase 10 — Monetization & Polish

| Done | Task |
|------|------|
| ☐ | **Donator perks / store** — Donator-only perks and optional store. |

---

## Quick reference — your list grouped

- **Working on** — Crafter NPC done for now. Next: other NPC types or refine Crafter mission lines (see NPC_TODO.md).
- **Trading** → Phase 1  
- **Items** (knife/crowbar/enhanced crowbar) → Phase 2  
- **Levels** (printers, entities, job requirements) → Phase 1 + 2  
- **5 printers, coolers, swag bags** → Phase 2  
- **Teleporters** → Phase 3  
- **POC** → Phase 2  
- **Admin** → Phase 1  
- **NPCs** (all 10) → Phase 4  
- **Quest lines** → Phase 7  
- **Perks** → Phase 8  
- **Drug farming** → Phase 8  
- **Parties/equipment view** → Phase 8  
- **Jobs** (Param, Miner, Banker, Drug Dealer, Cook) → Phase 5  
- **Cars** → Phase 3  
- **Bank robbery** → Phase 7  
- **Taser cops** → Phase 6  
- **Door/raid** → Phase 1  
- **Armor** → Phase 1  
- **Utility items** → Phase 2  
- **Events** → Phase 9  
- **Donator/store** → Phase 10  

Use this as the master todo: work Phase 1 first, then 2, and so on. Tick boxes when done (replace `☐` with `☑` or add a “Done” column if you prefer).
