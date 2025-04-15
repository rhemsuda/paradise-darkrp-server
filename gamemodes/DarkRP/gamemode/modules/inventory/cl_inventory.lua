-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Inventory Module] cl_inventory.lua loaded successfully")

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug") and GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Include sh_items.lua
if file.Exists("modules/inventory/sh_items.lua", "LUA") then
    include("modules/inventory/sh_items.lua")
end

PlayerInventories = PlayerInventories or {}

-- Utility Functions
local function GenerateUUID()
    return string.format("%08x-%04x-%04x-%04x-%12x", 
        math.random(0, 0xffffffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffffffffffff))
end

-- Weapon Type Definitions for Damage Assignment
local WeaponTypes = {
    -- Pistols
    ["weapon_pistol"] = "pistol",
    ["deagle"] = "pistol",
    ["fiveseven"] = "pistol",
    -- Assault Rifles
    ["ak47"] = "assault_rifle",
    ["m4a1"] = "assault_rifle",
    ["sg552"] = "assault_rifle",
    ["aug"] = "assault_rifle",
    ["m249"] = "assault_rifle",
    -- Shotguns
    ["weapon_shotgun"] = "shotgun",
    ["spas12"] = "shotgun",
    -- Snipers
    ["awp"] = "sniper",
    ["scout"] = "sniper",
    ["g3sg1"] = "sniper"
}

-- Inventory Management Functions
function AddItemToInventory(ply, itemID, amount, stats, page, silent)
    if not IsValid(ply) or not InventoryItems[itemID] then 
        DebugPrint("[Inventory Module] Invalid player or itemID: " .. tostring(itemID))
        return 
    end

    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, positions = { [1] = {} }, maxPages = 1, loadout = {} }
    page = tonumber(page) or 1
    inv.maxPages = inv.maxPages or 1

    if page < 1 or page > inv.maxPages then 
        DebugPrint("[Inventory Module] Invalid page " .. page .. " for " .. ply:Nick() .. " (maxPages: " .. inv.maxPages .. ")")
        return 
    end

    inv.items[page] = inv.items[page] or {}
    inv.positions[page] = inv.positions[page] or {}

    for i = 1, (amount or 1) do
        local uniqueID = stats and stats.id or GenerateUUID()
        local isWeaponOrArmor = InventoryItems[itemID].category == "Weapons" or InventoryItems[itemID].category == "Armor"
        -- Only generate stats if none are provided (i.e., new item)
        if not stats then
            stats = {
                damage = 0, -- Will be set below for weapons
                slots = 0,
                rarity = nil,
                slotType = nil,
                crafter = ply:Nick()
            }
            if isWeaponOrArmor then
                local rarityRoll = math.random(1, 500)
                stats.rarity = rarityRoll == 1 and "Legendary" or rarityRoll <= 3 and "Epic" or rarityRoll <= 10 and "Rare" or rarityRoll <= 50 and "Uncommon" or "Common"
                local slotCaps = { Common = 2, Uncommon = 3, Rare = 4, Epic = 5, Legendary = 6 }
                stats.slots = math.random(0, slotCaps[stats.rarity] or 2)

                if InventoryItems[itemID].category == "Weapons" then
                    stats.slotType = math.random(1, 500) == 1 and "Sidearm" or "Primary"
                    local weaponType = WeaponTypes[itemID] or "unknown"
                    if weaponType == "pistol" then
                        stats.damage = stats.rarity == "Legendary" and math.random(6, 20) or math.random(6, 15)
                    elseif weaponType == "assault_rifle" then
                        stats.damage = stats.rarity == "Legendary" and math.random(15, 25) or math.random(12, 20)
                    elseif weaponType == "shotgun" then
                        stats.damage = stats.rarity == "Legendary" and math.random(5, 15) or math.random(5, 10)
                    elseif weaponType == "sniper" then
                        stats.damage = stats.rarity == "Legendary" and math.random(50, 100) or math.random(25, 50)
                    else
                        stats.damage = math.random(10, 80)
                    end
                end
            end
        end

        local itemInstance = { 
            id = uniqueID, 
            itemID = itemID, 
            damage = stats.damage, 
            slots = stats.slots, 
            rarity = stats.rarity, 
            slotType = stats.slotType, 
            crafter = stats.crafter 
        }
        table.insert(inv.items[page], itemInstance)

        -- Assign a position in the inventory grid
        local positionAssigned = false
        for row = 1, 6 do
            for col = 1, 10 do
                local slotTaken = false
                for _, pos in pairs(inv.positions[page]) do
                    if pos[1] == row and pos[2] == col then 
                        slotTaken = true 
                        break 
                    end
                end
                if not slotTaken then
                    inv.positions[page][uniqueID] = {row, col}
                    positionAssigned = true
                    break
                end
            end
            if positionAssigned then break end
        end
    end

    PlayerInventories[steamID] = inv
