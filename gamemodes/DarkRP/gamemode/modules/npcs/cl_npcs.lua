--[[---------------------------------------------------------------------------
  Paradise NPCs — Client. Open menu with Missions and Shop tabs.
  Content (quest lines, shop items) comes from sh_npc_content.lua; admins cannot change it in-game.
---------------------------------------------------------------------------]]
if not CLIENT then return end

-- Ref for admin NPC spawn editor list (updated when server sends spawn list)
Paradise.NPCSpawnListView = nil

net.Receive("Admin_SendNPCSpawns", function()
    if not IsValid(Paradise.NPCSpawnListView) then return end
    local list = Paradise.NPCSpawnListView
    list:Clear()
    local n = net.ReadUInt(16)
    for i = 1, n do
        local pos = net.ReadVector()
        local ang = net.ReadAngle()
        local npcType = net.ReadString()
        local model = net.ReadString()
        local posStr = string.format("%.0f, %.0f, %.0f", pos.x, pos.y, pos.z)
        list:AddLine(i, npcType, posStr, model)
    end
end)

-- Styling for NPC menu (same colors across gamemode). Dark theme for DLists.
local MENU_W, MENU_H = 580, 368
local LIST_W = 270
local LIST_HEADER = Color(42, 50, 64, 255)
local LIST_BG = Color(38, 44, 58, 255)
local LIST_ROW = Color(46, 52, 68, 255)
local LIST_ROW_ALT = Color(42, 48, 62, 255)
local LIST_ROW_SEL = Color(58, 72, 92, 255)
-- List text: white for readability; yellow = in progress, green = completed (future).
local LIST_TEXT = Color(255, 255, 255)
local LIST_TEXT_ACCEPTED = Color(255, 220, 100)
local LIST_TEXT_COMPLETED = Color(120, 255, 120)
-- Safe set text/color on a panel (DListView_Line has child labels; they may use SetColor or SetTextColor).
local function setPanelChildColors(panel, color)
    if not IsValid(panel) or not color then return end
    for _, c in ipairs(panel:GetChildren() or {}) do
        if IsValid(c) then
            if type(c.SetTextColor) == "function" then c:SetTextColor(color) end
            if type(c.SetColor) == "function" then c:SetColor(color) end
        end
    end
end
local function npcNotify(msg)
    net.Start("Paradise_NPCNotify")
    net.WriteString(msg)
    net.SendToServer()
end
local MENU_BG = Color(28, 34, 44, 252)
local MENU_PANEL_BG = Color(36, 42, 54, 255)
local MENU_BORDER = Color(60, 72, 88, 255)
local MENU_HEADER_BG = Color(42, 50, 64, 255)
local MENU_ACCENT = Color(70, 140, 200, 255)
local NPC_MENU_CLOSE_DIST = 160

-- Client-side mission status (New/Accepted/Completed); synced from server when opening menu.
Paradise.NPCs.AcceptedMissions = Paradise.NPCs.AcceptedMissions or {}
Paradise.NPCs.CompletedMissions = Paradise.NPCs.CompletedMissions or {}
-- Crafter staged state (synced from server on Open and after Add Resources)
Paradise.CrafterStaged = Paradise.CrafterStaged or { blueprintId = "", resources = {} }
net.Receive("Crafter_StagedUpdate", function()
    Paradise.CrafterStaged.blueprintId = net.ReadString() or ""
    Paradise.CrafterStaged.resources = net.ReadTable() or {}
end) -- [mission_id] = npc_type

local function getMissionStatus(missionId)
    if Paradise.NPCs.CompletedMissions and Paradise.NPCs.CompletedMissions[missionId] then return "Completed" end
    if Paradise.NPCs.AcceptedMissions and Paradise.NPCs.AcceptedMissions[missionId] then return "Accepted" end
    return "New"
end

