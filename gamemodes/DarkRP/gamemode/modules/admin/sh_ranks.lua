--[[---------------------------------------------------------------------------
  Paradise Ranks — Shared. Defines rank display names, prop limits, exp bonus,
  endurance caps, and printer limits. Used by admin, leveling, perks, rpents.
  Ranks: user, member, donator, sdonator, admin, superadmin
---------------------------------------------------------------------------]]
if not Admin then Admin = {} end

Admin.RankDisplayNames = {
    user       = "User",
    member     = "Member",
    donator    = "Donator",
    sdonator   = "Super Donator",
    admin      = "Admin",
    superadmin = "Super Admin",
}

-- Prop limits per rank (sbox_maxprops override per player)
Admin.RankPropLimits = {
    user       = 10,
    member     = 10,
    donator    = 20,
    sdonator   = 30,
    admin      = 30,
    superadmin = 30,
}

-- Extra XP multiplier (1.0 = 0%, 1.05 = 5%, 1.10 = 10%)
Admin.RankExpMultiplier = {
    user       = 1.0,
    member     = 1.0,
    donator    = 1.05,
    sdonator   = 1.10,
    admin      = 1.0,
    superadmin = 1.0,
}

-- Max endurance level unlock per rank (User can't unlock past 10 without Donator)
Admin.RankEnduranceMax = {
    user       = 10,
    member     = 10,
    donator    = 15,
    sdonator   = 20,
    admin      = 20,
    superadmin = 20,
}

-- Extra printer slots (base 4, +2 for Donator ranks)
Admin.RankPrinterBonus = {
    user       = 0,
    member     = 0,
    donator    = 2,
    sdonator   = 2,
    admin      = 0,
    superadmin = 0,
}

function Admin.GetPropLimit(rank)
    return Admin.RankPropLimits and Admin.RankPropLimits[rank] or 10
end

function Admin.GetExpMultiplier(rank)
    return Admin.RankExpMultiplier and Admin.RankExpMultiplier[rank] or 1.0
end

function Admin.GetEnduranceMax(rank)
    return Admin.RankEnduranceMax and Admin.RankEnduranceMax[rank] or 10
end

function Admin.GetPrinterBonus(rank)
    return Admin.RankPrinterBonus and Admin.RankPrinterBonus[rank] or 0
end

-- Scoreboard display: Admin and Super Admin both show as "Admin"; others use RankDisplayNames (User, Member, Donator, Super Donator, etc.)
function Admin.GetScoreboardRankDisplay(rank)
    if not rank then return "User" end
    if rank == "admin" or rank == "superadmin" then return "Admin" end
    return (Admin.RankDisplayNames and Admin.RankDisplayNames[rank]) or rank
end
