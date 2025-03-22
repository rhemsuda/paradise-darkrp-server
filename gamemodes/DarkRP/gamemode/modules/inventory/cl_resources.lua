print("[Inventory Module] cl_resources.lua loaded successfully")

local Resources = {}

local function BuildResourcesMenu()
    local frame = vgui.Create("DFrame")
    frame:SetSize(760, 280)
    frame:Center()
    frame:SetTitle("Resources")
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225))
    end

    local gridPanel = vgui.Create("DPanel", frame)
    gridPanel:SetPos(10, 30)
    gridPanel:SetSize(740, 240)
    gridPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240))
    end

    local scroll = vgui.Create("DScrollPanel", gridPanel)
    scroll:Dock(FILL)

    local categories = {
        { name = "Minerals", items = { "rock", "copper", "iron", "steel", "titanium" } },
        { name = "Gems", items = { "emerald", "ruby", "sapphire", "obsidian", "diamond" } },
        { name = "Lumber", items = { "ash", "birch", "oak", "mahogany", "yew" } }
    }

    local layout = vgui.Create("DIconLayout", scroll)
    layout:Dock(FILL)
    layout:SetSpaceX(10)
    layout:SetSpaceY(10)

    for _, category in ipairs(categories) do
        local catPanel = layout:Add("DPanel")
        catPanel:SetSize(240, 40 + #category.items * 40)
        catPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
        end

        local catLabel = vgui.Create("DLabel", catPanel)
        catLabel:SetPos(10, 10)
        catLabel:SetText(category.name)
        catLabel:SetSize(220, 20)
        catLabel:SetColor(Color(255, 215, 0))

        for i, resourceID in ipairs(category.items) do
            print("[Debug] Checking " .. resourceID .. ": " .. tostring(Resources[resourceID] or 0))
            local resPanel = vgui.Create("DPanel", catPanel)
            resPanel:SetPos(10, 30 + (i - 1) * 40)
            resPanel:SetSize(220, 30)
            resPanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200))
            end

            local displayName = string.upper(resourceID:sub(1,1)) .. resourceID:sub(2)
            local resLabel = vgui.Create("DLabel", resPanel)
            resLabel:SetPos(10, 5)
            resLabel:SetText(displayName .. ": " .. (Resources[resourceID] or 0))
            resLabel:SetSize(200, 20)
            resLabel:SetColor(Color(255, 255, 255))
            resLabel.Think = function(self)
                local currentAmount = Resources[resourceID] or 0
                self:SetText(displayName .. ": " .. currentAmount)
            end
            resLabel.OnMousePressed = function(self, code)
                if code == MOUSE_LEFT and (Resources[resourceID] or 0) > 0 then
                    local menu = DermaMenu()
                    menu:AddOption("Drop Amount", function()
                        Derma_StringRequest(
                            "Drop " .. displayName,
                            "How many " .. displayName .. " to drop? (Max: " .. (Resources[resourceID] or 0) .. ")",
                            "1",
                            function(text)
                                local dropAmount = math.min(tonumber(text) or 1, Resources[resourceID] or 0)
                                if dropAmount > 0 then
                                    net.Start("DropResource")
                                    net.WriteString(resourceID)
                                    net.WriteUInt(dropAmount, 16)
                                    net.SendToServer()
                                end
                            end
                        )
                    end)
                    local x, y = self:LocalToScreen(0, 30)
                    menu:Open(x, y)
                end
            end
        end
    end
end

net.Receive("SyncResources", function()
    Resources = net.ReadTable()
    print("[Debug] Received resources: " .. table.ToString(Resources))
end)

net.Receive("OpenResourcesMenu", function()
    print("[Debug] Opening Resources Menu with Resources: " .. table.ToString(Resources))
    BuildResourcesMenu()
end)

net.Receive("InventoryMessage", function()
    local msg = net.ReadString()
    chat.AddText(Color(255, 215, 0), "[Inventory] ", Color(255, 255, 255), msg)
end)