net.Receive("Paradise_NPCOpenMenu", function()
    local npcType = net.ReadString() or "generic"
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end
    -- Server sends accepted then completed mission IDs (persisted per player; survives rejoin).
    Paradise.NPCs.AcceptedMissions = {}
    local n = net.ReadUInt(16)
    for i = 1, n do
        local id = net.ReadString()
        if id and #id > 0 then Paradise.NPCs.AcceptedMissions[id] = true end
    end
    Paradise.NPCs.CompletedMissions = {}
    n = net.ReadUInt(16)
    for i = 1, n do
        local id = net.ReadString()
        local ntype = net.ReadString() or "generic"
        if id and #id > 0 then Paradise.NPCs.CompletedMissions[id] = ntype end
    end

    local displayName = Paradise.NPCs and Paradise.NPCs.GetDisplayName and Paradise.NPCs.GetDisplayName(npcType) or npcType
    local missionLines = Paradise.NPCs and Paradise.NPCs.GetMissionLines and Paradise.NPCs.GetMissionLines(npcType) or {}
    local shop = Paradise.NPCs and Paradise.NPCs.GetShop and Paradise.NPCs.GetShop(npcType) or {}
    local typeNames = Paradise.NPCs and Paradise.NPCs.MissionTypes or {}

    local frame = vgui.Create("DFrame")
    frame:SetSize(MENU_W, MENU_H)
    frame:Center()
    frame:SetTitle(" " .. displayName)
    frame:SetVisible(true)
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    frame._npcEnt = ent
    frame.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, MENU_BG)
        surface.SetDrawColor(MENU_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.RoundedBox(4, 2, 2, w - 4, 22, MENU_HEADER_BG)
    end
    -- Close menu when player moves away from NPC.
    frame.Think = function(self)
        if not IsValid(ent) or not IsValid(LocalPlayer()) then self:Close() return end
        local dist = LocalPlayer():GetPos():Distance(ent:GetPos())
        if dist > NPC_MENU_CLOSE_DIST then
            self:Close()
        end
    end

    -- ========== Crafter: single page only (no Missions/Shop tabs) ==========
    if npcType == "crafter" then
        if Crafting and Crafting.BuildRecipes then Crafting.BuildRecipes() end
        frame:SetSize(720, 480)
        net.Start("Crafter_Open")
        net.SendToServer()

        frame.OnClose = function(self)
            net.Start("Crafter_Close")
            net.SendToServer()
        end

        -- Defensive: ensure we have tables so loops never error (menu can still open with empty lists)
        local catalog = (Inventory and Inventory.Items) or {}
        local items = (Inventory and Inventory.Client and Inventory.Client.Items) or {}
        if type(items) ~= "table" then items = {} end
        if type(catalog) ~= "table" then catalog = {} end
        local pouch = Paradise.PlayerResources or {}
        local stagedResources = function() return Paradise.CrafterStaged and Paradise.CrafterStaged.resources or {} end
        local stagedBlueprintId = function() return Paradise.CrafterStaged and Paradise.CrafterStaged.blueprintId or "" end
        local slotBlueprintId, slotBlueprintUid, slotBlueprintName = "", "", ""
        local craftingInProgress = false
        local craftProgressStart = 0
        local craftDuration = 5
        local pendingCraftResult = nil

        -- Staged state is updated by global Crafter_StagedUpdate receiver into Paradise.CrafterStaged

        local main = vgui.Create("DPanel", frame)
        main:Dock(FILL)
        main:DockMargin(2, 20, 2, 2)
        main.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, MENU_PANEL_BG) end

        local ok, err = pcall(function()
        local craftSplit = vgui.Create("DPanel", main)
        craftSplit:Dock(FILL)
        craftSplit:DockMargin(6, 6, 6, 6)
        craftSplit.Paint = function() end

        local leftPanel = vgui.Create("DPanel", craftSplit)
        leftPanel:Dock(LEFT)
        leftPanel:SetWide(200)
        leftPanel.Paint = function() end

        local rarityFilter = nil -- nil = All, or "Common", "Rare", "Unique", "Epic", "Legendary"
        local raritiesOrder = (Inventory and Inventory.Rarities) or { "Common", "Rare", "Unique", "Epic", "Legendary" }

        -- Filter button first (Dock TOP) so layout is correct; DoClick set after buildCrafterBlueprintList exists
        local rarityFilterBtn = vgui.Create("DButton", leftPanel)
        rarityFilterBtn:Dock(TOP)
        rarityFilterBtn:SetTall(28)
        rarityFilterBtn:DockMargin(0, 0, 0, 4)
        rarityFilterBtn:SetText("Only show: All")
        rarityFilterBtn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 46, 58))
            surface.SetDrawColor(MENU_BORDER)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        rarityFilterBtn.UpdateAppearance = function(self)
            local label = rarityFilter and ("Only show: " .. rarityFilter) or "Only show: All"
            self:SetText(label)
            local col = (rarityFilter and Inventory and Inventory.GetRarityColor and Inventory.GetRarityColor(rarityFilter)) or Color(200, 205, 215)
            self:SetColor(col)
        end
        rarityFilterBtn:UpdateAppearance()

        local scroll = vgui.Create("DScrollPanel", leftPanel)
        scroll:Dock(FILL)
        scroll.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, LIST_BG) end
        local iconSize = 56
        local grid = vgui.Create("DIconLayout", scroll)
        grid:Dock(FILL)
        grid:DockMargin(4, 4, 4, 4)
        grid:SetSpaceX(4)
        grid:SetSpaceY(4)
        local function updateBlueprintListVisibility()
            for _, pnl in ipairs(grid:GetChildren()) do
                if IsValid(pnl) and pnl._uid then
                    pnl:SetVisible(pnl._uid ~= slotBlueprintUid or slotBlueprintUid == "")
                end
            end
            if IsValid(grid) and grid.InvalidateLayout then grid:InvalidateLayout(true) end
        end
        -- Rebuild the left blueprint list from current inventory (so right-click "put back" shows the blueprint again)
        local function buildCrafterBlueprintList()
            for _, c in ipairs(grid:GetChildren()) do c:Remove() end
            local itemsList = (Inventory and Inventory.Client and Inventory.Client.Items) or {}
            if type(itemsList) ~= "table" then itemsList = {} end
            for _, inst in ipairs(itemsList) do
            if inst.id and string.sub(inst.id, 1, 10) == "blueprint_" then
                local def = catalog[inst.id]
                if def then
                    -- Blueprint list shows all blueprints; "Only show" filter affects only the claim popup after crafting
                    local pnl = vgui.Create("DPanel", grid)
                    pnl:SetSize(iconSize, iconSize)
                    pnl._bpId = inst.id
                    pnl._uid = inst.uid or ""
                    pnl._inst = inst
                    pnl.Paint = function(self, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, Color(46, 52, 68))
                        surface.SetDrawColor(MENU_BORDER)
                        surface.DrawOutlinedRect(0, 0, w, h, 1)
                    end
                    -- Same icon as inventory: blueprint uses def.model (binder) with FOV 70
                    local modelPath = (def.model and def.model ~= "" and string.match(string.lower(def.model), "^models/")) and def.model or nil
                    if not modelPath then
                        local resultId = (Crafting and Crafting.GetResultItemId and Crafting.GetResultItemId(inst.id)) or nil
                        if resultId then
                            local resultDef = (Inventory and Inventory.Items and Inventory.Items[resultId]) or catalog[resultId]
                            modelPath = (resultDef and resultDef.model) or ""
                            if (not modelPath or modelPath == "") and resultDef and resultDef.class and weapons and weapons.GetStored then
                                local swep = weapons.GetStored(resultDef.class)
                                if swep and swep.WorldModel and swep.WorldModel ~= "" then modelPath = swep.WorldModel end
                            end
                        end
                    end
                    if modelPath and modelPath ~= "" and string.match(string.lower(modelPath), "^models/") then
                        local mdlp = vgui.Create("DModelPanel", pnl)
                        mdlp:SetPos(2, 2)
                        mdlp:SetSize(iconSize - 4, iconSize - 4)
                        mdlp:SetMouseInputEnabled(false)
                        mdlp:SetModel(modelPath)
                        mdlp:SetFOV(70)
                        function mdlp:LayoutEntity() return end
                        if IsValid(mdlp.Entity) then
                            local mn, mx = mdlp.Entity:GetRenderBounds()
                            local size = math.max(math.abs(mn.x)+math.abs(mx.x), math.abs(mn.y)+math.abs(mx.y), math.abs(mn.z)+math.abs(mx.z))
                            mdlp:SetCamPos(Vector(size*0.9, size*1.1, size*0.8))
                            mdlp:SetLookAt((mn + mx) * 0.5)
                        end
                    else
                        local icon = vgui.Create("DImage", pnl)
                        local isz = iconSize - 8
                        icon:SetSize(isz, isz)
                        icon:SetPos(4, 4)
                        icon:SetImage(def.icon or "icon16/page_white_text.png")
                    end
                    -- Hover tooltip like inventory: rarity border, name, damage range, and result weapon model
                    pnl.OnCursorEntered = function(self)
                        if IsValid(self._tip) then self._tip:Remove() end
                        local sx, sy = self:LocalToScreen(self:GetWide() + 8, 0)
                        local lx, ly = main:ScreenToLocal(sx, sy)
                        local tip = vgui.Create("DPanel", main)
                        tip:SetPos(lx, ly)
                        tip:SetSize(220, 200)
                        tip:SetZPos(10000)
                        tip:SetDrawOnTop(true)
                        local d = catalog[self._bpId]
                        local resultId = (Crafting and Crafting.GetResultItemId and Crafting.GetResultItemId(self._bpId)) or nil
                        local resultDef = resultId and ((Inventory and Inventory.Items and Inventory.Items[resultId]) or catalog[resultId])
                        local dmgMin = tonumber((resultDef and resultDef.damageMin) or 0) or 0
                        local dmgMax = tonumber((resultDef and resultDef.damageMax) or 0) or 0
                        if dmgMin <= 0 or dmgMax <= 0 then
                            local bd = tonumber((resultDef and resultDef.baseDamage) or 0) or 0
                            dmgMin, dmgMax = bd - 2, bd + 2
                        end
                        local maxMul = (Inventory and Inventory.RarityDamageMul and Inventory.RarityDamageMul.Legendary) or 1.90
                        local nameStr = (d and d.name) and (d.name:gsub(" Weapon Blueprint%s*$", " BP")) or self._bpId
                        local instRef = self._inst
                        -- Result weapon model (e.g. AWP) like inventory blueprint tooltip
                        local modelPath = (resultDef and resultDef.model) or ""
                        if (not modelPath or modelPath == "") and resultDef and resultDef.class and weapons and weapons.GetStored then
                            local swep = weapons.GetStored(resultDef.class)
                            if swep and swep.WorldModel and swep.WorldModel ~= "" then modelPath = swep.WorldModel end
                        end
                        if modelPath and modelPath ~= "" and string.match(string.lower(modelPath), "^models/") then
                            local mdlp = vgui.Create("DModelPanel", tip)
                            mdlp:SetPos(10, 28)
                            mdlp:SetSize(120, 140)
                            mdlp:SetModel(modelPath)
                            mdlp:SetFOV(52)
                            mdlp:SetMouseInputEnabled(false)
                            function mdlp:LayoutEntity() return end
                            if IsValid(mdlp.Entity) then
                                local mn, mx = mdlp.Entity:GetRenderBounds()
                                local size = math.max(math.abs(mn.x)+math.abs(mx.x), math.abs(mn.y)+math.abs(mx.y), math.abs(mn.z)+math.abs(mx.z))
                                mdlp:SetCamPos(Vector(size*0.9, size*1.1, size*0.8))
                                mdlp:SetLookAt((mn + mx) * 0.5)
                            end
                        end
                        tip.Paint = function(_, tw, th)
                            draw.RoundedBox(4, 0, 0, tw, th, Color(30, 30, 30, 245))
                            surface.SetDrawColor(70, 70, 80, 255)
                            surface.DrawOutlinedRect(0, 0, tw, th, 1)
                            local effRarity = (instRef and instRef.rarity and instRef.rarity ~= "") and instRef.rarity or (d and d.rarity or "") or ""
                            local rc = (Inventory and Inventory.GetRarityColor and Inventory.GetRarityColor(effRarity)) or Color(120, 120, 120)
                            surface.SetDrawColor(rc.r, rc.g, rc.b, 200)
                            surface.DrawOutlinedRect(1, 1, tw - 2, th - 2, 1)
                            local rarityText = (effRarity ~= "" and (effRarity .. " ") or "")
                            draw.SimpleText(rarityText .. nameStr, "DermaDefaultBold", 10, 8, Color(255, 255, 255))
                            local maxDmg = math.floor(dmgMax * maxMul)
                            draw.SimpleText("Damage range: " .. tostring(dmgMin) .. "–" .. tostring(maxDmg), "DermaDefault", tw - 10, 28, Color(170, 220, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                        end
                        self._tip = tip
                    end
                    pnl.OnCursorExited = function(self)
                        if IsValid(self._tip) then self._tip:Remove() self._tip = nil end
                    end
                    pnl:Droppable("crafter_blueprint")
                    pnl.OnMousePressed = function(self, code)
                        if code == MOUSE_LEFT then
                            self:MouseCapture(true)
                            self:SetZPos(9999)
                            self:DragMousePress(code)
                        end
                    end
                    pnl.OnMouseReleased = function(self, code)
                        if code == MOUSE_LEFT then
                            self:DragMouseRelease(code)
                            self:MouseCapture(false)
                            self:SetZPos(0)
                        end
                    end
                    if inst.count and inst.count > 1 then
                        local lbl = vgui.Create("DLabel", pnl)
                        lbl:SetText("x" .. tostring(inst.count))
                        lbl:SetPos(iconSize - 26, iconSize - 20)
                        lbl:SetSize(24, 12)
                        lbl:SetContentAlignment(6)
                        lbl:SetColor(LIST_TEXT)
                        lbl:SetFont("DermaDefault")
                    end
                end
            end
            end
            if IsValid(grid) and grid.InvalidateLayout then grid:InvalidateLayout(true) end
        end
        buildCrafterBlueprintList()

        -- DoClick must be set after buildCrafterBlueprintList is defined (Lua forward-reference)
        rarityFilterBtn.DoClick = function()
            if not next(raritiesOrder) then return end
            if rarityFilter == nil then
                rarityFilter = raritiesOrder[1]
            else
                local idx
                for i, r in ipairs(raritiesOrder) do if r == rarityFilter then idx = i break end end
                if idx and idx < #raritiesOrder then
                    rarityFilter = raritiesOrder[idx + 1]
                else
                    rarityFilter = nil
                end
            end
            rarityFilterBtn:UpdateAppearance()
            buildCrafterBlueprintList()
            if IsValid(scroll) then scroll:InvalidateLayout(true) end
            if IsValid(grid) then grid:InvalidateLayout(true) end
        end

        local rightPanel = vgui.Create("DPanel", craftSplit)
        rightPanel:Dock(FILL)
        rightPanel:DockMargin(8, 0, 0, 0)
        rightPanel.Paint = function() end

        local dropZone = vgui.Create("DPanel", rightPanel)
        dropZone:Dock(TOP)
        dropZone:SetTall(112)
        dropZone:DockMargin(0, 0, 0, 6)
        dropZone.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 36, 46, 240))
            surface.SetDrawColor(MENU_BORDER)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
            if slotBlueprintId == "" then
                draw.SimpleText("Drag a blueprint here", "DermaDefault", w / 2, h / 2 - 6, Color(200, 205, 215), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        -- Right-click in drop zone puts blueprint back to the list (rebuild list so it shows again)
        dropZone.OnMousePressed = function(self, code)
            if code == MOUSE_RIGHT and slotBlueprintId ~= "" then
                slotBlueprintId = ""
                slotBlueprintUid = ""
                slotBlueprintName = ""
                updateDropZoneIcon()
                net.Start("Crafter_SetBlueprint")
                net.WriteString("")
                net.SendToServer()
                if Inventory and Inventory.NET and Inventory.NET.RequestFull then
                    net.Start(Inventory.NET.RequestFull)
                    net.SendToServer()
                end
                -- Defer rebuild + layout so blueprint reappears in left list (panel refresh)
                timer.Simple(0, function()
                    if not IsValid(frame) then return end
                    buildCrafterBlueprintList()
                    if IsValid(scroll) then scroll:InvalidateLayout(true) end
                    if IsValid(grid) then grid:InvalidateLayout(true) end
                end)
            end
        end
        -- Build drop-zone hover tip (used by drop zone and by overlay when blueprint is in zone)
        local function showDropZoneHoverTip()
            if slotBlueprintId == "" then return end
            if IsValid(dropZone._tip) then dropZone._tip:Remove() end
            local sx, sy = dropZone:LocalToScreen(dropZone:GetWide() + 8, 0)
            local lx, ly = main:ScreenToLocal(sx, sy)
            local tip = vgui.Create("DPanel", main)
            tip:SetPos(lx, ly)
            tip:SetSize(220, 200)
            tip:SetZPos(10000)
            tip:SetDrawOnTop(true)
            local d = catalog[slotBlueprintId]
            local resultId = (Crafting and Crafting.GetResultItemId and Crafting.GetResultItemId(slotBlueprintId)) or nil
            local resultDef = resultId and ((Inventory and Inventory.Items and Inventory.Items[resultId]) or catalog[resultId])
            local dmgMin = tonumber((resultDef and resultDef.damageMin) or 0) or 0
            local dmgMax = tonumber((resultDef and resultDef.damageMax) or 0) or 0
            if dmgMin <= 0 or dmgMax <= 0 then
                local bd = tonumber((resultDef and resultDef.baseDamage) or 0) or 0
                dmgMin, dmgMax = bd - 2, bd + 2
            end
            local maxMul = (Inventory and Inventory.RarityDamageMul and Inventory.RarityDamageMul.Legendary) or 1.90
            local nameStr = (d and d.name) and (d.name:gsub(" Weapon Blueprint%s*$", " BP")) or slotBlueprintId
            local modelPath = (resultDef and resultDef.model) or ""
            if (not modelPath or modelPath == "") and resultDef and resultDef.class and weapons and weapons.GetStored then
                local swep = weapons.GetStored(resultDef.class)
                if swep and swep.WorldModel and swep.WorldModel ~= "" then modelPath = swep.WorldModel end
            end
            if modelPath and modelPath ~= "" and string.match(string.lower(modelPath), "^models/") then
                local mdlp = vgui.Create("DModelPanel", tip)
                mdlp:SetPos(10, 28)
                mdlp:SetSize(120, 140)
                mdlp:SetModel(modelPath)
                mdlp:SetFOV(52)
                mdlp:SetMouseInputEnabled(false)
                function mdlp:LayoutEntity() return end
                if IsValid(mdlp.Entity) then
                    local mn, mx = mdlp.Entity:GetRenderBounds()
                    local size = math.max(math.abs(mn.x)+math.abs(mx.x), math.abs(mn.y)+math.abs(mx.y), math.abs(mn.z)+math.abs(mx.z))
                    mdlp:SetCamPos(Vector(size*0.9, size*1.1, size*0.8))
                    mdlp:SetLookAt((mn + mx) * 0.5)
                end
            end
            tip.Paint = function(_, tw, th)
                draw.RoundedBox(4, 0, 0, tw, th, Color(30, 30, 30, 245))
                surface.SetDrawColor(70, 70, 80, 255)
                surface.DrawOutlinedRect(0, 0, tw, th, 1)
                local rc = (Inventory and Inventory.GetRarityColor and Inventory.GetRarityColor(d and d.rarity or "")) or Color(120, 120, 120)
                surface.SetDrawColor(rc.r, rc.g, rc.b, 200)
                surface.DrawOutlinedRect(1, 1, tw - 2, th - 2, 1)
                local rarityText = (d and d.rarity and d.rarity ~= "" and (d.rarity .. " ")) or ""
                draw.SimpleText(rarityText .. nameStr, "DermaDefaultBold", 10, 8, Color(255, 255, 255))
                local maxDmg = math.floor(dmgMax * maxMul)
                draw.SimpleText("Damage range: " .. tostring(dmgMin) .. "–" .. tostring(maxDmg), "DermaDefault", tw - 10, 28, Color(170, 220, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end
            dropZone._tip = tip
        end
        local function hideDropZoneHoverTip()
            if IsValid(dropZone._tip) then dropZone._tip:Remove() dropZone._tip = nil end
        end
        -- Update drop zone to show blueprint icon when one is set; clear when none. Overlay so hover works when icon is present.
        local function updateDropZoneIcon()
            for _, c in ipairs(dropZone:GetChildren()) do c:Remove() end
            hideDropZoneHoverTip()
            if slotBlueprintId == "" then return end
            local def = catalog[slotBlueprintId]
            if not def then return end
            local modelPath = (def.model and def.model ~= "" and string.match(string.lower(def.model), "^models/")) and def.model or nil
            if not modelPath then
                local resultId = (Crafting and Crafting.GetResultItemId and Crafting.GetResultItemId(slotBlueprintId)) or nil
                if resultId then
                    local resultDef = (Inventory and Inventory.Items and Inventory.Items[resultId]) or catalog[resultId]
                    modelPath = (resultDef and resultDef.model) or ""
                    if (not modelPath or modelPath == "") and resultDef and resultDef.class and weapons and weapons.GetStored then
                        local swep = weapons.GetStored(resultDef.class)
                        if swep and swep.WorldModel and swep.WorldModel ~= "" then modelPath = swep.WorldModel end
                    end
                end
            end
            local zw, zh = dropZone:GetWide(), dropZone:GetTall()
            if modelPath and modelPath ~= "" and string.match(string.lower(modelPath), "^models/") then
                local mdlp = vgui.Create("DModelPanel", dropZone)
                local sz = math.min(zw, zh) - 12
                mdlp:SetPos((zw - sz) / 2, (zh - sz) / 2)
                mdlp:SetSize(sz, sz)
                mdlp:SetModel(modelPath)
                mdlp:SetFOV(70)
                mdlp:SetMouseInputEnabled(false)
                function mdlp:LayoutEntity() return end
                if IsValid(mdlp.Entity) then
                    local mn, mx = mdlp.Entity:GetRenderBounds()
                    local size = math.max(math.abs(mn.x)+math.abs(mx.x), math.abs(mn.y)+math.abs(mx.y), math.abs(mn.z)+math.abs(mx.z))
                    mdlp:SetCamPos(Vector(size*0.9, size*1.1, size*0.8))
                    mdlp:SetLookAt((mn + mx) * 0.5)
                end
            else
                local img = vgui.Create("DImage", dropZone)
                local sz = 56
                img:SetPos((zw - sz) / 2, (zh - sz) / 2)
                img:SetSize(sz, sz)
                img:SetImage(def.icon or "icon16/page_white_text.png")
            end
            -- Full-size overlay so hover works when blueprint is in zone (icon would block drop zone cursor)
            local overlay = vgui.Create("DPanel", dropZone)
            overlay:Dock(FILL)
            overlay:SetZPos(10)
            overlay.Paint = function() end
            overlay.OnCursorEntered = function() showDropZoneHoverTip() end
            overlay.OnCursorExited = function() hideDropZoneHoverTip() end
            overlay.OnMousePressed = function(_, code)
                if code == MOUSE_RIGHT and slotBlueprintId ~= "" then
                    slotBlueprintId = ""
                    slotBlueprintUid = ""
                    slotBlueprintName = ""
                    updateDropZoneIcon()
                    net.Start("Crafter_SetBlueprint")
                    net.WriteString("")
                    net.SendToServer()
                    if Inventory and Inventory.NET and Inventory.NET.RequestFull then
                        net.Start(Inventory.NET.RequestFull)
                        net.SendToServer()
                    end
                    timer.Simple(0, function()
                        if not IsValid(frame) then return end
                        buildCrafterBlueprintList()
                        if IsValid(scroll) then scroll:InvalidateLayout(true) end
                        if IsValid(grid) then grid:InvalidateLayout(true) end
                    end)
                end
            end
        end
        -- Use shared hover tip for drop zone when empty area is hovered (no blueprint in zone)
        dropZone.OnCursorEntered = function(self)
            if slotBlueprintId == "" then return end
            showDropZoneHoverTip()
        end
        dropZone.OnCursorExited = function(self)
            hideDropZoneHoverTip()
        end
        dropZone:Receiver("crafter_blueprint", function(self, panels, dropped)
            if not dropped or not panels or #panels == 0 then return end
            local p = panels[1]
            if IsValid(p) and p._bpId then
                slotBlueprintId = p._bpId
                slotBlueprintUid = p._uid or ""
                slotBlueprintName = (catalog[p._bpId] and catalog[p._bpId].name) or p._bpId
                updateBlueprintListVisibility()
                updateDropZoneIcon()
                net.Start("Crafter_SetBlueprint")
                net.WriteString(slotBlueprintId)
                net.SendToServer()
            end
        end)

        -- Progress bar and craft button below the draggable area (progressBar must exist before craftBtn.DoClick so closure sees it)
        local progressBar = vgui.Create("DPanel", rightPanel)
        progressBar:Dock(TOP)
        progressBar:SetTall(24)
        progressBar:DockMargin(0, 0, 0, 6)
        progressBar:SetVisible(false)
        progressBar.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(20, 24, 32))
            local frac = craftingInProgress and math.Clamp((CurTime() - craftProgressStart) / craftDuration, 0, 1) or 0
            draw.RoundedBox(4, 0, 0, w * frac, h, MENU_ACCENT)
        end

        local craftBtn = vgui.Create("DButton", rightPanel)
        craftBtn:Dock(BOTTOM)
        craftBtn:SetTall(24)
        craftBtn:DockMargin(0, 6, 0, 0)
        craftBtn:SetText("Craft")
        craftBtn:SetVisible(false)
        craftBtn:SetEnabled(false)
        craftBtn.DoClick = function()
            if slotBlueprintId == "" or slotBlueprintUid == "" then npcNotify("Need a blueprint in the slot.") return end
            if craftingInProgress then return end
            local recipe = Crafting and Crafting.GetRecipe(slotBlueprintId) or {}
            local st = stagedResources()
            local canCraft = true
            for resId, need in pairs(recipe) do
                if (st[resId] or 0) < need then canCraft = false break end
            end
            if not canCraft then npcNotify("Add more resources first.") return end
            craftingInProgress = true
            craftProgressStart = CurTime()
            progressBar:SetVisible(true)
            net.Start("Crafter_Craft")
            net.WriteString(slotBlueprintId)
            net.WriteString(slotBlueprintUid)
            net.SendToServer()
        end

        -- When inventory sync is received (e.g. after craft, put-back, RequestFull): rebuild list and clear slot if blueprint stack was fully consumed
        local hookName = "Crafter_RebuildOnSync"
        hook.Add("Inventory_Synced", hookName, function()
            if not IsValid(frame) then hook.Remove("Inventory_Synced", hookName) return end
            -- If slot has a blueprint UID but it's no longer in inventory (stack was fully consumed), clear the slot
            if slotBlueprintUid ~= "" then
                local items = Inventory and Inventory.Client and Inventory.Client.Items
                local found = false
                if items then
                    for _, inst in ipairs(items) do
                        if (inst.uid or "") == slotBlueprintUid then found = true break end
                    end
                end
                if not found then
                    slotBlueprintId = ""
                    slotBlueprintUid = ""
                    slotBlueprintName = ""
                    net.Start("Crafter_SetBlueprint")
                    net.WriteString("")
                    net.SendToServer()
                    if IsValid(dropZone) then updateDropZoneIcon() end
                end
            end
            buildCrafterBlueprintList()
            if IsValid(grid) then updateBlueprintListVisibility() end
            if IsValid(scroll) then scroll:InvalidateLayout(true) end
            if IsValid(grid) then grid:InvalidateLayout(true) end
        end)
        local oldOnClose = frame.OnClose
        frame.OnClose = function(self)
            hook.Remove("Inventory_Synced", hookName)
            if oldOnClose then oldOnClose(self) end
        end

        local recipePanel = vgui.Create("DPanel", rightPanel)
        recipePanel:Dock(TOP)
        recipePanel:DockMargin(0, 0, 0, 6)
        recipePanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 36, 46, 240)) end
        local recipeLabel = vgui.Create("DLabel", recipePanel)
        recipeLabel:SetPos(8, 6)
        recipeLabel:SetText("Materials")
        recipeLabel:SetColor(Color(200, 205, 215))
        local fillBtn = vgui.Create("DButton", recipePanel)
        fillBtn:SetPos(76, 4)
        fillBtn:SetSize(24, 22)
        fillBtn:SetText("")
        fillBtn:SetTooltip("Fill from pouch")
        fillBtn.Paint = function(self, w, h)
            if not self:IsEnabled() then return end
            draw.RoundedBox(2, 0, 0, w, h, self:IsHovered() and Color(70, 80, 100) or Color(50, 56, 70))
            surface.SetDrawColor(MENU_BORDER)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        local fillIcon = vgui.Create("DImage", fillBtn)
        fillIcon:SetSize(16, 16)
        fillIcon:Center()
        fillIcon:SetImage("icon16/add.png")
        fillIcon:SetMouseInputEnabled(false)
        fillBtn.DoClick = function()
            if slotBlueprintId == "" then npcNotify("Drag a blueprint first.") return end
            if craftingInProgress then return end
            net.Start("Crafter_AddResources")
            net.WriteString(slotBlueprintId)
            net.SendToServer()
        end
        fillBtn:SetVisible(false)
        local contentWrap = vgui.Create("DPanel", recipePanel)
        contentWrap:SetPos(8, 24)
        contentWrap:SetSize(500, 220)
        contentWrap.Paint = function() end
        local recipeContent = vgui.Create("DPanel", contentWrap)
        recipeContent:SetPos(0, 0)
        recipeContent:SetSize(260, 1)
        recipeContent.Paint = function() end
        local blueprintInfoPanel = vgui.Create("DPanel", contentWrap)
        blueprintInfoPanel:SetPos(268, 0)
        blueprintInfoPanel:SetSize(220, 200)
        blueprintInfoPanel:SetVisible(false)
        blueprintInfoPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 245))
            surface.SetDrawColor(70, 70, 80, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        local lastRecipeKey = ""
        local lastBlueprintInfoKey = ""
        local function refreshRecipeDisplay()
            local st = stagedResources()
            local key = slotBlueprintId .. "|"
            for k, v in pairs(st) do key = key .. k .. "=" .. tostring(v) .. ";" end
            if key == lastRecipeKey then return end
            lastRecipeKey = key
            for _, c in ipairs(recipeContent:GetChildren()) do c:Remove() end
            recipeContent:SetTall(1)
            if fillBtn then fillBtn:SetVisible(slotBlueprintId ~= "") end
            if blueprintInfoPanel then blueprintInfoPanel:SetVisible(false) end
            local resDisplay = Paradise.ResourceDisplay or {}
            if slotBlueprintId == "" then
                contentWrap:SetTall(1)
                recipePanel:SetTall(24 + 6 + 6)
                return
            end
            if not Crafting or not Crafting.GetRecipe then return end
            local recipe = Crafting.GetRecipe(slotBlueprintId)
            local st = stagedResources()
            local iconSz = 52
            local rowH = iconSz + 4
            local y = 0
            local canCraft = true
            local sorted = {}
            for resId, need in pairs(recipe) do table.insert(sorted, { id = resId, need = need }) end
            table.sort(sorted, function(a, b) return (a.id or "") < (b.id or "") end)
            for _, entry in ipairs(sorted) do
                local resId, need = entry.id, entry.need
                local staged = st[resId] or 0
                if staged < need then canCraft = false end
                local info = resDisplay[resId] or { name = resId, icon = "models/props_junk/rock001a.mdl", color = Color(200, 200, 200), material = nil }
                local row = vgui.Create("DPanel", recipeContent)
                row:SetPos(0, y)
                row:SetSize(260, rowH)
                row.Paint = function() end
                local iconPath = info.icon or "models/props_junk/rock001a.mdl"
                local col = info.color
                local mat = info.material
                if string.match(string.lower(iconPath), "^icon") then
                    local img = vgui.Create("DImage", row)
                    img:SetPos(0, 2)
                    img:SetSize(iconSz, iconSz)
                    img:SetImage(iconPath)
                else
                    local mdl = vgui.Create("DModelPanel", row)
                    mdl:SetPos(0, 2)
                    mdl:SetSize(iconSz, iconSz)
                    mdl:SetModel(iconPath)
                    mdl:SetFOV(32)
                    mdl:SetCamPos(Vector(30, 30, 30))
                    mdl:SetLookAt(Vector(0, 0, 0))
                    mdl:SetMouseInputEnabled(false)
                    function mdl:LayoutEntity() return end
                    -- Same as Q menu resources tab: SetMaterial on entity, SetColor on panel (reflective models/shiny)
                    timer.Simple(0, function()
                        if not IsValid(mdl) then return end
                        if IsValid(mdl.Entity) then
                            if mat and mat ~= "" then mdl.Entity:SetMaterial(mat) end
                        end
                        if col and mdl.SetColor then mdl:SetColor(col) end
                    end)
                    mdl.Think = function(self)
                        if not IsValid(self.Entity) then return end
                        if mat and mat ~= "" then self.Entity:SetMaterial(mat) end
                        if col and self.SetColor then self:SetColor(col) end
                    end
                end
                -- Overlay: material name top-left, count "0/4" on the icon (bottom-right)
                local overlay = vgui.Create("DPanel", row)
                overlay:SetPos(0, 2)
                overlay:SetSize(iconSz, iconSz)
                overlay.Paint = function(_, ow, oh)
                    local nameStr = info.name or resId
                    local countStr = tostring(staged) .. "/" .. tostring(need)
                    draw.SimpleText(nameStr, "DermaDefault", 4, 4, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.RoundedBox(4, ow - 36, oh - 18, 34, 16, Color(0, 0, 0, 180))
                    draw.SimpleText(countStr, "DermaDefault", ow - 4, oh - 4, staged >= need and Color(120, 255, 120) or Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
                end
                overlay:SetMouseInputEnabled(false)
                y = y + rowH
            end
            recipeContent:SetTall(math.max(1, y))
            if fillBtn then fillBtn:SetVisible(slotBlueprintId ~= "") end
            if craftBtn then craftBtn:SetVisible(slotBlueprintId ~= "") craftBtn:SetEnabled(canCraft) end
            -- Blueprint info panel beside materials (always visible when blueprint is set, no hover needed)
            if blueprintInfoPanel then
                if slotBlueprintId == "" then
                    blueprintInfoPanel:SetVisible(false)
                else
                    local key = slotBlueprintId
                    if key ~= lastBlueprintInfoKey then
                        lastBlueprintInfoKey = key
                        for _, c in ipairs(blueprintInfoPanel:GetChildren()) do c:Remove() end
                        local d = catalog[slotBlueprintId]
                        local resultId = (Crafting and Crafting.GetResultItemId and Crafting.GetResultItemId(slotBlueprintId)) or nil
                        local resultDef = resultId and ((Inventory and Inventory.Items and Inventory.Items[resultId]) or catalog[resultId])
                        local dmgMin = tonumber((resultDef and resultDef.damageMin) or 0) or 0
                        local dmgMax = tonumber((resultDef and resultDef.damageMax) or 0) or 0
                        if dmgMin <= 0 or dmgMax <= 0 then
                            local bd = tonumber((resultDef and resultDef.baseDamage) or 0) or 0
                            dmgMin, dmgMax = bd - 2, bd + 2
                        end
                        local maxMul = (Inventory and Inventory.RarityDamageMul and Inventory.RarityDamageMul.Legendary) or 1.90
                        local nameStr = (d and d.name) and (d.name:gsub(" Weapon Blueprint%s*$", " BP")) or slotBlueprintId
                        local modelPath = (resultDef and resultDef.model) or ""
                        if (not modelPath or modelPath == "") and resultDef and resultDef.class and weapons and weapons.GetStored then
                            local swep = weapons.GetStored(resultDef.class)
                            if swep and swep.WorldModel and swep.WorldModel ~= "" then modelPath = swep.WorldModel end
                        end
                        if modelPath and modelPath ~= "" and string.match(string.lower(modelPath), "^models/") then
                            local mdlp = vgui.Create("DModelPanel", blueprintInfoPanel)
                            mdlp:SetPos(10, 28)
                            mdlp:SetSize(120, 140)
                            mdlp:SetModel(modelPath)
                            mdlp:SetFOV(52)
                            mdlp:SetMouseInputEnabled(false)
                            function mdlp:LayoutEntity() return end
                            if IsValid(mdlp.Entity) then
                                local mn, mx = mdlp.Entity:GetRenderBounds()
                                local size = math.max(math.abs(mn.x)+math.abs(mx.x), math.abs(mn.y)+math.abs(mx.y), math.abs(mn.z)+math.abs(mx.z))
                                mdlp:SetCamPos(Vector(size*0.9, size*1.1, size*0.8))
                                mdlp:SetLookAt((mn + mx) * 0.5)
                            end
                        end
                        blueprintInfoPanel.PaintOver = function(_, tw, th)
                            local rarityText = (d and d.rarity and d.rarity ~= "" and (d.rarity .. " ")) or ""
                            draw.SimpleText(rarityText .. nameStr, "DermaDefaultBold", 10, 8, Color(255, 255, 255))
                            local maxDmg = math.floor(dmgMax * maxMul)
                            draw.SimpleText("Damage: " .. tostring(dmgMin) .. "–" .. tostring(maxDmg), "DermaDefault", 10, 172, Color(170, 220, 120))
                        end
                    end
                    blueprintInfoPanel:SetVisible(true)
                end
                local contentH = math.max(recipeContent:GetTall(), blueprintInfoPanel:IsVisible() and 200 or 0)
                contentWrap:SetTall(contentH)
                recipePanel:SetTall(24 + contentH + 6)
            else
                contentWrap:SetTall(math.max(1, y))
                recipePanel:SetTall(24 + math.max(1, y) + 6)
            end
        end
        recipePanel.Think = function(self)
            pouch = Paradise.PlayerResources or {}
            refreshRecipeDisplay()
            -- Update craft button every frame from current staged state (so it appears as soon as all materials are green)
            if slotBlueprintId ~= "" and craftBtn and Crafting and Crafting.GetRecipe then
                local recipe = Crafting.GetRecipe(slotBlueprintId)
                local st = stagedResources()
                local canCraft = true
                for resId, need in pairs(recipe or {}) do
                    if (st[resId] or 0) < need then canCraft = false break end
                end
                craftBtn:SetVisible(true)
                craftBtn:SetEnabled(canCraft)
            end
        end

        -- Defined before net.Receive so the callback can call it even if the server responds before we finish building the UI
        local function showCraftResultPopup(data)
            if not data then return end
            local resultName = data.resultName or data.resultId or ""
            local rarity = data.rarity or ""
            local model = data.model or ""
            local slots = data.slots or 0
            local crafterName = data.crafterName or ""

            local hasSlots = slots and slots > 0
            local mdlW, mdlH = 280, 240
            local popupW = math.max(320, mdlW + 24)
            local popupH = (hasSlots and 400 or 360)
            local popup = vgui.Create("DFrame")
            popup:SetSize(popupW, popupH)
            popup:Center()
            popup:SetTitle(" ")
            popup:SetDraggable(true)
            popup:ShowCloseButton(false)
            popup:MakePopup()
            popup.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, MENU_BG)
                surface.SetDrawColor(MENU_BORDER)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
            end

            local rarityColor = (Inventory and Inventory.RarityColors and Inventory.RarityColors[rarity]) or Color(255, 255, 255)
            local titleStr = (rarity ~= "" and (rarity .. " " .. resultName)) or resultName
            local nameLbl = vgui.Create("DLabel", popup)
            nameLbl:SetPos(12, 8)
            nameLbl:SetSize(popupW - 24, 28)
            nameLbl:SetText(titleStr)
            nameLbl:SetColor(rarityColor)
            nameLbl:SetFont("TargetID")
            nameLbl:SetContentAlignment(5)

            -- Glow behind model: smaller, cascaded layers (more elegant)
            local glowPad = 16
            local glowPanel = vgui.Create("DPanel", popup)
            glowPanel:SetPos((popupW - mdlW - glowPad * 2) / 2, 36 - glowPad / 2)
            glowPanel:SetSize(mdlW + glowPad * 2, mdlH + glowPad * 2)
            glowPanel:SetMouseInputEnabled(false)
            glowPanel.Paint = function(self, gw, gh)
                local rc, gc, bc = rarityColor.r, rarityColor.g, rarityColor.b
                local ins = 4
                draw.RoundedBox(12, 0, 0, gw, gh, Color(rc, gc, bc, 28))
                draw.RoundedBox(14, ins, ins, gw - ins * 2, gh - ins * 2, Color(rc, gc, bc, 18))
                draw.RoundedBox(16, ins * 2, ins * 2, gw - ins * 4, gh - ins * 4, Color(rc, gc, bc, 10))
                draw.RoundedBox(18, ins * 3, ins * 3, gw - ins * 6, gh - ins * 6, Color(rc, gc, bc, 4))
            end

            local mdl = vgui.Create("DModelPanel", popup)
            mdl:SetPos((popupW - mdlW) / 2, 36)
            mdl:SetSize(mdlW, mdlH)
            mdl:SetModel(model ~= "" and model or "models/props_junk/PopCan01a.mdl")
            mdl:SetFOV(32)
            mdl:SetAmbientLight(Color(80, 80, 80))
            mdl:SetDirectionalLight(BOX_TOP, Color(180, 180, 180))
            mdl:SetDirectionalLight(BOX_FRONT, Color(120, 120, 120))
            function mdl:LayoutEntity()
                if IsValid(self.Entity) then
                    -- Slightly turned to show the side of the weapon
                    self.Entity:SetAngles(Angle(0, 130, 0))
                    local mn, mx = self.Entity:GetRenderBounds()
                    local size = math.max(mn:Distance(mx) * 0.6, 10)
                    self:SetCamPos(Vector(size * 0.9, size * 1.2, size * 0.7))
                    self:SetLookAt((mn + mx) * 0.5)
                end
                return
            end

            local yNext = 36 + mdlH + 8
            if hasSlots then
                local slotLbl = vgui.Create("DLabel", popup)
                slotLbl:SetPos(12, yNext)
                slotLbl:SetText("Slots: " .. tostring(slots))
                slotLbl:SetColor(LIST_TEXT)
                yNext = yNext + 20
            end

            local crafterLbl = vgui.Create("DLabel", popup)
            crafterLbl:SetPos(12, yNext)
            crafterLbl:SetSize(popupW - 24, 20)
            crafterLbl:SetContentAlignment(6)
            crafterLbl:SetText("Crafted by " .. (crafterName ~= "" and crafterName or "Player"))
            crafterLbl:SetColor(Color(160, 168, 180))
            yNext = yNext + 24

            local claimBtn = vgui.Create("DButton", popup)
            claimBtn:SetText("Claim")
            claimBtn:SetTall(32)
            claimBtn:SetWide(120)
            claimBtn:SetPos((popupW - 120) / 2, yNext + 4)
            claimBtn:SetFont("DermaDefaultBold")
            claimBtn.Paint = function(self, w, h)
                local col = self:IsHovered() and Color(60, 140, 200) or MENU_ACCENT
                draw.RoundedBox(4, 0, 0, w, h, col)
                surface.SetDrawColor(MENU_BORDER)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            claimBtn:SetColor(Color(255, 255, 255))
            claimBtn.DoClick = function()
                if IsValid(popup) then popup:Remove() end
            end
        end

        net.Receive("Crafter_CraftResult", function()
            local ok = net.ReadBool()
            if not ok then
                craftingInProgress = false
                if IsValid(progressBar) then progressBar:SetVisible(false) end
                npcNotify(net.ReadString() or "Craft failed.")
                return
            end
            local data = {
                resultId = net.ReadString() or "",
                resultName = net.ReadString() or "",
                rarity = net.ReadString() or "",
                model = net.ReadString() or "",
                baseDamage = net.ReadUInt(16) or 0,
                slots = net.ReadUInt(4) or 0,
                crafterName = net.ReadString() or "",
            }
            pendingCraftResult = data
            -- Do not clear the slot here; keep blueprint visible until the loading bar finishes so closing the menu mid-craft doesn't break flow or cause dupes
            -- Slot is cleared in progressBar.Think when the bar completes
        end)

        progressBar.Think = function(self)
            if not craftingInProgress then return end
            if CurTime() - craftProgressStart >= craftDuration then
                craftingInProgress = false
                self:SetVisible(false)
                if pendingCraftResult then
                    if IsValid(grid) then updateBlueprintListVisibility() end
                    if IsValid(dropZone) then updateDropZoneIcon() end
                    -- Skip claim screen when crafted item is BELOW the selected tier (Common < Rare < Unique < Epic < Legendary)
                    local tierOrder = { Common = 1, Rare = 2, Unique = 3, Epic = 4, Legendary = 5 }
                    local craftedTier = tierOrder[pendingCraftResult.rarity] or 0
                    local filterTier = tierOrder[rarityFilter] or 0
                    local skipClaim = (rarityFilter ~= nil and rarityFilter ~= "" and craftedTier < filterTier)
                    if not skipClaim then
                        showCraftResultPopup(pendingCraftResult)
                    end
                    pendingCraftResult = nil
                    surface.PlaySound("buttons/button14.wav")
                end
                -- Refresh menu when bar disappears (inventory changed from crafted item)
                if Inventory and Inventory.NET and Inventory.NET.RequestFull then
                    net.Start(Inventory.NET.RequestFull)
                    net.SendToServer()
                end
                timer.Simple(0, function()
                    if not IsValid(frame) then return end
                    buildCrafterBlueprintList()
                    if IsValid(scroll) then scroll:InvalidateLayout(true) end
                    if IsValid(grid) then grid:InvalidateLayout(true) end
                end)
            end
        end
        end) -- pcall
        if not ok then
            local errLbl = vgui.Create("DLabel", main)
            errLbl:Dock(FILL)
            errLbl:SetWrap(true)
            errLbl:SetContentAlignment(5)
            errLbl:SetText("Crafter UI failed to load.\nCheck console (F10) for errors.\n\n" .. tostring(err))
            errLbl:SetColor(Color(220, 100, 100))
        end
    else
    -- PropertySheet: tabs for non-crafter NPCs
    local sheet = vgui.Create("DPropertySheet", frame)
    sheet:Dock(FILL)
    sheet:DockMargin(2, 20, 2, 2)
    sheet.Paint = function() end
    if sheet.GetContentArea then
        local area = sheet:GetContentArea()
        if IsValid(area) then area:DockMargin(0, 0, 0, 0) end
    end

    -- ========== Missions tab: left DList | right info panel ==========
    local missionsPanel = vgui.Create("DPanel", sheet)
    missionsPanel.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, MENU_PANEL_BG) end

    local missionsSplit = vgui.Create("DPanel", missionsPanel)
    missionsSplit:Dock(FILL)
    missionsSplit:DockMargin(4, 2, 4, 36)
    missionsSplit.Paint = function() end
    missionsSplit.PerformLayout = function(self)
        if missionListWrap then missionListWrap:SetWide(LIST_W) end
    end

    local missionListWrap = vgui.Create("DPanel", missionsSplit)
    missionListWrap:Dock(LEFT)
    missionListWrap:SetWide(LIST_W)
    missionListWrap:DockMargin(0, 0, 6, 0)
    missionListWrap.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, LIST_BG) end

    local missionList = vgui.Create("DListView", missionListWrap)
    missionList:Dock(FILL)
    missionList:SetMultiSelect(false)
    missionList.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, LIST_BG) end
    if missionList.SetRowHeight then missionList:SetRowHeight(20) end
    missionList:AddColumn("Mission"):SetFixedWidth(160)
    missionList:AddColumn("Status"):SetFixedWidth(64)
    missionList:AddColumn("Req."):SetFixedWidth(44)
    for _, m in ipairs(missionLines) do
        if getMissionStatus(m.id) ~= "Completed" then
            local status = getMissionStatus(m.id)
            local reqStr = m.level_req and ("Lvl " .. tostring(m.level_req)) or "—"
            local line = missionList:AddLine(m.name or "?", status, reqStr)
            line.missionData = m
        end
    end
    if not missionList:GetLines() or #missionList:GetLines() == 0 then
        missionList:AddLine("No missions.", "—", "—")
    end
    local function colorForMissionLine(line)
        if not line.missionData then return LIST_TEXT end
        local st = getMissionStatus(line.missionData.id)
        if st == "Accepted" then return LIST_TEXT_ACCEPTED end
        if st == "Completed" then return LIST_TEXT_COMPLETED end
        return LIST_TEXT
    end
    timer.Simple(0, function()
        if not IsValid(missionList) then return end
        for _, child in ipairs(missionList:GetChildren() or {}) do
            if IsValid(child) and child.ClassName == "DListView_Header" then
                child.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, LIST_HEADER) end
                for _, col in ipairs(child:GetChildren() or {}) do
                    if IsValid(col) then
                        if type(col.SetTextColor) == "function" then col:SetTextColor(LIST_TEXT) end
                        if type(col.SetColor) == "function" then col:SetColor(LIST_TEXT) end
                        setPanelChildColors(col, LIST_TEXT)
                    end
                end
                break
            end
        end
        for _, line in ipairs(missionList:GetLines() or {}) do
            if IsValid(line) then
                line.Paint = function(self, w, h)
                    local col = self:IsSelected() and LIST_ROW_SEL or LIST_ROW
                    draw.RoundedBox(0, 0, 0, w, h, col)
                end
                setPanelChildColors(line, colorForMissionLine(line))
            end
        end
    end)

    local missionInfo = vgui.Create("DPanel", missionsSplit)
    missionInfo:Dock(FILL)
    missionInfo:DockMargin(0, 0, 0, 0)
    missionInfo.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 36, 46, 240)) end
    local missionPlaceholder = vgui.Create("DLabel", missionInfo)
    missionPlaceholder:Dock(FILL)
    missionPlaceholder:SetContentAlignment(5)
    missionPlaceholder:SetText("Select a mission")
    missionPlaceholder:SetColor(Color(140, 150, 165))
    missionPlaceholder:SetFont("DermaDefault")
    local missionDetail = vgui.Create("DPanel", missionInfo)
    missionDetail:Dock(FILL)
    missionDetail:SetVisible(false)
    missionDetail.Paint = function() end
    local missionTitle = vgui.Create("DLabel", missionDetail)
    missionTitle:Dock(TOP)
    missionTitle:SetTall(20)
    missionTitle:DockMargin(8, 8, 8, 4)
    missionTitle:SetFont("DermaDefaultBold")
    missionTitle:SetColor(LIST_TEXT)
    local missionReq = vgui.Create("DLabel", missionDetail)
    missionReq:Dock(TOP)
    missionReq:SetWrap(true)
    missionReq:DockMargin(8, 2, 8, 4)
    missionReq:SetColor(LIST_TEXT)
    local missionObj = vgui.Create("DLabel", missionDetail)
    missionObj:Dock(TOP)
    missionObj:SetWrap(true)
    missionObj:DockMargin(8, 2, 8, 4)
    missionObj:SetColor(LIST_TEXT)
    local missionRewards = vgui.Create("DLabel", missionDetail)
    missionRewards:Dock(TOP)
    missionRewards:SetWrap(true)
    missionRewards:DockMargin(8, 2, 8, 4)
    missionRewards:SetColor(LIST_TEXT)
    local rewardsIcons = vgui.Create("DPanel", missionDetail)
    rewardsIcons:Dock(TOP)
    rewardsIcons:SetTall(28)
    rewardsIcons:DockMargin(8, 2, 8, 6)
    rewardsIcons.Paint = function() end

    local function refreshMissionInfo(m)
        if not m then
            missionPlaceholder:SetVisible(true)
            missionDetail:SetVisible(false)
            return
        end
        missionPlaceholder:SetVisible(false)
        missionDetail:SetVisible(true)
        missionTitle:SetText(m.name or "?")
        missionReq:SetText("Requirements: " .. (m.requirements or "None"))
        missionObj:SetText("Objective: " .. (m.objective or m.description or "—"))
        local rw = m.rewards or {}
        local parts = {}
        if rw.money and rw.money > 0 then table.insert(parts, "$" .. tostring(rw.money)) end
        if rw.items and #rw.items > 0 then for _, it in ipairs(rw.items) do table.insert(parts, it) end end
        missionRewards:SetText("Rewards: " .. (#parts > 0 and table.concat(parts, ", ") or "None"))
        rewardsIcons:Clear()
        local x = 0
        if rw.money and rw.money > 0 then
            local icon = vgui.Create("DImage", rewardsIcons)
            icon:SetPos(x, 2)
            icon:SetSize(22, 22)
            icon:SetImage("icon16/money.png")
            x = x + 26
        end
        if rw.items then
            for _, it in ipairs(rw.items) do
                local icon = vgui.Create("DImage", rewardsIcons)
                icon:SetPos(x, 2)
                icon:SetSize(22, 22)
                icon:SetImage("icon16/box.png")
                x = x + 26
            end
        end
    end

    local missionBtns = vgui.Create("DPanel", missionsPanel)
    missionBtns:Dock(BOTTOM)
    missionBtns:SetTall(30)
    missionBtns:DockMargin(4, 2, 4, 4)
    missionBtns.Paint = function() end
    local acceptBtn = vgui.Create("DButton", missionBtns)
    acceptBtn:SetText("Accept")
    acceptBtn:SetSize(90, 26)
    acceptBtn:Dock(LEFT)
    acceptBtn:DockMargin(0, 2, 8, 0)
    acceptBtn:SetEnabled(false)
    acceptBtn:SetVisible(false)
    local cancelBtn = vgui.Create("DButton", missionBtns)
    cancelBtn:SetText("Cancel Mission")
    cancelBtn:SetSize(108, 26)
    cancelBtn:Dock(LEFT)
    cancelBtn:DockMargin(0, 2, 8, 0)
    cancelBtn:SetEnabled(false)
    cancelBtn:SetVisible(false)
    local turnInBtn = vgui.Create("DButton", missionBtns)
    turnInBtn:SetText("Turn in")
    turnInBtn:SetSize(70, 26)
    turnInBtn:Dock(LEFT)
    turnInBtn:DockMargin(0, 2, 8, 0)
    turnInBtn:SetEnabled(false)
    turnInBtn:SetVisible(false)
    -- Defined before DoClick so callbacks can call it (closure captures this).
    local function updateBtnVisibility()
        local _, l = missionList:GetSelectedLine()
        local isNew = l and l.missionData and getMissionStatus(l.missionData.id) == "New"
        local accepted = l and l.missionData and getMissionStatus(l.missionData.id) == "Accepted"
        acceptBtn:SetVisible(isNew)
        acceptBtn:SetEnabled(isNew)
        cancelBtn:SetVisible(accepted)
        cancelBtn:SetEnabled(accepted)
        turnInBtn:SetVisible(accepted)
        turnInBtn:SetEnabled(accepted)
    end
    acceptBtn.DoClick = function()
        local _, l = missionList:GetSelectedLine()
        if not l or not l.missionData or getMissionStatus(l.missionData.id) ~= "New" then return end
        local m = l.missionData
        Derma_Query("Accept the mission: " .. (m.name or "?") .. "?", "Accept Mission", "Yes", function()
            Paradise.NPCs.AcceptedMissions = Paradise.NPCs.AcceptedMissions or {}
            Paradise.NPCs.AcceptedMissions[m.id] = true
            l:SetColumnText(2, "Accepted")
            setPanelChildColors(l, LIST_TEXT_ACCEPTED)
            net.Start("Paradise_NPCAcceptMission")
            net.WriteString(m.id)
            net.SendToServer()
            npcNotify("Mission accepted: " .. (m.name or "?"))
            updateBtnVisibility()
        end, "No", function() end)
    end
    cancelBtn.DoClick = function()
        local _, l = missionList:GetSelectedLine()
        if l and l.missionData then
            local mid = l.missionData.id
            Paradise.NPCs.AcceptedMissions[mid] = nil
            l:SetColumnText(2, "New")
            setPanelChildColors(l, LIST_TEXT)
            net.Start("Paradise_NPCCancelMission")
            net.WriteString(mid)
            net.SendToServer()
            npcNotify("Mission cancelled: " .. (l.missionData.name or "?"))
            updateBtnVisibility()
        end
    end
    turnInBtn.DoClick = function()
        local lineId, l = missionList:GetSelectedLine()
        if not l or not l.missionData or getMissionStatus(l.missionData.id) ~= "Accepted" then return end
        local m = l.missionData
        Paradise.NPCs.AcceptedMissions[m.id] = nil
        Paradise.NPCs.CompletedMissions[m.id] = npcType
        net.Start("Paradise_NPCCompleteMission")
        net.WriteString(m.id)
        net.WriteString(npcType)
        net.SendToServer()
        npcNotify("Mission completed: " .. (m.name or "?"))
        missionList:RemoveLine(lineId)
        refreshMissionInfo(nil)
        updateBtnVisibility()
    end

    missionList.OnRowSelected = function(_, lineId, line)
        refreshMissionInfo(line.missionData)
        updateBtnVisibility()
    end
    missionList.OnRowRightClick = function(_, lineId, line)
        missionList:SelectItem(line)
        refreshMissionInfo(line.missionData)
        updateBtnVisibility()
    end
    missionList.DoDoubleClick = function(_, lineId, line)
        local m = line and line.missionData
        if not m then return end
        if getMissionStatus(m.id) == "Accepted" then return end
        Derma_Query("Accept the mission: " .. (m.name or "?") .. "?", "Accept Mission", "Yes", function()
            Paradise.NPCs.AcceptedMissions = Paradise.NPCs.AcceptedMissions or {}
            Paradise.NPCs.AcceptedMissions[m.id] = true
            line:SetColumnText(2, "Accepted")
            setPanelChildColors(line, LIST_TEXT_ACCEPTED)
            net.Start("Paradise_NPCAcceptMission")
            net.WriteString(m.id)
            net.SendToServer()
            npcNotify("Mission accepted: " .. (m.name or "?"))
            updateBtnVisibility()
        end, "No", function() end)
    end

    sheet:AddSheet("Missions", missionsPanel, "icon16/comments.png")

    -- Mission log: all completed missions (openable from every NPC)
    local logPanel = vgui.Create("DPanel", sheet)
    logPanel.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, MENU_PANEL_BG) end
    local logList = vgui.Create("DListView", logPanel)
    logList:Dock(FILL)
    logList:DockMargin(4, 4, 4, 4)
    logList:SetMultiSelect(false)
    logList.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, LIST_BG) end
    if logList.SetRowHeight then logList:SetRowHeight(20) end
    logList:AddColumn("Mission"):SetFixedWidth(200)
    logList:AddColumn("NPC"):SetFixedWidth(120)
    for mid, ntype in pairs(Paradise.NPCs.CompletedMissions or {}) do
        local lines = Paradise.NPCs.GetMissionLines and Paradise.NPCs.GetMissionLines(ntype) or {}
        local name = mid
        for _, m in ipairs(lines) do if m.id == mid then name = m.name or mid break end end
        local npcName = Paradise.NPCs.GetDisplayName and Paradise.NPCs.GetDisplayName(ntype) or ntype
        logList:AddLine(name, npcName)
    end
    if not logList:GetLines() or #logList:GetLines() == 0 then
        logList:AddLine("No completed missions yet.", "—")
    end
    timer.Simple(0, function()
        if not IsValid(logList) then return end
        for _, child in ipairs(logList:GetChildren() or {}) do
            if IsValid(child) and child.ClassName == "DListView_Header" then
                child.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, LIST_HEADER) end
                for _, col in ipairs(child:GetChildren() or {}) do
                    if IsValid(col) then
                        if type(col.SetTextColor) == "function" then col:SetTextColor(LIST_TEXT) end
                        if type(col.SetColor) == "function" then col:SetColor(LIST_TEXT) end
                        setPanelChildColors(col, LIST_TEXT)
                    end
                end
                break
            end
        end
        for _, line in ipairs(logList:GetLines() or {}) do
            if IsValid(line) then
                line.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, LIST_ROW) end
                setPanelChildColors(line, LIST_TEXT_COMPLETED)
            end
        end
    end)
    sheet:AddSheet("Mission log", logPanel, "icon16/page_white_text.png")

    if npcType == "banker" then
        -- Banker has Bank tab (no shop); bank UI later.
        local bankPanel = vgui.Create("DPanel", sheet)
        bankPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, MENU_PANEL_BG) end
        local bankLbl = vgui.Create("DLabel", bankPanel)
        bankLbl:Dock(FILL)
        bankLbl:SetContentAlignment(5)
        bankLbl:SetText("Bank services coming soon.")
        bankLbl:SetColor(Color(160, 170, 185))
        sheet:AddSheet("Bank", bankPanel, "icon16/money.png")
    else
        -- ========== Shop tab: left DList | right info (Icon, Description) ==========
        local shopPanel = vgui.Create("DPanel", sheet)
        shopPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, MENU_PANEL_BG) end
        local shopSplit = vgui.Create("DPanel", shopPanel)
        shopSplit:Dock(FILL)
        shopSplit:DockMargin(4, 4, 4, 4)
        shopSplit.Paint = function() end
        local shopListWrap = vgui.Create("DPanel", shopSplit)
        shopListWrap:Dock(LEFT)
        shopListWrap:SetWide(LIST_W)
        shopListWrap:DockMargin(0, 0, 6, 0)
        shopListWrap.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, LIST_BG) end
        local shopList = vgui.Create("DListView", shopListWrap)
        shopList:Dock(FILL)
        shopList:SetMultiSelect(false)
        shopList.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, LIST_BG) end
        if shopList.SetRowHeight then shopList:SetRowHeight(22) end
        shopList:AddColumn("Item"):SetFixedWidth(130)
        shopList:AddColumn("Price"):SetFixedWidth(56)
        shopList:AddColumn("Req."):SetFixedWidth(48)
        for _, row in ipairs(shop) do
            local name = row.name or row.item_id or "?"
            local price = tostring(row.price or 0)
            local reqStr = row.level_req and ("Lvl " .. row.level_req) or "—"
            local line = shopList:AddLine(name, price, reqStr)
            line.shopRow = row
        end
        if #shop == 0 then
            shopList:AddLine("No items.", "—", "—")
        end
        timer.Simple(0, function()
            if not IsValid(shopList) then return end
            for _, child in ipairs(shopList:GetChildren() or {}) do
                if IsValid(child) and child.ClassName == "DListView_Header" then
                    child.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, LIST_HEADER) end
                    for _, col in ipairs(child:GetChildren() or {}) do
                        if IsValid(col) then
                            if type(col.SetTextColor) == "function" then col:SetTextColor(LIST_TEXT) end
                            if type(col.SetColor) == "function" then col:SetColor(LIST_TEXT) end
                            setPanelChildColors(col, LIST_TEXT)
                        end
                    end
                    break
                end
            end
            for _, line in ipairs(shopList:GetLines() or {}) do
                if IsValid(line) then
                    line.Paint = function(self, w, h)
                        local col = self:IsSelected() and LIST_ROW_SEL or LIST_ROW
                        draw.RoundedBox(0, 0, 0, w, h, col)
                    end
                    setPanelChildColors(line, LIST_TEXT)
                end
            end
        end)
        local shopInfo = vgui.Create("DPanel", shopSplit)
        shopInfo:Dock(FILL)
        shopInfo.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 36, 46, 240)) end
        local shopIcon = vgui.Create("DImage", shopInfo)
        shopIcon:SetPos(10, 10)
        shopIcon:SetSize(44, 44)
        shopIcon:SetImage("icon16/box.png")
        local shopItemName = vgui.Create("DLabel", shopInfo)
        shopItemName:Dock(TOP)
        shopItemName:SetTall(20)
        shopItemName:DockMargin(62, 10, 8, 4)
        shopItemName:SetText("Select an item")
        shopItemName:SetFont("DermaDefaultBold")
        shopItemName:SetColor(LIST_TEXT)
        local shopDesc = vgui.Create("DLabel", shopInfo)
        shopDesc:Dock(TOP)
        shopDesc:SetWrap(true)
        shopDesc:DockMargin(8, 4, 8, 8)
        shopDesc:SetText("Description will appear here.")
        shopDesc:SetColor(LIST_TEXT)
        local function refreshShopInfo(row)
            if not row then
                shopIcon:SetImage("icon16/box.png")
                shopItemName:SetText("Select an item")
                shopDesc:SetText("Description will appear here.")
                return
            end
            shopIcon:SetImage(row.icon or "icon16/box.png")
            shopItemName:SetText(row.name or row.item_id or "?")
            shopDesc:SetText(row.description or "No description.")
        end
        shopList.OnRowSelected = function(_, lineId, line)
            refreshShopInfo(line and line.shopRow)
        end
        shopList.OnRowRightClick = function(_, lineId, line)
            shopList:SelectItem(line)
            refreshShopInfo(line and line.shopRow)
        end
        shopList.DoDoubleClick = function(_, lineId, line)
            local row = line.shopRow
            if row then npcNotify("Buy not yet wired: " .. (row.name or row.item_id or "?")) end
        end
        sheet:AddSheet("Shop", shopPanel, "icon16/cart.png")
    end
    end -- else (non-crafter NPC)
