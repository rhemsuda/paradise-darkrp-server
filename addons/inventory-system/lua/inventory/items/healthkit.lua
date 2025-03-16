RegisterInventoryItem("healthkit", {
    name = "Health Kit",
    model = "models/items/healthkit.mdl",
    entityClass = "item_healthkit",
    useFunction = function(ply)
        ply:SetHealth(math.min(ply:Health() + 25, ply:GetMaxHealth()))
    end
})