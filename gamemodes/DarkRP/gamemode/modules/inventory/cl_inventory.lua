-- Debug print to confirm the file is loading
print("[Inventory Module] cl_inventory.lua loaded successfully")

-- Helper function for debug messages
local function DebugPrint(...)
    if GetConVar("rp_debug") and GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Include sh_items.lua
if file.Exists("modules/inventory/sh_items.lua", "LUA") then
    include("modules/inventory/sh_items.lua")
    DebugPrint("[Inventory Module] Successfully included sh_items.lua")
else
    DebugPrint("[Inventory Module] Warning: sh_items.lua not found at modules/inventory/sh_items.lua")
end

-- Include cl_jobs.lua
local jobsPath = "darkrp_modules/rpjobs/cl_jobs.lua"
if file.Exists(jobsPath, "LUA") then
    include(jobsPath)
    if BuildJobsPanel then
        DebugPrint("[Inventory Module] Successfully included cl_jobs.lua from " .. jobsPath)
    else
        DebugPrint("[Inventory Module] Error: cl_jobs.lua included but BuildJobsPanel not defined (possible syntax error)")
    end
else
    DebugPrint("[Inventory Module] Error: cl_jobs.lua not found at " .. jobsPath)
end

-- Include cl_rpents.lua
local entsPath = "darkrp_modules/rpents/cl_rpents.lua"
if file.Exists(entsPath, "LUA") then
    include(entsPath)
    if BuildEntitiesPanel then
        DebugPrint("[Inventory Module] Successfully included cl_rpents.lua from " .. entsPath)
    else
        DebugPrint("[Inventory Module] Error: cl_rpents.lua included but BuildEntitiesPanel not defined (possible syntax error)")
    end
else
    DebugPrint("[Inventory Module] Error: cl_rpents.lua not found at " .. entsPath)
end

-- Fallback if BuildJobsPanel is not defined
if not BuildJobsPanel then
    function BuildJobsPanel(parent)
        if not IsValid(parent) then return end
        local label = vgui.Create("DLabel", parent)
        label:SetText("Jobs Tab - Failed to load (cl_jobs.lua not found or has errors)")
        label:SetPos(10, 10)
        label:SetSize(300, 20)
        label:SetColor(Color(255, 0, 0))
        DebugPrint("[Inventory Module] Fallback BuildJobsPanel used because cl_jobs.lua was not loaded properly")
    end
end

-- Fallback if BuildEntitiesPanel is not defined
if not BuildEntitiesPanel then
    function BuildEntitiesPanel(parent)
        if not IsValid(parent) then return end
        local label = vgui.Create("DLabel", parent)
        label:SetText("Entities Tab - Failed to load (cl_rpents.lua not found or has errors)")
        label:SetPos(10, 10)
        label:SetSize(300, 20)
        label:SetColor(Color(255, 0, 0))
        DebugPrint("[Inventory Module] Fallback BuildEntitiesPanel used because cl_rpents.lua was not loaded properly")
    end
end

-- Client-Side Logic
local Inventory, InventoryPositions, Loadout = {}, {}, {}
local InventoryFrame, ToolSelectorFrame, inventoryTab, resourcesTab, adminTab, propsTab, entitiesTab, jobsTab
local isInventoryOpen, isToolSelectorOpen, isQKeyHeld = false, false, false
local currentTooltip, currentInfoBox
local activeMenus = {}
local allowedTools = { "button", "fading_door", "keypad_willox", "camera", "nocollide", "remover", "stacker" }
local currentPage = 1
local currentNotification = nil
local SelectedItems = {}
local MultiSelectMode = false
local PendingUnequip = {}

-- Tooltip Configuration
surface.CreateFont("TooltipFont", { font = "DermaDefault", size = 14, weight = 500 })
local TOOLTIP_LINE_HEIGHT = 18
local TOOLTIP_PADDING_X = 10
local TOOLTIP_PADDING_Y = 10
local TOOLTIP_ZPOS = 1000
local TOOLTIP_SPACING = 2
local TOOLTIP_FADEOUT_DELAY = 0.2
local RARITY_COLORS = {
    common = Color(200, 200, 200),
    uncommon = Color(0, 255, 0),
    rare = Color(0, 0, 139),
    epic = Color(255, 245, 200),
    legendary = Color(139, 0, 0)
}

-- Utility Functions
local function GenerateUUID()
    return string.format("%08x-%04x-%04x-%04x-%12x", 
        math.random(0, 0xffffffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffffffffffff))
end

