-- Paradise NPCs - Shared definitions. See NPC_TODO.md for NPC list.
-- Missions/Shops per type are in sh_npc_content.lua (loaded by module loader before this).
Paradise = Paradise or {}
Paradise.NPCs = Paradise.NPCs or {}

-- Display names per NPC type (for menus and editor).
Paradise.NPCs.Types = {
    generic = "Paradise Citizen",
    cook = "Cook",
    banker = "Banker",
    crafter = "Crafter",
    medic = "Medic",
    miner = "Miner",
    police = "Police HQ",
    blackmarket = "Black Market",
    drugdealer = "Druggie",
    merchant = "Merchant",
    mechanic = "Mechanic",
    gang = "Gang Member",
    dojo = "Dojo",
    cardealer = "Car Dealer",
}

-- Model path per NPC type (used when spawning). Add or change here to swap appearances.
Paradise.NPCs.Models = {
    generic = "models/mossman.mdl",
    cook = "models/mossman.mdl",
    miner = "models/alyx.mdl",
    police = "models/breen.mdl",
    blackmarket = "models/gman_high.mdl",
    drugdealer = "models/Eli.mdl",
    medic = "models/Kleiner.mdl",
    merchant = "models/vortigaunt.mdl",
    mechanic = "models/soldier_stripped.mdl",
    banker = "models/Humans/Group01/male_08.mdl",
    gang = "models/Humans/Group03/male_03.mdl",
    dojo = "models/Humans/Group02/Male_04.mdl",
    crafter = "models/stalker.mdl",
    cardealer = "models/Barney.mdl",
}

function Paradise.NPCs.GetDisplayName(npcType)
    return Paradise.NPCs.Types[npcType] or Paradise.NPCs.Types.generic
end

-- Returns the model path for an NPC type; fallback if type has no model defined.
function Paradise.NPCs.GetModelForType(npcType)
    return (Paradise.NPCs.Models and Paradise.NPCs.Models[npcType]) or "models/mossman.mdl"
end

-- NPCs that will deal with wanted players (all others refuse). Configurable in admin NPC settings later.
Paradise.NPCs.DealsWithWanted = {
    drugdealer = true,
    gang = true,
    blackmarket = true,
    mechanic = true,
}
function Paradise.NPCs.DealsWithWantedType(npcType)
    return Paradise.NPCs.DealsWithWanted and Paradise.NPCs.DealsWithWanted[npcType]
end
