-- cl_inventory.lua  (client) – clean inventory UI only (no loadout here)

if not CLIENT then return end

local FRAME, GRID, SIDEBAR
local INV_DEBUG = CreateClientConVar("inv_debug", "0", true, false)

-- Expose client-side inventory data to allow spawnmenu panels to render
Inventory = Inventory or {}
Inventory.Client = Inventory.Client or {}
Inventory.Client.ItemsCatalog = Inventory.Client.ItemsCatalog or {}   -- id -> def
Inventory.Client.Items = Inventory.Client.Items or {}                 -- flat list of entries from server
Inventory.Client.MaxPages = Inventory.Client.MaxPages or 1

local ItemsCatalog = Inventory.Client.ItemsCatalog
local Items = Inventory.Client.Items
local MaxPages = Inventory.Client.MaxPages

-- Keep rebuild hooks for any external panels we create (spawnmenu)
local Rebuilders = {}
local function registerRebuilder(fn)
    if not isfunction(fn) then return end
    for i = 1, #Rebuilders do
        if Rebuilders[i] == fn then return end
    end
    table.insert(Rebuilders, fn)
end
local function notifyRebuilders()
    for i = #Rebuilders, 1, -1 do
        local ok, err = pcall(Rebuilders[i])
        if not ok then table.remove(Rebuilders, i) end
    end
end

-- Theme fallback if addon theme not loaded
local T = (ParadiseUI and ParadiseUI.Theme) or {}
local function col(key, fallback) return T[key] or fallback end
local R = T.radius or 8

