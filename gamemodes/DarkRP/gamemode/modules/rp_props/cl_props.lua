-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Props Module] cl_props.lua is loading...")

-- Ensure InventoryItems exists clientside
if not InventoryItems and file.Exists("darkrp_modules/inventory/sh_items.lua", "LUA") then
    include("darkrp_modules/inventory/sh_items.lua")
end



if not CLIENT then return end

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Tooltip Configuration (matching inventory style)
surface.CreateFont("TooltipFont", { font = "DermaDefault", size = 14, weight = 500 })
local TOOLTIP_LINE_HEIGHT = 18
local TOOLTIP_PADDING_X = 10
local TOOLTIP_PADDING_Y = 10
local TOOLTIP_ZPOS = 1000
local TOOLTIP_SPACING = 2
local TOOLTIP_FADEOUT_DELAY = 0.2

-- Global variable to track the active tooltip
local ActiveTooltip = nil

-- Client-side buy mode (true = Buy, false = Craft)
local BuyMode = false

-- List of prop itemIDs (in order, to match server-side PropItemIDs)
local PropItemIDs = {
    "weapon_stripper",
    "slotted_door",
    "metal_plate_1x1",
    "metal_plate_1x2",
    "metal_plate_2x2",
    "metal_plate_2x4",
    "metal_plate_4x4",
    "metal_tube",
    "metal_tube_2x",
    "i_beam_2x8",
    "i_beam_2x16",
    "i_beam_2x32",
    "billboard",
    "wooden_shelves",
    "gear_60t1",
    "blast_door_c",
    "blast_door_b",
    "storefront_bars",
    --"interior_fence_002d",
    --"fence_03a",
    --"interior_fence_001g",
    "concrete_barrier",
    "vending_machine",
    "kitchen_fridge",
    "covered_bridge_bottom"
}

