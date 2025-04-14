-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Resources Module] cl_resources.lua is loading...")

if not CLIENT then return end

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Client-side Resources Table
local Resources = {}

-- Resource appearances for visual customization
local resourceAppearances = {
    rock = { material = "", color = nil },
    copper = { material = "models/shiny", color = Color(184, 115, 51, 100) },
    iron = { material = "models/shiny", color = Color(169, 169, 169, 255) },
    steel = { material = "models/shiny", color = Color(192, 192, 192, 255) },
    titanium = { material = "models/shiny", color = Color(46, 139, 87, 255) },
    emerald = { material = "models/shiny", color = Color(0, 255, 127, 200) },
    ruby = { material = "models/shiny", color = Color(255, 36, 0, 200) },
    sapphire = { material = "models/shiny", color = Color(0, 191, 255, 200) },
    obsidian = { material = "models/shiny", color = Color(47, 79, 79, 200) },
    diamond = { material = "models/shiny", color = Color(240, 248, 255, 200) }
    --[[ Commented out lumber appearances for later development
    ash = { material = "models/shiny", color = Color(139, 69, 19, 255) },
    birch = { material = "models/shiny", color = Color(245, 245, 220, 255) },
    oak = { material = "models/shiny", color = Color(160, 82, 45, 255) },
    mahogany = { material = "models/shiny", color = Color(139, 0, 0, 255) },
    yew = { material = "models/shiny", color = Color(85, 107, 47, 255) }
    ]]
}

-- Resource templates for UI categorization
local resourceTemplates = {
    minerals = {
        { id = "rock", name = "Rock", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "copper", name = "Copper", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "iron", name = "Iron", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "steel", name = "Steel", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "titanium", name = "Titanium", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" }
    },
    gems = {
        { id = "emerald", name = "Emerald", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "ruby", name = "Ruby", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "sapphire", name = "Sapphire", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "obsidian", name = "Obsidian", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "diamond", name = "Diamond", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" }
    },
    --[[ Commented out lumber section for later development
    lumber = {
        { id = "ash", name = "Ash", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "birch", name = "Birch", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "oak", name = "Oak", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "mahogany", name = "Mahogany", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "yew", name = "Yew", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" }
    }
    ]]
}

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
        { name = "Gems", items = resourceTemplates.gems },
        --[[ Commented out lumber category for later development
        { name = "Lumber", items = resourceTemplates.lumber }
        ]]
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
            local appearance = resourceAppearances[resourceID] or { material = "models/shiny", color = Color(255, 255, 255) }
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