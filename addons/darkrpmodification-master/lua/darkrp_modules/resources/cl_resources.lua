-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Resources Module] cl_resources.lua is loading...")

if not CLIENT then return end

-- Include sh_items.lua to ensure resourceTemplates and ResourceItems are defined
include("sh_items.lua")

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Client-side Resources Table
local Resources = {}

-- Function to build the resources menu (used by sh_inventory.lua)
function BuildResourcesMenu(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)
    local layout = vgui.Create("DIconLayout", scroll)
    layout:Dock(FILL)
    layout:SetSpaceX(10)
    layout:SetSpaceY(10)

    local categories = {
        { name = "Minerals", items = resourceTemplates.minerals },
        { name = "Gems", items = resourceTemplates.gems }
    }
    for _, cat in ipairs(categories) do
        local catPanel = layout:Add("DPanel")
        catPanel:SetSize(300, 60 + table.Count(cat.items) * 50)
        catPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

        local catLabel = vgui.Create("DLabel", catPanel)
        catLabel:SetPos(10, 10)
        catLabel:SetText(cat.name)
        catLabel:SetSize(280, 20)
        catLabel:SetColor(Color(255, 215, 0))

        local i = 1
        for _, data in ipairs(cat.items) do
            local resourceID = data.id
            local resPanel = vgui.Create("DPanel", catPanel)
            resPanel:SetPos(10, 40 + (i - 1) * 50)
            resPanel:SetSize(280, 40)
            resPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200)) end

            local resIcon = vgui.Create("DModelPanel", resPanel)
            resIcon:SetPos(5, 0)
            resIcon:SetSize(40, 40)
            resIcon:SetModel(data.icon)
            resIcon:SetFOV(30)
            resIcon:SetCamPos(Vector(30, 30, 30))
            resIcon:SetLookAt(Vector(0, 0, 0))
            local appearance = ResourceAppearances[resourceID] or { material = "models/shiny", color = Color(255, 255, 255) }
            if appearance.material != "" then resIcon.Entity:SetMaterial(appearance.material) end
            if appearance.color then resIcon:SetColor(appearance.color) end
            resIcon.OnCursorEntered = function(self)
                if IsValid(currentTooltip) then currentTooltip:Remove() end
                currentTooltip = vgui.Create("DLabel", resPanel)
                currentTooltip:SetText(data.name)
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
                    DebugPrint("[Resources Module] Dropped 1 " .. resourceID .. " (left-click)")
                elseif code == MOUSE_RIGHT then
                    Derma_StringRequest("Drop " .. data.name, "How many to drop? (Max: " .. (Resources[resourceID] or 0) .. ")", "1",
                        function(text)
                            local amount = math.min(math.floor(tonumber(text) or 0), Resources[resourceID] or 0)
                            if amount > 0 then
                                net.Start("DropResource")
                                net.WriteString(resourceID)
                                net.WriteUInt(amount, 16)
                                net.SendToServer()
                                DebugPrint("[Resources Module] Dropped " .. amount .. " " .. resourceID .. " (right-click)")
                            end
                        end, nil, "Drop", "Cancel")
                end
            end

            local resAmount = vgui.Create("DLabel", resPanel)
            resAmount:SetPos(50, 10)
            resAmount:SetText(": " .. (Resources[resourceID] or 0))
            resAmount:SetSize(220, 20)
            resAmount.Think = function(self) self:SetText(": " .. (Resources[resourceID] or 0)) end
            i = i + 1
        end
    end
end

-- Net message handlers
net.Receive("SyncResources", function()
    Resources = net.ReadTable()
    DebugPrint("[Resources Module] Synced resources: " .. table.ToString(Resources))
    -- The BuildResourcesMenu call will be handled by sh_inventory.lua
end)

net.Receive("ResourcesMessage", function()
    local message = net.ReadString()
    chat.AddText(Color(255, 215, 0), "[Resources] ", Color(255, 255, 255), message)
end)

-- This print will always show to confirm successful load
print("[Resources Module] Loaded successfully (Client).")