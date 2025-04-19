print("[RPMenu] cl_rpmenu.lua loaded successfully")

if not CLIENT then return end

-- Constants for layout
local FRAME_WIDTH, FRAME_HEIGHT = 880, 700
local PADDING = 10
local QUADRANT_WIDTH = (FRAME_WIDTH - 3 * PADDING) / 2 -- 425
local RIGHT_PANEL_WIDTH = 400 -- Fixed width for right panels (upgradeListPanel and gangItemsPanel)
local TOP_OFFSET = 40
local INFO_HEIGHT = 250
local UPGRADE_HEIGHT = 155 -- 6 upgrades: 6 * 20 + 5 * 5 spacing + 10 padding
local BUTTON_HEIGHT = 30
local BUTTON_WIDTH = 100 -- Adjusted for 4 buttons in a row

-- Define fonts using built-in Garry's Mod fonts
local function CreateFonts()
    surface.CreateFont("RPMenuTitle", {
        font = "Trebuchet24", size = 40, weight = 700, antialias = true, shadow = true
    })
    surface.CreateFont("RPMenuText", {
        font = "Trebuchet18", size = 20, weight = 500, antialias = true, shadow = true
    })
    surface.CreateFont("RPMenuTextSmall", {
        font = "Trebuchet18", size = 18, weight = 500, antialias = true, shadow = true
    })
    surface.CreateFont("RPMenuTextLargeBold", {
        font = "Trebuchet18", size = 24, weight = 700, antialias = true, shadow = true
    })
end
CreateFonts()

-- Global state
local RPMenu = nil
local RPMMenuSheet = nil
local CurrentGangLevel = 1
local CurrentGangXP = 0
local IsDataLoaded = false
local CachedGangData = nil
local PendingGangData = nil
local gangItemsPanel = nil

-- Helper function to create a rounded box panel
local function CreateRoundedPanel(parent, x, y, w, h, color)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(x, y)
    panel:SetSize(w, h)
    panel.Paint = function(self, pw, ph)
        draw.RoundedBox(4, 0, 0, pw, ph, color)
    end
    return panel
end

-- Helper function to create a labeled text entry
local function CreateLabeledEntry(parent, labelText, x, y, w, placeholder)
    local label = vgui.Create("DLabel", parent)
    label:SetPos(x, y)
    label:SetSize(150, 20)
    label:SetFont("RPMenuText")
    label:SetText(labelText)
    label:SetTextColor(Color(255, 255, 255))

    local entry = vgui.Create("DTextEntry", parent)
    entry:SetPos(x + 160, y)
    entry:SetSize(w - 160, 20)
    entry:SetPlaceholderText(placeholder)
    return entry
end

-- Helper function to create a button
local function CreateButton(parent, x, y, w, h, text, onClick, bgColor)
    local button = vgui.Create("DButton", parent)
    button:SetPos(x, y)
    button:SetSize(w, h)
    button:SetText(text)
    button:SetFont("RPMenuTextSmall")
    button:SetTextColor(Color(255, 255, 255))
    button:SetContentAlignment(5)
    button.Paint = function(self, pw, ph)
        draw.RoundedBox(4, 0, 0, pw, ph, bgColor or Color(70, 70, 70, 150))
    end
    button.DoClick = onClick
    return button
end