local function CreatePropTooltip(parent, prop, posX, posY, row, col)
    -- Remove any existing tooltip
    if IsValid(ActiveTooltip) then
        ActiveTooltip:Remove()
        ActiveTooltip = nil
    end

    local lines = {
        { text = prop.name, color = Color(255, 255, 255) },
        { text = "Health: " .. prop.health, color = Color(255, 255, 255) },
    }

    -- Show cost based on buy mode
    if BuyMode then
        table.insert(lines, { text = "Cost: $" .. prop.price, color = Color(255, 255, 255) })
    else
        -- Only show materials with a cost greater than 0
        for resource, cost in pairs(prop.resources) do
            if cost > 0 then
                table.insert(lines, { text = resource:gsub("^%l", string.upper) .. ": " .. cost, color = Color(255, 255, 255) })
            end
        end
    end

    local maxWidth = 0
    for _, line in ipairs(lines) do
        surface.SetFont("TooltipFont")
        local textWidth, _ = surface.GetTextSize(line.text)
        maxWidth = math.max(maxWidth, textWidth)
    end
    local tooltipWidth = maxWidth + TOOLTIP_PADDING_X * 2
    local tooltipHeight = (#lines * TOOLTIP_LINE_HEIGHT) + (TOOLTIP_PADDING_Y * 2)

    local tooltip = vgui.Create("DPanel", parent)
    tooltip:SetSize(tooltipWidth, tooltipHeight)
    tooltip:SetZPos(TOOLTIP_ZPOS)
    tooltip.Lines = lines

    -- Grid dimensions (based on the DIconLayout spacing and size)
    local slotWidth, slotHeight = 80, 80 -- Reduced size of each prop icon panel
    local iconsPerRow = math.floor((960 + 5) / (slotWidth + 5)) -- 960 is the width of the gridPanel, 5 is the spacing
    local isRightmost = (col % iconsPerRow) == 0
    local isBottomRow = row == math.ceil(#parent:GetChildren() / iconsPerRow)
    local localX, localY

    -- Default: position to the right, aligned with the top of the slot
    localX = posX + slotWidth + TOOLTIP_SPACING
    localY = posY

    -- Adjust positioning based on grid position
    if isRightmost then
        if isBottomRow then
            -- Rightmost column and bottom row: position above the item
            localX = posX - (tooltipWidth - slotWidth) / 2 -- Center horizontally
            localY = posY - tooltipHeight - TOOLTIP_SPACING
        else
            -- Rightmost column but not bottom row: position below the item
            localX = posX - (tooltipWidth - slotWidth) / 2 -- Center horizontally
            localY = posY + slotHeight + TOOLTIP_SPACING
        end
    elseif isBottomRow then
        -- Bottom row but not rightmost column: position above the item
        localX = posX + slotWidth + TOOLTIP_SPACING
        localY = posY - tooltipHeight - TOOLTIP_SPACING
    end

    -- Ensure tooltip stays within gridPanel bounds
    local gridWidth, gridHeight = parent:GetSize()
    localX = math.max(0, math.min(localX, gridWidth - tooltipWidth))
    localY = math.max(0, math.min(localY, gridHeight - tooltipHeight))

    tooltip:SetPos(localX, localY)
    tooltip.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
        for i, line in ipairs(self.Lines) do
            draw.SimpleText(line.text, "TooltipFont", TOOLTIP_PADDING_X, TOOLTIP_PADDING_Y + (i - 1) * TOOLTIP_LINE_HEIGHT, line.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    ActiveTooltip = tooltip
    return tooltip
end

-- Global variable to store the toggle button
local GlobalToggleButton = nil

-- Function to build the props panel (used by sh_inventory.lua). Fills the tab area; scroll only when too many props.
function BuildPropsPanel(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end

    local topPanel = vgui.Create("DPanel", parent)
    topPanel:Dock(TOP)
    topPanel:DockMargin(5, 5, 5, 0)
    topPanel:SetTall(40)
    topPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end

    local toggleButton = vgui.Create("DButton", topPanel)
    toggleButton:SetPos(10, 5)
    toggleButton:SetSize(150, 30)
    toggleButton:SetText(BuyMode and "Mode: Buy" or "Mode: Craft")
    toggleButton:SetTextColor(Color(255, 255, 255))
    toggleButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70))
        if self:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 50))
        end
    end
    toggleButton.DoClick = function()
        net.Start("ToggleBuyMode")
        net.SendToServer()
    end
    GlobalToggleButton = toggleButton

    local scrollPanel = vgui.Create("DScrollPanel", parent)
    scrollPanel:Dock(FILL)
    scrollPanel:DockMargin(5, 5, 5, 5)
    scrollPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    local canvas = scrollPanel:GetCanvas()
    canvas:DockPadding(5, 5, 5, 5)

    local slotW, slotH, spaceX, spaceY = 80, 80, 5, 5
    local PropList = {}
    for _, itemID in ipairs(PropItemIDs) do
        if InventoryItems[itemID] then
            table.insert(PropList, InventoryItems[itemID])
        end
    end

    -- Manual grid container: we position every prop by row/col so the list always shows as a grid (no DIconLayout).
    local gridWrap = vgui.Create("DPanel", canvas)
    gridWrap:Dock(TOP)
    gridWrap.Paint = function() end
    local numProps = #PropList
    local function layoutGridWrap()
        if not IsValid(gridWrap) or numProps == 0 then return end
        local w = gridWrap:GetWide()
        if w <= 0 then w = IsValid(parent) and (parent:GetWide() - 30) or 500 end
        w = math.max(260, w)
        local cols = math.max(1, math.floor((w + spaceX) / (slotW + spaceX)))
        local rows = math.ceil(numProps / cols)
        gridWrap:SetTall(rows * (slotH + spaceY) + spaceY)
        local kids = gridWrap:GetChildren()
        for i = 1, #kids do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            kids[i]:SetPos(col * (slotW + spaceX) + spaceX, row * (slotH + spaceY) + spaceY)
        end
    end
    gridWrap:SetWide(500)
    gridWrap:SetTall(math.max(100, math.ceil(numProps / math.max(1, math.floor((500 + spaceX) / (slotW + spaceX)))) * (slotH + spaceY) + spaceY))
    gridWrap.PerformLayout = layoutGridWrap

    for index, prop in ipairs(PropList) do
        local propPanel = vgui.Create("DPanel", gridWrap)
        propPanel:SetSize(slotW, slotH)
        local col = (index - 1) % math.max(1, math.floor((500 + spaceX) / (slotW + spaceX)))
        local row = math.floor((index - 1) / math.max(1, math.floor((500 + spaceX) / (slotW + spaceX))))
        propPanel:SetPos(col * (slotW + spaceX) + spaceX, row * (slotH + spaceY) + spaceY)
        propPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200))
        end

        local modelPanel = vgui.Create("DModelPanel", propPanel)
        modelPanel:SetSize(60, 60)
        modelPanel:SetPos(10, 10)
        local modelPath = (prop.model and type(prop.model) == "string") and prop.model or ""
        if modelPath == "" or not string.match(string.lower(modelPath), "^models/") then
            modelPath = "models/error.mdl"
        end
        modelPanel:SetModel(modelPath)
        modelPanel:SetFOV(40)
        modelPanel:SetCamPos(Vector(100, 100, 100))
        modelPanel:SetLookAt(Vector(0, 0, 0))
        modelPanel:SetMouseInputEnabled(true)

        modelPanel.OnCursorEntered = function(self)
            if IsValid(self.Tooltip) then self.Tooltip:Remove() end
            local panelX, panelY = self:GetParent():GetPos()
            local scrollX, scrollY = scrollPanel:GetPos()
            panelX = panelX + scrollX
            panelY = panelY + scrollY
            panelY = panelY - scrollPanel:GetVBar():GetScroll()
            local gw = math.max(200, scrollPanel:GetWide() - 25)
            local ipr = math.max(1, math.floor((gw + spaceX) / (slotW + spaceX)))
            local r = math.ceil(index / ipr)
            local c = (index - 1) % ipr + 1
            self.Tooltip = CreatePropTooltip(scrollPanel, prop, panelX, panelY, r, c)
        end

        modelPanel.OnCursorExited = function(self)
            if IsValid(self.Tooltip) then
                timer.Simple(TOOLTIP_FADEOUT_DELAY, function()
                    if IsValid(self.Tooltip) and not self:IsHovered() then
                        self.Tooltip:Remove()
                        if ActiveTooltip == self.Tooltip then ActiveTooltip = nil end
                    end
                end)
            end
        end

        modelPanel.DoClick = function()
            net.Start("SpawnProp")
            net.WriteUInt(index, 8)
            net.SendToServer()
            DebugPrint("[Props Module] Requested to spawn prop: " .. prop.name)
        end
    end

    -- When canvas gets a width (e.g. tab shown), size the grid wrapper and re-position all slots
    local oldCanvasLayout = canvas.PerformLayout
    canvas.PerformLayout = function(self)
        if oldCanvasLayout then oldCanvasLayout(self) end
        local cw = self:GetWide()
        if cw > 0 and IsValid(gridWrap) then
            gridWrap:SetWide(cw - 10)
            layoutGridWrap()
        end
    end
    timer.Simple(0, function()
        if IsValid(parent) and parent:GetWide() > 0 and IsValid(gridWrap) then
            gridWrap:SetWide(parent:GetWide() - 30)
            layoutGridWrap()
        end
    end)
