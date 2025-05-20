--[[---------------------------------------------------------------------------
DarkRP custom jobs
---------------------------------------------------------------------------
This file contains your custom jobs.
This file should also contain jobs from DarkRP that you edited.

Note: If you want to edit a default DarkRP job, first disable it in darkrp_config/disabled_defaults.lua
      Once you've done that, copy and paste the job to this file and edit it.

The default jobs can be found here:
https://github.com/FPtje/DarkRP/blob/master/gamemode/config/jobrelated.lua

For examples and explanation please visit this wiki page:
https://darkrp.miraheze.org/wiki/DarkRP:CustomJobFields

Add your custom jobs under the following line:
---------------------------------------------------------------------------]]

TEAM_MINER = DarkRP.createJob("Miner", {
    color = Color(100, 100, 38),
    model = "models/player/Group03/male_09.mdl",
    description = [[
        Mine minerals and gems for crafting
    ]],
    weapons = {"weapon_shovel"},
    command = "miner",
    max = 5,
    salary = 100,
    admin = 0,
    vote = false,
    hasLicense = false,
    category = "Citizens",
    canDemote = true,
})

TEAM_MERC = DarkRP.createJob("Mercenary", {
    color = Color(10, 100, 255),
    model = "models/Combine_Super_Soldier.mdl",
    description = [[
        A job for the most deadly of people.
    ]],
    weapons = {"bb_fiveseven"},
    command = "merc",
    max = 5,
    salary = 100,
    admin = 0,
    vote = false,
    hasLicense = false,
    category = "Bonus",
    canDemote = false,
})

TEAM_PARA = DarkRP.createJob("Paramedic", {
    color = Color(10, 100, 255),
    model = "models/Characters/hostage_04.mdl",
    description = [[
        You're a medic except with exceptional tools!
    ]],
    weapons = {"med_kit"},
    command = "para",
    max = 2,
    salary = 100,
    admin = 0,
    vote = false,
    hasLicense = false,
    category = "Bonus",
    canDemote = true,
})

TEAM_SPEC = DarkRP.createJob("Specialist", {
    color = Color(20, 160, 50),
    model = "models/Humans/Group03/male_07.mdl",
    description = [[
        A job for the most deadly of people.
    ]],
    weapons = {"bb_usp"},
    command = "special",
    max = 5,
    salary = 100,
    admin = 0,
    vote = false,
    hasLicense = false,
    category = "Bonus",
    canDemote = false,
})

--TEAM_ZOMB = DarkRP.createJob("Zombie", {
  --  color = Color(255, 10, 10),
   -- model = "models/Zombie/Classic.mdl",
   -- description = [[
  --      You are infected! KILL THEM ALL!
 --   ]],
  --  weapons = {},
 --   command = "aimzombz",
 --   max = 20,
 --   salary = 100,
 --   admin = 0,
--    vote = false,
--    hasLicense = false,
--    category = "Atomic Infection",
--    canDemote = false,
--})

TEAM_DRUG = DarkRP.createJob("Druggie", {
    color = Color(255, 10, 10),
    model = "models/player/t_phoenix.mdl",
    description = [[
        Drugs.... MMMM DRUGZ
    ]],
    weapons = {},
    command = "druggie",
    max = 20,
    salary = 100,
    admin = 0,
    vote = false,
    hasLicense = false,
    category = "Gangsters",
    canDemote = false,
})

--[[---------------------------------------------------------------------------
Define which team joining players spawn into and what team you change to if demoted
---------------------------------------------------------------------------]]
GAMEMODE.DefaultTeam = TEAM_CITIZEN
--[[---------------------------------------------------------------------------
Define which teams belong to civil protection
Civil protection can set warrants, make people wanted and do some other police related things
---------------------------------------------------------------------------]]
GAMEMODE.CivilProtection = {
    [TEAM_POLICE] = false,
    [TEAM_CHIEF] = true,
    [TEAM_MAYOR] = true,
}
--[[---------------------------------------------------------------------------
Jobs that are hitmen (enables the hitman menu)
---------------------------------------------------------------------------]]
--DarkRP.addHitmanTeam(TEAM_MOB)
