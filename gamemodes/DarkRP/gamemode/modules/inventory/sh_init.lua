-- DarkRP Inventory – Module Loader (shared)
-- Optional rp_props: prefer gamemode module (gamemode/modules/rp_props/), then addon (darkrp_modules/rp_props/).
local function rp_props_sh_items_path()
  local GM = GAMEMODE or GM
  if GM and GM.FolderName then
    local p = GM.FolderName .. "/gamemode/modules/rp_props/sh_items.lua"
    if file.Exists(p, "LUA") then return p end
  end
  if file.Exists("darkrp_modules/rp_props/sh_items.lua", "LUA") then
    return "darkrp_modules/rp_props/sh_items.lua"
  end
  return nil
end

if SERVER then
  AddCSLuaFile("sh_inventory.lua")
  AddCSLuaFile("sh_items.lua")
  AddCSLuaFile("cl_inventory.lua")
  AddCSLuaFile("cl_inventory_loadout.lua")
  AddCSLuaFile("cl_inventory_spawnmenu.lua")
  local rpPropsPath = rp_props_sh_items_path()
  if rpPropsPath then
    AddCSLuaFile(rpPropsPath)
  end
  -- Send legacy items file to client only if present
  if file.Exists("gamemodes/DarkRP/gamemode/modules/Inventory/PREV-shitems.lua", "LUA") then
    AddCSLuaFile("gamemodes/DarkRP/gamemode/modules/Inventory/PREV-shitems.lua")
  end

  include("sh_inventory.lua")
  include("sh_items.lua")
  include("sv_inventory.lua")
  if rp_props_sh_items_path() then
    include(rp_props_sh_items_path())
  end
  -- Import legacy item definitions (server-only) and register into new Inventory
  if file.Exists("gamemodes/DarkRP/gamemode/modules/Inventory/PREV-shitems.lua", "LUA") then
    include("gamemodes/DarkRP/gamemode/modules/Inventory/PREV-shitems.lua")
    if istable(InventoryItems) then
      for id, old in pairs(InventoryItems) do
        local mapped = {
          name = old.name or id,
          desc = old.description or old.desc or "",
          icon = old.icon or "",
          model = old.model or "",
          class = old.entityClass or old.class or "",
          category = old.category or "Misc",
        }
        Inventory.RegisterItem(id, mapped)
        -- also add lowercase alias for convenience
        local def = Inventory.Items[id]
        if def then
          def.aliases = def.aliases or {}
          table.insert(def.aliases, string.lower(id))
        end
      end
    end
  end
else
  include("sh_inventory.lua")
  include("sh_items.lua")
  include("cl_inventory.lua")
  include("cl_inventory_loadout.lua")
  include("cl_inventory_spawnmenu.lua")
  if rp_props_sh_items_path() then
    include(rp_props_sh_items_path())
  end
  -- Client also imports for UI completeness (no server-only funcs)
  if file.Exists("gamemodes/DarkRP/gamemode/modules/Inventory/PREV-shitems.lua", "LUA") then
    include("gamemodes/DarkRP/gamemode/modules/Inventory/PREV-shitems.lua")
    if istable(InventoryItems) then
      for id, old in pairs(InventoryItems) do
        if not Inventory.Items[id] then
          Inventory.Items[id] = {
            name = old.name or id,
            desc = old.description or old.desc or "",
            icon = old.icon or "",
            model = old.model or "",
            class = old.entityClass or old.class or "",
            category = old.category or "Misc",
          }
        end
        local def = Inventory.Items[id]
        if def then
          def.aliases = def.aliases or {}
          table.insert(def.aliases, string.lower(id))
        end
      end
    end
  end
end

