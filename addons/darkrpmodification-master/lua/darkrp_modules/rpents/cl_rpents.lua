-- Include the shared entities file
include("sh_entities.lua")

print("[RPEnts Module] cl_rpents.lua loaded successfully")

-- Store entity data received from the server
local EntitiesData = {}
local IsDonator = false

-- Currently selected entity (for the info panel)
local SelectedEntity = nil
local InfoPanel = nil

-- Reference to the entities tab (set externally if needed)
entitiesTab = entitiesTab or nil

-- Store the active timer name
local ActiveTimerName = nil

-- Notification function (copied from cl_inventory.lua)
local function ShowNotification(message)
    local screenW, screenH = ScrW(), ScrH()
    local notification = vgui.Create("DPanel")
    notification:SetSize(300, 50)
    notification:SetPos(screenW - 320, 20)
    notification:SetZPos(1000)
    notification.Think = function(self)
        if self.StartTime and (CurTime() - self.StartTime) > 3 then
            self:Remove()
        end
    end
    notification.StartTime = CurTime()
    notification.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
        draw.SimpleText(message, "DermaDefaultBold", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    surface.PlaySound("ui/buttonclick.wav")
end

-- Function to update the information panel with the selected entity's details
local function UpdateInfoPanel(entity)
    if not IsValid(InfoPanel) then return end
    for _, child in pairs(InfoPanel:GetChildren()) do child:Remove() end

    SelectedEntity = entity

    if not entity then
        local label = vgui.Create("DLabel", InfoPanel)
        label:SetText("Select an entity to view details.")
        label:SetPos(10, 10)
        label:SetSize(280, 20)
        label:SetColor(Color(255, 255, 255))
        return
    end

    local yPos = 10

    -- Entity Name
    local nameLabel = vgui.Create("DLabel", InfoPanel)
    nameLabel:SetText("Entity: " .. entity.name)
    nameLabel:SetPos(10, yPos)
    nameLabel:SetSize(280, 20)
    nameLabel:SetColor(Color(255, 255, 255))
    yPos = yPos + 40

    -- Price
    local priceLabel = vgui.Create("DLabel", InfoPanel)
    priceLabel:SetText("Price: $" .. entity.price)
    priceLabel:SetPos(10, yPos)
    priceLabel:SetSize(280, 20)
    priceLabel:SetColor(Color(0, 255, 0))
    yPos = yPos + 40

    -- Buy Button
    local buyButton = vgui.Create("DButton", InfoPanel)
    buyButton:SetSize(150, 40)
    buyButton:SetPos(140, yPos)
    buyButton:SetText("Buy " .. entity.name)
    buyButton:SetTextColor(Color(0, 0, 0))
    buyButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(100, 200, 100, 240) or Color(50, 150, 50, 240))
    end
    buyButton.DoClick = function()
        if not SelectedEntity then return end
        local success, err = pcall(function()
            net.Start("BuyEntity")
            net.WriteString(SelectedEntity.name)
            net.SendToServer()
        end)
        if success then
            print("[RPEnts Module] Requested to buy entity: " .. SelectedEntity.name)
        else
            print("[RPEnts Module] Error sending BuyEntity message: " .. tostring(err))
            ShowNotification("Failed to buy entity: Network error")
        end
    end
end

