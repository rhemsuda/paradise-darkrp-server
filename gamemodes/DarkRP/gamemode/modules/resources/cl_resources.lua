if not CLIENT then return end

-- sh_resources.lua is loaded by the module loader before this file and defines:
--   Paradise.ResourceItems, Paradise.ResourceAppearances, Paradise.ResourceCategories

-- Helper function to print debug messages conditionally (set rp_debug 1 to see)
local function DebugPrint(...)
    local cv = GetConVar("rp_debug")
    if cv and cv:GetInt() == 1 then print(...) end
end

-- Client-side Resources Table (also exposed as Paradise.PlayerResources for crafter menu)
local Resources = {}
Paradise = Paradise or {}
Paradise.PlayerResources = Paradise.PlayerResources or {}

-- Flat lookup for crafter/other UI: resourceID -> { name, icon, color, material }
-- Built once from the shared tables so both the resource panel and the crafter can reference it.
Paradise.ResourceDisplay = Paradise.ResourceDisplay or {}
for id, item in pairs(Paradise.ResourceItems or {}) do
    local app = Paradise.ResourceAppearances[id] or {}
    Paradise.ResourceDisplay[id] = {
        name     = item.name or id,
        icon     = item.model or "models/props_junk/rock001a.mdl",
        color    = app.color or Color(200, 200, 200),
        material = (app.material and app.material ~= "") and app.material or nil,
    }
end

-- Function to build the resources menu (used by sh_inventory.lua)
-- Match Inventory Q-menu / Tool Selector sidebar colors (bg_panel, bg_raised)
local RES_PANEL_BG = Color(22, 28, 38, 220)
local RES_CAT_BG = Color(30, 36, 48, 220)

function BuildResourcesMenu(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end
    local pad = 8
    -- Minerals and Gems side by side so they don't go under the tool section; each gets ~half width.
    for col, cat in ipairs(Paradise.ResourceCategories or {}) do
        local catPanel = vgui.Create("DPanel", parent)
        catPanel:Dock(LEFT)
        catPanel:DockMargin(col == 1 and pad or pad * 0.5, pad, col == 2 and pad or pad * 0.5, pad)
        catPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, RES_PANEL_BG) end
        catPanel.PerformLayout = function(self)
            if not IsValid(parent) then return end
            local pw = parent:GetWide()
            if pw > 0 then
                self:SetWide(math.max(200, math.floor((pw - pad * 3) * 0.5)))
            end
        end
        catPanel:SetWide(260)
        catPanel:SetTall(60 + #cat.ids * 50)

        local catLabel = vgui.Create("DLabel", catPanel)
        catLabel:SetPos(10, 10)
        catLabel:SetText(cat.name)
        catLabel:SetSize(200, 20)
        catLabel:SetFont("DermaDefaultBold")
        catLabel:SetColor(Color(255, 215, 0))

        for i, resourceID in ipairs(cat.ids) do
            local item = Paradise.ResourceItems[resourceID] or {}
            local display = Paradise.ResourceDisplay[resourceID] or {}
            local resPanel = vgui.Create("DPanel", catPanel)
            resPanel:SetPos(10, 40 + (i - 1) * 50)
            resPanel:SetSize(240, 40)
            resPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, RES_CAT_BG) end

            local resIcon = vgui.Create("DModelPanel", resPanel)
            resIcon:SetPos(5, 0)
            resIcon:SetSize(40, 40)
            resIcon:SetModel(item.model or "models/props_junk/rock001a.mdl")
            resIcon:SetFOV(30)
            resIcon:SetCamPos(Vector(30, 30, 30))
            resIcon:SetLookAt(Vector(0, 0, 0))
            if display.material then resIcon.Entity:SetMaterial(display.material) end
            if display.color then resIcon:SetColor(display.color) end
            resIcon.OnCursorEntered = function(self)
                if IsValid(currentTooltip) then currentTooltip:Remove() end
                currentTooltip = vgui.Create("DLabel", resPanel)
                currentTooltip:SetText(item.name or resourceID)
                currentTooltip:SetPos(50, 10)
                currentTooltip:SetSize(100, 20)
                currentTooltip:SetZPos(10000)
                currentTooltip.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
            end
            resIcon.OnCursorExited = function(self)
                if IsValid(currentTooltip) then currentTooltip:Remove() currentTooltip = nil end
            end
            resIcon.OnMousePressed = function(self, code)
                if (Resources[resourceID] or 0) <= 0 then return end
                if code == MOUSE_LEFT then
                    net.Start("DropResource")
                    net.WriteString(resourceID)
                    net.WriteUInt(1, 16)
                    net.SendToServer()
                elseif code == MOUSE_RIGHT then
                    Derma_StringRequest("Drop " .. (item.name or resourceID),
                        "How many to drop? (Max: " .. (Resources[resourceID] or 0) .. ")", "1",
                        function(text)
                            local amount = math.min(math.floor(tonumber(text) or 0), Resources[resourceID] or 0)
                            if amount > 0 then
                                net.Start("DropResource")
                                net.WriteString(resourceID)
                                net.WriteUInt(amount, 16)
                                net.SendToServer()
                            end
                        end, nil, "Drop", "Cancel")
                end
            end

            local resAmount = vgui.Create("DLabel", resPanel)
            resAmount:SetPos(50, 10)
            resAmount:SetText(": " .. (Resources[resourceID] or 0))
            resAmount:SetSize(220, 20)
            resAmount.Think = function(self) self:SetText(": " .. (Resources[resourceID] or 0)) end
        end
    end
