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

    -- Base frame
    InventoryFrame = vgui.Create("DFrame")
    InventoryFrame:SetSize(400, 300) -- Fixed size for now, can adjust later
    InventoryFrame:Center()
    InventoryFrame:SetTitle("Your Inventory")
    InventoryFrame:MakePopup()
	InventoryFrame.Paint = function( self, w, h )
		draw.RoundedBox(4, 0, 0, w, h, Color(10, 10, 10, 150))
	end

    -- Container for the grid
    local ItemContainer = vgui.Create("DPanel", InventoryFrame)
    ItemContainer:Dock(FILL)
    ItemContainer:DockMargin(5, 5, 5, 5)
    ItemContainer.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(80, 80, 80, 200)) -- Background
    end

    -- Grid layout for icons
    local ItemGrid = vgui.Create("DIconLayout", ItemContainer)
    ItemGrid:Dock(FILL)
    ItemGrid:SetSpaceX(5) -- Horizontal spacing between icons
    ItemGrid:SetSpaceY(5) -- Vertical spacing between icons

    function InventoryFrame:UpdateInventory()
        ItemGrid:Clear()

        for itemID, amount in pairs(PlayerInventory) do
            local item = InventoryItems[itemID]
            if item then
                for i = 1, amount do -- Add one icon per item instance
                    local ItemIcon = ItemGrid:Add("DModelPanel")
                    ItemIcon:SetSize(55, 55) -- Size of each icon
                    ItemIcon:SetModel(item.model)
                    ItemIcon:SetTooltip(item.name) -- Hover text is just the item name

                    -- Adjust the model view (optional, for better visibility)
                    ItemIcon:SetCamPos(Vector(20, 20, 20))
                    ItemIcon:SetLookAt(Vector(0, 0, 0))

                    -- Make the icon clickable to drop the item
                    ItemIcon.DoClick = function()
                        net.Start("DropItem")
                        net.WriteString(itemID)
                        net.WriteUInt(1, 8) -- Drop 1 item
                        net.SendToServer()
                    end
                end
            end
        end
    end

    InventoryFrame:UpdateInventory()
end)