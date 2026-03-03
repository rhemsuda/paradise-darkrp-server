-- cl_inventory_loadout.lua – separate Loadout window (CLIENT ONLY)
-- Open: inv_loadout_open or +inv_loadout (hold B by default). Close: release key (-inv_loadout) or X button.

if not CLIENT then return end

local LFRAME
local IsOpen = false

local slots = { "primary", "sidearm", "armor", "boots", "utility" }
local pretty = { primary="Primary", sidearm="Sidearm", armor="Armor", boots="Boots", utility="Utility" }
local current = { primary="", sidearm="", armor="", boots="", utility="" }

local function buildUI()
    if IsValid(LFRAME) then LFRAME:Remove() end

    LFRAME = vgui.Create("DFrame")
    LFRAME:SetSize(520, 380)
    LFRAME:SetPos(10, (ScrH()-380)/2)
    LFRAME:SetTitle("Loadout")
    LFRAME:SetDraggable(true)
    LFRAME:ShowCloseButton(true)
    LFRAME:MakePopup()
    IsOpen = true
    function LFRAME:Paint(w,h)
        surface.SetDrawColor(20,20,22,245) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(70,70,80,255) surface.DrawOutlinedRect(0,0,w,h,2)
    end

    function LFRAME:OnClose()
        IsOpen = false
    end

    -- Left: player model
    local left = vgui.Create("DPanel", LFRAME)
    left:Dock(LEFT)
    left:DockMargin(10,10,6,10)
    left:SetWide(220)
    function left:Paint(w,h)
        surface.SetDrawColor(22,22,22,240) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(60,60,60,255) surface.DrawOutlinedRect(0,0,w,h,1)
    end

    local mdl = vgui.Create("DModelPanel", left)
    mdl:Dock(FILL)
    local mdlPath = LocalPlayer():GetModel() or "models/player/kleiner.mdl"
    mdl:SetModel(mdlPath)
    mdl:SetFOV(32)

    -- Nice camera for humans (FOV 32 so full model visible)
    timer.Simple(0, function()
        if not IsValid(mdl) or not IsValid(mdl.Entity) then return end
        local ent = mdl.Entity
        local mn, mx = ent:GetRenderBounds()
        local center = (mn + mx) * 0.5
        local size = math.max(math.abs(mn.x-mx.x), math.abs(mn.y-mx.y), math.abs(mn.z-mx.z))
        mdl:SetLookAt(center)
        mdl:SetCamPos(center + Vector(size*0.9, 0, size*0.6))
    end)

    -- drag to rotate
    function mdl:DragMousePress()
        self.PressX, self.PressY = gui.MousePos()
        self.Pressed = true
    end
    function mdl:DragMouseRelease() self.Pressed = false end
    function mdl:LayoutEntity(ent)
        if self.Pressed then
            local mx = gui.MousePos()
            ent:SetAngles(Angle(0, (self.PressX - mx) * 0.5, 0))
        end
    end

    -- Right: slots list
    local right = vgui.Create("DPanel", LFRAME)
    right:Dock(FILL)
    right:DockMargin(6,10,10,10)
    function right:Paint(w,h)
        surface.SetDrawColor(25,25,27,255) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(60,60,60,255) surface.DrawOutlinedRect(0,0,w,h,1)
    end

    local slotList = vgui.Create("DPanel", right)
    slotList:Dock(FILL)
    slotList:DockMargin(10,10,10,10)

    local slotSize = 48
    local catalog = (Inventory and Inventory.Client and Inventory.Client.ItemsCatalog) or (Inventory and Inventory.Items) or {}

    for _, s in ipairs(slots) do
        local row = vgui.Create("DPanel", slotList)
        row:Dock(TOP)
        row:DockMargin(0,0,0,6)
        row:SetTall(slotSize + 8)
        function row:Paint(w,h)
            surface.SetDrawColor(30,30,30,255) surface.DrawRect(0,0,w,h)
            surface.SetDrawColor(70,70,70,255) surface.DrawOutlinedRect(0,0,w,h,1)
        end

        local lbl = vgui.Create("DLabel", row)
        lbl:Dock(LEFT)
        lbl:DockMargin(10,0,10,0)
        lbl:SetWide(100)
        lbl:SetFont("DermaDefaultBold")
        lbl:SetText(pretty[s] .. ":")

        -- Equipped item: model or icon; click = unequip, right-click = drop with confirm
        local itemId = current[s]
        local def = (itemId and itemId ~= "" and (catalog[itemId] or (Inventory and Inventory.Items and Inventory.Items[itemId]))) or nil
        local iconPanel = vgui.Create("DPanel", row)
        iconPanel:Dock(LEFT)
        iconPanel:SetWide(slotSize + 8)
        iconPanel:DockMargin(4, 4, 4, 4)
        iconPanel._itemId = itemId
        iconPanel._def = def
        iconPanel._slotName = s
        iconPanel.Paint = function(self, w, h)
            surface.SetDrawColor(50, 50, 54, 255)
            surface.DrawRect(2, 2, w - 4, h - 4)
            surface.SetDrawColor(80, 80, 90, 255)
            surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
        end
        local modelPath = def and (def.model or "") or ""
        if (not modelPath or modelPath == "") and def and def.class and weapons and weapons.GetStored then
            local swep = weapons.GetStored(def.class)
            if swep and swep.WorldModel and swep.WorldModel ~= "" then modelPath = swep.WorldModel end
        end
        if def and modelPath ~= "" and string.match(string.lower(modelPath), "^models/") then
            local modelPnl = vgui.Create("DModelPanel", iconPanel)
            modelPnl:Dock(FILL)
            modelPnl:DockMargin(2, 2, 2, 2)
            modelPnl:SetModel(modelPath)
            modelPnl:SetFOV(50)
            modelPnl:SetMouseInputEnabled(false)
            function modelPnl:LayoutEntity() return end
            -- Frame weapon model in view (weapon world models vary; use render bounds)
            timer.Simple(0.1, function()
                if not IsValid(modelPnl) or not IsValid(modelPnl.Entity) then return end
                local ent = modelPnl.Entity
                local mn, mx = ent:GetRenderBounds()
                local center = (mn + mx) * 0.5
                local size = math.max(math.abs(mn.x - mx.x), math.abs(mn.y - mx.y), math.abs(mn.z - mx.z), 20)
                modelPnl:SetLookAt(center)
                modelPnl:SetCamPos(center + Vector(size * 1.2, size * 0.3, size * 0.5))
            end)
        else
            local iconLabel = vgui.Create("DLabel", iconPanel)
            iconLabel:Dock(FILL)
            iconLabel:SetContentAlignment(5)
            if def then
                local matPath = def.icon or (def.class and def.class ~= "" and "icon16/gun.png") or "icon16/box.png"
                local ok, mat = pcall(Material, matPath)
                if ok and mat then
                    iconLabel:SetText("")
                    iconLabel.Paint = function(_, iw, ih)
                        surface.SetDrawColor(255, 255, 255, 255)
                        surface.SetMaterial(mat)
                        local sz = math.min(iw - 8, ih - 8, 48)
                        surface.DrawTexturedRect((iw - sz) / 2, (ih - sz) / 2, sz, sz)
                    end
                else
                    iconLabel:SetText(def.name or itemId or "?")
                    iconLabel:SetTextColor(Color(220, 220, 220))
                end
            elseif itemId and itemId ~= "" then
                iconLabel:SetText(itemId)
                iconLabel:SetTextColor(Color(180, 180, 180))
            else
                iconLabel:SetText("<empty>")
                iconLabel:SetTextColor(Color(120, 120, 120))
            end
        end
        -- Tooltip: inventory-style DPanel on hover (same look as inventory item tooltip)
        local tip
        iconPanel.OnCursorEntered = function(self)
            if not self._def then return end
            if IsValid(tip) then tip:Remove() end
            local d = self._def
            local inst = (Inventory.Client and Inventory.Client.LoadoutInstances and self._slotName) and Inventory.Client.LoadoutInstances[self._slotName] or nil
            local effectiveRarity = (inst and inst.rarity and inst.rarity ~= "") and inst.rarity or (d.rarity or "")
            local rc = (Inventory and Inventory.GetRarityColor and Inventory.GetRarityColor(effectiveRarity)) or Color(255, 255, 255)
            local tipW, tipH = 280, 100
            local sx, sy = self:LocalToScreen(self:GetWide() + 8, 0)
            tip = vgui.Create("DPanel")
            tip:SetSize(tipW, tipH)
            tip:SetPos(sx, sy)
            tip:SetZPos(10001)
            tip:SetDrawOnTop(true)
            tip.Paint = function(_, tw, th)
                draw.RoundedBox(4, 0, 0, tw, th, Color(30, 30, 30, 245))
                surface.SetDrawColor(70, 70, 80, 255)
                surface.DrawOutlinedRect(0, 0, tw, th, 1)
                if effectiveRarity == "Epic" or effectiveRarity == "Legendary" or effectiveRarity == "Unique" then
                    surface.SetDrawColor(rc.r, rc.g, rc.b, 60)
                    surface.DrawOutlinedRect(1, 1, tw - 2, th - 2, 2)
                end
                local nameStr = (effectiveRarity ~= "" and (effectiveRarity .. " ") or "") .. (d.name or itemId or "?")
                draw.SimpleText(nameStr, "DermaDefaultBold", 10, 8, rc)
                local y = 28
                if d.class and d.class ~= "" then
                    local bd = (inst and inst.baseDamage and inst.baseDamage > 0) and inst.baseDamage or (tonumber(d.baseDamage or 0) or 0)
                    local mul = (Inventory and Inventory.GetRarityDamageMultiplier and Inventory.GetRarityDamageMultiplier(effectiveRarity or "")) or 1
                    draw.SimpleText("Damage: " .. math.floor(bd * mul), "DermaDefault", 10, y, Color(170, 220, 120))
                    y = y + 18
                end
                if d.desc and d.desc ~= "" then
                    draw.SimpleText(d.desc, "DermaDefault", 10, y, Color(200, 200, 200))
                end
            end
        end
        iconPanel.OnCursorExited = function()
            if IsValid(tip) then tip:Remove() tip = nil end
        end
        iconPanel.OnRemove = function()
            if IsValid(tip) then tip:Remove() end
        end

        -- Left-click = unequip (return to inventory). Right-click removed to avoid drop error.
        iconPanel.OnMousePressed = function(self, code)
            if not self._itemId or self._itemId == "" then return end
            if code == MOUSE_LEFT then
                net.Start(Inventory.NET.ItemAction)
                    net.WriteString("unequip")
                    net.WriteString(current[s])
                    net.WriteString(s)
                net.SendToServer()
                net.Start(Inventory.NET.RequestLoadout)
                net.SendToServer()
            end
        end
    end