-- Function to build the Entities panel (called from cl_inventory.lua)
function BuildEntitiesPanel(parent)
    if not IsValid(parent) then
        print("[RPEnts Module] Error: Parent panel is not valid, cannot build Entities panel")
        return
    end

    -- Clean up any existing timer for this panel
    local timerName = "CheckEntitiesData_" .. tostring(parent)
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
    ActiveTimerName = timerName -- Store the timer name

    -- Clear existing children
    for _, child in pairs(parent:GetChildren()) do
        if IsValid(child) then child:Remove() end
    end

    -- Left panel: List of entities (using DPanel instead of DScrollPanel)
    local leftPanel = vgui.Create("DPanel", parent)
    leftPanel:SetSize(650, 650) -- Adjusted to fit 990x670 content area
    leftPanel:SetPos(10, 10)
    leftPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    -- Container panel for entities (no scrolling)
    local container = vgui.Create("DPanel", leftPanel)
    container:Dock(FILL)
    container:DockMargin(5, 5, 20, 5)
    container.Paint = function() end

    -- Right panel: Information panel for selected entity
    InfoPanel = vgui.Create("DPanel", parent)
    InfoPanel:SetSize(310, 650) -- Adjusted to fit 990x670 content area
    InfoPanel:SetPos(670, 10)
    InfoPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    -- If we haven't received entity data yet, show a loading message and request data
    if table.IsEmpty(EntitiesData) then
        local label = vgui.Create("DLabel", container)
        label:SetText("Loading entities...")
        label:SetPos(10, 10)
        label:SetSize(280, 20)
        label:SetColor(Color(255, 255, 255))

        -- Request data from the server with a slight delay
        timer.Simple(0.5, function()
            local success, err = pcall(function()
                net.Start("RequestEntitiesData")
                net.SendToServer()
            end)
            if success then
                print("[RPEnts Module] Requested entities data")
            else
                print("[RPEnts Module] Error sending RequestEntitiesData message: " .. tostring(err))
                ShowNotification("Failed to load entities: Network error")
            end
        end)

        -- Wait for data to be received
        timer.Create(timerName, 0.5, 4, function()
            if not timer.Exists(timerName) then return end -- Stop if timer was removed
            if not IsValid(parent) or not IsValid(container) or not IsValid(leftPanel) or not IsValid(InfoPanel) then
                print("[RPEnts Module] Parent, container, left panel, or info panel became invalid, stopping CheckEntitiesData timer")
                timer.Remove(timerName)
                ActiveTimerName = nil
                return
            end

            if not table.IsEmpty(EntitiesData) then
                -- Filter entities based on donator status
                local filteredEntities = {}
                for _, ent in ipairs(EntitiesData) do
                    if not ent.donatorOnly or IsDonator then
                        table.insert(filteredEntities, ent)
                    end
                end

                -- Clear the loading message and populate the panel
                for _, child in pairs(container:GetChildren()) do
                    if IsValid(child) then child:Remove() end
                end

                local entitiesAvailable = #filteredEntities > 0
                if not entitiesAvailable then
                    local noEntLabel = vgui.Create("DLabel", container)
                    noEntLabel:SetText("No entities available.")
                    noEntLabel:SetPos(10, 10)
                    noEntLabel:SetSize(280, 20)
                    noEntLabel:SetColor(Color(255, 255, 255))
                    UpdateInfoPanel(nil)
                    print("[RPEnts Module] No entities available after filtering")
                else
                    -- Populate the panel with filtered entities
                    local categories = {}
                    for _, ent in ipairs(filteredEntities) do
                        local category = ent.category or "General Entities"
                        if not categories[category] then
                            categories[category] = {}
                        end
                        table.insert(categories[category], ent)
                    end

                    local mainCat = vgui.Create("DCollapsibleCategory", container)
                    mainCat:Dock(TOP)
                    mainCat:SetLabel("Entities")
                    mainCat:SetExpanded(true)
                    mainCat:DockMargin(5, 5, 5, 0)

                    local mainLayout = vgui.Create("DPanel", mainCat)
                    mainLayout:Dock(FILL)
                    mainLayout:DockMargin(5, 5, 5, 5)
                    mainLayout.Paint = function() end

                    mainCat:SetContents(mainLayout)

                    local sortedCategories = {}
                    for category, _ in pairs(categories) do
                        table.insert(sortedCategories, category)
                    end
                    table.sort(sortedCategories)

                    for _, category in ipairs(sortedCategories) do
                        local subCat = vgui.Create("DCollapsibleCategory", mainLayout)
                        subCat:Dock(TOP)
                        subCat:SetLabel(category)
                        subCat:SetExpanded(true)
                        subCat:DockMargin(5, 5, 5, 0)

                        local layout = vgui.Create("DPanel", subCat)
                        layout:Dock(FILL)
                        layout:SetTall(math.ceil(#categories[category] / 2) * 130)
                        layout:DockMargin(5, 5, 5, 5)
                        layout.Paint = function() end

                        subCat:SetContents(layout)

                        -- Custom sorting for Printers category to ensure "Printer" comes before "Donator Printer"
                        if category == "Printers" then
                            table.sort(categories[category], function(a, b)
                                if a.name == "Printer" then return true end
                                if b.name == "Printer" then return false end
                                return a.name < b.name
                            end)
                        else
                            table.sort(categories[category], function(a, b) return a.name < b.name end)
                        end

                        for i, ent in ipairs(categories[category]) do
                            local panel = vgui.Create("DPanel", layout)
                            panel:SetSize(280, 120)
                            local row = math.floor((i - 1) / 2)
                            local col = (i - 1) % 2
                            panel:SetPos(col * (280 + 10) + 5, row * (120 + 10) + 5)
                            panel.Entity = ent
                            panel.Paint = function(self, w, h)
                                local bgColor = (SelectedEntity and SelectedEntity == ent) and Color(60, 60, 60, 240) or Color(40, 40, 40, 200)
                                draw.RoundedBox(4, 0, 0, w, h, bgColor)
                            end

                            local modelPanel = vgui.Create("DModelPanel", panel)
                            modelPanel:SetSize(80, 80)
                            modelPanel:SetPos(10, 20)
                            modelPanel:SetModel(ent.model or "models/error.mdl")
                            modelPanel:SetFOV(20)
                            modelPanel:SetCamPos(Vector(50, 50, 50))
                            modelPanel:SetLookAt(Vector(0, 0, 0))
                            modelPanel:SetMouseInputEnabled(true) -- Enable mouse input for clicking
                            -- Apply gold tint to Donator Printer's model preview
                            if ent.name == "Donator Printer" then
                                modelPanel.RenderOverride = function(self)
                                    render.SetColorModulation(1, 0.8, 0) -- Gold color (same as in-game)
                                    self:DrawModel()
                                    render.SetColorModulation(1, 1, 1) -- Reset
                                end
                            end
                            modelPanel.DoClick = function(self)
                                UpdateInfoPanel(ent)
                            end

                            local nameLabel = vgui.Create("DLabel", panel)
                            nameLabel:SetPos(100, 20)
                            nameLabel:SetSize(170, 20)
                            nameLabel:SetText(ent.name)
                            nameLabel:SetColor(Color(255, 255, 255))

                            local priceLabel = vgui.Create("DLabel", panel)
                            priceLabel:SetPos(100, 50)
                            priceLabel:SetSize(170, 20)
                            priceLabel:SetText("Price: $" .. ent.price)
                            priceLabel:SetColor(Color(0, 255, 0))

                            panel.OnMousePressed = function(self, code)
                                if code == MOUSE_LEFT then
                                    UpdateInfoPanel(self.Entity)
                                end
                            end
                        end
                    end

                    UpdateInfoPanel(nil)
                    print("[RPEnts Module] Successfully loaded entities data")
                end
                timer.Remove(timerName)
                ActiveTimerName = nil
                return
            end

            if timer.RepsLeft(timerName) == 0 then
                if not IsValid(container) then
                    print("[RPEnts Module] Container panel became invalid, cannot update with timeout message")
                    return
                end
                for _, child in pairs(container:GetChildren()) do
                    if IsValid(child) then child:Remove() end
                end
                local label = vgui.Create("DLabel", container)
                label:SetText("Failed to load entities. Please try again.")
                label:SetPos(10, 10)
                label:SetSize(280, 20)
                label:SetColor(Color(255, 100, 100))
                print("[RPEnts Module] Failed to load entities after timeout")
            end
        end)

        UpdateInfoPanel(nil)
        return
    end

    -- Filter entities based on donator status
    local filteredEntities = {}
    for _, ent in ipairs(EntitiesData) do
        if not ent.donatorOnly or IsDonator then
            table.insert(filteredEntities, ent)
        end
    end

    -- If EntitiesData is still empty after filtering, show "No entities available"
    if #filteredEntities == 0 then
        if not IsValid(container) then
            print("[RPEnts Module] Container panel became invalid, cannot display 'No entities available' message")
            return
        end
        local label = vgui.Create("DLabel", container)
        label:SetText("No entities available.")
        label:SetPos(10, 10)
        label:SetSize(280, 20)
        label:SetColor(Color(255, 255, 255))
        UpdateInfoPanel(nil)
        print("[RPEnts Module] No entities available after filtering")
        return
    end

    -- Organize filtered entities by category under the main "Entities" category
    local categories = {}
    for _, ent in ipairs(filteredEntities) do
        local category = ent.category or "General Entities"
        if not categories[category] then
            categories[category] = {}
        end
        table.insert(categories[category], ent)
    end

    -- Create the main "Entities" category
    local mainCat = vgui.Create("DCollapsibleCategory", container)
    mainCat:Dock(TOP)
    mainCat:SetLabel("Entities")
    mainCat:SetExpanded(true)
    mainCat:DockMargin(5, 5, 5, 0)

    local mainLayout = vgui.Create("DPanel", mainCat)
    mainLayout:Dock(FILL)
    mainLayout:DockMargin(5, 5, 5, 5)
    mainLayout.Paint = function() end

    mainCat:SetContents(mainLayout)

    -- Sort categories alphabetically
    local sortedCategories = {}
    for category, _ in pairs(categories) do
        table.insert(sortedCategories, category)
    end
    table.sort(sortedCategories)

    -- Create subcategories under "Entities"
    for _, category in ipairs(sortedCategories) do
        local subCat = vgui.Create("DCollapsibleCategory", mainLayout)
        subCat:Dock(TOP)
        subCat:SetLabel(category)
        subCat:SetExpanded(true)
        subCat:DockMargin(5, 5, 5, 0)

        local layout = vgui.Create("DPanel", subCat)
        layout:Dock(FILL)
        layout:SetTall(math.ceil(#categories[category] / 2) * 130)
        layout:DockMargin(5, 5, 5, 5)
        layout.Paint = function() end

        subCat:SetContents(layout)

        -- Custom sorting for Printers category to ensure "Printer" comes before "Donator Printer"
        if category == "Printers" then
            table.sort(categories[category], function(a, b)
                if a.name == "Printer" then return true end
                if b.name == "Printer" then return false end
                return a.name < b.name
            end)
        else
            table.sort(categories[category], function(a, b) return a.name < b.name end)
        end

        -- Add each entity to the category, two per row
        for i, ent in ipairs(categories[category]) do
            local panel = vgui.Create("DPanel", layout)
            panel:SetSize(280, 120)
            -- Position: Two per row
            local row = math.floor((i - 1) / 2)
            local col = (i - 1) % 2
            panel:SetPos(col * (280 + 10) + 5, row * (120 + 10) + 5)
            panel.Entity = ent
            panel.Paint = function(self, w, h)
                local bgColor = (SelectedEntity and SelectedEntity == ent) and Color(60, 60, 60, 240) or Color(40, 40, 40, 200)
                draw.RoundedBox(4, 0, 0, w, h, bgColor)
            end

            -- Entity model preview
            local modelPanel = vgui.Create("DModelPanel", panel)
            modelPanel:SetSize(80, 80)
            modelPanel:SetPos(10, 20)
            modelPanel:SetModel(ent.model or "models/error.mdl")
            modelPanel:SetFOV(20)
            modelPanel:SetCamPos(Vector(50, 50, 50))
            modelPanel:SetLookAt(Vector(0, 0, 0))
            modelPanel:SetMouseInputEnabled(true) -- Enable mouse input for clicking
            -- Apply gold tint to Donator Printer's model preview
            if ent.name == "Donator Printer" then
                modelPanel.RenderOverride = function(self)
                    render.SetColorModulation(1, 0.8, 0) -- Gold color (same as in-game)
                    self:DrawModel()
                    render.SetColorModulation(1, 1, 1) -- Reset
                end
            end
            modelPanel.DoClick = function(self)
                UpdateInfoPanel(ent)
            end

            -- Entity details
            local nameLabel = vgui.Create("DLabel", panel)
            nameLabel:SetPos(100, 20)
            nameLabel:SetSize(170, 20)
            nameLabel:SetText(ent.name)
            nameLabel:SetColor(Color(255, 255, 255))

            local priceLabel = vgui.Create("DLabel", panel)
            priceLabel:SetPos(100, 50)
            nameLabel:SetSize(170, 20)
            priceLabel:SetText("Price: $" .. ent.price)
            priceLabel:SetColor(Color(0, 255, 0))

            -- Clicking the panel selects the entity and updates the info panel
            panel.OnMousePressed = function(self, code)
                if code == MOUSE_LEFT then
                    UpdateInfoPanel(self.Entity)
                end
            end
        end
    end

    -- Initialize the info panel with no selection
    UpdateInfoPanel(nil)
end

-- Receive entity data from the server
net.Receive("SendEntitiesData", function()
    EntitiesData = net.ReadTable()
    IsDonator = net.ReadBool()
    print("[RPEnts Module] Received entities data: " .. table.ToString(EntitiesData))
    print("[RPEnts Module] Donator status: " .. tostring(IsDonator))

    -- Rebuild the Entities panel if it's open
    if IsValid(entitiesTab) then
        BuildEntitiesPanel(entitiesTab)
    end
end)

-- Listen for DarkRP notifications about entity spawning
hook.Add("OnPlayerChat", "RPEnts_SpawnFeedback", function(ply, text)
    if ply ~= LocalPlayer() then return end

    -- Check for custom error messages
    if text:find("You must be a donator") then
        ShowNotification("You must be a donator to buy this entity!")
    elseif text:find("You cannot afford") then
        ShowNotification("Cannot afford to buy this entity!")
    elseif text:find("Successfully bought and spawned") then
        ShowNotification("Successfully bought the entity!")
    end
end)

-- Clean up timer when the panel is closed
hook.Add("OnContextMenuClose", "RPEnts_CleanUpTimer", function()
    if ActiveTimerName and timer.Exists(ActiveTimerName) then
        timer.Remove(ActiveTimerName)
        print("[RPEnts Module] Cleaned up timer: " .. ActiveTimerName)
        ActiveTimerName = nil
    end
end)

-- Clean up timer when the inventory menu closes
hook.Add("OnInventoryMenuClosed", "RPEnts_CleanUpTimerOnInventoryClose", function()
    if ActiveTimerName and timer.Exists(ActiveTimerName) then
        timer.Remove(ActiveTimerName)
        print("[RPEnts Module] Cleaned up timer due to inventory menu close: " .. ActiveTimerName)
        ActiveTimerName = nil
    end
end)

print("[RPEnts Module] Client-side loaded successfully")