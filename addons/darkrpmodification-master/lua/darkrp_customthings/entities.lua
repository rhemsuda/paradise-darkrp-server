--[[---------------------------------------------------------------------------
DarkRP custom entities
---------------------------------------------------------------------------

This file contains your custom entities.
This file should also contain entities from DarkRP that you edited.

Note: If you want to edit a default DarkRP entity, first disable it in darkrp_config/disabled_defaults.lua
    Once you've done that, copy and paste the entity to this file and edit it.

The default entities can be found here:
https://github.com/FPtje/DarkRP/blob/master/gamemode/config/addentities.lua

For examples and explanation please visit this wiki page:
https://darkrp.miraheze.org/wiki/DarkRP:CustomEntityFields

Add entities under the following line:
---------------------------------------------------------------------------]]

print("[DarkRP Entities] entities.lua loaded successfully")

DarkRP.createEntity("Basic Money Printer", {
    ent = "basic_money_printer",
    model = "models/props_c17/consolebox01a.mdl",
    price = 1000,
    max = 2,
    cmd = "buybasicmoneyprinter",
    allowed = {},
    category = "Other",
    customCategory = "Printers"
})

DarkRP.createEntity("Advanced Money Printer", {
    ent = "advanced_money_printer",
    model = "models/props_c17/consolebox03a.mdl",
    price = 2500,
    max = 2,
    cmd = "buyadvancedmoneyprinter",
    allowed = {},
    category = "Other",
    customCategory = "Printers"
})

print("[DarkRP Entities] Finished defining entities")