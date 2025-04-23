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
})

--TEAM_FOR = DarkRP.createJob("Forager", {
   -- color = Color(247, 100, 38),
   -- model = "models/Characters/Hostage_01.mdl",
   -- description = [[
   --     Gather Materials for crafting
   -- ]],
  -- weapons = {},
  --  command = "forager",
   -- max = 5,
   -- salary = 100,
   -- admin = 0,
   -- vote = false,
   -- hasLicense = false,
   -- category = "Citizens",
   -- canDemote = false,
--})

-- TEAM_MINER = DarkRP.createJob("Miner", {
   -- color = Color(247, 160, 38),
  --  model = models/player/Group03/male_09.mdl,
   -- description = [[
   --     Mine minerals and gems for crafting
 --   ]]--,
   -- weapons = {},
   -- command = "miner",
   -- max = 5,
   -- salary = 100,
   -- admin = 0,
   -- vote = false,
   -- hasLicense = false,
   -- category = "Citizen",
--canDemote = false,
--})

--[[---------------------------------------------------------------------------
Define which team joining players spawn into and what team you change to if demoted
---------------------------------------------------------------------------]]
GAMEMODE.DefaultTeam = TEAM_CITIZEN
--[[---------------------------------------------------------------------------
Define which teams belong to civil protection
Civil protection can set warrants, make people wanted and do some other police related things
---------------------------------------------------------------------------]]
--[[GAMEMODE.CivilProtection = {
    [TEAM_POLICE] = false,
    [TEAM_CHIEF] = true,
    [TEAM_MAYOR] = false,
}
--[[---------------------------------------------------------------------------
Jobs that are hitmen (enables the hitman menu)
---------------------------------------------------------------------------]]
--DarkRP.addHitmanTeam(TEAM_MOB)