end

-- Shared loadout state for cl_inventory (so Equip menu knows which slots are filled)
Inventory.Client = Inventory.Client or {}
Inventory.Client.Loadout = Inventory.Client.Loadout or { primary="", sidearm="", armor="", boots="", utility="" }

-- Update from server (does NOT open the window)
net.Receive(Inventory.NET.SyncLoadout, function()
    current.primary = net.ReadString()
    current.sidearm = net.ReadString()
    current.armor   = net.ReadString()
    current.boots   = net.ReadString()
    current.utility = net.ReadString()
    -- Per-slot instance data (rarity, baseDamage) so tooltip shows e.g. Epic M249 not def "Rare"
    local instSlots = { "primary", "sidearm", "armor", "boots", "utility" }
    Inventory.Client.LoadoutInstances = Inventory.Client.LoadoutInstances or {}
    for _, slot in ipairs(instSlots) do
        local r = net.ReadString() or ""
        local bd = net.ReadUInt(16) or 0
        Inventory.Client.LoadoutInstances[slot] = (r ~= "" or bd > 0) and { rarity = r ~= "" and r or nil, baseDamage = bd } or nil
    end

    -- Expose for cl_inventory (equip menu: don't offer Equip if slot is filled)
    Inventory.Client.Loadout = {
        primary = current.primary or "",
        sidearm = current.sidearm or "",
        armor   = current.armor or "",
        boots   = current.boots or "",
        utility = current.utility or "",
    }

    if IsOpen and IsValid(LFRAME) then
        -- rebuild so labels refresh
        buildUI()
    end
    -- notify any embedded panels to update
    hook.Run("InventoryLoadoutChanged")
end)

-- Console command to open (tap or from bind)
concommand.Add("inv_loadout_open", function()
    if not IsOpen then buildUI() else if IsValid(LFRAME) then LFRAME:MakePopup() end end
    net.Start(Inventory.NET.RequestLoadout) net.SendToServer()
end)

-- Hold-to-open: +inv_loadout on key down, -inv_loadout on key release. Default bind: B.
concommand.Add("+inv_loadout", function()
    if not IsOpen then buildUI() end
    if IsValid(LFRAME) then LFRAME:SetVisible(true) LFRAME:MakePopup() end
    net.Start(Inventory.NET.RequestLoadout) net.SendToServer()
end, nil, "Open loadout (hold key)", FCVAR_DONTRECORD)

concommand.Add("-inv_loadout", function()
    Inventory_Loadout_Close()
end, nil, "Close loadout (release key)", FCVAR_DONTRECORD)

function Inventory_Loadout_Open()
    if not IsOpen then buildUI() else if IsValid(LFRAME) then LFRAME:SetVisible(true) LFRAME:MakePopup() end end
    net.Start(Inventory.NET.RequestLoadout) net.SendToServer()
end

function Inventory_Loadout_Close()
    if IsValid(LFRAME) then LFRAME:Remove() LFRAME = nil end
    IsOpen = false
end

-- If loadout was opened by context menu key (C), close it when that key is released.
hook.Add("OnContextMenuClose", "Inventory_Loadout_CloseOnContextRelease", function()
    if IsOpen then Inventory_Loadout_Close() end
end)

-- B key = loadout window (shows equipped weapons: primary, sidearm, armor, boots, utility).
-- Hold B to open, release to close. We poll the key instead of using the bind command so we
-- don't trigger "Command is blocked! (bind)" on servers that block bind.
local lastB = false
hook.Add("Think", "Inventory_Loadout_B_Key", function()
    if not LocalPlayer or not IsValid(LocalPlayer()) then return end
    -- Don't react to B when typing (chat, console, etc.)
    local focus = vgui.GetKeyboardFocus()
    if IsValid(focus) and focus:IsValid() then lastB = input.IsKeyDown(KEY_B or 66) return end
    local b = input.IsKeyDown(KEY_B or 66)
    if b and not lastB then
        Inventory_Loadout_Open()
    elseif not b and lastB then
        Inventory_Loadout_Close()
    end
    lastB = b
end)

--
-- Spawnmenu support: panelized loadout view
--
function Inventory.BuildLoadoutPanel(parent)
    if not IsValid(parent) then return end

    local frame = vgui.Create("DPanel", parent)
    frame:Dock(FILL)

    local left = vgui.Create("DPanel", frame)
    left:Dock(LEFT)
    left:DockMargin(10,10,6,10)
    left:SetWide(280)
    function left:Paint(w,h)
        surface.SetDrawColor(22,22,22,240) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(60,60,60,255) surface.DrawOutlinedRect(0,0,w,h,1)
    end

    local mdl = vgui.Create("DModelPanel", left)
    mdl:Dock(FILL)
    local mdlPath = LocalPlayer():GetModel() or "models/player/kleiner.mdl"
    mdl:SetModel(mdlPath)
    mdl:SetFOV(32)
    timer.Simple(0, function()
        if not IsValid(mdl.Entity) then return end
        local ent = mdl.Entity
        local headPos = ent:LocalToWorld(ent:OBBCenter()) + Vector(0,0,8)
        mdl:SetLookAt(headPos)
        mdl:SetCamPos(headPos + Vector(60, 0, 5))
    end)

    local right = vgui.Create("DPanel", frame)
    right:Dock(FILL)
    right:DockMargin(6,10,10,10)

    local slots = { "primary", "sidearm", "armor", "boots", "utility" }
    local pretty = { primary="Primary", sidearm="Sidearm", armor="Armor", boots="Boots", utility="Utility" }

    local function rebuild()
        right:Clear()
        for _, s in ipairs(slots) do
            local row = vgui.Create("DPanel", right)
            row:Dock(TOP)
            row:DockMargin(0,0,0,6)
            row:SetTall(50)
            function row:Paint(w,h)
                surface.SetDrawColor(30,30,30,255) surface.DrawRect(0,0,w,h)
                surface.SetDrawColor(70,70,70,255) surface.DrawOutlinedRect(0,0,w,h,1)
            end

            local lbl = vgui.Create("DLabel", row)
            lbl:Dock(LEFT)
            lbl:DockMargin(10,0,10,0)
            lbl:SetWide(120)
            lbl:SetFont("DermaDefaultBold")
            lbl:SetText(pretty[s] .. ":")

            local name = vgui.Create("DPanel", row)
            name:Dock(FILL)
            name:DockMargin(8,8,8,8)
            name.Paint = function(self,w,h) end
            local icon = vgui.Create("DModelPanel", name)
            icon:Dock(LEFT)
            icon:SetWide(56)
            icon:SetMouseInputEnabled(true)
            local function refreshEquipped()
                local id = current[s]
                if id == "" then icon:SetVisible(false); return end
                local def = (Inventory and Inventory.Items and Inventory.Items[id]) or ((Inventory and Inventory.Client and Inventory.Client.ItemsCatalog or {})[id])
                icon:SetVisible(true)
                local modelPath = def and (def.model or "") or ""
                if (not modelPath or modelPath == "") and def and def.class and weapons and weapons.GetStored then
                    local swep = weapons.GetStored(def.class)
                    if swep and swep.WorldModel and swep.WorldModel ~= "" then modelPath = swep.WorldModel end
                end
                -- Only set model if path is valid (GMod expects "models/..."; "Entities/Props/Jobs/..." etc. show as missing)
                if modelPath ~= "" and string.match(string.lower(modelPath), "^models/") then
                    icon:SetModel(modelPath)
                end
                icon:SetFOV(18); function icon:LayoutEntity() return end
            end
            refreshEquipped()
            icon.OnCursorEntered = function()
                local id = current[s]
                if id == "" then return end
                local def = (Inventory and Inventory.Items and Inventory.Items[id]) or ((Inventory and Inventory.Client and Inventory.Client.ItemsCatalog or {})[id])
                if not def then return end
                local tip = vgui.Create("DPanel")
                local tw,th = 300, 120
                local sx, sy = icon:LocalToScreen(icon:GetWide()+8, 0)
                tip:SetSize(tw,th)
                tip:SetPos(sx, sy)
                tip:SetDrawOnTop(true)
                tip.Paint = function(self,w,h)
                    draw.RoundedBox(4,0,0,w,h, Color(30,30,30,245))
                    surface.SetDrawColor(70,70,80,255) surface.DrawOutlinedRect(0,0,w,h,1)
                    local rarity = def.rarity or ""
                    local rc = Inventory.GetRarityColor and Inventory.GetRarityColor(rarity) or color_white
                    draw.SimpleText((rarity ~= "" and (rarity.." ") or "") .. (def.name or id), "DermaDefaultBold", 10, 8, rc)
                    draw.SimpleText(def.desc or "", "DermaDefault", 10, 28, Color(220,220,220))
                end
                icon._tip = tip
            end
            icon.OnCursorExited = function() if IsValid(icon._tip) then icon._tip:Remove() end end

            icon.OnMousePressed = function(self, code)
                if current[s] == "" then return end
                if code == MOUSE_LEFT then
                    net.Start(Inventory.NET.ItemAction)
                        net.WriteString("unequip")
                        net.WriteString(current[s])
                        net.WriteString(s)
                    net.SendToServer()
                    net.Start(Inventory.NET.RequestLoadout)
                    net.SendToServer()
                end
            end
        end
    end

    -- initial snapshot
    net.Start(Inventory.NET.RequestLoadout) net.SendToServer()
    timer.Simple(0, rebuild)

    -- live updates
    local unique = "InventoryLoadoutChanged_" .. tostring(frame)
    hook.Add("InventoryLoadoutChanged", unique, function()
        if not IsValid(frame) then hook.Remove("InventoryLoadoutChanged", unique) return end
        rebuild()
    end)
    frame.OnRemove = function()
        hook.Remove("InventoryLoadoutChanged", unique)
    end

    return frame
end