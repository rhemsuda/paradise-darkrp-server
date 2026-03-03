-- Debug print to confirm the file is loading
print("[Jobs Module] sv_jobs.lua loaded successfully")

if not SERVER then return end

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug") and GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Network strings
util.AddNetworkString("RequestJobsData")
util.AddNetworkString("SendJobsData")
util.AddNetworkString("RequestJobChange")

-- Function to send jobs data to a player
local function SendJobsDataToPlayer(ply)
    if not IsValid(ply) then return end

    -- Fetch DarkRP jobs
    local jobsData = {}
    for jobIndex, job in pairs(RPExtraTeams) do
        -- Placeholder entities list based on typical DarkRP roles
        local entities = {}
        if job.name == "Citizen" then
            entities = {"None"}
        elseif job.name:find("Police") or job.name:find("Chief") then
            entities = {"Police Barricade"}
        elseif job.name:find("Gangster") or job.name:find("Mob") then
            entities = {"Money Printer", "Drug Lab"}
        else
            entities = {"None"}
        end

        jobsData[jobIndex] = {
            name = job.name,
            description = job.description or "No description available.",
            salary = job.salary,
            max = job.max,
            admin = job.admin,
            model = istable(job.model) and job.model[1] or job.model,
            team = job.team,
            category = job.category or "Other",
            weapons = job.weapons or {},
            entities = entities,
            candropweapons = job.candropweapons or false,
            level = job.level or 0,
        }
    end

    net.Start("SendJobsData")
    net.WriteTable(jobsData)
    net.Send(ply)
    DebugPrint("[Jobs Module] Sent jobs data to " .. ply:Nick())
end

-- Handle request for jobs data
net.Receive("RequestJobsData", function(len, ply)
    SendJobsDataToPlayer(ply)
end)

-- Handle job change request
net.Receive("RequestJobChange", function(len, ply)
    if not IsValid(ply) then return end
    if IsPlayerGhost and IsPlayerGhost(ply) then
        DarkRP.notify(ply, 1, 4, "You cannot change job while dead!")
        return
    end

    local jobIndex = net.ReadUInt(16)
    local job = RPExtraTeams[jobIndex]

    if not job then
        DebugPrint("[Jobs Module] " .. ply:Nick() .. " attempted to switch to invalid job index: " .. jobIndex)
        return
    end

    -- Check if the player can switch to this job
    if job.admin > 0 and not ply:IsAdmin() then
        DebugPrint("[Jobs Module] " .. ply:Nick() .. " attempted to switch to admin-only job: " .. job.name)
        return
    end

    if job.max > 0 and #team.GetPlayers(job.team) >= job.max then
        DarkRP.notify(ply, 1, 4, "This job is full!")
        DebugPrint("[Jobs Module] " .. ply:Nick() .. " attempted to switch to job at max capacity: " .. job.name)
        return
    end

    local requiredLevel = job.level or 0
    if requiredLevel > 0 then
        local playerLevel = ply:GetNWInt("DarkRP_Level", 1)
        if playerLevel < requiredLevel then
            DarkRP.notify(ply, 1, 4, "You need level " .. requiredLevel .. " for this job!")
            return
        end
    end

    -- Switch the player's job
    ply:changeTeam(job.team, true)
    DebugPrint("[Jobs Module] " .. ply:Nick() .. " switched to job: " .. job.name)
end)

-- Send job data to the player when they initially spawn
hook.Add("PlayerInitialSpawn", "SendJobsDataOnJoin", function(ply)
    -- Small delay to ensure the player is fully connected
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        SendJobsDataToPlayer(ply)
    end)
end)

print("[Jobs Module] Server-side loaded successfully.")