local function ensureFrame()
    if IsValid(FRAME) then return end

    local cell = Inventory.Config.SLOT + Inventory.Config.PAD
    local gridW = Inventory.Config.GRID_W * cell + 4
    local gridH = Inventory.Config.GRID_H * cell + 4
    local sidebarW = 280
    local pad = 12
    local headerH = 40
    local tabsH = 32
    local topbarH = 32
    -- Size menu flush to grid + toolbar (no extra empty space below)
    local minContentW = 1050
    local contentW = (pad*2) + 8 + gridW + 8 + 6 + sidebarW
    local frameW = math.max(contentW, minContentW)
    local gridAreaH = (8 + 32) + (6 + 8) + gridH + 8
    local frameH = (pad) + headerH + (4 + tabsH + 6) + (pad) + gridAreaH

    FRAME = vgui.Create("DFrame")
    FRAME:SetSize(frameW, frameH)
    FRAME:SetMinWidth(920)
    FRAME:SetMinHeight(420)
    FRAME:SetSizable(true)
    FRAME:Center()
    FRAME:SetTitle("")
    FRAME:SetDraggable(true)
    FRAME:ShowCloseButton(false)
    FRAME:SetVisible(false)
    function FRAME:Paint(w,h)
        draw.RoundedBox(R, 0, 0, w, h, col("bg_dark", Color(14, 18, 26, 250)))
        surface.SetDrawColor(col("accent", Color(0, 200, 255)):Unpack())
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    -- Header bar (futuristic)
    local headerTitle = "Inventory"
    local header = vgui.Create("DPanel", FRAME)
    header:Dock(TOP)
    header:SetTall(headerH)
    header:DockMargin(pad, pad, pad, 0)
    function header:Paint(w,h)
        draw.RoundedBoxEx(R, 0, 0, w, h, col("bg_panel", Color(22, 28, 38)), true, true, false, false)
        surface.SetDrawColor(col("border_light", Color(70, 85, 110)):Unpack())
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(headerTitle, "DermaDefaultBold", 14, h/2, col("text", color_white), 0, 1)
    end

    -- Tabs row
    local tabsRow = vgui.Create("DPanel", FRAME)
    tabsRow:Dock(TOP)
    tabsRow:SetTall(tabsH)
    tabsRow:DockMargin(pad, 4, pad, 6)
    function tabsRow:Paint() end

    -- Body: left area (content + grid) and right tools sidebar. Left panel is sized to exclude tools so grid can never go under it.
    local body = vgui.Create("DPanel", FRAME)
    body:Dock(FILL)
    body:DockMargin(pad, 0, pad, pad)
    function body:Paint() end

    -- Left panel: only this panel is sized to (0, 0, W - sidebar - gap, H). Content will FILL this, so grid stays inside.
    local leftPanel = vgui.Create("DPanel", body)
    leftPanel._sidebarW = sidebarW
    function leftPanel:Paint() end

    -- Content (tabs + pages) fills the left panel only
    local content = vgui.Create("DPanel", leftPanel)
    content:Dock(FILL)
    function content:Paint(w,h)
        draw.RoundedBox(R, 0, 0, w, h, col("bg_panel", Color(22, 28, 38)))
        surface.SetDrawColor(col("border", Color(50, 60, 78)):Unpack())
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- Right tools sidebar; positioned and sized in body:PerformLayout
    local toolsPanel = vgui.Create("DPanel", body)
    toolsPanel._sidebarW = sidebarW
    function toolsPanel:Paint(w,h)
        draw.RoundedBox(R, 0, 0, w, h, col("bg_panel", Color(22, 28, 38)))
        surface.SetDrawColor(col("border", Color(50, 60, 78)):Unpack())
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local toolsHeader = vgui.Create("DPanel", toolsPanel)
    toolsHeader:Dock(TOP)
    toolsHeader:SetTall(34)
    function toolsHeader:Paint(w,h)
        draw.RoundedBoxEx(R, 0, 0, w, h, col("bg_raised", Color(30, 36, 48)), true, true, false, false)
        surface.SetDrawColor(col("accent", Color(0, 200, 255)):Unpack())
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("Tool Selector", "DermaDefaultBold", 10, h/2, col("text", color_white), 0, 1)
    end

    local toolsScroll = vgui.Create("DScrollPanel", toolsPanel)
    toolsScroll:Dock(FILL)
    toolsScroll:DockMargin(6,6,6,6)

    local function friendlyToolName(n)
        if not n then return "" end
        if isstring(n) and string.StartWith(n, "#") and language and language.GetPhrase then
            return language.GetPhrase(n)
        end
        return n
    end

    local function populateTools()
        toolsScroll:Clear()
        local tools = list.Get and list.Get("Tool") or {}
        -- Curated common list first (if present)
        local common = {"button","fading_door","keypad","camera","nocollide","remover","stacker"}
        local function addButton(label, mode)
            local b = vgui.Create("DButton", toolsScroll)
            b:Dock(TOP)
            b:DockMargin(0,0,0,4)
            b:SetTall(26)
            b:SetText("")
            local hovered = false
            b.OnCursorEntered = function() hovered = true end
            b.OnCursorExited  = function() hovered = false end
            b.Paint = function(self,w,h)
                local bg = hovered and col("bg_hover", Color(42, 50, 66)) or col("bg_raised", Color(30, 36, 48))
                draw.RoundedBox(T.radius_sm or 4, 0, 0, w, h, bg)
                surface.SetDrawColor(col("border", Color(50, 60, 78)):Unpack())
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(friendlyToolName(label), "DermaDefaultBold", 10, h/2, col("text", color_white), 0, 1)
            end
            b.DoClick = function()
                RunConsoleCommand("gmod_toolmode", mode)
                RunConsoleCommand("use", "gmod_tool")
                surface.PlaySound("buttons/button15.wav")
                if Inventory_Close then Inventory_Close() end
            end
        end
        local added = {}
        -- Helper to prefer Willox keypad if present
        local function findKeypad(toolsTbl)
            local candidate, willox
            for mode, data in pairs(toolsTbl or {}) do
                local name = tostring(data.Name or ""):lower()
                local m = (data.Mode or mode):lower()
                if name:find("keypad") or m:find("keypad") then
                    candidate = {label = data.Name or mode, mode = data.Mode or mode}
                    if name:find("willox") or m:find("willox") then
                        willox = {label = data.Name or mode, mode = data.Mode or mode}
                        break
                    end
                end
            end
            return willox or candidate
        end

        for _, key in ipairs(common) do
            local found = false
            for mode, data in pairs(tools or {}) do
                local m = (data.Mode or mode):lower()
                if m:find(key) then
                    addButton(data.Name or mode, data.Mode or mode)
                    added[data.Mode or mode] = true
                    found = true
                end
            end
            if not found then
                if key == "keypad" then
                    local kp = findKeypad(tools)
                    if kp then
                        addButton(kp.label, kp.mode); added[kp.mode] = true
                    else
                        -- Prefer Willox keypad by default if installed name differs
                        local preferred = "keypad_willox"
                        addButton("Keypad", preferred)
                    end
                else
                    addButton(key:gsub("^%l", string.upper), key)
                end
            end
        end
        -- Add remaining tools grouped by category
        local byCat = {}
        for mode, data in pairs(tools) do
            local fullMode = data.Mode or mode
            if not added[fullMode] then
                local cat = data.Category or "Other"
                byCat[cat] = byCat[cat] or {}
                table.insert(byCat[cat], {mode = fullMode, name = data.Name or fullMode})
            end
        end
        local cats = {}
        for k in pairs(byCat) do table.insert(cats, k) end
        table.sort(cats)
        for _, cat in ipairs(cats) do
            local hdr = vgui.Create("DLabel", toolsScroll)
            hdr:Dock(TOP) hdr:SetTall(20) hdr:SetText(" "+cat) hdr:SetTextColor(Color(200,200,200))
            for _, t in ipairs(byCat[cat]) do addButton(t.name, t.mode) end
        end
    end
    populateTools()

    -- Size left panel to everything except the tools strip; tools panel on the right. Content already Dock(FILL)s leftPanel.
    function body:PerformLayout()
        local W, H = self:GetWide(), self:GetTall()
        local sw = (toolsPanel._sidebarW or sidebarW) + 6
        if IsValid(leftPanel) then
            leftPanel:SetPos(0, 0)
            leftPanel:SetSize(math.max(0, W - sw), H)
        end
        if IsValid(toolsPanel) then
            toolsPanel:SetPos(W - (sw - 6), 0)
            toolsPanel:SetSize(sw - 6, H)
        end
    end

    -- Helpers
    local tabPages = {}
    local function addTab(text, builder)
        local btn = vgui.Create("DButton", tabsRow)
        btn:Dock(LEFT)
        btn:DockMargin(0,0,6,0)
        btn:SetText("")
        btn:SetWide(110)
        btn._selected = false
        btn.Paint = function(self,w,h)
            local bg = self._selected and col("accent", Color(0, 200, 255)) or col("bg_raised", Color(30, 36, 48))
            draw.RoundedBox(R, 0, 0, w, h, bg)
            surface.SetDrawColor(self._selected and col("accent", Color(0, 200, 255)) or col("border", Color(50, 60, 78)))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(text, "DermaDefaultBold", w/2, h/2, col("text", color_white), 1, 1)
        end

        -- Pre-create a page for this tab and build it once
        local page = vgui.Create("DPanel", content)
        page:Dock(FILL)
        function page:Paint(w,h)
            draw.RoundedBox(R, 0, 0, w, h, col("bg_panel", Color(22, 28, 38)))
            surface.SetDrawColor(col("border", Color(50, 60, 78)):Unpack())
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        page:SetVisible(false)
        tabPages[text] = page
        -- Build once after first layout tick to ensure valid sizes
        timer.Simple(0, function()
            if IsValid(page) then builder(page) end
        end)

        btn.DoClick = function(self)
            for _, child in ipairs(tabsRow:GetChildren()) do child._selected = false end
            self._selected = true
            headerTitle = text
            for name, pnl in pairs(tabPages) do if IsValid(pnl) then pnl:SetVisible(name == text) end end
        end

        return btn
    end

    local function buildInventory(parent)
        local top = vgui.Create("DPanel", parent)
        top:Dock(TOP)
        top:SetTall(32)
        top:DockMargin(8, 8, 8, 0)
        function top:Paint(w, h)
            draw.RoundedBox(R, 0, 0, w, h, col("bg_raised", Color(30, 36, 48)))
            surface.SetDrawColor(col("border", Color(50, 60, 78)):Unpack())
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        local page = vgui.Create("DButton", top)
        page:Dock(LEFT)
        page:DockMargin(6,4,0,4)
        page:SetWide(100)
        page:SetText("Page 1")
        page:SetEnabled(false)

        -- Refresh button on the Inventory tab
        local refresh = vgui.Create("DButton", top)
        refresh:Dock(RIGHT)
        refresh:DockMargin(0,4,6,4)
        refresh:SetWide(100)
    refresh:SetText("Refresh")
    refresh.DoClick = function()
        net.Start(Inventory.NET.RequestFull) net.SendToServer()
    end

        -- Black box that parents the item grid. nil = fill available space; or set e.g. 700, 420 to force size.
        local GRID_PANEL_W, GRID_PANEL_H = nil, nil
        local gridWrap = vgui.Create("DPanel", parent)
        gridWrap:Dock(FILL)
        gridWrap:DockMargin(0, 0, 0, 0)
        function gridWrap:PerformLayout()
            if GRID_PANEL_W and GRID_PANEL_H and self:GetParent() then
                self:SetPos(0, 42)
                self:SetSize(GRID_PANEL_W, GRID_PANEL_H)
            end
        end
        function gridWrap:Paint(w, h)
            draw.RoundedBox(R, 0, 0, w, h, col("bg_panel", Color(22, 28, 38)))
            surface.SetDrawColor(col("border", Color(50, 60, 78)):Unpack())
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        local gridInset = 0
        local minCellPx = 24
        GRID = vgui.Create("DPanel", gridWrap)
        GRID:Dock(FILL)
        GRID:SetMouseInputEnabled(true)
        GRID._hoverGX, GRID._hoverGY = nil, nil
        GRID._inset = gridInset
        local slotRadius = 4
        local slotGap = 1
        function GRID:PerformLayout()
            local w, h = self:GetWide(), self:GetTall()
            if w <= 0 or h <= 0 then return end
            local cw = (w - slotGap * (Inventory.Config.GRID_W - 1)) / Inventory.Config.GRID_W
            local ch = (h - slotGap * (Inventory.Config.GRID_H - 1)) / Inventory.Config.GRID_H
            cw = math.max(minCellPx, cw)
            ch = math.max(minCellPx, ch)
            self._cellX = cw + slotGap
            self._cellY = ch + slotGap
            self._cell = (self._cellX + self._cellY) / 2
            self._slotSize = math.max(20, math.min(cw, ch))
        end
        function GRID:Paint(w, h)
            local cellX = self._cellX or (Inventory.Config.SLOT + Inventory.Config.PAD)
            local cellY = self._cellY or (Inventory.Config.SLOT + Inventory.Config.PAD)
            local slotW = cellX - slotGap
            local slotH = cellY - slotGap
            local ins = self._inset or 0
            draw.RoundedBox(slotRadius, 0, 0, w, h, Color(30, 30, 30, 255))
            for gy = 1, Inventory.Config.GRID_H do
                for gx = 1, Inventory.Config.GRID_W do
                    local x = ins + (gx - 1) * cellX
                    local y = ins + (gy - 1) * cellY
                    draw.RoundedBox(slotRadius, x, y, slotW, slotH, Color(38, 42, 50, 220))
                    surface.SetDrawColor(col("border", Color(50, 60, 78)):Unpack())
                    surface.DrawOutlinedRect(x, y, slotW, slotH, 1)
                end
            end
            local gx, gy = self._hoverGX, self._hoverGY
            if gx and gy then
                local x = ins + (gx - 1) * cellX
                local y = ins + (gy - 1) * cellY
                draw.RoundedBox(slotRadius, x, y, slotW, slotH, Color(60, 120, 60, 120))
                surface.SetDrawColor(80, 180, 80, 200)
                surface.DrawOutlinedRect(x, y, slotW, slotH, 2)
            end
        end

        -- no immediate populate here; wait for SyncInventory -> rebuild()
        -- also fetch on opening this tab to ensure latest state
        net.Start(Inventory.NET.RequestFull) net.SendToServer()
    end

    local function buildProps(parent)
        if BuildPropsPanel then
            local holder = vgui.Create("DPanel", parent)
            holder:Dock(FILL)
            holder:DockMargin(6,6,6,6)
            holder.Paint = function() end
            timer.Simple(0, function()
                if not IsValid(holder) then return end
                local ok = pcall(BuildPropsPanel, holder)
                if not ok then
                    local l = vgui.Create("DLabel", parent) l:Dock(FILL) l:SetContentAlignment(5) l:SetText("Props module unavailable")
                end
            end)
        else
            local l = vgui.Create("DLabel", parent) l:Dock(FILL) l:SetContentAlignment(5) l:SetText("Props module unavailable")
        end
    end

    local function buildResources(parent)
        if BuildResourcesMenu then
            local ok = pcall(BuildResourcesMenu, parent)
            if not ok then local l = vgui.Create("DLabel", parent) l:Dock(FILL) l:SetContentAlignment(5) l:SetText("Resources unavailable") end
        else
            local l = vgui.Create("DLabel", parent) l:Dock(FILL) l:SetContentAlignment(5) l:SetText("Resources module unavailable")
        end
    end

    local function buildAdmin(parent)
        -- Admin panel: gamemode module (admin/) or addon (darkrp_modules/admin/)
        local GM = GAMEMODE or GM
        local prefix = GM and GM.FolderName and (GM.FolderName .. "/gamemode/modules/") or ""
        if not BuildAdminPanel and prefix ~= "" and file.Exists(prefix .. "admin/cl_admin.lua", "LUA") then
            pcall(function() include(prefix .. "admin/cl_admin.lua") end)
        end
        if not BuildAdminPanel and file.Exists("darkrp_modules/admin/cl_admin.lua", "LUA") then
            pcall(function() include("darkrp_modules/admin/cl_admin.lua") end)
        end
        if BuildAdminPanel then
            BuildAdminPanel(parent)
        else
            local l = vgui.Create("DLabel", parent)
            l:Dock(FILL)
            l:SetContentAlignment(5)
            l:SetText("Admin module unavailable (add darkrp_modules addon for admin panel)")
        end
    end

    -- Optional: load Entities/Jobs panel builders from gamemode modules or addon if not already set
    local function ensureEntityJobBuilders()
        if BuildEntitiesPanel and BuildJobsPanel then return end
        local GM = GAMEMODE or GM
        local prefix = GM and GM.FolderName and (GM.FolderName .. "/gamemode/modules/") or ""
        local paths = {}
        if prefix ~= "" then
            paths[#paths + 1] = prefix .. "rpents/cl_rpents.lua"
            paths[#paths + 1] = prefix .. "rpjobs/cl_jobs.lua"
        end
        for _, p in ipairs({"darkrp_modules/rpents/cl_rpents.lua", "darkrp_modules/rp_entities/cl_rp_entities.lua", "darkrp_modules/rpjobs/cl_jobs.lua", "darkrp_modules/rp_jobs/cl_rp_jobs.lua"}) do
            paths[#paths + 1] = p
        end
        for _, p in ipairs(paths) do
            if file.Exists(p, "LUA") then
                pcall(function() include(p) end)
                if BuildEntitiesPanel and BuildJobsPanel then return end
            end
        end
    end

    -- Entities: use addon builder if present, else embed F4 menu entities panel (same data, no path error)
    local function buildEntities(parent)
        ensureEntityJobBuilders()
        if BuildEntitiesPanel then
            entitiesTab = parent
            BuildEntitiesPanel(parent)
        elseif vgui.GetControlTable("F4MenuEntities") then
            entitiesTab = parent
            local pnl = vgui.Create("F4MenuEntities", parent)
            pnl:Dock(FILL)
        else
            local l = vgui.Create("DLabel", parent)
            l:Dock(FILL)
            l:SetContentAlignment(5)
            l:SetText("Entities module unavailable")
        end
    end

    -- Jobs: use addon builder if present, else embed F4 menu jobs panel (same data, no path error)
    local function buildJobs(parent)
        ensureEntityJobBuilders()
        if BuildJobsPanel then
            jobsTab = parent
            local holder = vgui.Create("DPanel", parent)
            holder:Dock(FILL)
            holder:DockMargin(6,6,6,6)
            holder.Paint = function() end
            timer.Simple(0, function()
                if not IsValid(holder) then return end
                local ok = pcall(BuildJobsPanel, holder)
                if not ok then local l = vgui.Create("DLabel", parent) l:Dock(FILL) l:SetContentAlignment(5) l:SetText("Jobs module unavailable") end
            end)
        elseif vgui.GetControlTable("F4MenuJobs") then
            jobsTab = parent
            local holder = vgui.Create("DPanel", parent)
            holder:Dock(FILL)
            holder:DockMargin(6,6,6,6)
            holder.Paint = function() end
            local pnl = vgui.Create("F4MenuJobs", holder)
            pnl:Dock(FILL)
        else
            local l = vgui.Create("DLabel", parent)
            l:Dock(FILL)
            l:SetContentAlignment(5)
            l:SetText("Jobs module unavailable")
        end
    end

    -- Tools list (Toolgun modes)
    local function buildTools(parent)
        for _, c in ipairs(parent:GetChildren()) do c:Remove() end
        local tools = list.Get and list.Get("Tool") or {}
        local byCat = {}
        for mode, data in pairs(tools or {}) do
            local cat = data.Category or "Other"
            byCat[cat] = byCat[cat] or {}
            table.insert(byCat[cat], {mode = data.Mode or mode, name = data.Name or mode, desc = data.Information or ""})
        end
        local cats = {}
        for k in pairs(byCat) do table.insert(cats, k) end
        table.sort(cats)

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)
        scroll:DockMargin(8,8,8,8)

        for _, cat in ipairs(cats) do
            local catPanel = vgui.Create("DCollapsibleCategory", scroll)
            catPanel:Dock(TOP)
            catPanel:SetLabel(cat)
            catPanel:SetExpanded(false)
            catPanel:DockMargin(0,0,0,6)

            local container = vgui.Create("DPanel", catPanel)
            container:Dock(TOP)
            container:SetTall( math.ceil(#byCat[cat] / 2) * 56 )
            container.Paint = function() end
            catPanel:SetContents(container)

            table.sort(byCat[cat], function(a,b) return a.name < b.name end)
            for i, t in ipairs(byCat[cat]) do
                local panel = vgui.Create("DPanel", container)
                panel:SetSize( (container:GetWide()-10)/2, 50)
                local row = math.floor((i-1)/2); local col = (i-1)%2
                panel:SetPos(col * ((container:GetWide()-10)/2 + 10), row * (50 + 6))
                panel.Paint = function(self,w,h)
                    draw.RoundedBox(4,0,0,w,h, Color(40,40,40,200))
                    surface.SetDrawColor(70,70,80,255) surface.DrawOutlinedRect(0,0,w,h,1)
                end

                local btn = vgui.Create("DButton", panel)
                btn:Dock(FILL)
                btn:SetText("")
                btn.Paint = function(self,w,h)
                    draw.SimpleText(t.name, "DermaDefaultBold", 10, h/2, color_white, 0, 1)
                end
                btn.DoClick = function()
                    RunConsoleCommand("gmod_toolmode", t.mode)
                    RunConsoleCommand("use", "gmod_tool")
                    surface.PlaySound("buttons/button15.wav")
                end
                btn.DoRightClick = btn.DoClick
            end
        end
    end

    local b1 = addTab("Inventory", buildInventory)
    local b2 = addTab("Entities", buildEntities)
    local b3 = addTab("Props", buildProps)
    local b4 = addTab("Resources", buildResources)
    local b5 = addTab("Jobs", buildJobs)
    -- Tools tab omitted: Tool Selector is always visible on the right when Q menu is open.
    local b7 = addTab("Admin Panel", buildAdmin)

    -- So content (inventory/tabs) draws on top of the sidebar and never appears underneath it
    if content.MoveToFront then content:MoveToFront() end

    timer.Simple(0, function() if IsValid(b1) then b1:DoClick() end end)
end

local function rarityColor(def)
    local r = def and def.rarity or ""
    if r == "" then return nil end
    return Inventory.GetRarityColor and Inventory.GetRarityColor(r) or nil
end

function makeSlotPanel(def, inst)
    local container = vgui.Create("DPanel")
    container:SetSize(Inventory.Config.SLOT, Inventory.Config.SLOT)
    container.Paint = function(self,w,h)
        draw.RoundedBox(4, 0, 0, w, h, Color(35, 35, 35, 255))
        surface.SetDrawColor(60, 60, 60, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        if drawTile then drawTile(w,h) end
    end

    container.ItemID = inst.id
    container._inst = inst
    container._dragging = false
    container._dragOffX = 0
    container._dragOffY = 0
    container._noTooltip = false
    container._dragGX = nil
    container._dragGY = nil

    -- Model preview (if available)
    local mdl = nil
    -- Visual: flat tile with centered icon (single panel only)
    local function drawTile(w,h)
        draw.RoundedBox(3, 2, 2, w-4, h-24, Color(50, 50, 54, 255))
        surface.SetDrawColor(80, 80, 90, 255)
        surface.DrawOutlinedRect(2, 2, w-4, h-24, 1)
        local matPath = (def and def.icon) or ""
        if not matPath or matPath == "" then
            -- pick a generic icon by category
            if def and def.class and def.class ~= "" then matPath = "icon16/gun.png" else matPath = "icon16/box.png" end
        end
        local ok, mat = pcall(Material, matPath)
    if ok and mat then
            surface.SetDrawColor(255,255,255,255)
            surface.SetMaterial(mat)
        local s = math.min(w-20, h-36, 48)
            surface.DrawTexturedRect((w-s)/2, (h-24-s)/2+2, s, s)
        else
            draw.SimpleText(def and def.name or (inst and inst.id) or "?", "DermaDefault", w/2, (h-24)/2+2, Color(220,220,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Always-on small model preview behind the flat icon if a model exists
    -- GMod expects paths under "models/..."; wrong paths (e.g. "Entities/Props/Jobs/...") show as missing
    do
        local modelPath = (def and def.model) or ""
        if (not modelPath or modelPath == "") and def and def.class and weapons and weapons.GetStored then
            local swep = weapons.GetStored(def.class)
            if swep and swep.WorldModel and swep.WorldModel ~= "" then modelPath = swep.WorldModel end
        end
        if modelPath and modelPath ~= "" and string.match(string.lower(modelPath), "^models/") then
            local mdlp = vgui.Create("DModelPanel", container)
            mdlp:SetPos(2,2)
            mdlp:SetSize(Inventory.Config.SLOT-4, Inventory.Config.SLOT-22)
            mdlp:SetMouseInputEnabled(false)
            mdlp:SetModel(modelPath)
            mdlp:SetFOV(22)
            function mdlp:LayoutEntity() return end
            if IsValid(mdlp.Entity) then
                local mn, mx = mdlp.Entity:GetRenderBounds()
                local size = math.max(math.abs(mn.x)+math.abs(mx.x), math.abs(mn.y)+math.abs(mx.y), math.abs(mn.z)+math.abs(mx.z))
                mdlp:SetCamPos(Vector(size*0.9, size*1.1, size*0.8))
                mdlp:SetLookAt((mn + mx) * 0.5)
            end
        end
    end

    local lbl = vgui.Create("DLabel", container)
    lbl:SetPos(4, Inventory.Config.SLOT-18)
    lbl:SetSize(Inventory.Config.SLOT-8, 16)
    lbl:SetText(def.name or inst.id)
    lbl:SetTextColor(rarityColor(def) or color_white)
    lbl:SetContentAlignment(4)
    lbl:SetVisible(false)

    -- removed per-tile xy overlay

    if inst.count and inst.count > 1 then
        local cnt = vgui.Create("DLabel", container)
        cnt:SetPos(Inventory.Config.SLOT-30, 4)
        cnt:SetSize(26, 16)
        cnt:SetText("x"..tostring(inst.count))
        cnt:SetTextColor(color_white)
        cnt:SetContentAlignment(6)
    end

    -- Only the container is draggable/droppable to avoid double-drag sources
    container:Droppable("inv_item")
    container.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            self._dragging = true
            self._committed = false
            self._noTooltip = true
            if IsValid(lbl) then lbl:SetVisible(false) end
            if IsValid(tip) then tip:Remove() end
            self:MouseCapture(true)
            self:SetZPos(9999)
            self:DragMousePress(code)
            if INV_DEBUG and INV_DEBUG.GetBool and INV_DEBUG:GetBool() then print("[INV] Drag start id=", inst.id, " uid=", inst.uid or "nil") end
        elseif code == MOUSE_RIGHT then
            local m = (DermaMenu and DermaMenu()) or vgui.Create("DMenu")
            if not IsValid(m) then return end
            local isWeapon = def.class and def.class ~= ""
            if not isWeapon then
        m:AddOption("Use", function()
            net.Start(Inventory.NET.ItemAction)
                net.WriteString("use"); net.WriteString(inst.id); net.WriteString("")
            net.SendToServer()
        end):SetIcon("icon16/accept.png")
            end

            -- Single Equip option: use inst.loadoutSlot if set (from admin creation), else choose slot from def
            -- Block Equip if that slot already has an item (must unequip first)
            local slot = Inventory.Slots.UTILITY
            if inst.loadoutSlot == "primary" or inst.loadoutSlot == "sidearm" then
                slot = inst.loadoutSlot
            elseif def.sidearm then slot = Inventory.Slots.SIDEARM
            elseif def.class then
                local cls = string.lower(def.class)
                if string.find(cls, "pist") or string.find(cls, "deagle") or string.find(cls, "elite") or
                   string.find(cls, "glock") or string.find(cls, "usp") or string.find(cls, "p228") or string.find(cls, "fiveseven") then
                    slot = Inventory.Slots.SIDEARM
                else slot = Inventory.Slots.PRIMARY end
            end
            local loadout = (Inventory.Client and Inventory.Client.Loadout) or {}
            local slotFilled = (loadout[slot] and loadout[slot] ~= "")
            if not slotFilled then
                m:AddOption("Equip", function()
                    net.Start(Inventory.NET.ItemAction)
                        net.WriteString("equip"); net.WriteString(inst.id); net.WriteString(slot); net.WriteString(inst.uid or "")
                    net.SendToServer()
                end):SetIcon("icon16/arrow_up.png")
            end
            -- When slot is filled, Equip is hidden; user must unequip from loadout (B) first

        m:AddSpacer()
        m:AddOption("Drop", function()
            net.Start(Inventory.NET.ItemAction)
                net.WriteString("drop"); net.WriteString(inst.id); net.WriteString(inst.uid or "")
            net.SendToServer()
        end):SetIcon("icon16/arrow_down.png")

        m:AddOption("Delete", function()
            net.Start(Inventory.NET.DeleteItems)
                net.WriteUInt(1, 16)
                net.WriteString(inst.id)
            net.SendToServer()
        end):SetIcon("icon16/delete.png")

            if m.Open then
                m:Open(gui.MouseX(), gui.MouseY())
            else
                m:SetPos(gui.MouseX(), gui.MouseY())
                m:MakePopup()
            end
        end
    end

    function container:OnMouseReleased(code)
        if code ~= MOUSE_LEFT then return end
        if not self._dragging then return end
        self._dragging = false
        self:DragMouseRelease(code)
        self:MouseCapture(false)
        self:SetZPos(0)
        if not IsValid(GRID) then return end
        if IsValid(GRID) then GRID._hoverGX, GRID._hoverGY = nil, nil end
        -- Fallback: if a Receiver didn't commit, snap to cell under mouse and send move
        if not self._committed then
            local mx, my = gui.MouseX(), gui.MouseY()
            local lx, ly = GRID:ScreenToLocal(mx, my)
            local cellX = (IsValid(GRID) and GRID._cellX) or (Inventory.Config.SLOT + Inventory.Config.PAD)
            local cellY = (IsValid(GRID) and GRID._cellY) or (Inventory.Config.SLOT + Inventory.Config.PAD)
            local slotSize = (IsValid(GRID) and GRID._slotSize) or Inventory.Config.SLOT
            local ins = (IsValid(GRID) and GRID._inset) or 1
            local gx = math.Clamp(math.floor((lx-ins)/cellX)+1, 1, Inventory.Config.GRID_W)
            local gy = math.Clamp(math.floor((ly-ins)/cellY)+1, 1, Inventory.Config.GRID_H)
            inst.x, inst.y = gx, gy
            self:SetParent(GRID)
            self:SetSize(slotSize, slotSize)
            self:SetPos((gx-1)*cellX + ins, (gy-1)*cellY + ins)
            if INV_DEBUG and INV_DEBUG.GetBool and INV_DEBUG:GetBool() then print("[INV] Fallback drop commit id=", inst.id, " uid=", inst.uid or "nil", " -> ", gx, gy) end
            net.Start(Inventory.NET.MoveItem)
                net.WriteString(inst.uid or "")
                net.WriteString(inst.id)
                net.WriteUInt(inst.page or 1, 8)
                net.WriteUInt(gx, 8)
                net.WriteUInt(gy, 8)
            net.SendToServer()
        end
        timer.Simple(0, function() if IsValid(self) then self._noTooltip = false end end)
    end

    -- Track hover cell while dragging for highlight (use tile's parent grid)
    container.Think = function(self)
        if not self._dragging then return end
        local grid = self:GetParent()
        if not IsValid(grid) then return end
        local mx, my = gui.MouseX(), gui.MouseY()
        local lx, ly = grid:ScreenToLocal(mx, my)
        local cellX = grid._cellX or (Inventory.Config.SLOT + Inventory.Config.PAD)
        local cellY = grid._cellY or (Inventory.Config.SLOT + Inventory.Config.PAD)
        local ins = grid._inset or 1
        local gx = math.Clamp(math.floor((lx-ins)/cellX)+1, 1, Inventory.Config.GRID_W)
        local gy = math.Clamp(math.floor((ly-ins)/cellY)+1, 1, Inventory.Config.GRID_H)
        grid._hoverGX, grid._hoverGY = gx, gy
    end

    -- Hover tooltip (size depends on content so slots/info never overflow)
    local tip
    container.OnCursorEntered = function()
        if container._dragging or container._noTooltip then return end
        if IsValid(tip) then tip:Remove() end
        local slotsHaveForSize = (inst and inst.slots) and tonumber(inst.slots) or 0
        local tipW, tipH = 300, 120
        if slotsHaveForSize and slotsHaveForSize > 0 then
            tipW, tipH = 320, 165
        end
        local sx, sy = container:LocalToScreen(container:GetWide()+8, 0)
        tip = vgui.Create("DPanel")
        tip:SetSize(tipW, tipH)
        tip:SetPos(sx, sy)
        tip:SetZPos(10000)
        tip:SetDrawOnTop(true)
        tip.Paint = function(self,w,h)
            -- background
            draw.RoundedBox(4,0,0,w,h, Color(30,30,30,245))
            surface.SetDrawColor(70,70,80,255)
            surface.DrawOutlinedRect(0,0,w,h,1)

            -- top-tier glow around tooltip for Epic/Legendary/Unique
            local r = def.rarity or ""
            if r == "Epic" or r == "Legendary" or r == "Unique" then
                local c = rarityColor(def) or Color(255,255,255)
                surface.SetDrawColor(c.r, c.g, c.b, 60)
                surface.DrawOutlinedRect(1,1,w-2,h-2,2)
                surface.SetDrawColor(c.r, c.g, c.b, 30)
                surface.DrawOutlinedRect(2,2,w-4,h-4,2)
            end

            -- header line: Rarity and Item Name
            local effectiveRarity = (inst and inst.rarity and inst.rarity ~= "") and inst.rarity or (def.rarity or "")
            local rc = Inventory.GetRarityColor and Inventory.GetRarityColor(effectiveRarity) or color_white
            local rarityText = (effectiveRarity ~= "" and (effectiveRarity .. " ") or "")
            draw.SimpleText(rarityText .. (def.name or inst.id), "DermaDefaultBold", 10, 8, rc)

            local y = 28
            -- Damage line (weapons only)
            if def.class and def.class ~= "" then
                local bd = tonumber((inst and inst.baseDamage) or def.baseDamage or 0) or 0
                local mul = Inventory.GetRarityDamageMultiplier and Inventory.GetRarityDamageMultiplier(effectiveRarity or "") or 1
                local dmg = math.floor(bd * mul)
                draw.SimpleText("Damage: " .. tostring(dmg), "DermaDefault", 10, y, Color(170,220,120))
                y = y + 18
            end

            -- Modification slots: only show when item has slots; keep fully inside tooltip with right margin
            local slotsHave = (inst and inst.slots) and tonumber(inst.slots) or 0
            if slotsHave and slotsHave > 0 then
                local slotSize = 36
                local gap = 6
                local rightMargin = 16
                local slotBlockW = 3 * slotSize + 2 * gap
                local slotStartX = w - rightMargin - slotBlockW
                for row = 0, 1 do
                    for col = 0, 2 do
                        local i = row * 3 + col
                        if i < slotsHave then
                            local sx = slotStartX + col * (slotSize + gap)
                            local sy = y + row * (slotSize + gap)
                            surface.SetDrawColor(72, 76, 88, 255)
                            draw.RoundedBox(2, sx, sy, slotSize, slotSize, Color(38, 42, 50, 220))
                            surface.DrawOutlinedRect(sx, sy, slotSize, slotSize, 1)
                        end
                    end
                end
                y = y + 2 * (slotSize + gap) + 4
            end

            -- Description last
            -- Crafter as description
            if inst and inst.crafter and inst.crafter ~= "" then
                draw.SimpleText("Crafted by: "..tostring(inst.crafter), "DermaDefault", 10, h-28, Color(200,200,200))
            end
            if inst and inst.admin then
                surface.SetDrawColor(200,60,60,255)
                surface.DrawOutlinedRect(w-20, h-20, 14, 14, 2)
                surface.DrawLine(w-19, h-19, w-7, h-7)
                surface.DrawLine(w-19, h-7, w-7, h-19)
            end
        end
        if IsValid(lbl) then lbl:SetVisible(true) end
        -- no-op; tile always draws icon/model now
    end
    container.OnCursorExited = function()
        if IsValid(tip) then tip:Remove() end
        if IsValid(lbl) then lbl:SetVisible(false) end
        -- no-op
    end

    container.OnRemove = function()
        if IsValid(tip) then tip:Remove() end
    end

    return container
end

local function rebuild()
    if not IsValid(GRID) then return end
    -- Clear grid children safely for both DIconLayout and generic panels
    if GRID.Clear then GRID:Clear() else for _, c in ipairs(GRID:GetChildren()) do c:Remove() end end

    local q = (IsValid(FRAME) and FRAME._search) or nil
    -- Force absolute positioning; use grid's dynamic cell/slot so grid fills area
    local isIconLayout = false
    local cellX = (IsValid(GRID) and GRID._cellX) or (Inventory.Config.SLOT + Inventory.Config.PAD)
    local cellY = (IsValid(GRID) and GRID._cellY) or (Inventory.Config.SLOT + Inventory.Config.PAD)
    local slotSize = (IsValid(GRID) and GRID._slotSize) or Inventory.Config.SLOT
    for i, inst in ipairs(Items) do
        local def = ItemsCatalog[inst.id]
        if def then
            local ok = true
            if q then
                local name = string.lower(def.name or inst.id)
                local id   = string.lower(inst.id or "")
                ok = string.find(name, q, 1, true) or string.find(id, q, 1, true)
            end
            if ok then
                inst._idx = i
                local pnl = makeSlotPanel(def, inst)
                if isIconLayout then
                GRID:Add(pnl)
                else
                    pnl:SetParent(GRID)
                    pnl:SetSize(slotSize, slotSize)
                    local ins = (IsValid(GRID) and GRID._inset) or 1
                    local px = (math.max(1, inst.x or 1)-1)*cellX + ins
                    local py = (math.max(1, inst.y or 1)-1)*cellY + ins
                    if INV_DEBUG and INV_DEBUG.GetBool and INV_DEBUG:GetBool() then print("[INV] Place ", inst.id, inst.uid or "nil", " -> ", px, py) end
                    pnl:SetPos(px, py)
                    if INV_DEBUG and INV_DEBUG.GetBool and INV_DEBUG:GetBool() then timer.Simple(0, function() if IsValid(pnl) then local sx, sy = pnl:GetPos(); print("[INV] After SetPos getpos=", sx, sy) end end) end
                end
            end
        end
    end
end

-- Networking
net.Receive(Inventory.NET.SyncInventory, function()
    MaxPages = net.ReadUInt(8)
    Inventory.Client.MaxPages = MaxPages
    -- reset items table
    for k in pairs(Items) do Items[k] = nil end

    local n = net.ReadUInt(16)
    for i=1,n do
        local id   = net.ReadString()
        local uid  = net.ReadString()
        local page = net.ReadUInt(8)
        local x    = net.ReadUInt(8)
        local y    = net.ReadUInt(8)
        local cnt  = net.ReadUInt(16)
        local slots = net.ReadUInt(4)
        local admin = net.ReadBool()
        local crafter = net.ReadString()
        local instRarity = net.ReadString()
        local instBaseDmg = net.ReadUInt(16)
        local loadoutSlot = net.ReadString() or ""
        table.insert(Items, { id=id, uid=uid, page=page, x=x, y=y, count=cnt, slots=slots, admin=admin, crafter=crafter, rarity=instRarity, baseDamage=instBaseDmg, loadoutSlot=(loadoutSlot == "primary" or loadoutSlot == "sidearm") and loadoutSlot or nil })
    end

    -- catalog (sent once per sync)
    for k in pairs(ItemsCatalog) do ItemsCatalog[k] = nil end
    local cn = net.ReadUInt(12)
    for i=1,cn do
        local id   = net.ReadString()
        ItemsCatalog[id] = {
            id=id,
            name = net.ReadString(),
            desc = net.ReadString(),
            icon = net.ReadString(),
            category = net.ReadString(),
            class = net.ReadString(),
            model = net.ReadString(),
            rarity = net.ReadString(),
            baseDamage = net.ReadUInt(16),
        }
    end

    rebuild()
    notifyRebuilders()
end)

-- Public open/close for the bridge
function Inventory_Open()
    ensureFrame()
    FRAME:SetVisible(true)
    FRAME:MakePopup()
    net.Start(Inventory.NET.RequestFull) net.SendToServer()
    gui.EnableScreenClicker(true)
    -- After first layout, auto-adjust frame height to fully fit the grid
    timer.Simple(0.05, function()
        if not IsValid(FRAME) or not IsValid(GRID) then return end
        local desiredH = (Inventory.Config.GRID_H * (Inventory.Config.SLOT + Inventory.Config.PAD)) + 4
        local actualH = GRID:GetTall() or 0
        local delta = desiredH - actualH
        if delta > 0 then
            local w, h = FRAME:GetSize()
            FRAME:SetSize(w, h + delta + 8)
            FRAME:Center()
        end
    end)
end

function Inventory_Close()
    if IsValid(FRAME) then FRAME:SetVisible(false) end
    gui.EnableScreenClicker(false)
end

-- Q key (+menu bind): hold to open inventory, release to close. Block spawn menu and handle ourselves.
hook.Add("PlayerBindPress", "Inventory_BlockMenuBind", function(ply, bind, pressed)
    if bind ~= "+menu" then return end
    if pressed then
        Inventory_Open()
        if g_SpawnMenu and IsValid(g_SpawnMenu) then g_SpawnMenu:SetVisible(false) end
    else
        Inventory_Close()
    end
    return true -- block default (spawn menu)
end)

-- Aggressively hide spawn menu every frame while inventory is visible (stops flash)
hook.Add("Think", "Inventory_HideSpawnMenuWhenOpen", function()
    if not IsValid(FRAME) or not FRAME:IsVisible() then return end
    if g_SpawnMenu and IsValid(g_SpawnMenu) then g_SpawnMenu:SetVisible(false) end
end)

-- Escape closes inventory (Q menu) so it doesn't stay open and bug when escape/console is used
hook.Add("Think", "Inventory_EscapeClose", function()
    if input.IsKeyDown(KEY_ESCAPE) and IsValid(FRAME) and FRAME:IsVisible() then
        Inventory_Close()
    end
end)

-- World tooltip for dropped inventory items: name + "Press E to pick up" only; box sized to fit.
hook.Add("HUDPaint", "INV_DrawWorldTooltip", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local tr = ply:GetEyeTrace()
    if not tr or not IsValid(tr.Entity) then return end
    local e = tr.Entity
    if e:GetPos():DistToSqr(ply:GetShootPos()) > (250*250) then return end
    local id = e:GetNWString("inv_id", "")
    if id == "" then return end
    local rarity = e:GetNWString("inv_rarity", "")
    local def = (Inventory and Inventory.Items and Inventory.Items[id]) or ItemsCatalog[id]
    if not def then return end
    local rc = Inventory.GetRarityColor and Inventory.GetRarityColor(rarity) or Color(230,230,230)
    local nameStr = (rarity ~= "" and (rarity.." ") or "") .. (def.name or id)
    local hintStr = "Press E to pick up"
    surface.SetFont("DermaDefaultBold")
    local tw, th1 = surface.GetTextSize(nameStr)
    surface.SetFont("DermaDefault")
    local _, th2 = surface.GetTextSize(hintStr)
    local boxW = math.max(tw + 24, 160)
    local boxH = th1 + th2 + 20
    local scrpos = e:GetPos():ToScreen()
    local x, y = scrpos.x, scrpos.y - 20 - boxH / 2
    local l, t = x - boxW/2, y
    surface.SetDrawColor(30,30,30,230)
    surface.DrawRect(l, t, boxW, boxH)
    surface.SetDrawColor(70,70,80,255)
    surface.DrawOutlinedRect(l, t, boxW, boxH, 1)
    draw.SimpleText(nameStr, "DermaDefaultBold", x, t + 10, rc, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    draw.SimpleText(hintStr, "DermaDefault", x, t + 10 + th1 + 6, Color(180,180,180), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end)

-- Notifications from server (player-only)
net.Receive(Inventory.NET.Notify, function()
    local msg = net.ReadString() or ""
    if msg == "" then return end
    if notification and notification.AddLegacy then
        notification.AddLegacy(msg, NOTIFY_GENERIC, 3)
    else
        chat.AddText(Color(200,200,200), msg)
    end
    surface.PlaySound("buttons/button15.wav")
end)

--
-- Spawnmenu support: panelized inventory view
--
function Inventory.BuildInventoryPanel(parent)
    if not IsValid(parent) then return end

    local root = vgui.Create("DPanel", parent)
    root:Dock(FILL)
    root:DockMargin(0,0,0,0)

    local pad = 10

    -- Left: Grid area
    -- Top bar
    local top = vgui.Create("DPanel", root)
    top:Dock(TOP)
    top:DockMargin(pad, pad, pad, 0)
    top:SetTall(32)
    function top:Paint(w,h)
        surface.SetDrawColor(18,18,18,240) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(60,60,60,255) surface.DrawOutlinedRect(0,0,w,h,1)
    end
    local pageBtn = vgui.Create("DButton", top)
    pageBtn:Dock(LEFT)
    pageBtn:DockMargin(6,4,0,4)
    pageBtn:SetWide(100)
    pageBtn:SetText("Page 1")
    pageBtn:SetEnabled(false)

    -- Grid fills below
    local gridWrap = vgui.Create("DPanel", root)
    gridWrap:Dock(FILL)
    gridWrap:DockMargin(pad, 5, pad, pad)
    local gridRadius = 6
    function gridWrap:Paint(w,h)
        draw.RoundedBox(gridRadius, 0, 0, w, h, Color(25, 25, 25, 230))
        surface.SetDrawColor(col("border", Color(50, 60, 78)):Unpack())
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- manual-positioned grid panel to respect item x/y and enable drag/drop
    local grid = vgui.Create("DPanel", gridWrap)
    grid:Dock(FILL)
    grid:SetMouseInputEnabled(true)
    grid._hoverGX, grid._hoverGY = nil, nil
    grid._inset = 1
    local slotRadius = 4
    function grid:Paint(w,h)
        local cell = Inventory.Config.SLOT + Inventory.Config.PAD
        local slotSize = Inventory.Config.SLOT
        local ins = self._inset or 1
        draw.RoundedBox(slotRadius, 0, 0, w, h, Color(30, 30, 30, 255))
        -- Visible grid: rounded slot boxes for each cell
        for gy = 1, Inventory.Config.GRID_H do
            for gx = 1, Inventory.Config.GRID_W do
                local x = (gx - 1) * cell + ins
                local y = (gy - 1) * cell + ins
                draw.RoundedBox(slotRadius, x, y, slotSize, slotSize, Color(38, 42, 50, 220))
                surface.SetDrawColor(55, 55, 58, 200)
                surface.DrawOutlinedRect(x, y, slotSize, slotSize, 1)
            end
        end
        -- Draw green drop highlight if present (rounded)
        local gx, gy = self._hoverGX, self._hoverGY
        if gx and gy then
            local x = (gx - 1) * cell + ins
            local y = (gy - 1) * cell + ins
            draw.RoundedBox(slotRadius, x, y, slotSize, slotSize, Color(60, 120, 60, 120))
            surface.SetDrawColor(80, 180, 80, 200)
            surface.DrawOutlinedRect(x, y, slotSize, slotSize, 2)
        end
    end

    function grid:GetCellFromLocal(lx, ly)
        local cell = Inventory.Config.SLOT + Inventory.Config.PAD
        local ins = self._inset or 1
        local gx = math.Clamp(math.floor((lx-ins)/cell)+1, 1, Inventory.Config.GRID_W)
        local gy = math.Clamp(math.floor((ly-ins)/cell)+1, 1, Inventory.Config.GRID_H)
        return gx, gy
    end

    -- Debug: visualize current instances as we lay them out
    function grid:OnChildAdded()
        -- intentionally empty; hook exists to keep debug footprint minimal
    end

    local function rebuildPanel()
        if not IsValid(grid) then return end
        for _, child in ipairs(grid:GetChildren()) do child:Remove() end
        if INV_DEBUG and INV_DEBUG.GetBool and INV_DEBUG:GetBool() then print("[INV] Rebuild grid: items=", #Items) end
        local prevGRID = GRID
        GRID = grid
        local q = root._search
        local cell = Inventory.Config.SLOT + Inventory.Config.PAD
        -- Create invisible slot receivers
        if not IsValid(grid._slotsHost) then
            if INV_DEBUG and INV_DEBUG.GetBool and INV_DEBUG:GetBool() then print("[INV] Creating slot receivers W/H:", Inventory.Config.GRID_W, Inventory.Config.GRID_H) end
            grid._slotsHost = vgui.Create("DPanel", grid)
            grid._slotsHost:SetSize(Inventory.Config.GRID_W*cell, Inventory.Config.GRID_H*cell)
            grid._slotsHost:SetPos(grid._inset or 1, grid._inset or 1)
            if grid._slotsHost.MoveToBack then grid._slotsHost:MoveToBack() end
            grid._slots = {}
            for gy=1, Inventory.Config.GRID_H do
                for gx=1, Inventory.Config.GRID_W do
                    local slot = vgui.Create("DPanel", grid._slotsHost)
                    slot:SetSize(Inventory.Config.SLOT, Inventory.Config.SLOT)
                    slot:SetPos((gx-1)*cell, (gy-1)*cell)
                    slot:SetVisible(true)
                    slot.gx, slot.gy = gx, gy
                    function slot:Paint(w,h)
                        if grid._hoverGX == self.gx and grid._hoverGY == self.gy then
                            draw.RoundedBox(4, 0, 0, w, h, Color(60, 120, 60, 120))
                            surface.SetDrawColor(80, 180, 80, 200)
                            surface.DrawOutlinedRect(0, 0, w, h, 2)
                        end
                    end
                    -- Register drop receiver (do NOT overwrite the built-in Receiver method)
                    slot:Receiver("inv_item", function(self, panels, dropped)
                        if not panels or not panels[1] then return end
                        local pnl = panels[1]
                        if not pnl._inst then return end
                        local inst = pnl._inst
                         if not dropped then
                             grid._hoverGX, grid._hoverGY = self.gx, self.gy
                             return
                         end
                         -- only commit moves from container panels
                         if pnl ~= container and pnl:GetParent() ~= grid then
                             -- ignore child drags (shouldn't exist anymore)
                             return
                         end
                         local gx, gy = self.gx, self.gy
                         local cell = Inventory.Config.SLOT + Inventory.Config.PAD
                         inst.x, inst.y = gx, gy
                         pnl:SetParent(grid)
                         local ins = grid._inset or 1
                         pnl:SetPos((gx-1)*cell + ins, (gy-1)*cell + ins)
                        if INV_DEBUG and INV_DEBUG.GetBool and INV_DEBUG:GetBool() then print("[INV] Drop commit id=", inst.id, " uid=", inst.uid or "nil", " -> ", gx, gy) end
                        pnl._committed = true
                         net.Start(Inventory.NET.MoveItem)
                             net.WriteString(inst.uid or "")
                             net.WriteString(inst.id)
                             net.WriteUInt(inst.page or 1, 8)
                             net.WriteUInt(gx, 8)
                             net.WriteUInt(gy, 8)
                         net.SendToServer()
                         grid._hoverGX, grid._hoverGY = nil, nil
                    end)
                end
            end
        end
        for i, inst in ipairs(Items) do
            inst._idx = i
            local def = ItemsCatalog[inst.id]
            if def then
                local ok = true
                if q then
                    local name = string.lower(def.name or inst.id)
                    local id   = string.lower(inst.id or "")
                    ok = string.find(name, q, 1, true) or string.find(id, q, 1, true)
                end
                if ok then
                    local pnl = makeSlotPanel(def, inst)
                    pnl._inst = inst
                    pnl:SetParent(grid)
                    pnl:SetSize(Inventory.Config.SLOT, Inventory.Config.SLOT)
                    local ins = grid._inset or 1
                    pnl:SetPos((math.max(1, inst.x or 1)-1)*cell + ins, (math.max(1, inst.y or 1)-1)*cell + ins)
                    -- Container is the only droppable; avoid double-source
                    -- Debug overlay for position
                    pnl._dbg = vgui.Create("DLabel", pnl)
                    pnl._dbg:SetPos(4,4)
                    pnl._dbg:SetSize(40,12)
                    pnl._dbg:SetTextColor(Color(180,180,180))
                    pnl._dbg:SetText(string.format("%d,%d", inst.x or 1, inst.y or 1))
                    -- Right-click menu
                    pnl.DoRightClick = function()
                        local m = DermaMenu()
                        local isWeapon = def.class and def.class ~= ""
                        if not isWeapon then
                            m:AddOption("Use", function()
                                net.Start(Inventory.NET.ItemAction)
                                    net.WriteString("use"); net.WriteString(inst.id); net.WriteString("")
                                net.SendToServer()
                            end)
                        else
                            local slot = Inventory.Slots.PRIMARY
                            if inst.loadoutSlot == "primary" or inst.loadoutSlot == "sidearm" then slot = inst.loadoutSlot
                            elseif def.sidearm then slot = Inventory.Slots.SIDEARM
                            elseif def.class then
                                local cls = string.lower(def.class)
                                if string.find(cls, "pist") or string.find(cls, "deagle") or string.find(cls, "elite") or
                                   string.find(cls, "glock") or string.find(cls, "usp") or string.find(cls, "p228") or string.find(cls, "fiveseven") then
                                    slot = Inventory.Slots.SIDEARM
                                else slot = Inventory.Slots.PRIMARY end
                            end
                            local loadout = (Inventory.Client and Inventory.Client.Loadout) or {}
                            local slotFilled = (loadout[slot] and loadout[slot] ~= "")
                            if not slotFilled then
                                m:AddOption("Equip", function()
                                    net.Start(Inventory.NET.ItemAction)
                                        net.WriteString("equip"); net.WriteString(inst.id); net.WriteString(slot); net.WriteString(inst.uid or "")
                                    net.SendToServer()
                                end)
                            end
                        end
                        m:AddOption("Delete", function()
                            net.Start(Inventory.NET.DeleteItems)
                                net.WriteUInt(1, 16)
                                net.WriteString(inst.id)
                            net.SendToServer()
                        end)
                        m:Open()
                    end
                end
            end
        end
        GRID = prevGRID
    end

    -- register rebuild callback and cleanup on remove
    registerRebuilder(rebuildPanel)
    -- Trigger a fresh snapshot to ensure we have item positions and avoid default 1,1 stacking
    net.Start(Inventory.NET.RequestFull) net.SendToServer()
    root.OnRemove = function()
        -- remove all instances of this callback
        for i = #Rebuilders, 1, -1 do
            if Rebuilders[i] == rebuildPanel then table.remove(Rebuilders, i) end
        end
    end

    -- initial fetch and build
    net.Start(Inventory.NET.RequestFull) net.SendToServer()
    timer.Simple(0, rebuildPanel)

    return root
end
