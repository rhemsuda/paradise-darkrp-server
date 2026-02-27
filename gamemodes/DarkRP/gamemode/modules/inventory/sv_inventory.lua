-- sv_inventory.lua  (server)
-- Simple persistence + actions (trimmed but functional)

if not SERVER then return end
AddCSLuaFile("sh_inventory.lua")
AddCSLuaFile("sh_items.lua")
AddCSLuaFile("cl_inventory.lua")
AddCSLuaFile("cl_inventory_loadout.lua")

local USE_SQLITE = true
local DATA_DIR = "inventory_v2"
if not file.IsDir(DATA_DIR, "DATA") then file.CreateDir(DATA_DIR) end

local function sqliteEnsure()
    if not USE_SQLITE then return end
    sql.Query("CREATE TABLE IF NOT EXISTS inv2_state (sid64 TEXT PRIMARY KEY, data TEXT);")
end
sqliteEnsure()

local function sid64(ply) return ply:SteamID64() or ("bot_" .. ply:EntIndex()) end
local function pathFor(ply) return DATA_DIR .. "/" .. sid64(ply) .. ".txt" end
local function makeUID()
    return tostring(util.CRC(tostring(SysTime()) .. tostring(math.Rand(0,1)) .. tostring(math.random(1, 1e9))))
end

local function defaultState()
    return {
        pages = 1,
        items = {},   -- array of {id="pistol", page=1, x=1, y=1, count=1, baseDamage=..., rarity=..., slots=...}
        loadout = { primary=nil, sidearm=nil, armor=nil, boots=nil, utility=nil },
        loadoutInstances = {},  -- slot -> instance table (so unequip returns same baseDamage/rarity/slots)
        resources = { rock=0, iron=0, copper=0, steel=0, titanium=0 },
    }
end

local PlayerInv = PlayerInv or {} -- sid64 -> state
local PlayerWeaponDamage = PlayerWeaponDamage or {} -- sid64 -> class -> damage

local function isOccupied(s, page, x, y)
    for _, it in ipairs(s.items or {}) do
        if (it.page or 1) == page and (it.x or 1) == x and (it.y or 1) == y then return true end
    end
    return false
end

local function findFreeSlot(s)
    local maxPages = s.pages or 1
    for p=1, maxPages do
        for yy=1, Inventory.Config.GRID_H do
            for xx=1, Inventory.Config.GRID_W do
                if not isOccupied(s, p, xx, yy) then return p, xx, yy end
            end
        end
    end
    -- if full, append a new page if allowed
    if (s.pages or 1) < (Inventory.Config.MAX_PAGES or 1) then
        s.pages = (s.pages or 1) + 1
        return s.pages, 1, 1
    end
    -- fallback: place at 1,1 on first page (will overlap)
    return 1, 1, 1
end

local function save(ply)
    local s = PlayerInv[sid64(ply)]
    if not s then return end
    local json = util.TableToJSON(s, true)
    if USE_SQLITE then
        local id = sid64(ply)
        sql.Query("REPLACE INTO inv2_state (sid64, data) VALUES (" .. sql.SQLStr(id) .. ", " .. sql.SQLStr(json) .. ")")
    else
        file.Write(pathFor(ply), json)
    end
end

local inv_svdebug = CreateConVar("inv_svdebug", "0", FCVAR_ARCHIVE, "Inventory server debug prints")

local function plyNotify(ply, msg)
    if not IsValid(ply) or not msg or msg == "" then return end
    net.Start(Inventory.NET.Notify)
        net.WriteString(msg)
    net.Send(ply)
end

-- Helper: spawn a world entity for an inventory instance (define before net handlers that use it)
local function spawnInventoryDropEntity(ply, inst, def)
    if not inst or not inst.id or not def then return nil end
    local pos = IsValid(ply) and (ply:GetShootPos() + ply:GetAimVector() * 30) or Vector(0,0,0)
    local ent = ents.Create("prop_physics")
    if not IsValid(ent) then return nil end
    local model = def.model or (weapons.GetStored(def.class or "") and weapons.GetStored(def.class).WorldModel) or "models/props_junk/PopCan01a.mdl"
    ent:SetModel(model)
    ent:SetPos(pos)
    ent:Spawn()
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) and IsValid(ply) then phys:Wake() phys:SetVelocity(ply:GetAimVector()*120) end
    ent:SetNWString("inv_id", inst.id or "")
    ent:SetNWString("inv_uid", inst.uid or "")
    ent:SetNWString("inv_rarity", inst.rarity or "")
    ent:SetNWInt("inv_slots", inst.slots or 0)
    ent:SetNWString("inv_crafter", inst.crafter or "")
    ent:SetNWBool("inv_admin", inst.admin and true or false)
    ent:SetNWInt("inv_base", inst.baseDamage or 0)
    ent:SetNWInt("inv_count", inst.count or 1)
    ent:SetUseType(SIMPLE_USE)
    ent.IsInventoryDrop = true
    return ent