local function CreateTooltipContent(item, itemData)
    local isWeaponOrArmor = itemData.category == "Weapons" or itemData.category == "Armor"
    local isUtility = itemData.category == "Utility"
    local rarity = isWeaponOrArmor and (item.rarity or itemData.baseRarity or "Common") or nil
    local rarityColor = rarity and RARITY_COLORS[rarity:lower()] or Color(255, 255, 255)
    local damage = item.damage or "N/A"
    local slotType = item.slotType or "N/A"
    local slotTypeColor = (slotType == "Sidearm") and RARITY_COLORS.epic or Color(255, 255, 255)
    local crafter = item.crafter or "Unknown"

    local lines = {}
    if isWeaponOrArmor then
        table.insert(lines, { text = rarity, color = rarityColor })
        table.insert(lines, { text = itemData.name, color = Color(255, 255, 255) })
        if itemData.category == "Weapons" then
            table.insert(lines, { text = slotType, color = slotTypeColor })
        end
        table.insert(lines, { text = "Damage: " .. damage, color = Color(255, 255, 255) })
        table.insert(lines, { text = "Crafter: " .. crafter, color = Color(255, 255, 220) })
    elseif isUtility then
        table.insert(lines, { text = itemData.name, color = Color(255, 250, 250) })
        table.insert(lines, { text = "Crafter: " .. crafter, color = Color(255, 255, 220) })
    else
        table.insert(lines, { text = itemData.name, color = Color(255, 255, 255) })
        table.insert(lines, { text = "Damage: " .. damage, color = Color(255, 255, 255) })
        table.insert(lines, { text = "Crafter: " .. crafter, color = Color(255, 255, 220) })
    end
    return lines
end

