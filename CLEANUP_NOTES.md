# Paradise DarkRP Server – Cleanup Notes

Summary of cleanup done so you can run the server and see where things sit.

## What was cleaned

- **Debug / load prints**  
  Removed or gated all “module loaded” and noisy debug `print()` calls across:
  - **darkrpmodification addon**: RPEnts, Admin, Jobs, Props, Resources, DeathSystem (client + server). Debug output is now behind the `rp_debug` ConVar (created in deathsystem; set `rp_debug 1` in console to re-enable).
  - **Gamemode Inventory module**: Removed load confirmation prints from `sh_inventory`, `sh_init`, `sv_inventory`, `sh_items`, `cl_inventory_spawnmenu`, `cl_inventory_loadout`, and the commented print in `cl_inventory.lua`. Inventory move/debug logs are still controlled by `inv_svdebug` / `INV_DEBUG` ConVars.
  - **lua/weapons/weapon_shovel.lua**: Removed all shovel debug prints.
  - **lua/autorun/client/cl_f4menu_override.lua**: Removed load print.

- **Code tidy**
  - **rp_props/sv_props.lua**: Removed duplicate `util.AddNetworkString` and duplicate `if not SERVER then return end`.
  - **Admin module**: Fixed `DebugPrint` indentation and made ConVar access nil-safe where used.
  - **Props/Resources/DeathSystem**: All `DebugPrint` helpers now use a nil-safe `GetConVar("rp_debug")` check so they never error if the ConVar is missing.

- **Config**
  - DarkRP `config.lua` and `jobrelated.lua` were only reviewed; no functional changes. They look like standard DarkRP setup.

## Duplicate addons

You have both:

- `addons/ulib` and `addons/ulib-master`
- `addons/ulx` and `addons/ulx-master`

GMod will load every addon folder. Having both can mean ULib and ULX are loaded twice, which may cause duplicate hooks or errors. Recommendation: keep only one of each (e.g. remove the `-master` folders if they are just copies, or the non-`-master` if the `-master` ones are the ones you intend to use).

## Debug when you need it

- **RP modules (entities, jobs, props, admin, resources, death system):**  
  In console: `rp_debug 1`  
  Turn off with: `rp_debug 0`

- **Inventory (server):**  
  Use the existing `inv_svdebug` ConVar if you added one for server-side inventory moves.

- **Inventory (client):**  
  Use the existing `INV_DEBUG` ConVar if you use it for client inventory UI debug.

After cleanup, the console should be much quieter on a normal run. If something breaks or you want to trace a specific system, use the ConVars above or re-add temporary prints as needed.
