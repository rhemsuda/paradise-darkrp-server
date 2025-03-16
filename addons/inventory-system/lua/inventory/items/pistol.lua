RegisterInventoryItem("pistol", {
    name = "Pistol",
    model = "models/weapons/w_pistol.mdl",
    entityClass = "weapon_pistol",
    useFunction = function(ply)
        ply:Give("weapon_pistol")
        ply:GiveAmmo(30, "Pistol")
    end,
    maxStack = 1
})