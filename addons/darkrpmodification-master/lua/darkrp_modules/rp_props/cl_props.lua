-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Props Module] cl_props.lua is loading...")

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

local function CreatePropTooltip(parent, prop, posX, posY, row, col)
    -- Remove any existing tooltip
    if IsValid(ActiveTooltip) then
        ActiveTooltip:Remove()
        ActiveTooltip = nil
    end

    local lines = {
        { text = prop.name, color = Color(255, 255, 255) },
        { text = "Health: " .. prop.health, color = Color(255, 255, 255) },
        { text = "Wood: " .. prop.resources.wood, color = Color(255, 255, 255) },
        { text = "Metal: " .. prop.resources.metal, color = Color(255, 255, 255) },
        { text = "Stone: " .. prop.resources.stone, color = Color(255, 255, 255) },
    }

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
    local slotWidth, slotHeight = 120, 120 -- Size of each prop icon panel
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

-- Function to build the props panel (used by sh_inventory.lua)
function BuildPropsPanel(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end

    local scrollPanel = vgui.Create("DScrollPanel", parent)
    scrollPanel:SetPos(5, 5)
    scrollPanel:SetSize(970, 680)
    scrollPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end

    local gridPanel = vgui.Create("DIconLayout", scrollPanel)
    gridPanel:SetPos(5, 5)
    gridPanel:SetSize(960, 670)
    gridPanel:SetSpaceX(5)
    gridPanel:SetSpaceY(5)

    -- Get the prop list (for now, we'll define it locally; ideally, fetch from server if needed)
    local PropList = {
        { model = "models/props_c17/oildrum001.mdl", name = "Oil Drum", resources = { wood = 0, metal = 0, stone = 0 }, health = 100 },
        { model = "models/props_junk/wood_crate001a.mdl", name = "Wooden Crate", resources = { wood = 0, metal = 0, stone = 0 }, health = 100 },
        { model = "models/props_junk/metal_paintcan001a.mdl", name = "Paint Can", resources = { wood = 0, metal = 0, stone = 0 }, health = 100 },
        { model = "models/props_c17/chair02a.mdl", name = "Chair", resources = { wood = 0, metal = 0, stone = 0 }, health = 100 },
        { model = "models/props_wasteland/controlroom_desk001b.mdl", name = "Desk", resources = { wood = 0, metal = 0, stone = 0 }, health = 100 },
    }

    -- Create a grid of prop icons
    for index, prop in ipairs(PropList) do
        local propPanel = gridPanel:Add("DPanel")
        propPanel:SetSize(120, 120)
        propPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200))
        end

        local modelPanel = vgui.Create("DModelPanel", propPanel)
        modelPanel:SetSize(100, 100)
        modelPanel:SetPos(10, 10)
        modelPanel:SetModel(prop.model)
        modelPanel:SetFOV(30)
        modelPanel:SetCamPos(Vector(70, 70, 70))
        modelPanel:SetLookAt(Vector(0, 0, 0))
        modelPanel:SetMouseInputEnabled(true)

        -- Tooltip on hover
        modelPanel.OnCursorEntered = function(self)
            if IsValid(self.Tooltip) then self.Tooltip:Remove() end
            -- Get the position of the propPanel relative to scrollPanel
            local panelX, panelY = self:GetParent():GetPos()
            -- Adjust for scrollPanel's offset within the parent
            local scrollX, scrollY = scrollPanel:GetPos()
            panelX = panelX + scrollX
            panelY = panelY + scrollY
            -- Account for scroll offset
            panelY = panelY - scrollPanel:GetVBar():GetScroll()
            -- Calculate row and column based on index
            local iconsPerRow = math.floor((960 + 5) / (120 + 5))
            local row = math.ceil(index / iconsPerRow)
            local col = (index - 1) % iconsPerRow + 1
            self.Tooltip = CreatePropTooltip(scrollPanel, prop, panelX, panelY, row, col)
        end

        modelPanel.OnCursorExited = function(self)
            if IsValid(self.Tooltip) then
                timer.Simple(TOOLTIP_FADEOUT_DELAY, function()
                    if IsValid(self.Tooltip) and not self:IsHovered() then
                        self.Tooltip:Remove()
                        if ActiveTooltip == self.Tooltip then
                            ActiveTooltip = nil
                        end
                    end
                end)
            end
        end

        -- Spawn the prop on click
        modelPanel.DoClick = function()
            net.Start("SpawnProp")
            net.WriteUInt(index, 8)
            net.SendToServer()
            DebugPrint("[Props Module] Requested to spawn prop: " .. prop.name)
        end
    end
end

-- Display prop health on screen when looking at a prop
hook.Add("HUDPaint", "DisplayPropHealth", function()
    local trace = LocalPlayer():GetEyeTrace()
    local ent = trace.Entity

    if IsValid(ent) and ent:GetClass() == "prop_physics" and ent:GetNWInt("PropHealth", -1) ~= -1 then
        local health = ent:GetNWInt("PropHealth", 0)
        local maxHealth = ent:GetNWInt("PropMaxHealth", 100)
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

-- This print will always show to confirm successful load
print("[Props Module] Loaded successfully (Client).")