end

-- Client-Side Logic
local Inventory, InventoryPositions, Loadout = {}, {}, {}
local InventoryFrame, ToolSelectorFrame, inventoryTab, resourcesTab, adminTab
local isInventoryOpen, isToolSelectorOpen, isQKeyHeld = false, false, false
local currentTooltip, currentInfoBox
local activeMenus = {}
local allowedTools = { "button", "fading_door", "keypad_willox", "camera", "nocollide", "remover", "stacker" }
local currentPage = 1
local currentNotification = nil -- Track the current notification panel

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

local function CalculateSlotCounts(item, itemData)
    local isWeaponOrArmor = itemData.category == "Weapons" or itemData.category == "Armor"
    local slotCount = item.slots or 0
    local baseSlotCount = 0
    if isWeaponOrArmor then
        if itemData.category == "Weapons" then
            local weaponSlots = { ak47 = 2, m4a1 = 2, sg552 = 2, aug = 2, m249 = 2 }
            baseSlotCount = weaponSlots[item.itemID] or 1
        else
            baseSlotCount = 1
        end
    end
    local displaySlotCount = isWeaponOrArmor and math.max(slotCount, baseSlotCount) or slotCount
    return slotCount, baseSlotCount, displaySlotCount
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
    local slotCount, baseSlotCount, displaySlotCount = CalculateSlotCounts(item, itemData)

    local lines = {}
    if isWeaponOrArmor then
        table.insert(lines, { text = rarity, color = rarityColor })
        table.insert(lines, { text = itemData.name, color = Color(255, 255, 255) })
        if itemData.category == "Weapons" then
            table.insert(lines, { text = slotType, color = slotTypeColor })
        end
        table.insert(lines, { text = "Damage: " .. damage, color = Color(255, 255, 255) })
        if displaySlotCount > 0 then
            table.insert(lines, { text = "Slots:", color = Color(255, 255, 255) })
            for i = 1, displaySlotCount do
                local slotText = (slotCount > 0) and "Empty Slot" or "No Slots"
                table.insert(lines, { text = "  " .. slotText, color = Color(255, 255, 255) })
            end
        end
        table.insert(lines, { text = "Crafter: " .. crafter, color = Color(255, 255, 220) })
    elseif isUtility then
        table.insert(lines, { text = itemData.name, color = Color(255, 255, 255) })
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