local function CreateTooltip(parent, lines, posX, posY, row, col)
    local maxWidth = 0
    for _, line in ipairs(lines) do
        surface.SetFont("TooltipFont")
        local textWidth, _ = surface.GetTextSize(line.text)
        maxWidth = math.max(maxWidth, textWidth)
    end
    local tooltipWidth = maxWidth + TOOLTIP_PADDING_X * 2
    local tooltipHeight = (#lines * TOOLTIP_LINE_HEIGHT) + (TOOLTIP_PADDING_Y * 2)

    currentTooltip = vgui.Create("DPanel", parent)
    currentTooltip:SetSize(tooltipWidth, tooltipHeight)
    currentTooltip:SetZPos(TOOLTIP_ZPOS)
    currentTooltip.Lines = lines

    local slotWidth, slotHeight = 97, 97
    local isRightmost = col == 10
    local isBottomRow = row == 6
    local localX, localY

    localX = posX + slotWidth + TOOLTIP_SPACING
    localY = posY

    if isRightmost then
        if isBottomRow then
            localX = posX - (tooltipWidth - slotWidth) / 2
            localY = posY - tooltipHeight - TOOLTIP_SPACING
        else
            localX = posX - (tooltipWidth - slotWidth) / 2
            localY = posY + slotHeight + TOOLTIP_SPACING
        end
    elseif isBottomRow then
        localX = posX + slotWidth + TOOLTIP_SPACING
        localY = posY - tooltipHeight - TOOLTIP_SPACING
    end

    local gridWidth, gridHeight = parent:GetSize()
    localX = math.max(0, math.min(localX, gridWidth - tooltipWidth))
    localY = math.max(0, math.min(localY, gridHeight - tooltipHeight))

    currentTooltip:SetPos(localX, localY)
    currentTooltip.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
        for i, line in ipairs(self.Lines) do
            draw.SimpleText(line.text, "TooltipFont", TOOLTIP_PADDING_X, TOOLTIP_PADDING_Y + (i - 1) * TOOLTIP_LINE_HEIGHT, line.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
end

local function ShowNotification(message)
    if IsValid(currentNotification) then
        currentNotification:Remove()
        currentNotification = nil
    end

    local screenW, screenH = ScrW(), ScrH()
    currentNotification = vgui.Create("DPanel")
    currentNotification:SetSize(300, 50)
    currentNotification:SetPos(screenW - 320, 20)
    currentNotification:SetZPos(1000)
    currentNotification.Think = function(self)
        if self.StartTime and (CurTime() - self.StartTime) > 3 then
            self:Remove()
            if currentNotification == self then
                currentNotification = nil
            end
        end
    end
    currentNotification.StartTime = CurTime()
    currentNotification.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
        draw.SimpleText(message, "DermaDefaultBold", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    surface.PlaySound("ui/buttonclick.wav")
end

-- UI Functions
local function CreateTabPanel(parent, deleteButton, multiButton)
    local tabPanel = vgui.Create("DPanel", parent)
    tabPanel:SetSize(980, 50)
    tabPanel:SetPos(5, 5)
    tabPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    local pageTab = vgui.Create("DButton", tabPanel)
    pageTab:SetSize(100, 40)
    pageTab:SetPos(10, 5)
    pageTab:SetText("Page 1")
    pageTab.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, currentPage == 1 and Color(70, 70, 70, 240) or Color(50, 50, 50, 240))
    end
    pageTab.DoClick = function() 
        currentPage = 1 
        BuildInventoryUI(parent, currentPage) 
        DebugPrint("[Inventory Module] Switched to page 1")
    end

    local panelWidth = 980
    local buttonSpacing = 10
    local deleteButtonWidth = 120
    local multiButtonWidth = 80

    deleteButton:SetSize(deleteButtonWidth, 40)
    deleteButton:SetPos(panelWidth - deleteButtonWidth - buttonSpacing, 5)
    deleteButton:SetText("Delete Selected")
    deleteButton:SetTextColor(Color(0, 0, 0))
    deleteButton:SetVisible(false)
    deleteButton:SetParent(tabPanel)
    deleteButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(255, 50, 50, 240) or Color(200, 0, 0, 240))
    end
    deleteButton.DoClick = function()
        if table.IsEmpty(SelectedItems) then
            DebugPrint("[Inventory Module] No items selected to delete")
            return
        end
        for uniqueID, _ in pairs(SelectedItems) do
            net.Start("DeleteItem")
            net.WriteString(uniqueID)
            net.WriteUInt(currentPage, 8)
            net.SendToServer()
            DebugPrint("[Inventory Module] Deleting selected item " .. uniqueID .. " from page " .. currentPage)
        end
        SelectedItems = {}
        MultiSelectMode = false
        BuildInventoryUI(parent, currentPage)
        DebugPrint("[Inventory Module] Cleared selected items after deletion")
    end

    multiButton:SetSize(multiButtonWidth, 40)
    multiButton:SetPos(panelWidth - deleteButtonWidth - buttonSpacing - multiButtonWidth - buttonSpacing, 5)
    multiButton:SetText("Multi")
    multiButton:SetTextColor(Color(0, 0, 0))
    multiButton:SetVisible(false)
    multiButton:SetParent(tabPanel)
    multiButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, MultiSelectMode and Color(100, 200, 100, 240) or (self:IsHovered() and Color(100, 100, 100, 240) or Color(80, 80, 80, 240)))
    end
    multiButton.DoClick = function()
        MultiSelectMode = not MultiSelectMode
        multiButton:SetText(MultiSelectMode and "Multi: On" or "Multi")
        BuildInventoryUI(parent, currentPage)
        DebugPrint("[Inventory Module] Toggled multi-select mode: " .. tostring(MultiSelectMode))
    end

    tabPanel.Think = function(self)
        local hasSelection = not table.IsEmpty(SelectedItems)
        if hasSelection and not deleteButton:IsVisible() then
            deleteButton:SetVisible(true)
            multiButton:SetVisible(true)
            DebugPrint("[Inventory Module] Showing Delete Selected and Multi buttons")
        elseif not hasSelection and deleteButton:IsVisible() then
            deleteButton:SetVisible(false)
            multiButton:SetVisible(false)
            DebugPrint("[Inventory Module] Hiding Delete Selected and Multi buttons")
        end
    end

    return tabPanel
end

local function CreateGridPanel(parent)
    local gridPanel = vgui.Create("DPanel", parent)
    gridPanel:SetSize(980, 640)
    gridPanel:SetPos(5, 55)
    gridPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end
    gridPanel.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            SelectedItems = {}
            MultiSelectMode = false
            BuildInventoryUI(parent, currentPage)
            DebugPrint("[Inventory Module] Cleared selection due to click-off")
        end
    end
    return gridPanel
end

