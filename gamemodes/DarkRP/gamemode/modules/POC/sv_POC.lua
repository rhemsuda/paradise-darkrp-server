-- POC module: printer owner cleanup on disconnect (loaded as sv_*.lua by DarkRP module loader)
if not SERVER then return end

hook.Add("PlayerDisconnected", "PrinterOwnerCleanup", function(ply)
    for _, ent in ipairs(ents.GetAll()) do
        if ent:GetClass():match("^printer%d+") and IsValid(ent:Getowning_ent()) and ent:Getowning_ent() == ply then
            ent:Setowning_ent(nil)
            print("[PrinterOwnerCleanup] Set owner to nil for " .. ent:GetClass() .. " previously owned by " .. ply:Nick())
        end
    end
end)
