print("[JobsMenu] sv_jobs.lua loaded successfully")

if not SERVER then return end

-- Networking messages
util.AddNetworkString("JobsMenu_JobChange")

-- Server-side Network Handlers
net.Receive("JobsMenu_JobChange", function(len, ply)
    local jobTeam = net.ReadUInt(16)
    local job = RPExtraTeams[jobTeam]
    if not job then
        ply:ChatPrint("Invalid job selected!")
        print("[JobsMenu] JobChange: Invalid job team " .. jobTeam .. " for " .. ply:Nick())
        return
    end

    ply:changeTeam(jobTeam, true)
    ply:ChatPrint("You have become a " .. job.name .. "!")
    print("[JobsMenu] JobChange: " .. ply:Nick() .. " became " .. job.name)
end)

print("[JobsMenu] Server-side loaded successfully")