end

-- Display prop health on screen when looking at a prop
hook.Add("HUDPaint", "DisplayPropHealth", function()
    local trace = LocalPlayer():GetEyeTrace()
    local ent = trace.Entity

    if IsValid(ent) and ent:GetClass() == "prop_physics" and ent:GetNWInt("PropHealth", -1) ~= -1 then
        local health = math.floor(ent:GetNWInt("PropHealth", 0)) -- Ensure integer with math.floor
        local maxHealth = math.floor(ent:GetNWInt("PropMaxHealth", 100)) -- Ensure integer for maxHealth too
        local healthText = "Health: " .. health .. " / " .. maxHealth
        local screenW, screenH = ScrW(), ScrH()

        -- Draw the health text near the center of the screen
        draw.SimpleText(healthText, "DermaDefaultBold", screenW / 2, screenH / 2 + 50, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- Handle prop spawn notification as a tooltip-style message
net.Receive("PropSpawnNotification", function()
    local message = net.ReadString()
    local screenW, screenH = ScrW(), ScrH()

    -- Create a temporary panel for the notification
    local notification = vgui.Create("DPanel")
    notification:SetSize(300, 50)
    notification:SetPos(screenW - 320, 20) -- Top-right corner
    notification:SetZPos(1000)
    notification.Think = function(self)
        if self.StartTime and (CurTime() - self.StartTime) > 3 then
            self:Remove()
        end
    end
    notification.StartTime = CurTime()
    notification.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
        draw.SimpleText(message, "DermaDefaultBold", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- Handle buy mode sync from server (Props tab may not be open, so button can be nil)
net.Receive("SyncBuyMode", function()
    BuyMode = net.ReadBool()
    if IsValid(GlobalToggleButton) then
        GlobalToggleButton:SetText(BuyMode and "Mode: Buy" or "Mode: Craft")
    end
end)

-- This print will always show to confirm successful load
print("[Props Module] Loaded successfully (Client).")