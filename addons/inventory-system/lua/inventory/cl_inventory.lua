local InventoryFrame = nil -- Holds the inventory UI frame
local PlayerInventory = {} -- Stores the player’s current inventory locally

-- Syncs inventory data from server to client
net.Receive("SyncInventory", function()
    PlayerInventory = net.ReadTable() -- Update local inventory table
    if IsValid(InventoryFrame) then
        InventoryFrame:UpdateInventory() -- Refresh UI if open
    end
end)

-- Displays player-only inventory messages in chat
net.Receive("InventoryMessage", function()
    local message = net.ReadString()
    chat.AddText(Color(255, 255, 0), "[Inventory] ", Color(255, 255, 255), message) -- Yellow prefix, white text
end)

-- Opens the inventory UI when requested by server
net.Receive("OpenInventory", function()
    if IsValid(InventoryFrame) then
        InventoryFrame:Remove() -- Close existing frame if open
    end

    InventoryFrame = vgui.Create("DFrame") -- Create the main inventory window
    InventoryFrame:SetSize(600, 400) -- Larger size for more items
    InventoryFrame:Center() -- Center on screen
    InventoryFrame:SetTitle("Inventory") -- Window title
    InventoryFrame:MakePopup() -- Make it interactive
    InventoryFrame.Paint = function(self, w, h) -- Custom background
        draw.RoundedBox(0, 0, 0, w, h, Color(1, 1, 1, 125)) -- Semi-transparent white
    end

    local ItemContainer = vgui.Create("DPanel", InventoryFrame) -- Container for item grid
    ItemContainer:Dock(FILL) -- Fill the frame
    ItemContainer:DockMargin(5, 5, 5, 5) -- Add padding
    ItemContainer.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(100, 100, 100, 200)) -- Gray background
    end

    local ItemGrid = vgui.Create("DIconLayout", ItemContainer) -- Grid layout for items
    ItemGrid:Dock(FILL)
    ItemGrid:SetSpaceX(5) -- Horizontal spacing between items
    ItemGrid:SetSpaceY(5) -- Vertical spacing between items

    -- Updates the inventory UI with current items
    function InventoryFrame:UpdateInventory()
        ItemGrid:Clear() -- Remove all existing icons

        for itemID, amount in pairs(PlayerInventory) do
            local item = InventoryItems[itemID]
            if item then -- If item exists in whitelist
                local ItemPanel = ItemGrid:Add("DPanel") -- Panel for each item stack
                ItemPanel:SetSize(75, 75) -- Larger icon size
                ItemPanel.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200)) -- Dark gray background
                end

                local ItemIcon = vgui.Create("DModelPanel", ItemPanel) -- 3D model icon
                ItemIcon:SetSize(75, 75)
                ItemIcon:SetModel(item.model) -- Set item model
                ItemIcon:SetTooltip(item.name .. " (" .. amount .. ")") -- Show name and stack size
                ItemIcon:SetCamPos(Vector(20, 20, 20)) -- Camera position for model
                ItemIcon:SetLookAt(Vector(0, 0, 0)) -- Camera focus point

                local AmountLabel = vgui.Create("DLabel", ItemPanel) -- Stack size label
                AmountLabel:SetPos(2, 2) -- Top-left corner
                AmountLabel:SetText(amount) -- Display quantity
                AmountLabel:SetFont("DermaDefaultBold") -- Bold font for visibility
                AmountLabel:SetTextColor(Color(255, 255, 255)) -- White text
                AmountLabel:SizeToContents() -- Fit text size
                AmountLabel:SetContentAlignment(7) -- Align top-left

                -- Dropdown menu when clicking an item
                ItemIcon.DoClick = function()
                    local menu = DermaMenu() -- Create context menu
                    menu:AddOption("Drop", function() -- Drop option
                        Derma_StringRequest( -- Prompt for amount
                            "Drop Amount",
                            "How many " .. item.name .. "s to drop? (Max: " .. amount .. ")",
                            "1",
                            function(text)
                                local num = math.min(tonumber(text) or 1, amount)
                                if num > 0 then
                                    net.Start("DropItem")
                                    net.WriteString(itemID)
                                    net.WriteUInt(num, 8)
                                    net.SendToServer()
                                end
                            end
                        )
                    end)
                    menu:AddOption("Use", function() -- Use option (1 item)
                        net.Start("UseItem")
                        net.WriteString(itemID)
                        net.SendToServer()
                    end)
                    menu:AddOption("Delete", function() -- Delete option
                        Derma_StringRequest( -- Prompt for amount
                            "Delete Amount",
                            "How many " .. item.name .. "s to delete? (Max: " .. amount .. ")",
                            "1",
                            function(text)
                                local num = math.min(tonumber(text) or 1, amount)
                                if num > 0 then
                                    net.Start("DeleteItem")
                                    net.WriteString(itemID)
                                    net.WriteUInt(num, 8)
                                    net.SendToServer()
                                end
                            end
                        )
                    end)
                    menu:Open() -- Show the menu
                end
            end
        end
    end

    InventoryFrame:UpdateInventory() -- Initial UI update
end)