end)

--[[---------------------------------------------------------------------------
  Admin Settings: NPC spawn editor. Opened from Settings tab "NPC spawns" button.
  DListView of spawns; Add at my position, Remove selected. Content is saved to file server-side.
---------------------------------------------------------------------------]]
function OpenNPCSpawnEditor()
    if not LocalPlayer():IsSuperAdmin() then return end
    local frame = vgui.Create("DFrame")
    frame:SetSize(520, 380)
    frame:Center()
    frame:SetTitle("NPC spawns – add/remove positions (saved to file)")
    frame:SetVisible(true)
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(28, 34, 44, 250))
        surface.SetDrawColor(60, 72, 88, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local list = vgui.Create("DListView", frame)
    Paradise.NPCSpawnListView = list
    frame.OnClose = function() Paradise.NPCSpawnListView = nil end
    list:Dock(FILL)
    list:DockMargin(8, 36, 8, 44)
    list:AddColumn("#"):SetFixedWidth(32)
    list:AddColumn("Type"):SetFixedWidth(100)
    list:AddColumn("Position"):SetFixedWidth(180)
    list:AddColumn("Model"):SetFixedWidth(140)

    local btnRow = vgui.Create("DPanel", frame)
    btnRow:Dock(BOTTOM)
    btnRow:SetTall(36)
    btnRow:DockMargin(8, 4, 8, 8)
    btnRow.Paint = function() end
    local typeCombo = vgui.Create("DComboBox", btnRow)
    typeCombo:SetPos(0, 4)
    typeCombo:SetSize(140, 28)
    for k, displayName in pairs(Paradise.NPCs and Paradise.NPCs.Types or {}) do
        typeCombo:AddChoice(displayName, k)
    end
    typeCombo:ChooseOptionID(1)
    local addBtn = vgui.Create("DButton", btnRow)
    addBtn:SetPos(148, 4)
    addBtn:SetSize(120, 28)
    addBtn:SetText("Add at my position")
    addBtn.DoClick = function()
        local _, data = typeCombo:GetSelected()
        local npcType = data or "generic"
        net.Start("Admin_AddNPCSpawn")
        net.WriteString(npcType)
        net.WriteString("models/mossman.mdl")
        net.SendToServer()
        timer.Simple(0.3, function() if IsValid(frame) then net.Start("Admin_RequestNPCSpawns") net.SendToServer() end end)
    end
    local removeBtn = vgui.Create("DButton", btnRow)
    removeBtn:SetPos(276, 4)
    removeBtn:SetSize(100, 28)
    removeBtn:SetText("Remove selected")
    removeBtn.DoClick = function()
        local line = list:GetSelectedLine()
        if not line or line < 1 then return end
        net.Start("Admin_RemoveNPCSpawn")
        net.WriteUInt(line - 1, 16)
        net.SendToServer()
        list:RemoveLine(line)
        timer.Simple(0.2, function() if IsValid(frame) then net.Start("Admin_RequestNPCSpawns") net.SendToServer() end end)
    end

    net.Start("Admin_RequestNPCSpawns")
    net.SendToServer()
end