local function CreateSlots(gridPanel)
    local slotWidth, slotHeight = 97, 97
    local slots = {}
    for row = 1, 6 do
        slots[row] = {}
        for col = 1, 10 do
            local slot = vgui.Create("DPanel", gridPanel)
            slot:SetSize(slotWidth, slotHeight)
            slot:SetPos((col - 1) * (slotWidth + 1), (row - 1) * (slotHeight + 1))
            slot.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150)) end
            slot:Receiver("inventory_item", function(self, panels, dropped)
                if not dropped or not panels[1] or MultiSelectMode then return end
                local draggedUniqueID = panels[1].UniqueID
                local newPos = {row, col}
                local occupiedItem
                for uniqueID, pos in pairs(InventoryPositions) do
                    if pos[1] == row and pos[2] == col and uniqueID != draggedUniqueID then
                        occupiedItem = uniqueID
                        break
                    end
                end
                if occupiedItem then
                    local oldPos = InventoryPositions[draggedUniqueID]
                    InventoryPositions[draggedUniqueID] = newPos
                    InventoryPositions[occupiedItem] = oldPos
                else
                    InventoryPositions[draggedUniqueID] = newPos
                end
                net.Start("UpdateInventoryPositions")
                net.WriteUInt(currentPage, 8)
                net.WriteTable(InventoryPositions)
                net.SendToServer()
                DebugPrint("[Inventory Module] Moved item " .. draggedUniqueID .. " to position (" .. row .. ", " .. col .. ")")
            end)
            slots[row][col] = slot
        end
    end
    return slots
end

local function PopulateSlots(slots, gridPanel)
    local slotWidth, slotHeight = 97, 97
    for _, item in ipairs(Inventory) do
        local itemID = item.itemID
        local uniqueID = item.id
        if not InventoryItems[itemID] or not InventoryPositions[uniqueID] then continue end
        local pos = InventoryPositions[uniqueID]
        local row, col = pos[1], pos[2]
        if not slots[row] or not slots[row][col] then continue end

        local panel = vgui.Create("DPanel", slots[row][col])
        panel:SetSize(slotWidth, slotHeight)
        panel.UniqueID = uniqueID
        panel.Item = item
        panel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200))
            if SelectedItems[uniqueID] then
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 3)
            end
        end

        local model = vgui.Create("DModelPanel", panel)
        model:SetSize(75, 75)
        model:SetPos((slotWidth - 75) / 2, (slotHeight - 75) / 2)
        model:SetModel(InventoryItems[itemID].model or "models/error.mdl")
        model:SetFOV(30)
        model:SetCamPos(Vector(30, 30, 30))
        model:SetLookAt(Vector(0, 0, 0))
        model:SetMouseInputEnabled(true)
        model:Droppable("inventory_item")
        model.UniqueID = uniqueID
        model.Item = item

        model.OnCursorEntered = function(self)
            if IsValid(currentTooltip) then currentTooltip:Remove() end
            local itemData = InventoryItems[itemID]
            local lines = CreateTooltipContent(item, itemData)
            local slotPanel = slots[row][col]
            local slotX, slotY = slotPanel:GetPos()
            CreateTooltip(gridPanel, lines, slotX, slotY, row, col)
        end

        model.OnCursorExited = function(self)
            if IsValid(currentTooltip) then
                timer.Simple(TOOLTIP_FADEOUT_DELAY, function()
                    if IsValid(currentTooltip) and not self:IsHovered() then
                        currentTooltip:Remove()
                    end
                end)
            end
        end

        model.DoClick = function(self)
            if not isInventoryOpen then return end
            if MultiSelectMode then
                if SelectedItems[uniqueID] then
                    SelectedItems[uniqueID] = nil
                else
                    SelectedItems[uniqueID] = true
                end
                BuildInventoryUI(gridPanel:GetParent(), currentPage)
            else
                if SelectedItems[uniqueID] then
                    SelectedItems = {}
                else
                    SelectedItems = {}
                    SelectedItems[uniqueID] = true
                end
                BuildInventoryUI(gridPanel:GetParent(), currentPage)
            end
        end

        model.DoRightClick = function(self)
            if not isInventoryOpen or MultiSelectMode or SelectedItems[uniqueID] then return end
            local menu = DermaMenu()
            table.insert(activeMenus, menu)

            local isEquipable = false
            if InventoryItems[itemID].category == "Utility" and itemID != "medkit" then
                isEquipable = true
            elseif InventoryItems[itemID].category == "Weapons" then
                isEquipable = true
            end

            if not isEquipable and InventoryItems[itemID].useFunction then
                menu:AddOption("Use", function()
                    net.Start("UseItem")
                    net.WriteString(uniqueID)
                    net.WriteUInt(currentPage, 8)
                    net.SendToServer()
                    DebugPrint("[Inventory Module] Using item " .. uniqueID .. " from page " .. currentPage)
                end)
            end

            if isEquipable then
                local equipSlot = (InventoryItems[itemID].category == "Utility") and "Utility" or ((item.slotType == "Sidearm") and "Sidearm" or "Weapon")
                menu:AddOption("Equip", function()
                    if Loadout[equipSlot] then
                        local message = "You already have a " .. (equipSlot == "Utility" and "utility item" or "weapon") .. " equipped!"
                        DebugPrint("[Inventory Module] Equip failed: " .. equipSlot .. " slot already occupied for " .. LocalPlayer():Nick())
                        ShowNotification(message)
                        return
                    end
                    net.Start("EquipItem")
                    net.WriteString(uniqueID)
                    net.WriteUInt(currentPage, 8)
                    net.WriteString(equipSlot)
                    net.SendToServer()
                    DebugPrint("[Inventory Module] Equipping item " .. uniqueID .. " to " .. equipSlot .. " slot")
                end)
            end

            menu:AddOption("Delete", function()
                net.Start("DeleteItem")
                net.WriteString(uniqueID)
                net.WriteUInt(currentPage, 8)
                net.SendToServer()
                DebugPrint("[Inventory Module] Deleting item " .. uniqueID .. " from page " .. currentPage)
            end)

            menu:Open(self:LocalToScreen(10, 75))
            menu.OnRemove = function()
                for i, m in ipairs(activeMenus) do
                    if m == menu then table.remove(activeMenus, i) break end
                end
            end
        end
    end
