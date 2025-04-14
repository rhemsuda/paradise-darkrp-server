-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Admin Module] cl_admin.lua is loading...")

if not CLIENT then return end

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Function to build the admin panel (used by sh_inventory.lua)
function BuildAdminPanel(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end

    -- Create a dropdown for admin options
    local dropdown = vgui.Create("DComboBox", parent)
    dropdown:SetPos(10, 10)
    dropdown:SetSize(200, 30)
    dropdown:SetValue("Select an Option")
    dropdown:AddChoice("Item Edit")
    dropdown:AddChoice("Inventory Edit")
    dropdown:AddChoice("Props")
    dropdown:AddChoice("Events Panel")

    -- Create panels for each option (hidden by default)
    local panels = {}

    -- Item Edit Panel
    panels["Item Edit"] = vgui.Create("DPanel", parent)
    panels["Item Edit"]:SetPos(10, 50)
    panels["Item Edit"]:SetSize(970, 620)
    panels["Item Edit"]:SetVisible(false)
    panels["Item Edit"].Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    local itemEditLabel = vgui.Create("DLabel", panels["Item Edit"])
    itemEditLabel:SetPos(10, 10)
    itemEditLabel:SetSize(950, 30)
    itemEditLabel:SetText("Item Edit Panel - Add functionality here")
    itemEditLabel:SetColor(Color(255, 255, 255))

    -- Inventory Edit Panel
    panels["Inventory Edit"] = vgui.Create("DPanel", parent)
    panels["Inventory Edit"]:SetPos(10, 50)
    panels["Inventory Edit"]:SetSize(970, 620)
    panels["Inventory Edit"]:SetVisible(false)
    panels["Inventory Edit"].Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    local invEditLabel = vgui.Create("DLabel", panels["Inventory Edit"])
    invEditLabel:SetPos(10, 10)
    invEditLabel:SetSize(950, 30)
    invEditLabel:SetText("Inventory Edit Panel - Add functionality here")
    invEditLabel:SetColor(Color(255, 255, 255))

    -- Props Panel
    panels["Props"] = vgui.Create("DPanel", parent)
    panels["Props"]:SetPos(10, 50)
    panels["Props"]:SetSize(970, 620)
    panels["Props"]:SetVisible(false)
    panels["Props"].Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    local propsLabel = vgui.Create("DLabel", panels["Props"])
    propsLabel:SetPos(10, 10)
    propsLabel:SetSize(950, 30)
    propsLabel:SetText("Props Panel - Add functionality here")
    propsLabel:SetColor(Color(255, 255, 255))

    -- Events Panel
    panels["Events Panel"] = vgui.Create("DPanel", parent)
    panels["Events Panel"]:SetPos(10, 50)
    panels["Events Panel"]:SetSize(970, 620)
    panels["Events Panel"]:SetVisible(false)
    panels["Events Panel"].Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    local eventsLabel = vgui.Create("DLabel", panels["Events Panel"])
    eventsLabel:SetPos(10, 10)
    eventsLabel:SetSize(950, 30)
    eventsLabel:SetText("Events Panel - Add functionality here")
    eventsLabel:SetColor(Color(255, 255, 255))

    -- Show the selected panel when an option is chosen
    dropdown.OnSelect = function(self, index, value)
        for panelName, panel in pairs(panels) do
            panel:SetVisible(panelName == value)
        end
        DebugPrint("[Admin Module] Admin panel switched to: " .. value)
    end
end

-- This print will always show to confirm successful load
print("[Admin Module] Loaded successfully (Client).")