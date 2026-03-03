-- Load entity definitions from same module (gamemode path so it works when loader runs this file)
local M = (GAMEMODE or GM).FolderName .. "/gamemode/modules/rpents/"
if file.Exists(M .. "sh_entities.lua", "LUA") then
    include(M .. "sh_entities.lua")
end

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

    local pad = 10
    local panelW = math.max(180, InfoPanel:GetWide() - pad * 2)

    if not entity then
        local label = vgui.Create("DLabel", InfoPanel)
        label:SetText("Select an entity to view details.")
        label:SetPos(pad, pad)
        label:SetSize(panelW, 20)
        label:SetFont("DermaDefaultBold")
        label:SetColor(Color(255, 255, 255))
        label:SetWrap(true)
        return
    end

    local yPos = pad

    local nameLabel = vgui.Create("DLabel", InfoPanel)
    nameLabel:SetText(entity.name)
    nameLabel:SetPos(pad, yPos)
    nameLabel:SetSize(panelW, 22)
    nameLabel:SetFont("DermaDefaultBold")
    nameLabel:SetColor(Color(255, 255, 255))
    nameLabel:SetWrap(true)
    yPos = yPos + 28

    local priceLabel = vgui.Create("DLabel", InfoPanel)
    local priceText = "Price: $" .. entity.price
    priceLabel:SetText(priceText)
    priceLabel:SetPos(pad, yPos)
    priceLabel:SetSize(panelW, 20)
    priceLabel:SetFont("DermaDefaultBold")
    priceLabel:SetColor(Color(0, 255, 0))
    yPos = yPos + 24

    -- Level requirement and unlock status (same as jobs)
    local requiredLevel = entity.level or 0
    if requiredLevel > 0 then
        local playerLevel = LocalPlayer():GetNWInt("DarkRP_Level", 1)
        local levelLabel = vgui.Create("DLabel", InfoPanel)
        if playerLevel >= requiredLevel then
            levelLabel:SetText("Unlocked (Level " .. requiredLevel .. ")")
            levelLabel:SetColor(Color(100, 255, 100))
        else
            levelLabel:SetText("Requires level " .. requiredLevel .. " (you: " .. playerLevel .. ")")
            levelLabel:SetColor(Color(255, 180, 100))
        end
        levelLabel:SetPos(pad, yPos)
        levelLabel:SetSize(panelW, 18)
        levelLabel:SetFont("DermaDefaultBold")
        yPos = yPos + 22
    end

    yPos = yPos + 8

    local playerLevel = LocalPlayer():GetNWInt("DarkRP_Level", 1)
    local isLocked = requiredLevel > 0 and playerLevel < requiredLevel

    local buyButton = vgui.Create("DButton", InfoPanel)
    buyButton:SetSize(math.min(160, panelW), 36)
    buyButton:SetPos(pad, yPos)
    if isLocked then
        buyButton:SetText("Level " .. requiredLevel .. " required")
        buyButton:SetTextColor(Color(120, 120, 120))
        buyButton:SetContentAlignment(5)
        buyButton:SetEnabled(false)
        buyButton.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(80, 80, 80, 200))
        end
    else
        buyButton:SetText("Buy " .. entity.name)
        buyButton:SetTextColor(Color(0, 0, 0))
        buyButton:SetContentAlignment(5)
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

    -- Flexible split: left list gets ~45% width, info panel gets the rest, so neither is cut off.
    local pad = 10
    local leftPanel = vgui.Create("DPanel", parent)
    leftPanel:Dock(LEFT)
    leftPanel:DockMargin(pad, pad, pad * 0.5, pad)
    leftPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end
    -- Width set in parent PerformLayout so it scales with content area (avoids fixed 400px cut-off).
    local function layoutEntitiesPanels()
        if not IsValid(parent) or not IsValid(leftPanel) then return end
        if not IsValid(leftPanel:GetParent()) then return end
        local pw = parent:GetWide()
        if pw > 0 then
            -- Wide enough for a grid (min ~5 columns) like Jobs tab
            local minWidthForGrid = 5 * (56 + 6) + 30
            leftPanel:SetWide(math.max(minWidthForGrid, math.floor(pw * 0.55)))
        end
    end
    if parent.PerformLayout then
        local oldLayout = parent.PerformLayout
        parent.PerformLayout = function(self)
            if oldLayout then oldLayout(self) end
            layoutEntitiesPanels()
        end
    else
        parent.PerformLayout = layoutEntitiesPanels
    end
    layoutEntitiesPanels()

    local scrollPanel = vgui.Create("DScrollPanel", leftPanel)
    scrollPanel:Dock(FILL)
    scrollPanel:DockMargin(5, 5, 8, 5)
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

    -- Container inside the scroll panel (extra top padding so first header isn't cut off)
    local container = vgui.Create("DPanel", scrollPanel)
    container:Dock(TOP)
    container:DockPadding(8, 14, 8, 8)
    container.Paint = function() end

    InfoPanel = vgui.Create("DPanel", parent)
    InfoPanel:Dock(FILL)
    InfoPanel:DockMargin(pad * 0.5, pad, pad, pad)
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

        -- Group by category; custom headers + compact grid (like Jobs tab)
        local categories = {}
        for _, ent in ipairs(filteredEntities) do
            local category = ent.category or "General Entities"
            if not categories[category] then
                categories[category] = {}
            end
            table.insert(categories[category], ent)
        end

        local sortedCategories = {}
        for category, _ in pairs(categories) do
            table.insert(sortedCategories, category)
        end
        table.sort(sortedCategories)

        local iconSize, iconSpace = 56, 6
        local leftW = (IsValid(leftPanel) and leftPanel:GetWide() or 350) - 26
        local cols = math.max(5, math.floor(leftW / (iconSize + iconSpace)))
        local playerLevel = LocalPlayer():GetNWInt("DarkRP_Level", 1)
        local layoutY = 4

        for _, category in ipairs(sortedCategories) do
            if category == "Printers" then
                table.sort(categories[category], function(a, b)
                    local lvA, lvB = a.level or 1, b.level or 1
                    if lvA ~= lvB then return lvA < lvB end
                    return (a.name or "") < (b.name or "")
                end)
            else
                table.sort(categories[category], function(a, b) return (a.name or "") < (b.name or "") end)
            end

            -- Section header (same style as Jobs)
            local header = vgui.Create("DPanel", container)
            header:SetPos(0, layoutY)
            header:SetSize(leftW + 16, 28)
            layoutY = layoutY + 32
            header.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(35, 45, 60, 250))
                surface.SetDrawColor(0, 160, 220, 180)
                surface.DrawOutlinedRect(0, 0, w, h)
            end
            local headerLabel = vgui.Create("DLabel", header)
            headerLabel:SetText(category)
            headerLabel:SetFont("DermaDefaultBold")
            headerLabel:SetTextColor(Color(255, 255, 255))
            headerLabel:SetPos(8, 0)
            headerLabel:SetSize(leftW, 28)
            headerLabel:SetContentAlignment(4)

            -- Grid of compact entity icons
            local rows = math.ceil(#categories[category] / cols)
            local gridH = rows * (iconSize + iconSpace) + iconSpace
            local grid = vgui.Create("DPanel", container)
            grid:SetPos(8, layoutY)
            grid:SetSize(leftW, gridH)
            grid.Paint = function() end
            layoutY = layoutY + gridH + 8

            for i, ent in ipairs(categories[category]) do
                local requiredLevel = ent.level or 0
                local isLocked = requiredLevel > 0 and playerLevel < requiredLevel

                local row = math.floor((i - 1) / cols)
                local col = (i - 1) % cols
                local cell = vgui.Create("DPanel", grid)
                cell:SetPos(col * (iconSize + iconSpace), row * (iconSize + iconSpace) + iconSpace)
                cell:SetSize(iconSize, iconSize)
                cell.Entity = ent
                cell:SetAlpha(isLocked and 130 or 255)
                cell.Paint = function(self, w, h)
                    local bg = (SelectedEntity and SelectedEntity == ent) and Color(60, 70, 90, 240) or Color(40, 40, 40, 200)
                    draw.RoundedBox(4, 0, 0, w, h, bg)
                end

                local modelPanel = vgui.Create("DModelPanel", cell)
                modelPanel:Dock(FILL)
                modelPanel:DockMargin(4, 4, 4, 4)
                modelPanel:SetModel(ent.model or "models/error.mdl")
                -- Last two printers (printer5, printer6) use larger models; much higher FOV to show full model
                local fov = (ent.ent == "printer5" or ent.ent == "printer6") and 62 or 28
                modelPanel:SetFOV(fov)
                modelPanel:SetCamPos(Vector(55, 55, 55))
                modelPanel:SetLookAt(Vector(0, 0, 0))
                modelPanel:SetMouseInputEnabled(false)
                if ent.name == "Donator Printer" then
                    modelPanel.RenderOverride = function(self)
                        render.SetColorModulation(1, 0.8, 0)
                        self:DrawModel()
                        render.SetColorModulation(1, 1, 1)
                    end
                end

                local overlay = vgui.Create("DLabel", cell)
                overlay:SetPos(2, 2)
                overlay:SetSize(iconSize - 4, 14)
                overlay:SetFont("DermaDefault")
                overlay:SetContentAlignment(5)
                if isLocked then
                    overlay:SetText("Lv." .. requiredLevel)
                    overlay:SetColor(Color(255, 220, 100))
                elseif requiredLevel > 0 then
                    overlay:SetText("Unlocked")
                    overlay:SetColor(Color(150, 255, 150))
                else
                    overlay:SetText("")
                end

                cell:SetTooltip((ent.name or "") .. " · $" .. (ent.price or 0) .. (isLocked and (" (Level " .. requiredLevel .. " required)") or ""))
                cell.OnMousePressed = function(self, code)
                    if code == MOUSE_LEFT then UpdateInfoPanel(self.Entity) end
                end
            end
        end

        container:SetTall(math.max(60, layoutY + 10))
        container:DockMargin(8, 8, 8, 8)

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