end

function BuildInventoryUI(parent, page)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end

    local deleteButton = vgui.Create("DButton")
    local multiButton = vgui.Create("DButton")
    local tabPanel = CreateTabPanel(parent, deleteButton, multiButton)
    local gridPanel = CreateGridPanel(parent)
    local slots = CreateSlots(gridPanel)
    PopulateSlots(slots, gridPanel)
end

local function OpenToolSelector()
    if isToolSelectorOpen and IsValid(ToolSelectorFrame) then return end
    gui.EnableScreenClicker(true)
    ToolSelectorFrame = vgui.Create("DFrame")
    ToolSelectorFrame:SetSize(300, 700)
    ToolSelectorFrame:SetPos(ScrW()/2 + 510, ScrH()/2 - 350)
    ToolSelectorFrame:SetTitle("Tool Selector")
    ToolSelectorFrame:SetDraggable(false)
    ToolSelectorFrame:ShowCloseButton(false)
    ToolSelectorFrame:MakePopup()
    ToolSelectorFrame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225)) end
    ToolSelectorFrame.OnClose = function()
        gui.EnableScreenClicker(false)
        isToolSelectorOpen = false
        ToolSelectorFrame = nil
    end

    local scroll = vgui.Create("DScrollPanel", ToolSelectorFrame)
    scroll:Dock(FILL)
    local cat = vgui.Create("DCollapsibleCategory", scroll)
    cat:Dock(TOP)
    cat:SetLabel("Tools")
    cat:SetExpanded(true)
    local toolList = vgui.Create("DPanelList", cat)
    toolList:EnableVerticalScrollbar(true)
    toolList:SetTall(650)
    toolList:Dock(FILL)
    cat:SetContents(toolList)

    local toolNames = {
        button = "Button",
        fading_door = "Fading Door",
        keypad_willox = "Keypad",
        camera = "Camera",
        nocollide = "No-Collide",
        remover = "Remover",
        stacker = "Stacker"
    }
    for _, toolClass in ipairs(allowedTools) do
        local toolData = list.Get("Tool")[toolClass]
        local btn = vgui.Create("DButton")
        btn:SetText(toolData and toolData.Name or toolNames[toolClass] or toolClass)
        btn:Dock(TOP)
        btn:SetHeight(25)
        btn.DoClick = function()
            RunConsoleCommand("use", "gmod_tool")
            RunConsoleCommand("gmod_toolmode", toolClass)
            RunConsoleCommand("gmod_tool", toolClass)
            surface.PlaySound("buttons/button14.wav")
            DebugPrint("[Inventory Module] " .. LocalPlayer():Nick() .. " selected tool: " .. toolClass)
        end
        btn.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(70, 70, 70, 240) or Color(50, 50, 50, 240))
        end
        toolList:AddItem(btn)
    end
    isToolSelectorOpen = true
end

