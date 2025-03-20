print("[Inventory Module] cl_inventory.lua loaded successfully")

local Inventory = {}
local InventoryFrame = nil -- Global reference for refreshing

-- Function to build or refresh the inventory UI
local function BuildInventoryUI()
    if IsValid(InventoryFrame) then
        InventoryFrame:Remove()
    end

    InventoryFrame = vgui.Create("DFrame")
    InventoryFrame:SetSize(1000, 650)
    InventoryFrame:Center()
    InventoryFrame:SetTitle("Inventory")
    InventoryFrame:SetDraggable(true)
    InventoryFrame:ShowCloseButton(true)
    InventoryFrame:MakePopup()
    InventoryFrame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30))
    end

    local gridPanel = vgui.Create("DPanel", InventoryFrame)
    gridPanel:SetPos(10, 30)
    gridPanel:SetSize(980, 620) -- Full height of frame minus title
    gridPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40)) -- Solid background
        -- Grid: 10 columns (98px each, 980px total), 6 rows (103.33px each, 620px total)
        surface.SetDrawColor(0, 0, 0) -- Black lines
        for i = 0, 6 do -- 7 lines for 6 rows
            surface.DrawLine(0, i * 103.33, w, i * 103.33) -- Horizontal
        end
        for i = 0, 10 do -- 11 lines for 10 columns
            surface.DrawLine(i * 98, 0, i * 98, h) -- Vertical
        end
    end

    local scroll = vgui.Create("DScrollPanel", gridPanel)
    scroll:Dock(FILL)

    local layout = vgui.Create("DIconLayout", scroll)
    layout:Dock(FILL)
    layout:SetSpaceX(8) -- Adjusted to fit 98px columns (98 - 90 = 8)
    layout:SetSpaceY(2) -- Adjusted to fit 103.33px rows (103.33 - 101 ≈ 2)

    local activeMenu = nil

    for itemID, amount in pairs(Inventory) do
        if InventoryItems[itemID] then
            local itemPanel = layout:Add("DPanel")
            itemPanel:SetSize(90, 101)
            itemPanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200))
            end

            local model = vgui.Create("DModelPanel", itemPanel)
            model:SetSize(70, 70)
            model:SetPos(10, 5)
            model:SetModel(InventoryItems[itemID].model or "models/error.mdl")
            model:SetFOV(20)
            model:SetCamPos(Vector(15, 15, 15))
            model:SetLookAt(Vector(0, 0, 0))
            model.OnMousePressed = function(self, code)
                if code == MOUSE_LEFT then
                    if IsValid(activeMenu) then
                        activeMenu:Remove()
                    end
                    local menu = DermaMenu()
                    menu:AddOption("Use", function()
                        print("[Debug] Selected Use for " .. itemID)
                        net.Start("UseItem")
                        net.WriteString(itemID)
                        net.SendToServer()
                    end)
                    menu:AddOption("Drop", function()
                        print("[Debug] Selected Drop for " .. itemID)
                        net.Start("DropItem")
                        net.WriteString(itemID)
                        net.WriteUInt(1, 8)
                        net.SendToServer()
                    end)
                    menu:AddOption("Delete", function()
                        print("[Debug] Selected Delete for " .. itemID)
                        net.Start("DeleteItem")
                        net.WriteString(itemID)
                        net.WriteUInt(1, 8)
                        net.SendToServer()
                    end)
                    local x, y = self:LocalToScreen(10, 71)
                    menu:Open(x, y)
                    activeMenu = menu
                    menu.OnRemove = function()
                        activeMenu = nil
                    end
                end
            end

            local name = vgui.Create("DLabel", itemPanel)
            name:SetText(InventoryItems[itemID].name .. " x" .. amount)
            name:SetPos(10, 76)
            name:SizeToContents()
        else
            print("[Inventory Error] Unknown item ID: " .. itemID)
        end
    end
end

-- Receive inventory sync from server and refresh UI
net.Receive("SyncInventory", function()
    Inventory = net.ReadTable()
    print("[Debug] Received inventory: " .. table.ToString(Inventory))
    if IsValid(InventoryFrame) then
        BuildInventoryUI() -- Refresh UI when inventory updates
    end
end)

-- Receive messages from server
net.Receive("InventoryMessage", function()
    local msg = net.ReadString()
    chat.AddText(Color(255, 215, 0), "[Inventory] ", Color(255, 255, 255), msg)
end)

-- Open inventory UI on server command
net.Receive("OpenInventory", function()
    BuildInventoryUI()
end)