end

local function load(ply)
    local s = defaultState()
    if USE_SQLITE then
        local id = sid64(ply)
        local row = sql.QueryRow("SELECT data FROM inv2_state WHERE sid64=" .. sql.SQLStr(id) .. " LIMIT 1;")
        if row and row.data then
            local ok, tbl = pcall(util.JSONToTable, row.data or "")
            if ok and istable(tbl) then s = tbl end
        else
            table.insert(s.items, { id="pistol", page=1, x=1, y=1, count=1 })
            table.insert(s.items, { id="medkit", page=1, x=2, y=1, count=2 })
        end
    else
        local p = pathFor(ply)
        if file.Exists(p, "DATA") then
            local ok, tbl = pcall(util.JSONToTable, file.Read(p, "DATA") or "")
            if ok and istable(tbl) then s = tbl end
        else
            table.insert(s.items, { id="pistol", page=1, x=1, y=1, count=1 })
            table.insert(s.items, { id="medkit", page=1, x=2, y=1, count=2 })
        end
    end
    PlayerInv[sid64(ply)] = s
    -- backfill unique uids for items
    for _, it in ipairs(s.items or {}) do if not it.uid or it.uid == "" then it.uid = makeUID() end end
end

local function sendFull(ply)
    local s = PlayerInv[sid64(ply)] or defaultState()
    net.Start(Inventory.NET.SyncInventory)
        net.WriteUInt(s.pages or 1, 8)
        local items = s.items or {}
        net.WriteUInt(#items, 16)
        for _, it in ipairs(items) do
            net.WriteString(it.id or "")
            net.WriteString(it.uid or "")
            net.WriteUInt(it.page or 1, 8)
            net.WriteUInt(it.x or 1, 8)
            net.WriteUInt(it.y or 1, 8)
            net.WriteUInt(it.count or 1, 16)
            net.WriteUInt(math.Clamp(tonumber(it.slots or 0) or 0, 0, 6), 4)
            net.WriteBool(it.admin and true or false)
            net.WriteString(it.crafter or "")
            net.WriteString(it.rarity or "")
            net.WriteUInt(tonumber(it.baseDamage or 0) or 0, 16)
            net.WriteString(it.loadoutSlot or "")
        end
        -- send item catalog once
        local cat = Inventory.SafeItems()
        net.WriteUInt(table.Count(cat), 12)
        for k, v in pairs(cat) do
            net.WriteString(k)
            net.WriteString(v.name or k)
            net.WriteString(v.desc or "")
            net.WriteString(v.icon or "")
            net.WriteString(v.category or "Misc")
            net.WriteString(v.class or "")
            net.WriteString(v.model or "")
            net.WriteString(v.rarity or "")
            net.WriteUInt(tonumber(v.baseDamage or 0) or 0, 16)
        end
    net.Send(ply)

    local lo = s.loadout or {}
    net.Start(Inventory.NET.SyncLoadout)
        net.WriteString(lo.primary or "")
        net.WriteString(lo.sidearm or "")
        net.WriteString(lo.armor or "")
        net.WriteString(lo.boots or "")
        net.WriteString(lo.utility or "")
    net.Send(ply)

    local r = s.resources or {}
    net.Start(Inventory.NET.SyncResources)
        net.WriteUInt(r.rock or 0, 16)
        net.WriteUInt(r.iron or 0, 16)
        net.WriteUInt(r.copper or 0, 16)
        net.WriteUInt(r.steel or 0, 16)
        net.WriteUInt(r.titanium or 0, 16)
    net.Send(ply)
end

hook.Add("PlayerInitialSpawn", "INV_Load", function(ply)
    load(ply)
    timer.Simple(1, function() if IsValid(ply) then sendFull(ply) end end)
end)

-- Admin create item handler (uses exact entered values; no randomization – reserve randomization for crafting)
net.Receive(Inventory.NET.AdminCreateItem, function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local id = net.ReadString() or ""
    local count = net.ReadUInt(16) or 1
    local rarity = net.ReadString() or ""
    local baseDamage = net.ReadUInt(16) or 0
    local isAdminSpawned = net.ReadBool()
    local crafterName = net.ReadString() or ""
    local slots = net.ReadUInt(4) or 0
    local loadoutSlot = net.ReadString() or ""

    if id == "" then return end
    local def = Inventory.Items[id]
    if not def then return end

    local s = PlayerInv[sid64(ply)] or defaultState()
    local p,x,y = findFreeSlot(s)
    local inst = { id=id, uid=makeUID(), page=p, x=x, y=y, count=math.max(1, count), slots=math.Clamp(tonumber(slots or 0) or 0, 0, 6) }
    if rarity ~= "" then inst.rarity = rarity end
    if baseDamage and baseDamage > 0 then inst.baseDamage = baseDamage end
    if isAdminSpawned then inst.admin = true end
    if crafterName ~= "" then inst.crafter = crafterName end
    if loadoutSlot == "primary" or loadoutSlot == "sidearm" then inst.loadoutSlot = loadoutSlot end
    table.insert(s.items, inst)
    PlayerInv[sid64(ply)] = s
    save(ply)
    sendFull(ply)
    ServerLog(string.format("[INV][ADMIN] %s (%s) created %dx %s (rarity=%s, baseDamage=%d)\n", ply:Nick(), ply:SteamID(), count, id, rarity, baseDamage or 0))
end)

-- Admin modify an existing instance by uid
net.Receive(Inventory.NET.AdminModifyItem, function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local uid = net.ReadString() or ""
    local rarity = net.ReadString() or ""
    local baseDamage = net.ReadUInt(16) or 0
    local slots = net.ReadUInt(4) or 0
    local crafter = net.ReadString() or ""
    local admin = net.ReadBool()
    if uid == "" then return end
    local s = PlayerInv[sid64(ply)] or defaultState()
    for _, it in ipairs(s.items or {}) do
        if it.uid == uid then
            if rarity ~= "" then it.rarity = rarity end
            if baseDamage > 0 then it.baseDamage = baseDamage end
            it.slots = math.Clamp(tonumber(slots or 0) or 0, 0, 6)
            if crafter ~= "" then it.crafter = crafter end
            it.admin = admin and true or false
            save(ply)
            sendFull(ply)
            ServerLog(string.format("[INV][ADMIN] %s modified uid=%s (rarity=%s, base=%d, slots=%d)\n", ply:Nick(), uid, rarity, baseDamage, it.slots))
            return
        end
    end
end)

-- Admin delete an instance by uid
net.Receive(Inventory.NET.AdminDeleteInstance, function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local uid = net.ReadString() or ""
    if uid == "" then return end
    local s = PlayerInv[sid64(ply)] or defaultState()
    local keep = {}
    local removed
    for _, it in ipairs(s.items or {}) do
        if it.uid == uid then removed = it else table.insert(keep, it) end
    end
    if removed then
        s.items = keep
        save(ply)
        sendFull(ply)
        ServerLog(string.format("[INV][ADMIN] %s deleted uid=%s id=%s\n", ply:Nick(), uid, removed.id or "?"))
        if IsValid(ply) then ply:ChatPrint(string.format("[Inventory] Deleted %s (uid %s)", removed.id or "?", uid)) end
    end
end)

hook.Add("PlayerDisconnected", "INV_Save", function(ply) save(ply) end)

-- Client asks for a fresh snapshot
net.Receive(Inventory.NET.RequestFull, function(_, ply)
    sendFull(ply)
end)

-- Move item (drag/drop)
net.Receive(Inventory.NET.MoveItem, function(_, ply)
    local s = PlayerInv[sid64(ply)]; if not s then return end
    local uid   = net.ReadString()
    local iid   = net.ReadString() -- type id (unused for lookup)
    local page  = net.ReadUInt(8)
    local x     = net.ReadUInt(8)
    local y     = net.ReadUInt(8)

    if inv_svdebug:GetBool() then
        print(string.format("[INV][SERVER] MoveItem from %s uid=%s id=%s -> p=%d x=%d y=%d", ply:Nick(), tostring(uid), iid, page, x, y))
    end

    -- Prevent overlap: if another (different index) item already occupies x,y on this page, reject
    for j, it in ipairs(s.items) do
        if (it.uid or "") ~= (uid or "") and (it.page or 1) == page and (it.x or 1) == x and (it.y or 1) == y then
            -- conflict; do not move
            if inv_svdebug:GetBool() then print("[INV][SERVER] Move rejected: occupied by index", j) end
            sendFull(ply)
            return
        end
    end

    local matched = false
    for _, it in ipairs(s.items or {}) do
        if (it.uid or "") == (uid or "") then
            local newP = math.Clamp(page, 1, Inventory.Config.MAX_PAGES)
            local newX = math.Clamp(x, 1, Inventory.Config.GRID_W)
            local newY = math.Clamp(y, 1, Inventory.Config.GRID_H)
            it.page, it.x, it.y = newP, newX, newY
            matched = true
            if inv_svdebug:GetBool() then print(string.format("[INV][SERVER] Move accepted uid=%s -> p=%d x=%d y=%d", uid, newP, newX, newY)) end
            break
        end
    end
    if not matched then
        if inv_svdebug:GetBool() then print("[INV][SERVER] MoveItem: uid not found; sending full state") end
    end

    save(ply)
    sendFull(ply)
end)

-- Admin request another player's inventory (by SteamID string)
net.Receive(Inventory.NET.AdminRequestPlayerInv, function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local steamId = net.ReadString() or ""
    local tgt
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == steamId or p:SteamID64() == steamId then tgt = p break end
    end
    if not IsValid(tgt) then return end
    local s = PlayerInv[sid64(tgt)] or defaultState()
    -- Send a compact snapshot to the requesting admin
    net.Start(Inventory.NET.AdminSendPlayerInv)
        net.WriteString(tgt:SteamID())
        net.WriteUInt(#(s.items or {}), 16)
        for _, it in ipairs(s.items or {}) do
            net.WriteString(it.id or "")
            net.WriteString(it.uid or "")
            net.WriteUInt(it.page or 1, 8)
            net.WriteUInt(it.x or 1, 8)
            net.WriteUInt(it.y or 1, 8)
            net.WriteUInt(it.count or 1, 16)
            net.WriteUInt(it.slots or 0, 4)
            net.WriteBool(it.admin and true or false)
            net.WriteString(it.crafter or "")
            net.WriteString(it.rarity or "")
            net.WriteUInt(it.baseDamage or 0, 16)
        end
    net.Send(ply)
end)

-- Admin create item directly for a specific player
net.Receive(Inventory.NET.AdminCreateItemFor, function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local targetSid = net.ReadString() or ""
    local id = net.ReadString() or ""
    local count = net.ReadUInt(16) or 1
    local rarity = net.ReadString() or ""
    local baseDamage = net.ReadUInt(16) or 0
    local isAdminSpawned = net.ReadBool()
    local crafterName = net.ReadString() or ""
    local slots = net.ReadUInt(4) or 0
    local loadoutSlot = net.ReadString() or ""
    local tgt
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == targetSid or p:SteamID64() == targetSid then tgt = p break end
    end
    if not IsValid(tgt) or id == "" then return end
    local def = Inventory.Items[id]; if not def then return end
    local s = PlayerInv[sid64(tgt)] or defaultState()
    local p,x,y = findFreeSlot(s)
    local inst = { id=id, uid=makeUID(), page=p, x=x, y=y, count=math.max(1, count), slots=math.Clamp(tonumber(slots or 0) or 0, 0, 6) }
    if rarity ~= "" then inst.rarity = rarity end
    if baseDamage and baseDamage > 0 then inst.baseDamage = baseDamage end
    if isAdminSpawned then inst.admin = true end
    if crafterName ~= "" then inst.crafter = crafterName end
    if loadoutSlot == "primary" or loadoutSlot == "sidearm" then inst.loadoutSlot = loadoutSlot end
    table.insert(s.items, inst)
    PlayerInv[sid64(tgt)] = s
    save(tgt)
    sendFull(tgt)
    -- logging
    ServerLog(string.format("[INV][ADMIN] %s gave %dx %s to %s (%s) rarity=%s base=%d slots=%d\n",
        ply:Nick(), count, id, tgt:Nick(), tgt:SteamID(), rarity, baseDamage or 0, inst.slots or 0))
    if IsValid(ply) then ply:ChatPrint(string.format("[Inventory] Gave %dx %s to %s", count, id, tgt:Nick())) end
    if IsValid(tgt) then tgt:ChatPrint(string.format("[Inventory] Admin %s gave you %dx %s", ply:Nick(), count, id)) end
    -- Notify requesting admin with a fresh snapshot
    net.Start(Inventory.NET.AdminRequestPlayerInv)
        net.WriteString(targetSid)
    net.Send(ply)
end)

-- Delete (single or multi)
net.Receive(Inventory.NET.DeleteItems, function(_, ply)
    local s = PlayerInv[sid64(ply)]; if not s then return end
    local n = net.ReadUInt(16)
    local toDel = {}
    for i=1,n do toDel[ net.ReadString() ] = true end
    local keep = {}
    local removedCount = 0
    for _, it in ipairs(s.items) do
        if not toDel[it.id] then
            table.insert(keep, it)
        else
            removedCount = removedCount + (it.count or 1)
        end
    end
    s.items = keep
    save(ply)
    sendFull(ply)
    if removedCount > 0 then plyNotify(ply, string.format("Deleted %d item(s)", removedCount)) end
end)

-- Item actions (use/equip/drop) – minimal versions
net.Receive(Inventory.NET.ItemAction, function(_, ply)
    local act = net.ReadString()  -- "use" | "equip" | "unequip" | "drop"
    local id  = net.ReadString()
    local slot= net.ReadString() or ""
    local uid = (act == "equip" and net.ReadString()) or ""

    local s = PlayerInv[sid64(ply)]; if not s then return end
    local def = Inventory.Items[id]
    if not def then return end

    local function chooseSlot(def, requested)
        if requested and requested ~= "" then return requested end
        -- def.sidearm = true lets owners mark primary guns as sidearms (rare crafting outcome)
        if def.sidearm then return Inventory.Slots.SIDEARM end
        if def.class and def.class ~= "" then
            local cls = string.lower(def.class)
            -- Pistol-like: pist, deagle, elite, glock, usp, p228, fiveseven
            if string.find(cls, "pist") or string.find(cls, "deagle") or string.find(cls, "elite") or
               string.find(cls, "glock") or string.find(cls, "usp") or string.find(cls, "p228") or string.find(cls, "fiveseven") then
                return Inventory.Slots.SIDEARM
            end
            return Inventory.Slots.PRIMARY
        end
        return Inventory.Slots.UTILITY
    end

    if act == "equip" then
        slot = chooseSlot(def, slot)
        -- Block equipping if slot already has an item; must unequip first
        if s.loadout[slot] and s.loadout[slot] ~= "" then
            plyNotify(ply, "Unequip the current item from " .. slot .. " first.")
            return
        end
        s.loadout[slot] = id
        s.loadoutInstances = s.loadoutInstances or {}
        -- remove one instance from inventory and store it (prefer UID match so the clicked instance is equipped)
        local instForLoadout = nil
        local idx
        if uid and uid ~= "" then
            for i, it in ipairs(s.items) do
                if it.id == id and (it.uid or "") == uid then idx = i break end
            end
        end
        if not idx then
            for i, it in ipairs(s.items) do if it.id == id then idx = i break end end
        end
        if idx then
            local it = s.items[idx]
            if it.count and it.count > 1 then
                it.count = it.count - 1
                instForLoadout = {
                    id = it.id, uid = makeUID(), page = 0, x = 0, y = 0, count = 1,
                    baseDamage = it.baseDamage, rarity = it.rarity, slots = it.slots,
                    admin = it.admin, crafter = it.crafter,
                }
            else
                instForLoadout = table.remove(s.items, idx)
                if instForLoadout then instForLoadout.count = 1 end
            end
        end
        if instForLoadout then
            s.loadoutInstances[slot] = instForLoadout
        end
        if def.class and def.class ~= "" and ply.Give then ply:Give(def.class) end
        plyNotify(ply, string.format("Equipped %s to %s", def.name or id, slot))
        -- use the instance we equipped for scaled damage (so instance baseDamage/rarity is preserved)
        if def.class and def.class ~= "" and instForLoadout then
            local effRarity = (instForLoadout.rarity and instForLoadout.rarity ~= "") and instForLoadout.rarity or (def.rarity or "")
            local mul = Inventory.GetRarityDamageMultiplier and Inventory.GetRarityDamageMultiplier(effRarity) or 1
            local dmg = math.floor((tonumber(instForLoadout.baseDamage or def.baseDamage or 0) or 0) * mul)
            PlayerWeaponDamage[sid64(ply)] = PlayerWeaponDamage[sid64(ply)] or {}
            PlayerWeaponDamage[sid64(ply)][def.class] = dmg
        end
    elseif act == "unequip" then
        if s.loadout[slot] == id then
            s.loadoutInstances = s.loadoutInstances or {}
            local inst = s.loadoutInstances[slot]
            s.loadout[slot] = nil
            s.loadoutInstances[slot] = nil
            -- return the same instance we stored on equip (keeps baseDamage, rarity, slots)
            local p, x, y = findFreeSlot(s)
            if inst and inst.id then
                inst.page, inst.x, inst.y, inst.count = p, x, y, 1
                table.insert(s.items, inst)
            else
                -- fallback for old saves / missing loadoutInstances
                table.insert(s.items, { id = id, uid = makeUID(), page = p, x = x, y = y, count = 1 })
            end
            if def.class and ply:HasWeapon(def.class) then ply:StripWeapon(def.class) end
            plyNotify(ply, string.format("Unequipped %s (returned to inventory)", def.name or id))
            if def.class and PlayerWeaponDamage[sid64(ply)] then PlayerWeaponDamage[sid64(ply)][def.class] = nil end
        end
    elseif act == "use" then
        -- Example: medkit
        if id == "medkit" then ply:SetHealth(math.min(100, ply:Health() + 25)) end
        -- consume one
        for i, it in ipairs(s.items) do
            if it.id == id and it.count and it.count > 0 then
                it.count = it.count - 1
                if it.count <= 0 then table.remove(s.items, i) end
                break
            end
        end
        plyNotify(ply, string.format("Used %s", def.name or id))
    elseif act == "dropfromloadout" then
        -- Drop equipped item to world (from loadout menu right-click); instance comes from loadoutInstances
        s.loadoutInstances = s.loadoutInstances or {}
        local inst = s.loadoutInstances[slot]
        if s.loadout[slot] == id and inst and inst.id and def then
            s.loadout[slot] = nil
            s.loadoutInstances[slot] = nil
            if def.class and ply:HasWeapon(def.class) then ply:StripWeapon(def.class) end
            if PlayerWeaponDamage[sid64(ply)] then PlayerWeaponDamage[sid64(ply)][def.class] = nil end
            spawnInventoryDropEntity(ply, inst, def)
            plyNotify(ply, string.format("Dropped %s", def.name or id))
        end
    elseif act == "drop" then
        -- Third string (slot var) is the instance UID for drop – do NOT ReadString again or we corrupt the stream
        local uid = (slot and slot ~= "") and slot or ""
        local idx
        for i, it in ipairs(s.items) do
            if it.id == id and (uid == "" or (it.uid and tostring(it.uid) == tostring(uid))) then
                idx = i
                break
            end
        end
        if not idx and uid == "" then
            for i, it in ipairs(s.items) do if it.id == id then idx = i break end end
        end
        -- When client sent a specific uid, never drop a different instance (no silent fallback)
        if uid ~= "" and not idx then
            plyNotify(ply, "That item could not be found. Try refreshing your inventory.")
        end
        if idx then
            local inst = s.items[idx]
            if inst.count and inst.count > 1 then
                inst.count = inst.count - 1
                inst = {
                    id = inst.id, uid = makeUID(), page = 0, x = 0, y = 0, count = 1,
                    baseDamage = inst.baseDamage, rarity = inst.rarity, slots = inst.slots,
                    admin = inst.admin, crafter = inst.crafter,
                }
            else
                table.remove(s.items, idx)
            end
            plyNotify(ply, string.format("Dropped %s", def.name or id))
            spawnInventoryDropEntity(ply, inst, def)
        end
    end

    save(ply)
    sendFull(ply)
end)
-- Scale bullet damage for equipped weapons based on stored rarity-scaled damage
hook.Add("EntityFireBullets", "INV_ScaleDamage", function(ent, data)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    local wep = ent:GetActiveWeapon()
    if not IsValid(wep) then return end
    local class = wep:GetClass()
    local map = PlayerWeaponDamage[sid64(ent)] or {}
    local target = map[class]
    if not target or target <= 0 then return end
    -- Apply as damage override per bullet
    data.Callback = function(att, tr, dmginfo)
        dmginfo:SetDamage(target)
    end
    return true
end)

-- Drop the currently held weapon as an inventory item (for /drop) so UID/stats are preserved and pickup works.
-- Returns true if we handled it (weapon was from our loadout); false to let default DarkRP drop run.
function Inventory.DropHeldWeaponAsItem(ply)
    if not IsValid(ply) then return false end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return false end
    local class = wep:GetClass()
    local s = PlayerInv[sid64(ply)]
    if not s or not s.loadout or not Inventory.Items then return false end
    -- Find which loadout slot has this weapon class
    local foundSlot, foundId, def, inst
    for slot, id in pairs(s.loadout or {}) do
        if not id then continue end
        local d = Inventory.Items[id]
        if d and d.class and d.class == class then
            foundSlot = slot
            foundId = id
            def = d
            inst = (s.loadoutInstances or {})[slot]
            break
        end
    end
    if not foundSlot or not foundId or not def or not inst or not inst.uid then return false end
    -- Remove from loadout and spawn our inventory drop entity
    s.loadout[foundSlot] = nil
    s.loadoutInstances = s.loadoutInstances or {}
    s.loadoutInstances[foundSlot] = nil
    if PlayerWeaponDamage[sid64(ply)] then PlayerWeaponDamage[sid64(ply)][class] = nil end
    ply:StripWeapon(class)
    local ent = spawnInventoryDropEntity(ply, inst, def)
    if not IsValid(ent) then
        -- Put instance back into inventory on failure
        local p, x, y = findFreeSlot(s)
        inst.page, inst.x, inst.y, inst.count = p, x, y, 1
        table.insert(s.items, inst)
        s.loadout[foundSlot] = foundId
        s.loadoutInstances[foundSlot] = inst
        return false
    end
    save(ply)
    sendFull(ply)
    plyNotify(ply, string.format("Dropped %s", def.name or foundId))
    return true
end

-- E to pick up dropped inventory items (handled here so it works even when other addons block entity:Use)
hook.Add("PlayerUse", "INV_PickupDroppedItem", function(ply, ent)
    if not IsValid(ent) or not IsValid(ply) or not ent.IsInventoryDrop then return end
    local id = ent:GetNWString("inv_id", "")
    if id == "" then return end
    local def = Inventory.Items and Inventory.Items[id]
    if not def then return end
    local s = PlayerInv[sid64(ply)] or defaultState()
    local p, x, y = findFreeSlot(s)
    local newInst = {
        id = id,
        uid = makeUID(),
        page = p, x = x, y = y,
        count = math.max(1, ent:GetNWInt("inv_count", 1)),
        slots = ent:GetNWInt("inv_slots", 0),
        baseDamage = ent:GetNWInt("inv_base", 0),
        rarity = ent:GetNWString("inv_rarity", "") or nil,
        crafter = ent:GetNWString("inv_crafter", "") or nil,
        admin = ent:GetNWBool("inv_admin", false) and true or nil,
    }
    if newInst.rarity == "" then newInst.rarity = nil end
    if newInst.crafter == "" then newInst.crafter = nil end
    if newInst.baseDamage and newInst.baseDamage <= 0 then newInst.baseDamage = nil end
    table.insert(s.items, newInst)
    PlayerInv[sid64(ply)] = s
    save(ply)
    sendFull(ply)
    plyNotify(ply, string.format("Picked up %s", def.name or id))
    ent:Remove()
    return false
end)

-- Prevent physgun/pickup interference on dropped items
hook.Add("PhysgunPickup", "INV_BlockPickup", function(ply, ent)
    if IsValid(ent) and ent.IsInventoryDrop then return false end
end)
hook.Add("AllowPlayerPickup", "INV_BlockCarryPickup", function(ply, ent)
    if IsValid(ent) and ent.IsInventoryDrop then return false end
end)

-- Give loadout weapons on spawn (including after job change); runs after job gives default weapons
hook.Add("PlayerLoadout", "INV_GiveLoadoutWeapons", function(ply)
    if not IsValid(ply) or ply:isArrested() then return end
    local s = PlayerInv[sid64(ply)]
    if not s or not s.loadout or not Inventory.Items then return end
    for slot, itemId in pairs(s.loadout) do
        if itemId and itemId ~= "" then
            local def = Inventory.Items[itemId]
            if def and def.class and def.class ~= "" and ply.Give then
                ply:Give(def.class)
                local inst = (s.loadoutInstances or {})[slot]
                if def.class and inst then
                    local effRarity = (inst.rarity and inst.rarity ~= "") and inst.rarity or (def.rarity or "")
                    local mul = Inventory.GetRarityDamageMultiplier and Inventory.GetRarityDamageMultiplier(effRarity) or 1
                    local dmg = math.floor((tonumber(inst.baseDamage or def.baseDamage or 0) or 0) * mul)
                    PlayerWeaponDamage[sid64(ply)] = PlayerWeaponDamage[sid64(ply)] or {}
                    PlayerWeaponDamage[sid64(ply)][def.class] = dmg
                end
            end
        end
    end
end)

-- Clear equipped main weapons on death
hook.Add("PlayerDeath", "INV_ClearEquippedOnDeath", function(ply)
    local s = PlayerInv[sid64(ply)]; if not s then return end
    s.loadout = s.loadout or {}
    s.loadout[Inventory.Slots.PRIMARY] = nil
    s.loadout[Inventory.Slots.SIDEARM] = nil
    -- strip any weapons given by inventory
    for k, def in pairs(Inventory.Items or {}) do
        if def.class and ply:HasWeapon(def.class) then ply:StripWeapon(def.class) end
    end
    save(ply)
    timer.Simple(0, function() if IsValid(ply) then sendFull(ply) end end)
end)

-- Explicit refresh for the separate loadout window
net.Receive(Inventory.NET.RequestLoadout, function(_, ply)
    local s = PlayerInv[sid64(ply)] or defaultState()
    local lo = s.loadout or {}
    net.Start(Inventory.NET.SyncLoadout)
        net.WriteString(lo.primary or "")
        net.WriteString(lo.sidearm or "")
        net.WriteString(lo.armor or "")
        net.WriteString(lo.boots or "")
        net.WriteString(lo.utility or "")
    net.Send(ply)
end)

-- API for other modules (e.g. rpammo): get weapon classes from player's loadout
function Inventory.GetPlayerLoadoutWeapons(ply)
    if not IsValid(ply) then return {} end
    local s = PlayerInv[sid64(ply)]
    if not s or not s.loadout then return {} end
    local weapons = {}
    for slot, itemId in pairs(s.loadout) do
        if itemId and itemId ~= "" then
            local def = Inventory.Items and Inventory.Items[itemId]
            if def and def.class and def.class ~= "" then
                table.insert(weapons, { class = def.class, name = def.name or itemId })
            end
        end
    end
    return weapons
end

-- Admin/dev helper: give an item to yourself for testing
-- Usage: inv_giveitem <item_id> [count]
concommand.Add("inv_giveitem", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local id = string.lower(tostring(args[1] or ""))
    local count = tonumber(args[2] or 1) or 1
    if id == "" then ply:ChatPrint("Usage: inv_giveitem <item_id> [count]") return end
    -- Case-insensitive id resolution to support legacy names
    if not Inventory.Items[id] then
        for k in pairs(Inventory.Items) do
            if string.lower(k) == id then id = k break end
            local def = Inventory.Items[k]
            if def and def.aliases then
                for _, a in ipairs(def.aliases) do if string.lower(a) == id then id = k break end end
            end
        end
    end
    if not Inventory.Items[id] then
        ply:ChatPrint("Unknown item id: "..tostring(args[1]))
        return
    end
    local s = PlayerInv[sid64(ply)] or defaultState()
    s.items = s.items or {}
    local p,x,y = findFreeSlot(s)
    table.insert(s.items, { id=id, uid=makeUID(), page=p, x=x, y=y, count=math.max(1, count) })
    PlayerInv[sid64(ply)] = s
    save(ply)
    sendFull(ply)
    -- Admin log broadcast to admins
    for _, admin in ipairs(player.GetAll()) do
        if admin:IsAdmin() then
            admin:ChatPrint(string.format("[INV] %s (%s) gave self %dx %s", ply:Nick(), ply:SteamID(), count, id))
        end
    end
end)

-- Make /drop drop the held weapon as an inventory item (same as dropping from inventory UI).
-- Runs after entity scripts so we can override dropDRPWeapon.
timer.Simple(0, function()
    local meta = FindMetaTable("Player")
    if not meta then return end
    local old_dropDRPWeapon = meta.dropDRPWeapon
    if not old_dropDRPWeapon then return end
    function meta:dropDRPWeapon(weapon)
        if not IsValid(weapon) or weapon:GetOwner() ~= self then return end
        if Inventory and Inventory.DropHeldWeaponAsItem and Inventory.DropHeldWeaponAsItem(self) then
            -- DropHeldWeaponAsItem already StripWeapon'd; remove entity if still present
            if IsValid(weapon) then weapon:Remove() end
            return
        end
        return old_dropDRPWeapon(self, weapon)
    end
end)