end

-- Net message handlers
net.Receive("SyncResources", function()
    Resources = net.ReadTable()
    Paradise.PlayerResources = Resources -- Expose for crafter menu (pouch amounts)
    DebugPrint("[Resources Module] Synced resources: " .. table.ToString(Resources))
    -- The BuildResourcesMenu call will be handled by sh_inventory.lua
end)

-- Resource chat: no [Paradise] prefix; resource name shown in its tint color.
local RESOURCE_MSG_GRAY = Color(150, 155, 165)
local DEFAULT_RESOURCE_COLOR = Color(180, 185, 190)
-- Glow colors for Diamond/Obsidian name in chat (luminous so the word stands out in the chat box)
local DIAMOND_NAME_GLOW  = Color(220, 240, 255)
local OBSIDIAN_NAME_GLOW = Color(140, 110, 180)

local function resourceChatLine(prefix, resourceID)
    local display = Paradise.ResourceDisplay[resourceID] or {}
    local name  = display.name or resourceID
    local color = display.color or DEFAULT_RESOURCE_COLOR
    if resourceID == "diamond" then
        color = DIAMOND_NAME_GLOW
    elseif resourceID == "obsidian" then
        color = OBSIDIAN_NAME_GLOW
    end
    chat.AddText(RESOURCE_MSG_GRAY, prefix, color, name)
end

net.Receive("ResourcesMessage", function()
    local msgType = net.ReadString()
    if msgType == "mined" then
        resourceChatLine("You mined a ", net.ReadString())
    elseif msgType == "dropped" then
        local resourceID = net.ReadString()
        net.ReadUInt(16) -- amount (intentionally not shown in phrasing)
        resourceChatLine("You dropped a ", resourceID)
    elseif msgType == "pickedup" then
        local resourceID = net.ReadString()
        net.ReadUInt(16) -- amount (intentionally not shown in phrasing)
        resourceChatLine("Picked up a ", resourceID)
    elseif msgType == "plain" then
        chat.AddText(RESOURCE_MSG_GRAY, net.ReadString())
    else
        chat.AddText(RESOURCE_MSG_GRAY, msgType)
    end
end)

-- This print will always show to confirm successful load
print("[Resources Module] Loaded successfully (Client).")