local InventoryFrame = nil
local PlayerInventory = {}

net.Receive("SyncInventory", function()
    PlayerInventory = net.ReadTable()
    if IsValid(InventoryFrame) then
        InventoryFrame:UpdateInventory()
    end
end)

net.Receive("InventoryMessage", function()
    local message = net.ReadString()
    chat.AddText(Color(255, 255, 0), "[Inventory] ", Color(255, 255, 255), message)
end)

net.Receive("OpenInventory", function()
    if IsValid(InventoryFrame) then
        InventoryFrame:Remove()
    end

    InventoryFrame = vgui.Create("DFrame")
    InventoryFrame:SetSize(600, 400)
    InventoryFrame:Center()
    InventoryFrame:SetTitle("Inventory")
    InventoryFrame:MakePopup()
    InventoryFrame.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(1, 1, 1, 125))

    local ItemContainer = vgui.Create("DPanel", InventoryFrame)
    ItemContainer:Dock(FILL)
    ItemContainer:DockMargin(5, 5, 5, 5)
    ItemContainer.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(100, 100, 100, 200))
    end

    local ItemGrid = vgui.Create("DIconLayout", ItemContainer)
    ItemGrid:Dock(FILL)
    ItemGrid:SetSpaceX(5)
    ItemGrid:SetSpaceY(5)

    function InventoryFrame:UpdateInventory()
        ItemGrid:Clear()

        for itemID, amount in pairs(PlayerInventory) do
            local item = InventoryItems[itemID]
            if item then
                for i = 1, amount do
                    local ItemIcon = ItemGrid:Add("DModelPanel")
                    ItemIcon:SetSize(75, 75) -- Increased from 60x60 to 75x75
                    ItemIcon:SetModel(item.model)
                    ItemIcon:SetTooltip(item.name)
                    ItemIcon:SetCamPos(Vector(20, 20, 20))
                    ItemIcon:SetLookAt(Vector(0, 0, 0))

                    ItemIcon.DoClick = function()
                        local menu = DermaMenu()
                        menu:AddOption("Drop", function()
                            net.Start("DropItem")
                            net.WriteString(itemID)
                            net.WriteUInt(1, 8)
                            net.SendToServer()
                        end)
                        menu:AddOption("Use", function()
                            net.Start("UseItem")
                            net.WriteString(itemID)
                            net.SendToServer()
                        end)
                        menu:AddOption("Delete", function()
                            net.Start("DeleteItem")
                            net.WriteString(itemID)
                            net.WriteUInt(1, 8)
                            net.SendToServer()
                        end)
                        menu:Open()
                    end
                end
            end
        end
    end

    InventoryFrame:UpdateInventory()
end)