-- Create the main RPMenu (Gangs only)
local function CreateRPMenu()
    if IsValid(RPMenu) then RPMenu:Remove() end

    print("[RPMenu] Creating custom F4 menu (Gangs only)")

    RPMenu = vgui.Create("DFrame")
    RPMenu:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    RPMenu:SetPos((ScrW() - FRAME_WIDTH) / 2, (ScrH() - FRAME_HEIGHT) / 2)
    RPMenu:SetTitle("")
    RPMenu:SetDraggable(false)
    RPMenu:ShowCloseButton(true)
    RPMenu:MakePopup()
    RPMenu.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 255))
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, Color(50, 50, 50, 255))
    end
    RPMenu.OnClose = function()
        IsDataLoaded = false
        RPMMenuSheet = nil
        print("[RPMenu] Menu closed, resetting IsDataLoaded")
    end

    RPMMenuSheet = vgui.Create("DPropertySheet", RPMenu)
    RPMMenuSheet:Dock(FILL)
    RPMMenuSheet:DockMargin(PADDING, PADDING, PADDING, PADDING)
    RPMMenuSheet.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 50, 255))
    end

    -- Gangs Tab
    local gangsPanel = vgui.Create("DPanel", RPMMenuSheet)
    gangsPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
    end
    RPMMenuSheet:AddSheet("Gangs", gangsPanel, "icon16/group.png", false, false, "Manage your gang")
    gangsPanel:SetPaintBackground(false)
    gangsPanel:DockPadding(PADDING, PADDING, PADDING, PADDING)

    RPMMenuSheet.OnActiveTabChanged = function(self, oldTab, newTab)
        if newTab:GetText() == "Gangs" and not IsDataLoaded and not CachedGangData then
            print("[RPMenu] Gangs tab selected, requesting gang data")
            net.Start("RPMenu_RequestGangData")
            net.SendToServer()
        end
        if newTab:GetText() == "Gangs" and PendingGangData then
            print("[RPMenu] Applying pending gang data")
            CachedGangData = PendingGangData
            PendingGangData = nil
            if IsValid(gangsPanel) then
                gangsPanel:UpdateGangUI(CachedGangData)
            end
        end
    end

    local gangName = LocalPlayer():GetNWString("GangName", "")
    if gangName == "" then
        timer.Simple(0, function()
            if not IsValid(gangsPanel) then
                print("[RPMenu] Gangs panel invalid, aborting creation UI")
                return
            end

            local panelWidth, panelHeight = gangsPanel:GetSize()
            print("[RPMenu] Gangs panel size: " .. panelWidth .. "x" .. panelHeight)

            local creationPanel = CreateRoundedPanel(gangsPanel, 0, 0, panelWidth, panelHeight, Color(70, 70, 70, 150))

            local nameEntry = CreateLabeledEntry(creationPanel, "Gang Name:", PADDING, PADDING, panelWidth - 2 * PADDING, "Enter gang name")
            local colorLabel = vgui.Create("DLabel", creationPanel)
            colorLabel:SetPos(PADDING, PADDING + 40)
            colorLabel:SetSize(150, 20)
            colorLabel:SetFont("RPMenuText")
            colorLabel:SetText("Clan Color:")
            colorLabel:SetTextColor(Color(255, 255, 255))

            local colorMixer = vgui.Create("DColorMixer", creationPanel)
            colorMixer:SetPos(PADDING + 160, PADDING + 40)
            colorMixer:SetSize(panelWidth - 2 * PADDING - 160, 100)
            colorMixer:SetPalette(true)
            colorMixer:SetAlphaBar(false)
            colorMixer:SetWangs(true)
            colorMixer:SetColor(Color(255, 255, 255))

            local passwordEntry = CreateLabeledEntry(creationPanel, "Gang Password:", PADDING, PADDING + 150, panelWidth - 2 * PADDING, "Enter gang password")

            CreateButton(creationPanel, PADDING, PADDING + 190, panelWidth - 2 * PADDING, 40, "Create Gang", function()
                local gangName = nameEntry:GetValue()
                local gangColor = colorMixer:GetColor()
                local password = passwordEntry:GetValue()
                if gangName == "" or password == "" then
                    LocalPlayer():ChatPrint("Please fill in all fields!")
                    return
                end
                net.Start("RPMenu_CreateGang")
                net.WriteString(gangName)
                net.WriteColor(gangColor)
                net.WriteString(password)
                net.SendToServer()
            end)
        end)
        return
    end

    -- XP Bar
    local xpBar = CreateRoundedPanel(gangsPanel, 0, 0, FRAME_WIDTH - 6 * PADDING, 30, Color(0, 0, 0, 150))
    xpBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 150))
        surface.SetDrawColor(255, 0, 0, 150)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        local maxXPPerLevel = 1000
        local xpProgress = math.min(CurrentGangXP / maxXPPerLevel, 1)
        draw.RoundedBox(4, 2, 2, (w - 4) * xpProgress, h - 4, Color(0, 255, 0, 200))
        draw.SimpleText("Gang Level " .. CurrentGangLevel .. " (XP: " .. CurrentGangXP .. "/" .. maxXPPerLevel .. ")", "RPMenuText", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Gang Info (top left)
    local gangInfoPanel = CreateRoundedPanel(gangsPanel, 0, TOP_OFFSET, QUADRANT_WIDTH - PADDING, INFO_HEIGHT, Color(70, 70, 70, 150))
    gangInfoPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
        if not IsDataLoaded and not CachedGangData then
            draw.SimpleText("Fetching data...", "RPMenuText", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local labelWidth = QUADRANT_WIDTH - 3 * PADDING
    local namePrefixLabel = vgui.Create("DLabel", gangInfoPanel)
    namePrefixLabel:SetPos(PADDING, PADDING + 5)
    namePrefixLabel:SetSize(60, 20)
    namePrefixLabel:SetFont("RPMenuTextSmall")
    namePrefixLabel:SetText("Name:")
    namePrefixLabel:SetTextColor(Color(255, 255, 255))

    local nameLabel = vgui.Create("DLabel", gangInfoPanel)
    nameLabel:SetPos(70, PADDING)
    nameLabel:SetSize(labelWidth - 70, 30)
    nameLabel:SetFont("RPMenuTextLargeBold")
    nameLabel:SetText("Loading...")
    nameLabel:SetTextColor(Color(255, 255, 255))

    local levelLabel = vgui.Create("DLabel", gangInfoPanel)
    levelLabel:SetPos(PADDING, 50)
    levelLabel:SetSize(labelWidth, 20)
    levelLabel:SetFont("RPMenuTextSmall")
    levelLabel:SetText("Level: Loading...")
    levelLabel:SetTextColor(Color(255, 255, 255))

    local capacityLabel = vgui.Create("DLabel", gangInfoPanel)
    capacityLabel:SetPos(PADDING, 70)
    capacityLabel:SetSize(labelWidth, 20)
    levelLabel:SetFont("RPMenuTextSmall")
    capacityLabel:SetText("Gang Capacity: Loading...")
    capacityLabel:SetTextColor(Color(255, 255, 255))

    local bankLabel = vgui.Create("DLabel", gangInfoPanel)
    bankLabel:SetPos(PADDING, 90)
    bankLabel:SetSize(labelWidth, 20)
    bankLabel:SetFont("RPMenuTextSmall")
    bankLabel:SetText("Gang Bank: 0")
    bankLabel:SetTextColor(Color(255, 255, 255))

    local pointsLabel = vgui.Create("DLabel", gangInfoPanel)
    pointsLabel:SetPos(PADDING, 110)
    pointsLabel:SetSize(labelWidth, 20)
    pointsLabel:SetFont("RPMenuTextSmall")
    pointsLabel:SetText("Upgrade Points: Loading...")
    pointsLabel:SetTextColor(Color(255, 255, 255))

    -- Button row at the bottom
    local buttonY = INFO_HEIGHT - BUTTON_HEIGHT - PADDING

    -- Refresh Button
    CreateButton(gangInfoPanel, PADDING, buttonY, BUTTON_WIDTH, BUTTON_HEIGHT, "Refresh", function()
        net.Start("RPMenu_RequestGangData")
        net.SendToServer()
    end, Color(0, 0, 0, 255))

    -- Donate to Bank
    CreateButton(gangInfoPanel, PADDING + BUTTON_WIDTH + 5, buttonY, BUTTON_WIDTH, BUTTON_HEIGHT, "Donate", function()
        Derma_StringRequest("Donate to Gang Bank", "How much would you like to donate?", "", function(amountText)
            local amount = tonumber(amountText)
            if not amount or amount <= 0 then
                LocalPlayer():ChatPrint("Please enter a valid amount!")
                return
            end
            Derma_Query("Are you sure you want to donate " .. amount .. " to the gang bank?", "Confirm Donation", "Yes", function()
                net.Start("RPMenu_DonateToBank")
                net.WriteUInt(amount, 32)
                net.SendToServer()
                if IsValid(RPMenu) then
                    RPMenu:Close()
                end
            end, "No", function() end)
        end, function() end, "Next", "Cancel")
    end, Color(0, 0, 0, 255))

    -- Leave Gang
    CreateButton(gangInfoPanel, PADDING + 2 * (BUTTON_WIDTH + 5), buttonY, BUTTON_WIDTH, BUTTON_HEIGHT, "Leave Gang", function()
        Derma_Query("Are you sure you want to leave your gang?", "Leave Gang Confirmation", "Yes", function()
            net.Start("RPMenu_LeaveGang")
            net.SendToServer()
            if IsValid(RPMenu) then
                RPMenu:Close()
            end
        end, "No", function() end)
    end, Color(0, 0, 0, 255))

    -- Disband Gang (visible only to Leader, red background)
    local disbandButton = CreateButton(gangInfoPanel, PADDING + 3 * (BUTTON_WIDTH + 5), buttonY, BUTTON_WIDTH, BUTTON_HEIGHT, "Disband Gang", function()
        Derma_StringRequest("Disband Gang", "Enter the gang password to disband", "", function(password)
            Derma_Query("Are you sure you want to disband the gang? This action is irreversible.", "Disband Gang Confirmation", "Yes", function()
                net.Start("RPMenu_DisbandGang")
                net.WriteString(password)
                net.SendToServer()
            end, "No", function() end)
        end, function() end, "Submit", "Cancel")
    end, Color(255, 0, 0, 255))
    -- Set visibility based on rank
    disbandButton:SetVisible(false) -- Default to hidden
    hook.Add("Think", "CheckGangLeaderForDisbandButton", function()
        if not IsValid(disbandButton) then return end
        if not CachedGangData or not CachedGangData.members then return end
        local playerRank = "Unknown"
        for _, member in ipairs(CachedGangData.members) do
            if member.steamid == LocalPlayer():SteamID() then
                playerRank = member.rank or "Recruit"
                break
            end
        end
        disbandButton:SetVisible(playerRank == "Leader")
    end)

    -- Player List (bottom left)
    local playerListHeight = FRAME_HEIGHT - TOP_OFFSET - INFO_HEIGHT - 3 * PADDING
    local playerListView = vgui.Create("DListView", gangsPanel)
    playerListView:SetPos(0, TOP_OFFSET + INFO_HEIGHT + PADDING)
    playerListView:SetSize(QUADRANT_WIDTH - PADDING, playerListHeight)
    playerListView:SetMultiSelect(false)
    playerListView:AddColumn("Player Name (SteamID)")
    playerListView:AddColumn("Rank")
    playerListView:SetHeaderHeight(20)
    playerListView.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 150))
    end
    playerListView.VBar.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 150)) end
    playerListView.VBar.btnUp.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 150)) end
    playerListView.VBar.btnDown.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 150)) end
    playerListView.VBar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(200, 200, 200, 150)) end

    -- Add context menu for player list
    playerListView.OnRowRightClick = function(self, lineID, line)
        print("[RPMenu] Right-clicked on player list row: " .. line:GetColumnText(1))
        local steamID = string.match(line:GetColumnText(1), "%((STEAM_[0-1]:[0-1]:%d+)%)")
        local playerRank = "Unknown"
        for _, member in ipairs(CachedGangData and CachedGangData.members or {}) do
            if member.steamid == LocalPlayer():SteamID() then
                playerRank = member.rank or "Recruit"
                break
            end
        end
        print("[RPMenu] Player rank: " .. playerRank .. ", Target SteamID: " .. (steamID or "nil"))

        local menu = DermaMenu()
        if playerRank == "Leader" and steamID ~= LocalPlayer():SteamID() then
            menu:AddOption("Kick", function()
                Derma_Query("Are you sure you want to kick this player?", "Kick Confirmation", "Yes", function()
                    net.Start("RPMenu_KickPlayer")
                    net.WriteString(steamID)
                    net.SendToServer()
                end, "No", function() end)
            end):SetIcon("icon16/user_delete.png")
        end

        if (playerRank == "Leader" or playerRank == "Vice Leader") and steamID ~= LocalPlayer():SteamID() then
            local rankMenu = menu:AddSubMenu("Set Rank")
            rankMenu:SetIcon("icon16/user_edit.png")
            local targetRank = line:GetColumnText(2)
            local canModify = playerRank == "Leader" or (targetRank ~= "Leader" and targetRank != "Vice Leader")

            if canModify then
                rankMenu:AddOption("Recruit", function()
                    net.Start("RPMenu_SetRank")
                    net.WriteString(steamID)
                    net.WriteString("Recruit")
                    net.SendToServer()
                end):SetIcon("icon16/user.png")
                rankMenu:AddOption("Vice Leader", function()
                    net.Start("RPMenu_SetRank")
                    net.WriteString(steamID)
                    net.WriteString("Vice Leader")
                    net.SendToServer()
                end):SetIcon("icon16/user_orange.png")
                if playerRank == "Leader" then
                    rankMenu:AddOption("Leader", function()
                        net.Start("RPMenu_SetRank")
                        net.WriteString(steamID)
                        net.WriteString("Leader")
                        net.SendToServer()
                    end):SetIcon("icon16/user_red.png")
                end
            else
                rankMenu:AddOption("Cannot modify this rank", function() end):SetIcon("icon16/lock.png")
            end
        end

        menu:Open()
    end

    -- Upgrade List (top right)
    local upgradeListPanel = vgui.Create("DPanelList", gangsPanel)
    upgradeListPanel:SetPos(QUADRANT_WIDTH + PADDING, TOP_OFFSET)
    upgradeListPanel:SetSize(RIGHT_PANEL_WIDTH, UPGRADE_HEIGHT)
    upgradeListPanel:SetSpacing(5)
    upgradeListPanel:EnableVerticalScrollbar(false)
    upgradeListPanel:SetPadding(5)
    upgradeListPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
    end
    print("[RPMenu] Upgrade List Panel - Pos: (" .. (QUADRANT_WIDTH + PADDING) .. ", " .. TOP_OFFSET .. "), Size: (" .. RIGHT_PANEL_WIDTH .. ", " .. UPGRADE_HEIGHT .. ")")

    -- Gang Items (Entities) (bottom right)
    local gangItemsHeight = FRAME_HEIGHT - TOP_OFFSET - UPGRADE_HEIGHT - 4 * PADDING - BUTTON_HEIGHT - 10
    gangItemsPanel = CreateRoundedPanel(gangsPanel, QUADRANT_WIDTH + PADDING, TOP_OFFSET + UPGRADE_HEIGHT + PADDING, RIGHT_PANEL_WIDTH, gangItemsHeight, Color(70, 70, 70, 150))
    print("[RPMenu] Gang Items Panel - Pos: (" .. (QUADRANT_WIDTH + PADDING) .. ", " .. (TOP_OFFSET + UPGRADE_HEIGHT + PADDING) .. "), Size: (" .. RIGHT_PANEL_WIDTH .. ", " .. gangItemsHeight .. ")")

    -- Additional Buttons (below gang items)
    local buttonRowY = TOP_OFFSET + UPGRADE_HEIGHT + gangItemsHeight + 2 * PADDING
    local buttonSpacing = (RIGHT_PANEL_WIDTH - 3 * BUTTON_WIDTH) / 2
    CreateButton(gangsPanel, QUADRANT_WIDTH + PADDING, buttonRowY, BUTTON_WIDTH, BUTTON_HEIGHT, "Shared Cash", function()
        LocalPlayer():ChatPrint("Shared Cash functionality not implemented yet.")
    end)
    CreateButton(gangsPanel, QUADRANT_WIDTH + PADDING + BUTTON_WIDTH + buttonSpacing, buttonRowY, BUTTON_WIDTH, BUTTON_HEIGHT, "Damage Enter", function()
        LocalPlayer():ChatPrint("Damage Enter functionality not implemented yet.")
    end)
    CreateButton(gangsPanel, QUADRANT_WIDTH + PADDING + 2 * (BUTTON_WIDTH + buttonSpacing), buttonRowY, BUTTON_WIDTH, BUTTON_HEIGHT, "Lock", function()
        LocalPlayer():ChatPrint("Lock functionality not implemented yet.")
    end)

    -- UpdateGangUI method
    function gangsPanel:UpdateGangUI(data)
        if not IsValid(self) or not IsValid(nameLabel) or not IsValid(levelLabel) or not IsValid(capacityLabel) or
           not IsValid(bankLabel) or not IsValid(pointsLabel) or not IsValid(playerListView) or
           not IsValid(upgradeListPanel) then
            print("[RPMenu] UpdateGangUI: Invalid panels, storing as pending")
            PendingGangData = data
            return
        end

        print("[RPMenu] Updating gang UI for " .. data.gangName)
        print("[RPMenu] Gang Color - r: " .. tostring(data.gangColor.r) .. ", g: " .. tostring(data.gangColor.g) .. ", b: " .. tostring(data.gangColor.b))

        IsDataLoaded = true
        CurrentGangLevel = data.gangLevel
        CurrentGangXP = 0

        local gangColor = Color(255, 255, 0)
        if data.gangColor and type(data.gangColor.r) == "number" and type(data.gangColor.g) == "number" and type(data.gangColor.b) == "number" then
            gangColor = Color(data.gangColor.r, data.gangColor.g, data.gangColor.b)
        else
            print("[RPMenu] Invalid gang color, using fallback yellow")
        end
        nameLabel:SetText(data.gangName)
        nameLabel:SetTextColor(gangColor)

        levelLabel:SetText("Level: " .. data.gangLevel)
        levelLabel:SetTextColor(Color(255, 255, 255))
        capacityLabel:SetText("Gang Capacity: " .. #data.members)
        capacityLabel:SetTextColor(Color(255, 255, 255))
        bankLabel:SetText("Gang Bank: " .. (data.gangBank or 0))
        bankLabel:SetTextColor(Color(255, 255, 255))
        pointsLabel:SetText("Upgrade Points: " .. data.upgradePoints)
        pointsLabel:SetTextColor(Color(255, 255, 255))

        playerListView:Clear()
        for _, member in ipairs(data.members) do
            local playerName = "Unknown"
            for _, ply in ipairs(player.GetAll()) do
                if ply:SteamID() == member.steamid then
                    playerName = ply:Nick()
                    break
                end
            end
            local line = playerListView:AddLine(playerName .. " (" .. member.steamid .. ")", member.rank or "Recruit")
            for _, column in ipairs(line.Columns) do
                column:SetTextColor(Color(0, 0, 0))
            end
        end

        upgradeListPanel:Clear()
        local orderedUpgrades = {"Health", "Armor", "Damage", "Speed", "Luck", "Gang Items"}
        local iconPaths = {
            Health = "icon16/heart.png",
            Armor = "icon16/shield.png",
            Damage = "icon16/bomb.png",
            Speed = "icon16/lightning.png",
            Luck = "icon16/star.png",
            ["Gang Items"] = "icon16/box.png"
        }
        for _, upgrade in ipairs(orderedUpgrades) do
            local level = data.upgrades[upgrade] or 0
            local upgradePanel = vgui.Create("DPanel")
            local barWidth = 200
            upgradePanel:SetSize(barWidth, 20)
            upgradePanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 150))
                surface.SetDrawColor(255, 0, 0, 150)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                local progress = math.min(level / 10, 1)
                draw.RoundedBox(4, 2, 2, (w - 4) * progress, h - 4, Color(0, 255, 0, 200))
            end
            print("[RPMenu] Upgrade Bar (" .. upgrade .. ") - Width: " .. barWidth)

            local upgradeIcon = vgui.Create("DImageButton", upgradePanel)
            upgradeIcon:SetPos(2, 2)
            upgradeIcon:SetSize(16, 16)
            upgradeIcon:SetImage(iconPaths[upgrade])
            upgradeIcon.DoClick = function()
                if level >= 10 then
                    LocalPlayer():ChatPrint(upgrade .. " is already at max level!")
                    return
                end
                Derma_Query("Upgrade " .. upgrade .. " to level " .. (level + 1) .. " for 1 upgrade point?", "Upgrade Confirmation", "Yes", function()
                    net.Start("RPMenu_UpgradeGang")
                    net.WriteString(upgrade)
                    net.SendToServer()
                end, "No", function() end)
            end

            local upgradeLabel = vgui.Create("DLabel", upgradePanel)
            upgradeLabel:SetPos(20, 0)
            upgradeLabel:SetSize(barWidth - 20, 20)
            upgradeLabel:SetFont("RPMenuTextSmall")
            upgradeLabel:SetText(upgrade .. ": " .. level .. "/10")
            upgradeLabel:SetTextColor(Color(255, 255, 255))
            upgradeLabel:SetContentAlignment(5)

            upgradeListPanel:AddItem(upgradePanel)
        end

        if IsValid(gangItemsPanel) then
            gangsPanel:UpdateGangItemsUI(data)
        end
    end

    -- UpdateGangItemsUI method
    function gangsPanel:UpdateGangItemsUI(data)
        if not IsValid(gangItemsPanel) then
            print("[RPMenu] UpdateGangItemsUI: Gang items panel not valid")
            return
        end

        for _, child in pairs(gangItemsPanel:GetChildren()) do
            child:Remove()
        end

        local panelWidth = RIGHT_PANEL_WIDTH
        local titleLabel = vgui.Create("DLabel", gangItemsPanel)
        titleLabel:SetPos(PADDING, PADDING)
        titleLabel:SetSize(panelWidth - 2 * PADDING, 20)
        titleLabel:SetFont("RPMenuText")
        titleLabel:SetText("Gang Items (Entities)")
        titleLabel:SetTextColor(Color(255, 255, 255))

        local gangItemsLevel = data.upgrades["Gang Items"] or 0
        local entities = {
            {level = 1, name = "Ammo Crate", icon = "icon16/bullet_red.png"},
            {level = 3, name = "Health Station", icon = "icon16/heart_add.png"},
            {level = 5, name = "Armor Station", icon = "icon16/shield_add.png"},
            {level = 7, name = "Printer", icon = "icon16/money.png"},
            {level = 10, name = "Turret", icon = "icon16/gun.png"}
        }

        local yOffset = 40
        for i, entity in ipairs(entities) do
            if gangItemsLevel >= entity.level then
                local icon = vgui.Create("DImage", gangItemsPanel)
                icon:SetPos(PADDING, yOffset)
                icon:SetSize(16, 16)
                icon:SetImage(entity.icon)

                local label = vgui.Create("DLabel", gangItemsPanel)
                label:SetPos(PADDING + 25, yOffset - 2)
                label:SetSize(panelWidth - 2 * PADDING - 25, 20)
                label:SetFont("RPMenuTextSmall")
                label:SetText(entity.name .. " (Unlocked at Level " .. entity.level .. ")")
                label:SetTextColor(Color(255, 255, 255))
                label:SetWrap(true)

                yOffset = yOffset + 25
            end
        end

        if yOffset == 40 then
            local noItemsLabel = vgui.Create("DLabel", gangItemsPanel)
            noItemsLabel:SetPos(PADDING, 40)
            noItemsLabel:SetSize(panelWidth - 2 * PADDING, 40)
            noItemsLabel:SetFont("RPMenuTextSmall")
            noItemsLabel:SetText("No items unlocked. Upgrade 'Gang Items' to unlock entities.")
            noItemsLabel:SetTextColor(Color(255, 255, 255))
            noItemsLabel:SetWrap(true)
        end
    end

    -- Apply cached or pending data
    if PendingGangData and PendingGangData.gangName == LocalPlayer():GetNWString("GangName", "") then
        print("[RPMenu] Applying pending gang data")
        CachedGangData = PendingGangData
        PendingGangData = nil
        gangsPanel:UpdateGangUI(CachedGangData)
    elseif CachedGangData and CachedGangData.gangName == LocalPlayer():GetNWString("GangName", "") then
        print("[RPMenu] Using cached gang data")
        gangsPanel:UpdateGangUI(CachedGangData)
    end
