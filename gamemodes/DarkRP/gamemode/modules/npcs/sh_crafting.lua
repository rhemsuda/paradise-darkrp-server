--[[---------------------------------------------------------------------------
  Paradise Crafting — Shared. Recipe lookup from blueprint definitions (craft_recipe, weapon_id).
  Used by crafter menu (client) and crafting net handlers (server).
---------------------------------------------------------------------------]]
Crafting = Crafting or {}

-- Build recipe table from Inventory.Items blueprints that have craft_recipe and weapon_id
function Crafting.BuildRecipes()
    Crafting.Recipes = {}
    if not Inventory or not Inventory.Items then return end
    for bpId, def in pairs(Inventory.Items) do
        if type(bpId) == "string" and string.sub(bpId, 1, 10) == "blueprint_" and def and def.weapon_id and def.craft_recipe and type(def.craft_recipe) == "table" then
            Crafting.Recipes[bpId] = def.craft_recipe
        end
    end
end

-- Returns required resources for a blueprint: { resource_id = amount }
function Crafting.GetRecipe(bpId)
    if not Crafting.Recipes then Crafting.BuildRecipes() end
    return Crafting.Recipes and Crafting.Recipes[bpId] or {}
end

-- Returns the result item id (e.g. bb_ak47) for a blueprint
function Crafting.GetResultItemId(bpId)
    if not Inventory or not Inventory.Items or not bpId then return nil end
    local def = Inventory.Items[bpId]
    return def and def.weapon_id or nil
end

-- One-time build when items are ready (call after items loaded)
hook.Add("Initialize", "Crafting_BuildRecipes", function()
    Crafting.BuildRecipes()
end)