local function OpenCustomQMenu()
    if isInventoryOpen and IsValid(InventoryFrame) then return end
    gui.EnableScreenClicker(true)
    InventoryFrame = vgui.Create("DFrame")
    InventoryFrame:SetSize(1000, 700)
    InventoryFrame:SetPos(ScrW()/2 - 500, ScrH()/2 - 350)
    InventoryFrame:SetTitle("Inventory & Resources")
    InventoryFrame:SetDraggable(false)
    InventoryFrame:ShowCloseButton(false)
    InventoryFrame:MakePopup()
    InventoryFrame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225)) end
    InventoryFrame.OnClose = function()
        gui.EnableScreenClicker(false)
        isInventoryOpen = false
        for _, menu in ipairs(activeMenus) do if IsValid(menu) then menu:Remove() end end
        activeMenus = {}
        if IsValid(currentTooltip) then currentTooltip:Remove() end
        InventoryFrame = nil
        inventoryTab = nil
        resourcesTab = nil
        adminTab = nil
        propsTab = nil
        entitiesTab = nil
        jobsTab = nil
        if isToolSelectorOpen and IsValid(ToolSelectorFrame) then ToolSelectorFrame:Close() end
        SelectedItems = {}
        MultiSelectMode = false
        DebugPrint("[Inventory Module] Closed inventory menu")
    end

    local tabPanel = vgui.Create("DPropertySheet", InventoryFrame)
    tabPanel:Dock(FILL)

    inventoryTab = vgui.Create("DPanel", tabPanel)
    inventoryTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
    BuildInventoryUI(inventoryTab, currentPage)
    tabPanel:AddSheet("Inventory", inventoryTab, "icon16/briefcase.png")

    propsTab = vgui.Create("DPanel", tabPanel)
    propsTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
    BuildPropsPanel(propsTab)
    tabPanel:AddSheet("Props", propsTab, "icon16/bricks.png")

    jobsTab = vgui.Create("DPanel", tabPanel)
    jobsTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
    BuildJobsPanel(jobsTab)
    tabPanel:AddSheet("Jobs", jobsTab, "icon16/user.png")

    entitiesTab = vgui.Create("DPanel", tabPanel)
    entitiesTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
    BuildEntitiesPanel(entitiesTab)
    tabPanel:AddSheet("Entities", entitiesTab, "icon16/lightning.png")

    resourcesTab = vgui.Create("DPanel", tabPanel)
    resourcesTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
    BuildResourcesMenu(resourcesTab)
    tabPanel:AddSheet("Resources", resourcesTab, "icon16/box.png")

    if LocalPlayer():IsSuperAdmin() then
        adminTab = vgui.Create("DPanel", tabPanel)
        adminTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
        BuildAdminPanel(adminTab)
        tabPanel:AddSheet("Admin Panel", adminTab, "icon16/shield.png")
    end

    isInventoryOpen = true
    OpenToolSelector()
    DebugPrint("[Inventory Module] Opened inventory menu")
end

