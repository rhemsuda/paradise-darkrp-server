--[[---------------------------------------------------------------------------
  Paradise locations — NPC spawns and Death Orb spawns.
  Admin Settings tab will allow adding/editing/removing positions.
  Used by: death system (light spheres/orbs), future NPC spawner.
---------------------------------------------------------------------------]]
Paradise = Paradise or {}

-- Death Orb spawn positions. Format: { pos = Vector(...), ang = Angle(...) } or just Vector(...).
-- When non-empty, the death system spawns random orbs at these locations instead of fallback coords.
Paradise.DeathOrbLocations = Paradise.DeathOrbLocations or {}

-- NPC spawn positions. Format: { pos = Vector(...), ang = Angle(...), npc_type = "npc_xxx" (optional) }.
-- Future: NPC system will spawn NPCs at these locations on map load or when enabled.
Paradise.NPCSpawnLocations = Paradise.NPCSpawnLocations or {}
