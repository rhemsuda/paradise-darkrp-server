print("[Inventory Module] cl_inventory.lua loaded successfully")

local Inventory = {}

-- Receive inventory sync from server
net.Receive("SyncInventory", function()
    Inventory = net.ReadTable()
    print("[Debug] Received inventory: " .. table.ToString(Inventory))
end)

-- Receive messages from server
net.Receive("InventoryMessage", function()
    local msg = net.ReadString()
    chat.AddText(Color(255, 215, 0), "[Inventory] ", Color(255, 255, 255), msg)
end)

-- Open inventory UI on SWEP use
net.Receive("OpenInventory", function()
    if IsValid(InventoryFrame) then
        InventoryFrame:Remove()
    end

    InventoryFrame = vgui.Create("DFrame")
    InventoryFrame:SetSize(400, 300)
    InventoryFrame:Center()
    InventoryFrame:SetTitle("Inventory")
    InventoryFrame:SetDraggable(true)
    InventoryFrame:ShowCloseButton(true)
    InventoryFrame:MakePopup()

    local scroll = vgui.Create("DScrollPanel", InventoryFrame)
    scroll:Dock(FILL)

    local layout = vgui.Create("DIconLayout", scroll)
    layout:Dock(FILL)
    layout:SetSpaceX(5)
    layout:SetSpaceY(5)

    for itemID, amount in pairs(Inventory) do
        if InventoryItems[itemID] then
            local itemPanel = layout:Add("DPanel")
            itemPanel:SetSize(100, 100)
            itemPanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50))
            end

            local model = vgui.Create("DModelPanel", itemPanel)
            model:SetSize(80, 80)
            model:SetPos(10, 10)
            model:SetModel(InventoryItems[itemID].model)
            model:SetFOV(20)

            local name = vgui.Create("DLabel", itemPanel)
            name:SetText(InventoryItems[itemID].name .. " x" .. amount)
            name:SetPos(10, 80)
            name:SizeToContents()
        end
    end
end)