local function RefreshEquipmentSlots(frame, slotsPanel)
    if not IsValid(slotsPanel) or not IsValid(frame) then return end
    for _, child in pairs(slotsPanel:GetChildren()) do child:Remove() end

    local frameW, frameH = frame:GetSize()
    local slotOrder = {"Armor", "Weapon", "Sidearm", "Boots", "Utility"}
    local slotLabels = {Armor = "Armor", Weapon = "Primary Weapon", Sidearm = "Sidearm", Boots = "Boots", Utility = "Utility"}

    local slotsPanelW, slotsPanelH = slotsPanel:GetSize()
    local slotHeight = math.floor((slotsPanelH - 10 * (#slotOrder + 1)) / #slotOrder)
    local slotWidth = slotsPanelW - 20
    local iconSize = math.min(slotWidth - 20, slotHeight - 20)

    for i, slot in ipairs(slotOrder) do
        local slotPanel = vgui.Create("DPanel", slotsPanel)
        slotPanel:SetSize(slotWidth, slotHeight)
        slotPanel:SetPos(10, (i-1) * (slotHeight + 10) + 10)
        slotPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end

        local label = vgui.Create("DLabel", slotPanel)
        label:SetPos(5, 5)
        label:SetSize(slotWidth - 10, 20)
        label:SetText(slotLabels[slot])

        local item = Loadout[slot]
        if item and InventoryItems[item.itemID] then
            local model = vgui.Create("DModelPanel", slotPanel)
            model:SetSize(iconSize, iconSize)
            model:SetPos((slotWidth - iconSize) / 2, (slotHeight - iconSize) / 2)
            model:SetModel(InventoryItems[item.itemID].model or "models/error.mdl")
            model:SetFOV(30)
            model:SetCamPos(Vector(30, 30, 30))
            model:SetLookAt(Vector(0, 0, 0))
            model:SetMouseInputEnabled(true)
            model.Slot = slot
            model.Item = item

            model.OnCursorEntered = function(self)
                if IsValid(currentInfoBox) then currentInfoBox:Remove() end
                local itemData = InventoryItems[item.itemID]
                local lines = CreateTooltipContent(item, itemData)
                local infoBoxHeight = (#lines * TOOLTIP_LINE_HEIGHT) + (TOOLTIP_PADDING_Y * 2)
                currentInfoBox = vgui.Create("DPanel", frame)
                currentInfoBox:SetSize(frame.InfoBoxWidth, infoBoxHeight)
                currentInfoBox:SetPos(frame.InfoBoxX, frame.InfoBoxY)
                currentInfoBox:SetZPos(TOOLTIP_ZPOS)
                currentInfoBox.Lines = lines
                currentInfoBox.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
                    for j, line in ipairs(self.Lines) do
                        draw.SimpleText(line.text, "TooltipFont", TOOLTIP_PADDING_X, TOOLTIP_PADDING_Y + (j - 1) * TOOLTIP_LINE_HEIGHT, line.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    end
                end
            end

            model.OnCursorExited = function(self)
                if IsValid(currentInfoBox) then
                    timer.Simple(TOOLTIP_FADEOUT_DELAY, function()
                        if IsValid(currentInfoBox) and not self:IsHovered() then
                            currentInfoBox:Remove()
                        end
                    end)
                end
            end

            model.DoClick = function(self)
                local menu = DermaMenu()
                table.insert(activeMenus, menu)
                menu:AddOption("Unequip", function()
                    net.Start("UnequipItem")
                    net.WriteString(slot)
                    net.SendToServer()
                    DebugPrint("[Inventory Module] Unequipping item from slot " .. slot)
                    if slot == "Weapon" or slot == "Sidearm" then
                        local itemID = item.itemID
                        local weaponClass = InventoryItems[itemID].weaponClass or "weapon_" .. itemID
                        PendingUnequip[slot] = weaponClass
                        RunConsoleCommand("use", "weapon_physgun")
                        DebugPrint("[Inventory Module] Marked slot " .. slot .. " as pending unequip for weapon class " .. weaponClass)
                    end
                end)
                menu:Open(self:LocalToScreen(10, iconSize))
                menu.OnRemove = function()
                    for j, m in ipairs(activeMenus) do
                        if m == menu then table.remove(activeMenus, j) break end
                    end
                end
            end
        end
    end

    local reEquipButton = vgui.Create("DButton", slotsPanel)
    reEquipButton:SetSize(120, 40)
    reEquipButton:SetPos(slotsPanelW - 130, slotsPanelH - 50)
    reEquipButton:SetText("Re-Equip")
    reEquipButton:SetTextColor(Color(0, 0, 0))
    reEquipButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(100, 200, 100, 240) or Color(50, 150, 50, 240))
    end
    reEquipButton.DoClick = function()
        net.Start("ReEquipLoadout")
        net.SendToServer()
        DebugPrint("[Inventory Module] Requested to re-equip loadout")
    end
end

local function OpenEquipmentMenu()
    local screenW, screenH = ScrW(), ScrH()
    local frameWidth = math.min(screenW * 0.4, 500)
    local baseFrameHeight = math.min(screenH * 0.6, 600)
    local maxInfoBoxLines = 10
    local infoBoxHeight = (maxInfoBoxLines * TOOLTIP_LINE_HEIGHT) + (TOOLTIP_PADDING_Y * 2)
    local frameHeight = baseFrameHeight + infoBoxHeight + 20
    frameWidth = math.min(frameWidth, screenW - 40)
    frameHeight = math.min(frameHeight, screenH - 40)

    local frame = vgui.Create("DFrame")
    frame:SetSize(frameWidth, frameHeight)
    frame:SetPos((screenW - frameWidth) / 2, (screenH - frameHeight) / 2)
    frame:SetTitle("Equipment Loadout")
    frame:SetDraggable(false)
    frame:MakePopup()
    frame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225)) end
    frame.OnClose = function()
        if IsValid(currentInfoBox) then currentInfoBox:Remove() end
        for _, menu in ipairs(activeMenus) do if IsValid(menu) then menu:Remove() end end
        activeMenus = {}
        DebugPrint("[Inventory Module] Closed equipment menu")
    end

    local padding = 10
    local contentHeight = frameHeight - 30
    local leftPanelWidth = math.floor(frameWidth * 0.5)
    local rightPanelWidth = frameWidth - leftPanelWidth - padding
    local playerModelHeight = math.floor(contentHeight * 0.65)
    local infoBoxWidth = leftPanelWidth - 2 * padding

    frame.InfoBoxWidth = infoBoxWidth
    frame.InfoBoxX = padding
    frame.InfoBoxY = 30 + playerModelHeight + padding

    local playerModel = vgui.Create("DModelPanel", frame)
    playerModel:SetSize(leftPanelWidth - 2 * padding, playerModelHeight)
    playerModel:SetPos(padding, 30)
    playerModel:SetModel(LocalPlayer():GetModel())
    playerModel:SetFOV(30)
    playerModel:SetCamPos(Vector(70, 70, 70))
    playerModel:SetLookAt(Vector(0, 0, 40))

    local slotsPanel = vgui.Create("DPanel", frame)
    slotsPanel:SetSize(rightPanelWidth, contentHeight)
    slotsPanel:SetPos(leftPanelWidth + padding, 30)
    slotsPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    RefreshEquipmentSlots(frame, slotsPanel)

    net.Receive("SyncLoadout", function()
        Loadout = net.ReadTable()
        if IsValid(slotsPanel) then
            RefreshEquipmentSlots(frame, slotsPanel)
            DebugPrint("[Inventory Module] Synced loadout: " .. table.ToString(Loadout))
        end
    end)
    DebugPrint("[Inventory Module] Opened equipment menu")
end

hook.Add("PlayerSwitchWeapon", "BlockPendingUnequip", function(ply, oldWeapon, newWeapon)
    if ply ~= LocalPlayer() then return end
    for slot, weaponClass in pairs(PendingUnequip) do
        if newWeapon:GetClass() == weaponClass then
            DebugPrint("[Inventory Module] Blocked switch to " .. weaponClass .. " due to pending unequip from slot " .. slot)
            RunConsoleCommand("use", "weapon_physgun")
            return true
        end
    end
end)

hook.Add("Think", "EnforcePendingUnequip", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local currentWeapon = ply:GetActiveWeapon()
    if not IsValid(currentWeapon) then return end

    for slot, weaponClass in pairs(PendingUnequip) do
        if currentWeapon:GetClass() == weaponClass then
            RunConsoleCommand("use", "weapon_physgun")
            DebugPrint("[Inventory Module] Forced back to weapon_physgun due to pending unequip from slot " .. slot)
            break
        end
    end
end)

hook.Add("PlayerBindPress", "CustomMenuBinds", function(_, bind, pressed)
    if bind == "+menu" and pressed then
        isQKeyHeld = true
        OpenCustomQMenu()
        return true
    elseif bind == "impulse 100" and pressed then
        OpenEquipmentMenu()
        return true
    end
end)

hook.Add("Think", "CheckQKeyRelease", function()
    if isQKeyHeld and not input.IsKeyDown(KEY_Q) then
        isQKeyHeld = false
        if IsValid(InventoryFrame) then InventoryFrame:Close() end
    end
end)

net.Receive("SyncInventory", function()
    local page = net.ReadUInt(8)
    Inventory = net.ReadTable()
    InventoryPositions = net.ReadTable()
    DebugPrint("[Inventory Module] Received SyncInventory for page " .. page .. " - Items: " .. table.Count(Inventory) .. ", Positions: " .. table.Count(InventoryPositions))
    if isInventoryOpen and IsValid(inventoryTab) then
        BuildInventoryUI(inventoryTab, page)
        DebugPrint("[Inventory Module] Refreshed inventory UI for page " .. page)
    end
end)

net.Receive("InventoryNotification", function()
    local id = net.ReadString()
    local message = net.ReadString() or "Error: No message received"
    DebugPrint("[Inventory Module] Received notification - ID: " .. tostring(id) .. ", Message: " .. tostring(message))

    if message:find("Equipped") and table.IsEmpty(Loadout) then
        DebugPrint("[Inventory Module] Suppressed re-equip notification because loadout is empty")
        return
    end

    ShowNotification(message)
end)

net.Receive("SyncLoadout", function()
    Loadout = net.ReadTable()
    DebugPrint("[Inventory Module] Synced loadout: " .. table.ToString(Loadout))
    for slot, weaponClass in pairs(PendingUnequip) do
        if not Loadout[slot] then
            PendingUnequip[slot] = nil
            DebugPrint("[Inventory Module] Cleared pending unequip for slot " .. slot .. " (weapon class: " .. weaponClass .. ")")
        end
    end
end)

net.Receive("ForceWeaponSwitch", function()
    RunConsoleCommand("use", "weapon_physgun")
    DebugPrint("[Inventory Module] Server requested switch to weapon_physgun")
end)

concommand.Add("rp_loadout", OpenEquipmentMenu)

concommand.Add("rp_reequip", function()
    net.Start("ReEquipLoadout")
    net.SendToServer()
    DebugPrint("[Inventory Module] Requested to re-equip loadout via rp_reequip")
end)

print("[Inventory Module] Client-side loaded successfully.")