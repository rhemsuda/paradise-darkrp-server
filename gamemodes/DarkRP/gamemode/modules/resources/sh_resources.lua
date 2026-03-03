--[[---------------------------------------------------------------------------
  Paradise Resources — Shared definitions.
  Loaded by the module loader before cl_resources.lua (client) and explicitly
  included at the top of sv_resources.lua (server) so it is available early.
  Both sides use Paradise.ResourceItems, Paradise.ResourceAppearances, and
  Paradise.ResourceCategories instead of duplicating the data.
---------------------------------------------------------------------------]]
if Paradise and Paradise.ResourceItems then return end  -- guard against double-include

Paradise = Paradise or {}

-- Flat lookup: resource_id -> { name, model }
-- Used for validation, notification text, and world entity model.
Paradise.ResourceItems = {
    rock     = { name = "Rock",     model = "models/props_junk/rock001a.mdl" },
    copper   = { name = "Copper",   model = "models/props_junk/rock001a.mdl" },
    iron     = { name = "Iron",     model = "models/props_junk/rock001a.mdl" },
    steel    = { name = "Steel",    model = "models/props_junk/rock001a.mdl" },
    titanium = { name = "Titanium", model = "models/props_junk/rock001a.mdl" },
    emerald  = { name = "Emerald",  model = "models/props_junk/rock001a.mdl" },
    ruby     = { name = "Ruby",     model = "models/props_junk/rock001a.mdl" },
    sapphire = { name = "Sapphire", model = "models/props_junk/rock001a.mdl" },
    obsidian = { name = "Obsidian", model = "models/props_junk/rock001a.mdl" },
    diamond  = { name = "Diamond",  model = "models/props_junk/rock001a.mdl" },
}

-- Per-resource appearance: material overlay + tint color.
-- Used when spawning paradise_resource world entities and for UI icons.
Paradise.ResourceAppearances = {
    rock     = { material = "",             color = nil },
    copper   = { material = "models/shiny", color = Color(184, 115,  51, 255) },
    iron     = { material = "models/shiny", color = Color(169, 169, 169, 255) },
    steel    = { material = "models/shiny", color = Color(192, 192, 192, 255) },
    titanium = { material = "models/shiny", color = Color( 46, 139,  87, 255) },
    emerald  = { material = "models/shiny", color = Color(  0, 255, 127, 200) },
    ruby     = { material = "models/shiny", color = Color(255,  36,   0, 200) },
    sapphire = { material = "models/shiny", color = Color(  0, 191, 255, 200) },
    obsidian = { material = "models/shiny", color = Color( 28,  28,  35, 230) },
    -- Diamond: somewhat see-through (cloudy) but still clearly visible on the ground
    diamond  = { material = "models/shiny", color = Color(240, 248, 255, 175) },
}

-- Ordered UI categories for the resources panel (BuildResourcesMenu).
Paradise.ResourceCategories = {
    { name = "Minerals", ids = { "rock", "copper", "iron", "steel", "titanium" } },
    { name = "Gems",     ids = { "emerald", "ruby", "sapphire", "obsidian", "diamond" } },
}
