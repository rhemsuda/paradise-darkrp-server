print("[Inventory Module] cl_inventory.lua loaded successfully")

local Inventory = {}
local InventoryFrame = nil

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
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225))
    end

    local gridPanel = vgui.Create("DPanel", InventoryFrame)
    gridPanel:SetPos(10, 30)
    gridPanel:SetSize(980, 610)
    gridPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) -- Dark gray, transparent box
    end

    local scroll = vgui.Create("DScrollPanel", gridPanel)
    scroll:Dock(FILL)

    local layout = vgui.Create("DIconLayout", scroll)
    layout:Dock(FILL)
    layout:SetSpaceX(8) -- Space for 10 columns (980 / (90 + 8) ≈ 10)
    layout:SetSpaceY(8) -- Even vertical spacing

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