local InventoryFrame = nil
local PlayerInventory = {}

-- Receive inventory data from server
net.Receive("SyncInventory", function()
    PlayerInventory = net.ReadTable()
    if IsValid(InventoryFrame) then
        InventoryFrame:UpdateInventory()
    end
end)

-- Open the inventory UI
net.Receive("OpenInventory", function()
    if IsValid(InventoryFrame) then
        InventoryFrame:Remove()
    end

    InventoryFrame = vgui.Create("DFrame")
    InventoryFrame:SetSize(400, 300)
    InventoryFrame:Center()
    InventoryFrame:SetTitle("Inventory")
    InventoryFrame:MakePopup()

    local ScrollPanel = vgui.Create("DScrollPanel", InventoryFrame)
    ScrollPanel:Dock(FILL)

    local ItemList = vgui.Create("DPanelList", ScrollPanel)
    ItemList:Dock(FILL)
    ItemList:EnableVerticalScrollbar(true)
    ItemList:SetSpacing(8)

    function InventoryFrame:UpdateInventory()
        ItemList:Clear()

        for itemID, amount in pairs(PlayerInventory) do
            local item = InventoryItems[itemID]
            if item then
                local ItemPanel = vgui.Create("DPanel")
                ItemPanel:SetTall(50)
                ItemPanel:Dock(TOP)

                -- Background styling (optional)
                ItemPanel.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(75, 75, 50, 200))
                end

                -- Item Icon (DModelPanel)
                local ItemIcon = vgui.Create("DModelPanel", ItemPanel)
                ItemIcon:SetSize(40, 40)
                ItemIcon:SetPos(5, 5)
                ItemIcon:SetCamPos(Vector(15, 15, 15))
                ItemIcon:SetLookAt(Vector(0, 0, 0))
                ItemIcon:SetModel(item.model)
                ItemIcon:SetTooltip("Click to drop 1 " .. item.name)

                -- Make the icon clickable to drop the item
                ItemIcon.DoClick = function()
                    net.Start("DropItem")
                    net.WriteString(itemID)
                    net.WriteUInt(1, 8) -- Drop 1 item
                    net.SendToServer()
                end

                -- Item Name and Amount
                local ItemLabel = vgui.Create("DLabel", ItemPanel)
                ItemLabel:SetPos(50, 10)
                ItemLabel:SetText(item.name .. " x" .. amount)
                ItemLabel:SizeToContents()
                ItemLabel:SetTextColor(Color(255, 255, 255))

                ItemList:AddItem(ItemPanel)
            end
        end
    end

    InventoryFrame:UpdateInventory()
end)