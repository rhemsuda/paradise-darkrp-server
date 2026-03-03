--[[---------------------------------------------------------------------------
  Rollback module (shared) - Framework only.
  See ROLLBACK_FRAMEWORK.md for full design.
  Snapshots: day / week / month. Data: money, inventory, resources, perks, level/XP, gangs.
---------------------------------------------------------------------------]]
Paradise = Paradise or {}
Paradise.Rollback = Paradise.Rollback or {}

Paradise.Rollback.SnapshotType = {
    Day   = "day",
    Week  = "week",
    Month = "month",
}

-- Net names (for future admin UI)
Paradise.Rollback.NET = {
    RequestSnapshotList = "Paradise_Rollback_RequestList",
    SendSnapshotList    = "Paradise_Rollback_SendList",
    RequestRestore      = "Paradise_Rollback_RequestRestore",
    RestoreResult       = "Paradise_Rollback_Result",
}

if SERVER then
    for _, name in pairs(Paradise.Rollback.NET) do
        util.AddNetworkString(name)
    end
end
