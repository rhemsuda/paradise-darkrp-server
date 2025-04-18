-- People often copy jobs. When they do, the GM table does not exist anymore.
-- This line makes the job code work both inside and outside of gamemode files.
-- You should not copy this line into your code.
local GAMEMODE = GAMEMODE or GM
--[[--------------------------------------------------------
Default teams. Please do not edit this file. Please use the darkrpmod addon instead.
--------------------------------------------------------]]
TEAM_CITIZEN = DarkRP.createJob("Citizen", {
    color = Color(20, 150, 20, 255),
    model = {
        "models/player/Group01/Female_01.mdl",
        "models/player/Group01/Female_02.mdl",
        "models/player/Group01/Female_03.mdl",
        "models/player/Group01/Female_04.mdl",
        "models/player/Group01/Female_06.mdl",
        "models/player/group01/male_01.mdl",
        "models/player/Group01/Male_02.mdl",
        "models/player/Group01/male_03.mdl",
        "models/player/Group01/Male_04.mdl",
        "models/player/Group01/Male_05.mdl",
        "models/player/Group01/Male_06.mdl",
        "models/player/Group01/Male_07.mdl",
        "models/player/Group01/Male_08.mdl",
        "models/player/Group01/Male_09.mdl"
    },
    description = [[The Citizen is the most basic level of society you can hold besides being a hobo. You have no specific role in city life.]],
    weapons = {},
    command = "citizen",
    max = 0,
    salary = GAMEMODE.Config.normalsalary,
    admin = 0,
    vote = false,
    hasLicense = false,
    candemote = false,
    category = "Citizens",
    levelRequired = 0,
})

TEAM_MINER = DarkRP.createJob("Miner", {
    color = Color(247, 160, 38),
    model = "models/player/Group03/male_09.mdl",
    description = [[
        Mine minerals and gems for crafting
    ]],
    weapons = {},
    command = "miner",
    max = 5,
    salary = 100,
    admin = 0,
    vote = false,
    hasLicense = false,
    category = "Citizens",
    canDemote = false,
    levelRequired = 5,
})

TEAM_FORAGER = DarkRP.createJob("Forager", {
    color = Color(247, 100, 38),
    model = "models/Characters/Hostage_01.mdl",
    description = [[
        Gather Materials for crafting
    ]],
    weapons = {},
    command = "forager",
    max = 5,
    salary = 100,
    admin = 0,
    vote = false,
    hasLicense = false,
    category = "Citizens",
    canDemote = false,
    levelRequired = 5,
})

-- Compatibility for when default teams are disabled
TEAM_CITIZEN = TEAM_CITIZEN  or -1
TEAM_MINER = TEAM_MINER or -1
TEAM_FORAGER = TEAM_FORAGER or -1

-- Door groups
--AddDoorGroup("Cops and Mayor only", TEAM_CHIEF, TEAM_POLICE, TEAM_MAYOR)
--AddDoorGroup("Cops and Mayor only", TEAM_CHIEF, TEAM_MAYOR)
--AddDoorGroup("Gundealer only", TEAM_GUN)

-- Agendas
--DarkRP.createAgenda("Gangster's agenda", TEAM_MOB, {TEAM_GANG})
--DarkRP.createAgenda("Police agenda", {TEAM_MAYOR, TEAM_CHIEF}, {TEAM_POLICE})

-- Group chats
DarkRP.createGroupChat(function(ply) return ply:isCP() end)
--DarkRP.createGroupChat(TEAM_MOB, TEAM_GANG)
DarkRP.createGroupChat(function(listener, ply) return not ply or ply:Team() == listener:Team() end)

-- Initial team when first spawning
GAMEMODE.DefaultTeam = TEAM_CITIZEN

-- Teams that belong to Civil Protection
--GAMEMODE.CivilProtection = {
    --[TEAM_POLICE] = true,
    --[TEAM_CHIEF] = true,
--[TEAM_MAYOR] = true,
--}

-- Hitman team
--DarkRP.addHitmanTeam(TEAM_MOB)

-- Demote groups
--DarkRP.createDemoteGroup("Cops", {TEAM_POLICE, TEAM_CHIEF})
--DarkRP.createDemoteGroup("Cops", {TEAM_CHIEF})
--DarkRP.createDemoteGroup("Gangsters", {TEAM_GANG, TEAM_MOB})



-- Default categories
DarkRP.createCategory{
    name = "Citizens",
    categorises = "jobs",
    startExpanded = true,
    color = Color(0, 107, 0, 255),
    canSee = fp{fn.Id, true},
    sortOrder = 100,
}

--[[DarkRP.createCategory{
    name = "Civil Protection",
    categorises = "jobs",
    startExpanded = true,
    color = Color(25, 25, 170, 255),
    canSee = fp{fn.Id, true},
    sortOrder = 101,
}

DarkRP.createCategory{
    name = "Gangsters",
    categorises = "jobs",
    startExpanded = true,
    color = Color(75, 75, 75, 255),
    canSee = fp{fn.Id, true},
    sortOrder = 101,
}--]]

DarkRP.createCategory{
    name = "Other",
    categorises = "jobs",
    startExpanded = true,
    color = Color(0, 107, 0, 255),
    canSee = fp{fn.Id, true},
    sortOrder = 255,
}
