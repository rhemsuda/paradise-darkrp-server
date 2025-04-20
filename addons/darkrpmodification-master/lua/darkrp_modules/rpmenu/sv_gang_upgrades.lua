if not SERVER then return end

-- Function to get a player's gang upgrade levels
local function GetGangUpgrades(ply)
    if not IsValid(ply) then return nil end

    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then return nil end

    local gangData = sql.QueryRow("SELECT gang_upgrades FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then return nil end

    local upgrades = util.JSONToTable(gangData.gang_upgrades or "{}") or {}
    return upgrades
end

-- Function to apply upgrades to a player
local function ApplyGangUpgrades(ply)
    if not IsValid(ply) then return end

    local upgrades = GetGangUpgrades(ply)
    if not upgrades then return end

    -- Health: +5 per level (max +50 at level 10)
    local healthLevel = upgrades.Health or 0
    if healthLevel > 0 then
        local baseHealth = 100 -- DarkRP default
        local bonusHealth = healthLevel * 5
        ply:SetMaxHealth(baseHealth + bonusHealth)
        ply:SetHealth(baseHealth + bonusHealth) -- Set health to the new max health on spawn
    end

    -- Armor: +5 per level (max +50 at level 10)
    local armorLevel = upgrades.Armor or 0
    if armorLevel > 0 then
        local bonusArmor = armorLevel * 5
        ply:SetArmor(math.min(ply:Armor() + bonusArmor, 100 + bonusArmor))
    end

    -- Speed: +3% per level (max +30% at level 10)
    local speedLevel = upgrades.Speed or 0
    if speedLevel > 0 then
        local speedMultiplier = 1 + (speedLevel * 0.03)
        ply:SetRunSpeed(ply:GetRunSpeed() * speedMultiplier)
        ply:SetWalkSpeed(ply:GetWalkSpeed() * speedMultiplier)
    end
end

-- Hook to apply upgrades on player spawn
hook.Add("PlayerSpawn", "ApplyGangUpgradesOnSpawn", function(ply)
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        ApplyGangUpgrades(ply)
    end)
end)

-- Hook to reset speed when necessary (e.g., after a job change in DarkRP)
hook.Add("PlayerSetModel", "ResetGangSpeedUpgrades", function(ply)
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        -- Reset speed to default DarkRP values before reapplying
        ply:SetRunSpeed(240) -- DarkRP default
        ply:SetWalkSpeed(120) -- DarkRP default
        ApplyGangUpgrades(ply)
    end)
end)

-- Function to reapply upgrades to all players in a gang (e.g., after an upgrade is purchased)
function ReapplyGangUpgrades(gangName)
    if not gangName or gangName == "" then return end

    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNWString("GangName", "") == gangName then
            -- Reset speed to default before reapplying
            ply:SetRunSpeed(240)
            ply:SetWalkSpeed(120)
            ApplyGangUpgrades(ply)
        end
    end
end