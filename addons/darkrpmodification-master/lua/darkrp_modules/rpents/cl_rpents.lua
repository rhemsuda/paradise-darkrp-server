include("sh_entities.lua")

print("[RPEnts Module] cl_rpents.lua loaded successfully")

local EntitiesData = {}
local IsDonator = false
local IsGunDealer = false
local needsRefresh = false

local SelectedEntity = nil
local InfoPanel = nil

entitiesTab = entitiesTab or nil

local ActiveTimerName = nil

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

    local nameLabel = vgui.Create("DLabel", InfoPanel)
    nameLabel:SetText("Entity: " .. entity.name)
    nameLabel:SetPos(10, yPos)
    nameLabel:SetSize(280, 20)
    nameLabel:SetColor(Color(255, 255, 255))
    yPos = yPos + 40

    local priceLabel = vgui.Create("DLabel", InfoPanel)
    local priceText = "Price: $" .. entity.price
    priceLabel:SetText(priceText)
    priceLabel:SetPos(10, yPos)
    priceLabel:SetSize(280, 20)
    priceLabel:SetColor(Color(0, 255, 0))
    surface.SetFont("DermaDefault")
    local textWidth, _ = surface.GetTextSize(priceText)
    print("[RPEnts Module] Debug: Price text '" .. priceText .. "' has approximate width: " .. textWidth .. " pixels")
    yPos = yPos + 40

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

