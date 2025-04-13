print("[DEBUG] sh_npc_stats.lua loaded")

NPCStats = NPCStats or {}

function NPCStats:New(npc)
    local stats = {
        NPCID = npc:GetNWInt("NPCID"),
        Health = 100,
        Defence = 10,
        Damage = 5,
        AttackSpeed = 1.0,
        WalkSpeed = 100,
        RunSpeed = 200
    }

    npc:SetNWInt("Health", stats.Health)
    npc:SetNWInt("Defence", stats.Defence)
    npc:SetNWInt("Damage", stats.Damage)
    npc:SetNWFloat("AttackSpeed", stats.AttackSpeed)
    npc:SetNWFloat("WalkSpeed", stats.WalkSpeed)
    npc:SetNWFloat("RunSpeed", stats.RunSpeed)

    return stats
end

function NPCStats:GetStats(npc)
    return {
        NPCID = npc:GetNWInt("NPCID"),
        Health = npc:GetNWInt("Health"),
        Defence = npc:GetNWInt("Defence"),
        Damage = npc:GetNWInt("Damage"),
        AttackSpeed = npc:GetNWFloat("AttackSpeed"),
        WalkSpeed = npc:GetNWFloat("WalkSpeed"),
        RunSpeed = npc:GetNWFloat("RunSpeed")
    }
end

function NPCStats:SetHealth(npc, health)
    npc:SetNWInt("Health", health)
end

function NPCStats:SetDefence(npc, defence)
    npc:SetNWInt("Defence", defence)
end

function NPCStats:SetDamage(npc, damage)
    npc:SetNWInt("Damage", damage)
end

function NPCStats:SetAttackSpeed(npc, speed)
    npc:SetNWFloat("AttackSpeed", speed)
end

function NPCStats:SetWalkSpeed(npc, speed)
    npc:SetNWFloat("WalkSpeed", speed)
end

function NPCStats:SetRunSpeed(npc, speed)
    npc:SetNWFloat("RunSpeed", speed)
end