local function BuildInventoryUI(parent, page)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end
    
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
    
    local gridPanel = vgui.Create("DPanel", parent)
    gridPanel:SetSize(980, 640)
    gridPanel:SetPos(5, 55)
    gridPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end
    
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
                if not dropped or not panels[1] then return end
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
    
    for _, item in ipairs(Inventory) do
        local itemID = item.itemID
        local uniqueID = item.id
        if not InventoryItems[itemID] or not InventoryPositions[uniqueID] then continue end
        local pos = InventoryPositions[uniqueID]
        local row, col = pos[1], pos[2]
        if not slots[row] or not slots[row][col] then continue end
    
        local panel = vgui.Create("DPanel", slots[row][col])
        panel:SetSize(slotWidth, slotHeight)
        panel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200)) end
    
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
    
        model.OnCursorEntered = function(self)
            if IsValid(currentTooltip) then currentTooltip:Remove() end
            local itemData = InventoryItems[itemID]
            local lines = CreateTooltipContent(item, itemData)
            local slotPanel = slots[row][col]
            local slotX, slotY = slotPanel:GetPos()
            CreateTooltip(gridPanel, lines, slotX, slotY, row, col)
            DebugPrint("[Inventory Module] Showing tooltip for item " .. uniqueID .. " at position (" .. row .. ", " .. col .. ")")
        end

        model.OnCursorExited = function(self)
            if IsValid(currentTooltip) then
                timer.Simple(TOOLTIP_FADEOUT_DELAY, function()
                    if IsValid(currentTooltip) and not self:IsHovered() then
                        currentTooltip:Remove()
                        DebugPrint("[Inventory Module] Removed tooltip for item " .. uniqueID)
                    end
                end)
            end
        end
    
        model.DoClick = function(self)
            if not isInventoryOpen then return end
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

            if not (InventoryItems[itemID].category == "Weapons" or InventoryItems[itemID].category == "Armor") then
                menu:AddOption("Drop", function()
                    net.Start("DropItem")
                    net.WriteString(uniqueID)
                    net.WriteUInt(currentPage, 8)
                    net.SendToServer()
                    DebugPrint("[Inventory Module] Dropping item " .. uniqueID .. " from page " .. currentPage)
                end)
            end

            if InventoryItems[itemID].category == "Utility" and itemID != "medkit" then
                menu:AddOption("Equip", function()
                    net.Start("EquipItem")
                    net.WriteString(uniqueID)
                    net.WriteUInt(currentPage, 8)
                    net.WriteString("Utility")
                    net.SendToServer()
                    DebugPrint("[Inventory Module] Equipping item " .. uniqueID .. " to Utility slot")
                end)
            elseif InventoryItems[itemID].category == "Weapons" then
                local equipSlot = (item.slotType == "Sidearm") and "Sidearm" or "Weapon"
                menu:AddOption("Equip", function()
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
        if isToolSelectorOpen and IsValid(ToolSelectorFrame) then ToolSelectorFrame:Close() end
        DebugPrint("[Inventory Module] Closed inventory menu")
    end

    local tabPanel = vgui.Create("DPropertySheet", InventoryFrame)
    tabPanel:Dock(FILL)

    -- Inventory Tab
    inventoryTab = vgui.Create("DPanel", tabPanel)
    inventoryTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
    BuildInventoryUI(inventoryTab, currentPage)
    tabPanel:AddSheet("Inventory", inventoryTab, "icon16/briefcase.png")

    -- Props Tab (moved before Resources)
    propsTab = vgui.Create("DPanel", tabPanel)
    propsTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
    BuildPropsPanel(propsTab)
    tabPanel:AddSheet("Props", propsTab, "icon16/bricks.png")

    -- Resources Tab (now after Props)
    resourcesTab = vgui.Create("DPanel", tabPanel)
    resourcesTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
    BuildResourcesMenu(resourcesTab)
    tabPanel:AddSheet("Resources", resourcesTab, "icon16/box.png")

    -- Admin Panel Tab (Superadmins only)
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
                DebugPrint("[Inventory Module] Showing equipment tooltip for slot " .. slot)
            end

            model.OnCursorExited = function(self)
                if IsValid(currentInfoBox) then
                    timer.Simple(TOOLTIP_FADEOUT_DELAY, function()
                        if IsValid(currentInfoBox) and not self:IsHovered() then
                            currentInfoBox:Remove()
                            DebugPrint("[Inventory Module] Removed equipment tooltip for slot " .. slot)
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

hook.Add("PlayerBindPress", "CustomMenuBinds", function(_, bind, pressed)
    if bind == "+menu" and pressed then
        isQKeyHeld = true
        OpenCustomQMenu()
        return true
    elseif bind == "impulse 100" and pressed then -- "B" key for rp_loadout
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
    if IsValid(inventoryTab) then 
        BuildInventoryUI(inventoryTab, page) 
        DebugPrint("[Inventory Module] Synced inventory for page " .. page)
    end
end)

net.Receive("InventoryNotification", function()
    -- Remove the previous notification if it exists
    if IsValid(currentNotification) then
        currentNotification:Remove()
        currentNotification = nil
    end

    -- Read the ID and message as sent by the server
    local id = net.ReadString()
    local message = net.ReadString()

    -- Debug print to verify the message
    DebugPrint("[Inventory Module] Received notification - ID: " .. tostring(id) .. ", Message: " .. tostring(message))

    -- Use a fallback if the message is nil
    local displayMessage = message or "Error: No message received"

    local screenW, screenH = ScrW(), ScrH()

    -- Create a temporary panel for the notification
    currentNotification = vgui.Create("DPanel")
    currentNotification:SetSize(300, 50)
    currentNotification:SetPos(screenW - 320, 20) -- Top-right corner
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
        draw.SimpleText(displayMessage, "DermaDefaultBold", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Play DarkRP-style notification sound
    surface.PlaySound("ui/buttonclick.wav")
end)

net.Receive("SyncLoadout", function()
    Loadout = net.ReadTable()
    DebugPrint("[Inventory Module] Synced loadout: " .. table.ToString(Loadout))
end)

concommand.Add("rp_loadout", OpenEquipmentMenu)

-- This print will always show to confirm successful load
print("[Inventory Module] Client-side loaded successfully.")