end

-- Network Handlers
net.Receive("RPMenu_SendGangData", function()
    print("[RPMenu] Received RPMenu_SendGangData")
    local gangName = net.ReadString()
    local gangLevel = net.ReadUInt(8)
    local gangColor = util.JSONToTable(net.ReadString()) or {r = 255, g = 255, b = 255}
    local members = net.ReadTable()
    local upgrades = util.JSONToTable(net.ReadString()) or {}
    local upgradePoints = net.ReadUInt(8)
    local gangBank = net.ReadUInt(32)

    local localGangName = LocalPlayer():GetNWString("GangName", "")
    print("[RPMenu] Data - Name: " .. gangName .. ", Level: " .. gangLevel .. ", Members: " .. #members .. ", Points: " .. upgradePoints .. ", Bank: " .. gangBank)

    if gangName == localGangName then
        CachedGangData = {
            gangName = gangName,
            gangLevel = gangLevel,
            gangColor = gangColor,
            members = members,
            upgrades = upgrades,
            upgradePoints = upgradePoints,
            gangBank = gangBank
        }
        if IsValid(RPMenu) and IsValid(RPMMenuSheet) and IsValid(RPMMenuSheet:GetActiveTab()) and RPMMenuSheet:GetActiveTab():GetText() == "Gangs" then
            local gangsPanel = RPMMenuSheet:GetActiveTab():GetPanel()
            if IsValid(gangsPanel) then
                gangsPanel:UpdateGangUI(CachedGangData)
            else
                print("[RPMenu] Gangs panel not valid, storing as pending")
                PendingGangData = CachedGangData
            end
        else
            print("[RPMenu] Menu not open or not on Gangs tab, storing as pending")
            PendingGangData = CachedGangData
        end
    else
        print("[RPMenu] Gang name mismatch: Expected " .. localGangName .. ", Got " .. gangName)
        if IsValid(RPMenu) then
            RPMenu:Close()
        end
    end
end)

net.Receive("RPMenu_UpdateGangStatus", function()
    local gangName = net.ReadString()
    print("[RPMenu] Received RPMenu_UpdateGangStatus: " .. gangName)
    LocalPlayer():SetNWString("GangName", gangName)
    CachedGangData = nil
    PendingGangData = nil
    IsDataLoaded = false
    if IsValid(RPMenu) then
        RPMenu:Close()
    end
end)

-- Hooks and Commands
if DarkRP then
    if DarkRP.openF4Menu then
        print("[RPMenu] Overriding DarkRP.openF4Menu")
        local oldOpenF4Menu = DarkRP.openF4Menu
        DarkRP.openF4Menu = function(...)
            print("[RPMenu] DarkRP.openF4Menu called, redirecting to custom menu")
            CreateRPMenu()
            return true
        end
    else
        print("[RPMenu] DarkRP.openF4Menu not found, relying on hooks to block F4")
    end
end

hook.Add("ShowTeam", "CustomRPMenu", function()
    print("[RPMenu] ShowTeam hook triggered")
    CreateRPMenu()
    return true
end, -1000)

hook.Add("PlayerBindPress", "BlockDefaultF4Menu", function(ply, bind, pressed)
    if bind == "gm_showteam" and pressed then
        print("[RPMenu] F4 key pressed, opening custom menu")
        CreateRPMenu()
        return true
    end
end, -1000)

hook.Add("InitPostEntity", "DisableDarkRPF4Menu", function()
    print("[RPMenu] InitPostEntity hook triggered, attempting to disable DarkRP F4 menu")
    timer.Simple(1, function()
        if IsValid(RPMenu) then
            print("[RPMenu] Closing auto-opened menu")
            RPMenu:Remove()
        end
    end)
end)

concommand.Add("open_rpmenu", function()
    print("[RPMenu] Manual command triggered")
    CreateRPMenu()
end)

print("[RPMenu] Client-side loaded successfully")