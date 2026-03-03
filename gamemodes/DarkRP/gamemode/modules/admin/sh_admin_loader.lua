-- Admin shared loader
print('[ADMIN] sh_admin_loader.lua loaded')

DarkRP.declareChatCommand{
    command = "spawn",
    description = "Teleport a player to their job spawn (admin only). Silent.",
    delay = 0.5,
    tableArgs = false
}

DarkRP.declareChatCommand{
    command = "respawn",
    description = "Revive a dead player at their body (admin only). Silent.",
    delay = 0.5,
    tableArgs = false
}
