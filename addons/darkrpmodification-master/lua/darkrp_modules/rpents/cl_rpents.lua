print("[RPEnts Module] cl_rpents.lua loaded successfully")

-- Store entity data received from the server
local EntitiesData = {}

-- Currently selected entity (for the info panel)
local SelectedEntity = nil
local InfoPanel = nil

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

    -- Max Allowed
    local maxLabel = vgui.Create("DLabel", InfoPanel)
    maxLabel:SetText("Max Allowed: " .. (entity.max == 0 and "Unlimited" or entity.max))
    label:SetPos(10, yPos)
    label:SetSize(280, 20)
    label:SetColor(Color(255, 255, 255))
    yPos = yPos + 40

    -- Spawn Button
    local spawnButton = vgui.Create("DButton", InfoPanel)
    spawnButton:SetSize(150, 40)
    spawnButton:SetPos(140, yPos)
    spawnButton:SetText("Spawn " .. entity.name)
    spawnButton:SetTextColor(Color(0, 0, 0))
    spawnButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(100, 200, 100, 240) or Color(50, 150, 50, 240))
    end
    spawnButton.DoClick = function()
        if not SelectedEntity then return end
        RunConsoleCommand("say", "/" .. SelectedEntity.cmd)
        print("[RPEnts Module] Requested to spawn entity: " .. SelectedEntity.name)
    end
end

-- Function to build the Entities panel (called from cl_inventory.lua)
function BuildEntitiesPanel(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end

    -- Left panel: Scrollable list of entities
    local leftPanel = vgui.Create("DPanel", parent)
    leftPanel:SetSize(650, 650) -- Adjusted to fit 990x670 content area
    leftPanel:SetPos(10, 10)
    leftPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    local scroll = vgui.Create("DScrollPanel", leftPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(5, 5, 20, 5)
    scroll:GetVBar():SetWide(10)

    -- Right panel: Information panel for selected entity
    InfoPanel = vgui.Create("DPanel", parent)
    InfoPanel:SetSize(310, 650) -- Adjusted to fit 990x670 content area
    InfoPanel:SetPos(670, 10)
    InfoPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    -- If we haven't received entity data yet, show a loading message and request data
    if table.IsEmpty(EntitiesData) then
        local label = vgui.Create("DLabel", scroll)
        label:SetText("Loading entities...")
        label:SetPos(10, 10)
        label:SetSize(280, 20)
        label:SetColor(Color(255, 255, 255))

        -- Request data from the server
        net.Start("RequestEntitiesData")
        net.SendToServer()
        print("[RPEnts Module] Requested entities data")

        -- Wait for data to be received
        timer.Create("CheckEntitiesData", 0.5, 20, function() -- Check for 10 seconds (20 * 0.5s)
            if not IsValid(parent) then
                timer.Remove("CheckEntitiesData")
                return
            end
            if not table.IsEmpty(EntitiesData) then
                BuildEntitiesPanel(parent) -- Refresh the panel with the new data
                timer.Remove("CheckEntitiesData")
                print("[RPEnts Module] Successfully loaded entities data")
                return
            end
            if timer.RepsLeft("CheckEntitiesData") == 0 then
                for _, child in pairs(scroll:GetChildren()) do child:Remove() end
                local label = vgui.Create("DLabel", scroll)
                label:SetText("No entities available for your job.")
                label:SetPos(10, 10)
                label:SetSize(280, 20)
                label:SetColor(Color(255, 255, 255))
                print("[RPEnts Module] No entities available after timeout")
            end
        end)

        UpdateInfoPanel(nil) -- Initialize info panel with no selection
        return
    end

    -- If EntitiesData is still empty after receiving data, show "No entities available"
    if #EntitiesData == 0 then
        local label = vgui.Create("DLabel", scroll)
        label:SetText("No entities available for your job.")
        label:SetPos(10, 10)
        label:SetSize(280, 20)
        label:SetColor(Color(255, 255, 255))
        UpdateInfoPanel(nil)
        print("[RPEnts Module] No entities available for this job")
        return
    end

    -- Organize entities by category under the main "Entities" category
    local categories = {}
    for _, ent in ipairs(EntitiesData) do
        local category = ent.category or "General Entities"
        if not categories[category] then
            categories[category] = {}
        end
        table.insert(categories[category], ent)
    end

    -- Create the main "Entities" category
    local mainCat = vgui.Create("DCollapsibleCategory", scroll)
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

        -- Sort entities within the category by name
        table.sort(categories[category], function(a, b) return a.name < b.name end)

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

            -- Entity details
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

            local maxLabel = vgui.Create("DLabel", panel)
            maxLabel:SetPos(100, 80)
            maxLabel:SetSize(170, 20)
            maxLabel:SetText("Max: " .. (ent.max == 0 and "Unlimited" or ent.max))
            maxLabel:SetColor(Color(255, 255, 255))

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
    print("[RPEnts Module] Received entities data: " .. table.ToString(EntitiesData))

    -- Rebuild the Entities panel if it's open
    if IsValid(entitiesTab) then
        BuildEntitiesPanel(entitiesTab)
    end
end)

-- Listen for DarkRP notifications about entity spawning
hook.Add("OnPlayerChat", "RPEnts_SpawnFeedback", function(ply, text)
    if ply ~= LocalPlayer() then return end

    -- Check for common DarkRP error messages
    if text:find("You cannot afford") then
        ShowNotification("Cannot afford to spawn this entity!")
    elseif text:find("You have reached the maximum amount") then
        ShowNotification("Maximum amount of this entity reached!")
    elseif text:find("You have spawned a") then
        ShowNotification("Successfully spawned the entity!")
    end
end)

print("[RPEnts Module] Client-side loaded successfully")