function BuildEntitiesPanel(parent)
    if not IsValid(parent) then
        print("[RPEnts Module] Error: Parent panel is not valid, cannot build Entities panel")
        return
    end

    entitiesTab = parent

    local timerName = "CheckEntitiesData_" .. tostring(parent)
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
    ActiveTimerName = timerName

    for _, child in pairs(parent:GetChildren()) do
        if IsValid(child) then child:Remove() end
    end

    local leftPanel = vgui.Create("DPanel", parent)
    leftPanel:SetSize(650, 650)
    leftPanel:SetPos(10, 10)
    leftPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    -- Create a scroll panel to hold the entity list
    local scrollPanel = vgui.Create("DScrollPanel", leftPanel)
    scrollPanel:Dock(FILL)
    scrollPanel:DockMargin(5, 5, 20, 5)
    local sbar = scrollPanel:GetVBar()
    function sbar:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 100))
    end
    function sbar.btnUp:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50))
    end
    function sbar.btnDown:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50))
    end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(100, 100, 100))
    end

    -- Container inside the scroll panel
    local container = vgui.Create("DPanel", scrollPanel)
    container:Dock(TOP)
    container:DockPadding(5, 5, 5, 5)
    container.Paint = function() end

    InfoPanel = vgui.Create("DPanel", parent)
    InfoPanel:SetSize(310, 650)
    InfoPanel:SetPos(670, 10)
    InfoPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    -- Function to refresh the panel with the latest entities data
    local function RefreshEntitiesPanel()
        if not IsValid(parent) or not IsValid(container) or not IsValid(leftPanel) or not IsValid(InfoPanel) or not IsValid(scrollPanel) then
            print("[RPEnts Module] Parent, container, left panel, scroll panel, or info panel became invalid, stopping refresh")
            timer.Remove(timerName)
            ActiveTimerName = nil
            return
        end

        for _, child in pairs(container:GetChildren()) do
            if IsValid(child) then child:Remove() end
        end

        local filteredEntities = {}
        for _, ent in ipairs(EntitiesData) do
            if (not ent.donatorOnly or IsDonator) and (not ent.jobRestricted or IsGunDealer) then
                table.insert(filteredEntities, ent)
            end
        end

        print("[RPEnts Module] Filtered entities for display: " .. #filteredEntities)
        for _, ent in ipairs(filteredEntities) do
            print("[RPEnts Module] Debug:  - " .. ent.name .. " (Category: " .. ent.category .. ", JobRestricted: " .. tostring(ent.jobRestricted or false) .. ")")
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
            container:SetTall(30) -- Minimal height for "No entities" message
            return
        end

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
        mainLayout:Dock(TOP)
        mainLayout:DockMargin(5, 5, 5, 5)
        mainLayout.Paint = function() end

        mainCat:SetContents(mainLayout)

        local sortedCategories = {}
        for category, _ in pairs(categories) do
            table.insert(sortedCategories, category)
        end
        table.sort(sortedCategories)

        local totalHeight = 0

        for _, category in ipairs(sortedCategories) do
            local subCat = vgui.Create("DCollapsibleCategory", mainLayout)
            subCat:Dock(TOP)
            subCat:SetLabel(category)
            subCat:SetExpanded(true)
            subCat:DockMargin(5, 5, 5, 0)

            local layout = vgui.Create("DPanel", subCat)
            layout:Dock(TOP)
            layout:DockMargin(5, 5, 5, 5)
            layout.Paint = function() end

            if category == "Printers" then
                table.sort(categories[category], function(a, b)
                    if a.name == "Printer" then return true end
                    if b.name == "Printer" then return false end
                    return a.name < b.name
                end)
            else
                table.sort(categories[category], function(a, b) return a.name < b.name end)
            end

            local numEntities = #categories[category]
            local rows = math.ceil(numEntities / 2)
            layout:SetTall(rows * 130)

            subCat:SetContents(layout)

            totalHeight = totalHeight + 30 + (rows * 130) -- 30 for category header, 130 per row

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
                modelPanel:SetMouseInputEnabled(true)
                if ent.name == "Donator Printer" then
                    modelPanel.RenderOverride = function(self)
                        render.SetColorModulation(1, 0.8, 0)
                        self:DrawModel()
                        render.SetColorModulation(1, 1, 1)
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

        -- Adjust the container height to fit all categories
        mainLayout:SetTall(totalHeight)
        container:SetTall(totalHeight + 40) -- Add padding

        UpdateInfoPanel(nil)
        print("[RPEnts Module] Successfully loaded entities data")
    end

    if table.IsEmpty(EntitiesData) or needsRefresh then
        needsRefresh = false
        local label = vgui.Create("DLabel", container)
        label:SetText("Loading entities...")
        label:SetPos(10, 10)
        label:SetSize(280, 20)
        label:SetColor(Color(255, 255, 255))
        container:SetTall(30)

        timer.Simple(2, function()
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

        timer.Create(timerName, 0.5, 10, function()
            if not timer.Exists(timerName) then return end
            if not IsValid(parent) or not IsValid(container) or not IsValid(leftPanel) or not IsValid(InfoPanel) or not IsValid(scrollPanel) then
                print("[RPEnts Module] Parent, container, left panel, scroll panel, or info panel became invalid, stopping CheckEntitiesData timer")
                timer.Remove(timerName)
                ActiveTimerName = nil
                return
            end

            if not table.IsEmpty(EntitiesData) then
                RefreshEntitiesPanel()
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
                container:SetTall(30)
            end
        end)

        UpdateInfoPanel(nil)
        return
    end

    RefreshEntitiesPanel()
end

net.Receive("SendEntitiesData", function()
    EntitiesData = net.ReadTable()
    IsDonator = net.ReadBool()
    IsGunDealer = net.ReadBool()
    print("[RPEnts Module] Received entities data: " .. table.ToString(EntitiesData))
    print("[RPEnts Module] Donator status: " .. tostring(IsDonator))
    print("[RPEnts Module] Gun Dealer status: " .. tostring(IsGunDealer))

    if IsValid(entitiesTab) then
        BuildEntitiesPanel(entitiesTab)
    else
        needsRefresh = true
        print("[RPEnts Module] Entities tab not open, will refresh on next open")
    end
end)

hook.Add("OnPlayerChat", "RPEnts_SpawnFeedback", function(ply, text)
    if ply ~= LocalPlayer() then return end

    if text:find("You must be a donator") then
        ShowNotification("You must be a donator to buy this entity!")
    elseif text:find("You cannot afford") then
        ShowNotification("Cannot afford to buy this entity!")
    elseif text:find("Successfully bought and spawned") then
        ShowNotification("Successfully bought the entity!")
    elseif text:find("Successfully bought and dropped") then
        ShowNotification("Successfully dropped the weapon! Press E to pick it up.")
    elseif text:find("You must be a Gun Dealer") then
        ShowNotification("You must be a Gun Dealer to buy this entity!")
    end
end)

hook.Add("OnContextMenuClose", "RPEnts_CleanUpTimer", function()
    if ActiveTimerName and timer.Exists(ActiveTimerName) then
        timer.Remove(ActiveTimerName)
        print("[RPEnts Module] Cleaned up timer: " .. ActiveTimerName)
        ActiveTimerName = nil
    end
end)

hook.Add("OnInventoryMenuClosed", "RPEnts_CleanUpTimerOnInventoryClose", function()
    if ActiveTimerName and timer.Exists(ActiveTimerName) then
        timer.Remove(ActiveTimerName)
        print("[RPEnts Module] Cleaned up timer due to inventory menu close: " .. ActiveTimerName)
        ActiveTimerName = nil
    end
end)

hook.Add("OnPlayerChangedTeam", "RPEnts_RefreshOnJobChange", function(ply, oldTeam, newTeam)
    if ply ~= LocalPlayer() then return end
    print("[RPEnts Module] Player changed job from team " .. oldTeam .. " to " .. newTeam .. ", requesting new entities data")
    timer.Simple(2, function()
        local success, err = pcall(function()
            net.Start("RequestEntitiesData")
            net.SendToServer()
        end)
        if success then
            print("[RPEnts Module] Requested entities data after job change")
        else
            print("[RPEnts Module] Error sending RequestEntitiesData message after job change: " .. tostring(err))
            ShowNotification("Failed to refresh entities: Network error")
        end
    end)
end)

print("[RPEnts Module] Client-side loaded successfully")