--[[---------------------------------------------------------------------------
  NPC missions (quest lines) and shop items per NPC type.
  Defined in files so admins cannot change this in-game.
  MissionLines: list of missions shown in DListView. Types: talk_npc, collect.
---------------------------------------------------------------------------]]
Paradise = Paradise or {}
Paradise.NPCs = Paradise.NPCs or {}

-- Mission types: talk_npc = talk to another NPC; collect = collect N of entity/item that spawns on map.
Paradise.NPCs.MissionTypes = {
    talk_npc = "Talk to NPC",
    collect = "Collect items",
}

-- Mission lines per NPC type. Shown in Missions tab DListView.
-- id, name, type, target, amount, description, level_req (optional), requirements (string), objective (what to do), rewards {money, items[]}.
Paradise.NPCs.MissionLines = {
    generic = {
        { id = "gen_1", name = "Welcome to Paradise", type = "talk_npc", target = "banker", amount = 1, description = "Introduce yourself to the Banker.", level_req = nil, requirements = "None", objective = "Speak with the Banker.", rewards = { money = 50, items = {} } },
    },
    crafter = {
        { id = "craft_1", name = "Gather Wood", type = "collect", target = "wood", amount = 10, description = "Collect 10 Wood from around the map.", level_req = 1, requirements = "Level 1", objective = "Collect 10 Wood and bring them to the Crafter.", rewards = { money = 100, items = {"wood"} } },
        { id = "craft_2", name = "Meet the Miner", type = "talk_npc", target = "miner", amount = 1, description = "Go speak with the Miner.", level_req = nil, requirements = "None", objective = "Travel to the Miner and have a conversation.", rewards = { money = 25, items = {} } },
        { id = "craft_3", name = "Craft a Tool", type = "collect", target = "metal_scrap", amount = 5, description = "Bring 5 Metal Scrap.", level_req = 5, requirements = "Level 5", objective = "Collect 5 Metal Scrap and bring them to me.", rewards = { money = 200, items = {"tool_basic"} } },
    },
    banker = {
        { id = "bank_1", name = "Open an Account", type = "talk_npc", target = "banker", amount = 1, description = "Speak with the banker.", level_req = nil, requirements = "None", objective = "Open an account at the bank.", rewards = { money = 0, items = {} } },
    },
    medic = {
        { id = "med_1", name = "First Aid Run", type = "collect", target = "medkit", amount = 3, description = "Deliver 3 medkits.", level_req = 3, requirements = "Level 3", objective = "Find 3 medkits in the world and bring them to the Medic.", rewards = { money = 75, items = {"bandage"} } },
    },
    miner = {
        { id = "mine_1", name = "Ore Sample", type = "collect", target = "ore", amount = 5, description = "Collect 5 Ore.", level_req = 2, requirements = "Level 2", objective = "Mine or find 5 Ore and bring them to the Miner.", rewards = { money = 150, items = {"ore"} } },
    },
}

-- Shop items per NPC type. item_id, price, name, level_req (optional), description, icon (material path or nil).
-- TODO (Phase 4+): purchases are validated and executed server-side; add a net handler in sv_npcs.lua.
Paradise.NPCs.Shops = {
    generic = {},
    banker = { { item_id = "money_bag", price = 0, name = "Deposit (use ATM)", level_req = nil, description = "Deposit money at the ATM.", icon = "icon16/money.png" } },
    medic = {
        { item_id = "medkit", price = 50, name = "Medkit", level_req = nil, description = "Restores health when used.", icon = "icon16/heart.png" },
        { item_id = "bandage", price = 10, name = "Bandage", level_req = nil, description = "Minor healing.", icon = "icon16/heart.png" },
    },
    crafter = {
        { item_id = "wood", price = 15, name = "Wood (1)", level_req = 1, description = "Basic crafting material. Required for many recipes.", icon = "icon16/brick.png" },
        { item_id = "metal_scrap", price = 25, name = "Metal Scrap", level_req = 2, description = "Scrap metal used in crafting tools and weapons.", icon = "icon16/wrench.png" },
        { item_id = "tool_basic", price = 75, name = "Basic Tool", level_req = 5, description = "A simple tool for gathering and crafting.", icon = "icon16/wrench.png" },
    },
    miner = { { item_id = "pickaxe", price = 100, name = "Pickaxe", level_req = nil, description = "Used to mine ore and stone.", icon = "icon16/wrench.png" } },
}

-- Helper: get mission lines (DListView list) for a type (never nil).
function Paradise.NPCs.GetMissionLines(npcType)
    return (Paradise.NPCs.MissionLines[npcType]) or Paradise.NPCs.MissionLines.generic or {}
end

-- Helper: get shop for a type (never nil).
function Paradise.NPCs.GetShop(npcType)
    return (Paradise.NPCs.Shops[npcType]) or Paradise.NPCs.Shops.generic or {}
end
