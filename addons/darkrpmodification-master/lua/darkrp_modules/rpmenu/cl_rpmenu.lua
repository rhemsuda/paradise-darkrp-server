print("[RPMenu] cl_rpmenu.lua loaded successfully")

if not CLIENT then return end

-- Constants for layout
local FRAME_WIDTH, FRAME_HEIGHT = 1000, 700
local PADDING = 10
local QUADRANT_WIDTH = (FRAME_WIDTH - 3 * PADDING) / 2
local TOP_OFFSET = 40
local INFO_HEIGHT = 250
local UPGRADE_HEIGHT = 215 -- Adjusted for 6 upgrades: 6 * 30 + 5 * 5 spacing + 10 padding
local BUTTON_HEIGHT = 30
local BUTTON_WIDTH = 150

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
end
CreateFonts()

-- Global state
local RPMenu = nil
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
    label:SetSize(100, 20)
    label:SetFont("RPMenuText")
    label:SetText(labelText)
    label:SetTextColor(Color(255, 255, 255))

    local entry = vgui.Create("DTextEntry", parent)
    entry:SetPos(x + 110, y)
    entry:SetSize(w - 110, 20)
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

-- Create the main RPMenu
local function CreateRPMenu()
    if IsValid(RPMenu) then RPMenu:Remove() end

    print("[RPMenu] Creating custom F4 menu")

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
        print("[RPMenu] Menu closed, resetting IsDataLoaded")
    end

    local sheet = vgui.Create("DPropertySheet", RPMenu)
    sheet:Dock(FILL)
    sheet:DockMargin(PADDING, PADDING, PADDING, PADDING)
    sheet.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 50, 255))
    end

    -- Jobs Tab
    local jobsPanel = vgui.Create("DPanel", sheet)
    jobsPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
    end
    sheet:AddSheet("Jobs", jobsPanel, "icon16/user.png", false, false, "Select your job")

    local jobList = vgui.Create("DPanelList", jobsPanel)
    jobList:SetPos(0, 0)
    jobList:SetSize(QUADRANT_WIDTH, FRAME_HEIGHT - 2 * PADDING)
    jobList:SetSpacing(5)
    jobList:EnableVerticalScrollbar(true)
    jobList:SetPadding(5)

    local infoPanel = vgui.Create("DPanel", jobsPanel)
    infoPanel:SetPos(QUADRANT_WIDTH, 0)
    infoPanel:SetSize(QUADRANT_WIDTH, FRAME_HEIGHT - 2 * PADDING)
    infoPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
    end

    local infoBackground = CreateRoundedPanel(infoPanel, 0, 0, QUADRANT_WIDTH - PADDING, 200, Color(70, 70, 70, 150))

    local infoLabel = vgui.Create("DLabel", infoBackground)
    infoLabel:SetPos(PADDING, PADDING)
    infoLabel:SetSize(QUADRANT_WIDTH - 3 * PADDING, 180)
    infoLabel:SetFont("RPMenuText")
    infoLabel:SetText("Select a job for details")
    infoLabel:SetTextColor(Color(255, 255, 255))
    infoLabel:SetWrap(true)

    local selectedJob = nil
    local becomeButton = CreateButton(infoPanel, 0, 210, QUADRANT_WIDTH - PADDING, BUTTON_HEIGHT, "Become [job]", function()
        if selectedJob then
            net.Start("RPMenu_JobChange")
            net.WriteUInt(selectedJob.team, 16)
            net.SendToServer()
            RPMenu:Close()
        end
    end)

    local fixedJobs = {"Forager", "Miner", "Citizen", "Drug Dealer", "Police", "Banker", "Gun Dealer", "Medic", "Cook"}
    local currentJob = LocalPlayer():Team()

    for _, jobName in ipairs(fixedJobs) do
        local job = nil
        for _, j in pairs(RPExtraTeams) do
            if j.name == jobName then job = j break end
        end
        if job and job.team == currentJob then continue end

        local jobButton = vgui.Create("DButton")
        jobButton:SetText(jobName)
        jobButton:SetFont("RPMenuText")
        jobButton:SetSize(QUADRANT_WIDTH - PADDING, 40)
        jobButton.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 255))
        end

        local icon = vgui.Create("DModelPanel", jobButton)
        icon:SetSize(32, 32)
        icon:SetPos(5, 4)
        local modelPath = "models/error.mdl"
        if job then
            if jobName == "Miner" then modelPath = "models/props_mining/pickaxe01.mdl"
            elseif jobName == "Forager" then modelPath = "models/weapons/w_crowbar.mdl"
            elseif jobName == "Banker" then modelPath = "models/props_lab/monitor01a.mdl"
            elseif jobName == "Police" then modelPath = "models/weapons/w_stunbaton.mdl"
            elseif jobName == "Drug Dealer" then modelPath = "models/props/de_inferno/potted_plant2.mdl"
            elseif jobName == "Medic" then modelPath = "models/Items/HealthKit.mdl"
            elseif jobName == "Citizen" then
                if type(job.model) == "table" and #job.model > 0 then modelPath = job.model[1]
                elseif type(job.model) == "string" then modelPath = job.model end
            elseif jobName == "Gun Dealer" then modelPath = "models/weapons/w_pist_deagle.mdl"
            elseif jobName == "Cook" then modelPath = "models/props_interiors/pot02a.mdl"
            end
        end
        pcall(function() icon:SetModel(modelPath) end)
        icon:SetCamPos(Vector(30, 0, 5))
        icon:SetLookAt(Vector(0, 0, 5))
        icon:SetFOV(45)

        jobButton.DoClick = function()
            selectedJob = job
            if job then
                local desc = job.description or "No description available."
                infoLabel:SetText("Job: " .. jobName .. "\nModel: " .. modelPath .. "\nDescription: " .. desc)
            else
                infoLabel:SetText("Job not found: " .. jobName)
            end
            becomeButton:SetText("Become " .. jobName)
        end

        jobList:AddItem(jobButton)
    end

    -- Gangs Tab
    local gangsPanel = vgui.Create("DPanel", sheet)
    gangsPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
    end
    sheet:AddSheet("Gangs", gangsPanel, "icon16/group.png", false, false, "Manage your gang")
    gangsPanel:SetPaintBackground(false)
    gangsPanel:DockPadding(PADDING, PADDING, PADDING, PADDING)

    sheet.OnActiveTabChanged = function(self, oldTab, newTab)
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

            local creationPanel = CreateRoundedPanel(gangsPanel, (panelWidth - 400) / 2, (panelHeight - 400) / 2, 400, 400, Color(70, 70, 70, 150))

            local nameEntry = CreateLabeledEntry(creationPanel, "Gang Name:", PADDING, PADDING, 400 - 2 * PADDING, "Enter gang name")
            local colorLabel = vgui.Create("DLabel", creationPanel)
            colorLabel:SetPos(PADDING, 40)
            colorLabel:SetSize(100, 20)
            colorLabel:SetFont("RPMenuText")
            colorLabel:SetText("Clan Color:")
            colorLabel:SetTextColor(Color(255, 255, 255))

            local colorMixer = vgui.Create("DColorMixer", creationPanel)
            colorMixer:SetPos(PADDING + 110, 40)
            colorMixer:SetSize(400 - 2 * PADDING - 110, 100)
            colorMixer:SetPalette(true)
            colorMixer:SetAlphaBar(false)
            colorMixer:SetWangs(true)
            colorMixer:SetColor(Color(255, 255, 255))

            local passwordEntry = CreateLabeledEntry(creationPanel, "Gang Password:", PADDING, 150, 400 - 2 * PADDING, "Enter gang password")
            local levelEntry = vgui.Create("DNumberWang", creationPanel)
            levelEntry:SetPos(PADDING + 110, 180)
            levelEntry:SetSize(400 - 2 * PADDING - 110, 20)
            levelEntry:SetMin(1)
            levelEntry:SetMax(20)
            levelEntry:SetValue(1)

            local levelLabel = vgui.Create("DLabel", creationPanel)
            levelLabel:SetPos(PADDING, 180)
            levelLabel:SetSize(100, 20)
            label:SetFont("RPMenuText")
            levelLabel:SetText("Initial Level:")
            levelLabel:SetTextColor(Color(255, 255, 255))

            local iconLabel = vgui.Create("DLabel", creationPanel)
            iconLabel:SetPos(PADDING, 210)
            iconLabel:SetSize(100, 20)
            iconLabel:SetFont("RPMenuText")
            iconLabel:SetText("Gang Icon:")
            iconLabel:SetTextColor(Color(255, 255, 255))

            local iconPlaceholder = CreateRoundedPanel(creationPanel, PADDING + 110, 210, 32, 32, Color(255, 255, 255, 50))

            CreateButton(creationPanel, PADDING, 250, 400 - 2 * PADDING, 40, "Create Gang", function()
                local gangName = nameEntry:GetValue()
                local gangColor = colorMixer:GetColor()
                local password = passwordEntry:GetValue()
                local level = levelEntry:GetValue()
                if gangName == "" or password == "" then
                    LocalPlayer():ChatPrint("Please fill in all fields!")
                    return
                end
                net.Start("RPMenu_CreateGang")
                net.WriteString(gangName)
                net.WriteColor(gangColor)
                net.WriteString(password)
                net.WriteUInt(level, 8)
                net.SendToServer()
            end)

            CreateButton(creationPanel, PADDING, 300, 400 - 2 * PADDING, 40, "Recover Gang", function()
                Derma_StringRequest("Recover Gang", "Enter the gang name", "", function(gangName)
                    Derma_StringRequest("Recover Gang", "Enter the gang password", "", function(password)
                        net.Start("RPMenu_RecoverGang")
                        net.WriteString(gangName)
                        net.WriteString(password)
                        net.SendToServer()
                    end, function() end, "Submit", "Cancel")
                end, function() end, "Next", "Cancel")
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
    namePrefixLabel:SetPos(PADDING, PADDING)
    namePrefixLabel:SetSize(60, 20)
    namePrefixLabel:SetFont("RPMenuTextSmall")
    namePrefixLabel:SetText("Name:")
    namePrefixLabel:SetTextColor(Color(255, 255, 255))

    local nameLabel = vgui.Create("DLabel", gangInfoPanel)
    nameLabel:SetPos(70, PADDING)
    nameLabel:SetSize(labelWidth - 70, 20)
    nameLabel:SetFont("RPMenuTextSmall")
    nameLabel:SetText("Loading...")
    nameLabel:SetTextColor(Color(255, 255, 255))

    local levelLabel = vgui.Create("DLabel", gangInfoPanel)
    levelLabel:SetPos(PADDING, 40)
    levelLabel:SetSize(labelWidth, 20)
    levelLabel:SetFont("RPMenuTextSmall")
    levelLabel:SetText("Level: Loading...")
    levelLabel:SetTextColor(Color(255, 255, 255))

    local capacityLabel = vgui.Create("DLabel", gangInfoPanel)
    capacityLabel:SetPos(PADDING, 60)
    capacityLabel:SetSize(labelWidth, 20)
    capacityLabel:SetFont("RPMenuTextSmall")
    capacityLabel:SetText("Gang Capacity: Loading...")
    capacityLabel:SetTextColor(Color(255, 255, 255))

    local bankLabel = vgui.Create("DLabel", gangInfoPanel)
    bankLabel:SetPos(PADDING, 80)
    bankLabel:SetSize(labelWidth, 20)
    bankLabel:SetFont("RPMenuTextSmall")
    bankLabel:SetText("Gang Bank: 0")
    bankLabel:SetTextColor(Color(255, 255, 255))

    local pointsLabel = vgui.Create("DLabel", gangInfoPanel)
    pointsLabel:SetPos(PADDING, 100)
    pointsLabel:SetSize(labelWidth, 20)
    pointsLabel:SetFont("RPMenuTextSmall")
    pointsLabel:SetText("Upgrade Points: Loading...")
    pointsLabel:SetTextColor(Color(255, 255, 255))

    -- Donate to Bank (bottom of gangInfoPanel, full width, black background)
    CreateButton(gangInfoPanel, PADDING, INFO_HEIGHT - 2 * BUTTON_HEIGHT - 2 * PADDING, QUADRANT_WIDTH - 3 * PADDING, BUTTON_HEIGHT, "Donate to Bank", function()
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
            end, "No", function() end)
        end, function() end, "Next", "Cancel")
    end, Color(0, 0, 0, 255))

    -- Leave Gang (below Donate to Bank, full width, black background)
    CreateButton(gangInfoPanel, PADDING, INFO_HEIGHT - BUTTON_HEIGHT - PADDING, QUADRANT_WIDTH - 3 * PADDING, BUTTON_HEIGHT, "Leave Gang", function()
        Derma_Query("Are you sure you want to leave your gang?", "Leave Gang Confirmation", "Yes", function()
            net.Start("RPMenu_LeaveGang")
            net.SendToServer()
        end, "No", function() end)
    end, Color(0, 0, 0, 255))

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
        local steamID = string.match(line:GetColumnText(1), "%((STEAM_[0-1]:[0-1]:%d+)%)")
        local playerRank = "Unknown"
        for _, member in ipairs(CachedGangData and CachedGangData.members or {}) do
            if member.steamid == LocalPlayer():SteamID() then
                playerRank = member.rank or "Recruit"
                break
            end
        end

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
            local canModify = playerRank == "Leader" or (targetRank ~= "Leader" and targetRank ~= "Vice Leader")

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
    upgradeListPanel:SetSize(QUADRANT_WIDTH - PADDING, UPGRADE_HEIGHT)
    upgradeListPanel:SetSpacing(5)
    upgradeListPanel:EnableVerticalScrollbar(false)
    upgradeListPanel:SetPadding(5)
    upgradeListPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
    end

    -- Gang Items (Entities) (bottom right)
    local gangItemsHeight = FRAME_HEIGHT - TOP_OFFSET - UPGRADE_HEIGHT - 4 * PADDING - BUTTON_HEIGHT - 10
    gangItemsPanel = CreateRoundedPanel(gangsPanel, QUADRANT_WIDTH + PADDING, TOP_OFFSET + UPGRADE_HEIGHT + PADDING, QUADRANT_WIDTH - PADDING, gangItemsHeight, Color(70, 70, 70, 150))

    -- Additional Buttons (below gang items)
    local buttonRowY = TOP_OFFSET + UPGRADE_HEIGHT + gangItemsHeight + 2 * PADDING
    local buttonSpacing = (QUADRANT_WIDTH - PADDING - 3 * BUTTON_WIDTH) / 2
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
        IsDataLoaded = true
        CurrentGangLevel = data.gangLevel
        CurrentGangXP = 0
        nameLabel:SetText(data.gangName)
        nameLabel:SetTextColor(Color(data.gangColor.r, data.gangColor.g, data.gangColor.b))
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
            local barWidth = QUADRANT_WIDTH - PADDING - 100 -- Reduced size to fit panel
            upgradePanel:SetSize(barWidth, 30)
            upgradePanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 150))
                surface.SetDrawColor(255, 0, 0, 150)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                local progress = math.min(level / 10, 1)
                draw.RoundedBox(4, 2, 2, (w - 4) * progress, h - 4, Color(0, 255, 0, 200))
            end

            local upgradeIcon = vgui.Create("DImageButton", upgradePanel)
            upgradeIcon:SetPos(5, 5)
            upgradeIcon:SetSize(20, 20)
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
            upgradeLabel:SetPos(0, 5)
            upgradeLabel:SetSize(barWidth, 20)
            upgradeLabel:SetFont("RPMenuTextSmall")
            upgradeLabel:SetText(upgrade .. ": " .. level .. "/10")
            upgradeLabel:SetTextColor(Color(255, 255, 255))
            upgradeLabel:SetContentAlignment(5)

            upgradeListPanel:AddItem(upgradePanel)
        end

        -- Update Gang Items UI
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

        local titleLabel = vgui.Create("DLabel", gangItemsPanel)
        titleLabel:SetPos(PADDING, PADDING)
        titleLabel:SetSize(gangItemsPanel:GetWide() - 2 * PADDING, 20)
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
                label:SetSize(gangItemsPanel:GetWide() - 2 * PADDING - 25, 20)
                label:SetFont("RPMenuTextSmall")
                label:SetText(entity.name .. " (Unlocked at Level " .. entity.level .. ")")
                label:SetTextColor(Color(255, 255, 255))

                yOffset = yOffset + 25
            end
        end

        if yOffset == 40 then
            local noItemsLabel = vgui.Create("DLabel", gangItemsPanel)
            noItemsLabel:SetPos(PADDING, 40)
            noItemsLabel:SetSize(gangItemsPanel:GetWide() - 2 * PADDING, 20)
            noItemsLabel:SetFont("RPMenuTextSmall")
            noItemsLabel:SetText("No items unlocked. Upgrade 'Gang Items' to unlock entities.")
            noItemsLabel:SetTextColor(Color(255, 255, 255))
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
        if IsValid(RPMenu) and IsValid(RPMenu:GetActiveTab()) and RPMenu:GetActiveTab():GetText() == "Gangs" then
            local gangsPanel = RPMenu:GetActiveTab():GetPanel()
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
            CreateRPMenu()
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
        CreateRPMenu()
    end
end)

-- Hooks and Commands
if DarkRP and DarkRP.openF4Menu then
    print("[RPMenu] Overriding DarkRP.openF4Menu")
    local oldOpenF4Menu = DarkRP.openF4Menu
    DarkRP.openF4Menu = function()
        if input.IsKeyDown(KEY_F4) then
            print("[RPMenu] DarkRP.openF4Menu called by F4, redirecting to custom menu")
            CreateRPMenu()
        end
    end
end

hook.Add("ShowTeam", "CustomRPMenu", function()
    print("[RPMenu] ShowTeam hook triggered")
    if input.IsKeyDown(KEY_F4) then
        CreateRPMenu()
    end
    return true
end, 1000)

hook.Add("PlayerBindPress", "BlockDefaultF4Menu", function(ply, bind, pressed)
    if bind == "gm_showteam" and pressed then
        print("[RPMenu] F4 key pressed, opening custom menu")
        CreateRPMenu()
        return true
    end
end, 1000)

hook.Add("InitPostEntity", "DisableDarkRPF4Menu", function()
    print("[RPMenu] InitPostEntity hook triggered, attempting to disable DarkRP F4 menu")
    if DarkRP and DarkRP.toggleF4Menu then
        DarkRP.toggleF4Menu(false)
        print("[RPMenu] DarkRP F4 menu disabled via toggleF4Menu")
    else
        print("[RPMenu] DarkRP.toggleF4Menu not found, relying on hooks")
    end
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

-- Server-side code
if not SERVER then return end

print("[RPMenu] sv_rpmenu.lua file found, attempting to load")

-- Networking messages
util.AddNetworkString("RPMenu_CreateGang")
util.AddNetworkString("RPMenu_JobChange")
util.AddNetworkString("RPMenu_RequestGangData")
util.AddNetworkString("RPMenu_SendGangData")
util.AddNetworkString("RPMenu_UpdateGangStatus")
util.AddNetworkString("RPMenu_UpgradeGang")
util.AddNetworkString("RPMenu_RecoverGang")
util.AddNetworkString("RPMenu_DonateToBank")
util.AddNetworkString("RPMenu_LeaveGang")
util.AddNetworkString("RPMenu_KickPlayer")
util.AddNetworkString("RPMenu_SetRank")

-- SQL table creation and migration for gangs
sql.Begin()
    local createGangsTable = sql.Query([[
        CREATE TABLE IF NOT EXISTS darkrp_gangs (
            gang_name TEXT PRIMARY KEY,
            gang_level INTEGER DEFAULT 1,
            gang_color TEXT,
            gang_password TEXT,
            gang_upgrades TEXT DEFAULT '{}',
            upgrade_points INTEGER DEFAULT 0,
            members TEXT DEFAULT '[]',
            gang_bank INTEGER DEFAULT 0
        )
    ]])
    if createGangsTable == false then
        print("[RPMenu] Failed to create darkrp_gangs table: " .. sql.LastError())
    else
        print("[RPMenu] Created or verified darkrp_gangs table")
    end

    local columns = sql.Query("PRAGMA table_info(darkrp_gangs)")
    local columnExists = {}
    if columns then
        for _, column in ipairs(columns) do
            columnExists[column.name] = true
        end
    end

    if not columnExists.gang_password then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN gang_password TEXT")
        print("[RPMenu] Added gang_password column")
    end

    if not columnExists.upgrade_points then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN upgrade_points INTEGER DEFAULT 0")
        print("[RPMenu] Added upgrade_points column")
    end

    if not columnExists.members then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN members TEXT DEFAULT '[]'")
        print("[RPMenu] Added members column")
    end

    if not columnExists.gang_bank then
        sql.Query("ALTER TABLE darkrp_gangs ADD COLUMN gang_bank INTEGER DEFAULT 0")
        print("[RPMenu] Added gang_bank column")
    end
sql.Commit()

-- Function to send gang data to a player
local function SendGangData(ply)
    if not IsValid(ply) then
        print("[RPMenu] SendGangData: Invalid player")
        return
    end

    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        print("[RPMenu] SendGangData: No gang for " .. ply:Nick())
        return
    end

    print("[RPMenu] SendGangData: Querying for gang " .. gangName .. " for " .. ply:Nick())
    local gangData = sql.QueryRow("SELECT * FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        print("[RPMenu] SendGangData: Gang " .. gangName .. " not found in database for " .. ply:Nick())
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    print("[RPMenu] SendGangData: Preparing data - Name: " .. gangName .. ", Level: " .. gangData.gang_level .. ", Members: " .. #members .. ", Points: " .. (gangData.upgrade_points or 0))

    net.Start("RPMenu_SendGangData")
    net.WriteString(gangName)
    net.WriteUInt(tonumber(gangData.gang_level), 8)
    net.WriteString(gangData.gang_color or util.TableToJSON({r = 255, g = 255, b = 255}))
    net.WriteTable(members)
    net.WriteString(gangData.gang_upgrades or "{}")
    net.WriteUInt(tonumber(gangData.upgrade_points or 0), 8)
    net.WriteUInt(tonumber(gangData.gang_bank or 0), 32)
    net.Send(ply)
    print("[RPMenu] SendGangData: Sent data to " .. ply:Nick())
end

-- Function to add XP to a gang
function AddGangXP(gangName, xp)
    local gangData = sql.QueryRow("SELECT gang_level, upgrade_points FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        print("[RPMenu] Gang " .. gangName .. " not found for XP addition")
        return
    end
    local level = tonumber(gangData.gang_level)
    local points = tonumber(gangData.upgrade_points)
    local totalXP = (level - 1) * 1000 + xp
    local newLevel = math.min(math.floor(totalXP / 1000) + 1, 20)
    if newLevel > level then
        points = points + (newLevel - level)
        local updateQuery = sql.Query("UPDATE darkrp_gangs SET gang_level = " .. newLevel .. ", upgrade_points = " .. points .. " WHERE gang_name = " .. sql.SQLStr(gangName))
        if updateQuery == false then
            print("[RPMenu] Failed to update gang level and points: " .. sql.LastError())
            return
        end
        print("[RPMenu] Gang " .. gangName .. " leveled up to " .. newLevel .. " with " .. points .. " upgrade points")
    end
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNWString("GangName", "") == gangName then
            SendGangData(ply)
        end
    end
end

concommand.Add("add_gang_xp", function(ply, cmd, args)
    if not args[1] or not args[2] then
        print("Usage: add_gang_xp <gangName> <xp>")
        return
    end
    AddGangXP(args[1], tonumber(args[2]))
end)

-- Server-side Network Handlers
net.Receive("RPMenu_CreateGang", function(len, ply)
    local gangName = net.ReadString()
    local gangColor = net.ReadColor()
    local password = net.ReadString()
    local level = net.ReadUInt(8)

    print("[RPMenu] CreateGang: Attempt by " .. ply:Nick() .. " for gang " .. gangName .. " at level " .. level)

    if level < 1 or level > 20 then
        ply:ChatPrint("Invalid level selected! Must be between 1 and 20.")
        print("[RPMenu] CreateGang: Invalid level " .. level)
        return
    end

    local currentGang = ply:GetNWString("GangName", "")
    if currentGang != "" then
        ply:ChatPrint("You are already in a gang! Leave your current gang before creating a new one.")
        print("[RPMenu] CreateGang: Player " .. ply:Nick() .. " already in gang " .. currentGang)
        net.Start("RPMenu_UpdateGangStatus")
        net.WriteString(currentGang)
        net.Send(ply)
        SendGangData(ply)
        return
    end

    local existingGang = sql.Query("SELECT gang_name FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if existingGang and #existingGang > 0 then
        ply:ChatPrint("A gang with this name already exists!")
        print("[RPMenu] CreateGang: Gang name " .. gangName .. " already exists")
        return
    end

    local members = {{steamid = ply:SteamID(), rank = "Leader"}}
    local membersJSON = util.TableToJSON(members)
    local colorJSON = util.TableToJSON({r = gangColor.r, g = gangColor.g, b = gangColor.b})
    local insertGang = sql.Query([[
        INSERT INTO darkrp_gangs (gang_name, gang_level, gang_color, gang_password, gang_upgrades, upgrade_points, members, gang_bank)
        VALUES (]] .. sql.SQLStr(gangName) .. [[, ]] .. level .. [[, ]] .. sql.SQLStr(colorJSON) .. [[, ]] .. sql.SQLStr(password) .. [[, '{}', ]] .. level .. [[, ]] .. sql.SQLStr(membersJSON) .. [[, 0)
    ]])
    if insertGang == false then
        local err = sql.LastError()
        ply:ChatPrint("Failed to create gang: " .. err)
        print("[RPMenu] CreateGang: Failed to create gang " .. gangName .. ": " .. err)
        return
    end

    ply:SetNWString("GangName", gangName)
    ply:ChatPrint("Gang '" .. gangName .. "' created successfully at level " .. level .. "!")
    print("[RPMenu] CreateGang: Gang " .. gangName .. " created successfully for " .. ply:Nick())

    net.Start("RPMenu_UpdateGangStatus")
    net.WriteString(gangName)
    net.Send(ply)

    SendGangData(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            SendGangData(ply)
            print("[RPMenu] CreateGang: Retry SendGangData for " .. ply:Nick())
        end
    end)
end)

net.Receive("RPMenu_RecoverGang", function(len, ply)
    local gangName = net.ReadString()
    local password = net.ReadString()

    print("[RPMenu] RecoverGang: Attempt by " .. ply:Nick() .. " for gang " .. gangName)

    local currentGang = ply:GetNWString("GangName", "")
    if currentGang != "" then
        ply:ChatPrint("You are already in a gang! Leave your current gang first.")
        print("[RPMenu] RecoverGang: Player " .. ply:Nick() .. " already in gang " .. currentGang)
        net.Start("RPMenu_UpdateGangStatus")
        net.WriteString(currentGang)
        net.Send(ply)
        SendGangData(ply)
        return
    end

    local gangData = sql.QueryRow("SELECT gang_password, members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang not found!")
        print("[RPMenu] RecoverGang: Gang " .. gangName .. " not found")
        return
    end
    if gangData.gang_password != password then
        ply:ChatPrint("Incorrect password!")
        print("[RPMenu] RecoverGang: Incorrect password for " .. gangName)
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    for _, member in ipairs(members) do
        if member.rank == "Leader" then
            ply:ChatPrint("Gang already has a leader!")
            print("[RPMenu] RecoverGang: Gang " .. gangName .. " already has a leader")
            return
        end
    end

    table.insert(members, {steamid = ply:SteamID(), rank = "Leader"})
    local membersJSON = util.TableToJSON(members)
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(membersJSON) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to recover gang: " .. sql.LastError())
        print("[RPMenu] RecoverGang: Failed to update members for " .. gangName .. ": " .. sql.LastError())
        return
    end

    ply:SetNWString("GangName", gangName)
    ply:ChatPrint("Successfully recovered gang '" .. gangName .. "' as Leader!")
    print("[RPMenu] RecoverGang: " .. ply:Nick() .. " recovered gang " .. gangName .. " as Leader")

    net.Start("RPMenu_UpdateGangStatus")
    net.WriteString(gangName)
    net.Send(ply)

    SendGangData(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            SendGangData(ply)
            print("[RPMenu] RecoverGang: Retry SendGangData for " .. ply:Nick())
        end
    end)
end)

net.Receive("RPMenu_JobChange", function(len, ply)
    local jobTeam = net.ReadUInt(16)
    local job = RPExtraTeams[jobTeam]
    if not job then
        ply:ChatPrint("Invalid job selected!")
        print("[RPMenu] JobChange: Invalid job team " .. jobTeam .. " for " .. ply:Nick())
        return
    end

    ply:changeTeam(jobTeam, true)
    ply:ChatPrint("You have become a " .. job.name .. "!")
    print("[RPMenu] JobChange: " .. ply:Nick() .. " became " .. job.name)
end)

net.Receive("RPMenu_UpgradeGang", function(len, ply)
    local upgrade = net.ReadString()
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        print("[RPMenu] UpgradeGang: " .. ply:Nick() .. " not in a gang")
        return
    end

    print("[RPMenu] UpgradeGang: Attempt by " .. ply:Nick() .. " for " .. upgrade .. " in gang " .. gangName)
    local gangData = sql.QueryRow("SELECT gang_upgrades, upgrade_points FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] UpgradeGang: Gang data not found for " .. gangName)
        return
    end

    local upgrades = util.JSONToTable(gangData.gang_upgrades) or {}
    local points = tonumber(gangData.upgrade_points)
    if points < 1 then
        ply:ChatPrint("Not enough upgrade points!")
        print("[RPMenu] UpgradeGang: Not enough points for " .. gangName)
        return
    end

    local level = upgrades[upgrade] or 0
    if level >= 10 then
        ply:ChatPrint(upgrade .. " is already at max level!")
        print("[RPMenu] UpgradeGang: " .. upgrade .. " already at max level for " .. gangName)
        return
    end

    upgrades[upgrade] = level + 1
    points = points - 1
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET gang_upgrades = " .. sql.SQLStr(util.TableToJSON(upgrades)) .. ", upgrade_points = " .. points .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to upgrade: " .. sql.LastError())
        print("[RPMenu] UpgradeGang: Failed to update upgrades for " .. gangName .. ": " .. sql.LastError())
        return
    end

    ply:ChatPrint("Upgraded " .. upgrade .. " to level " .. (level + 1))
    print("[RPMenu] UpgradeGang: " .. upgrade .. " upgraded to level " .. (level + 1) .. " for " .. gangName)
    SendGangData(ply)
end)

net.Receive("RPMenu_DonateToBank", function(len, ply)
    local amount = net.ReadUInt(32)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        print("[RPMenu] DonateToBank: " .. ply:Nick() .. " not in a gang")
        return
    end

    local playerMoney = ply:getDarkRPVar("money") or 0
    if amount > playerMoney then
        ply:ChatPrint("You don't have enough money!")
        print("[RPMenu] DonateToBank: " .. ply:Nick() .. " has insufficient funds (" .. amount .. " > " .. playerMoney .. ")")
        return
    end

    local gangData = sql.QueryRow("SELECT gang_bank FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] DonateToBank: Gang data not found for " .. gangName)
        return
    end

    local newBank = (tonumber(gangData.gang_bank) or 0) + amount
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET gang_bank = " .. newBank .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to donate: " .. sql.LastError())
        print("[RPMenu] DonateToBank: Failed to update bank for " .. gangName .. ": " .. sql.LastError())
        return
    end

    ply:addMoney(-amount)
    ply:ChatPrint("Donated " .. amount .. " to the gang bank!")
    print("[RPMenu] DonateToBank: " .. ply:Nick() .. " donated " .. amount .. " to " .. gangName)

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_LeaveGang", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        print("[RPMenu] LeaveGang: " .. ply:Nick() .. " not in a gang")
        return
    end

    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] LeaveGang: Gang data not found for " .. gangName)
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    local newMembers = {}
    for _, member in ipairs(members) do
        if member.steamid != ply:SteamID() then
            table.insert(newMembers, member)
        end
    end

    if #newMembers == 0 then
        sql.Query("DELETE FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
        print("[RPMenu] LeaveGang: Gang " .. gangName .. " deleted as it has no members")
    else
        local membersJSON = util.TableToJSON(newMembers)
        local updateQuery = sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(membersJSON) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
        if updateQuery == false then
            ply:ChatPrint("Failed to leave gang: " .. sql.LastError())
            print("[RPMenu] LeaveGang: Failed to update members for " .. gangName .. ": " .. sql.LastError())
            return
        end
    end

    ply:SetNWString("GangName", "")
    ply:ChatPrint("You have left the gang '" .. gangName .. "'!")
    print("[RPMenu] LeaveGang: " .. ply:Nick() .. " left gang " .. gangName)

    net.Start("RPMenu_UpdateGangStatus")
    net.WriteString("")
    net.Send(ply)

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_KickPlayer", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        print("[RPMenu] KickPlayer: " .. ply:Nick() .. " not in a gang")
        return
    end

    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] KickPlayer: Gang data not found for " .. gangName)
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    local playerRank = "Recruit"
    for _, member in ipairs(members) do
        if member.steamid == ply:SteamID() then
            playerRank = member.rank or "Recruit"
            break
        end
    end

    if playerRank ~= "Leader" then
        ply:ChatPrint("Only the gang leader can kick players!")
        print("[RPMenu] KickPlayer: " .. ply:Nick() .. " is not a leader")
        return
    end

    local steamID = net.ReadString()
    local targetPlayer = nil
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == steamID then
            targetPlayer = p
            break
        end
    end

    local newMembers = {}
    local targetFound = false
    for _, member in ipairs(members) do
        if member.steamid == steamID then
            targetFound = true
        else
            table.insert(newMembers, member)
        end
    end

    if not targetFound then
        ply:ChatPrint("Player not found in gang!")
        print("[RPMenu] KickPlayer: Player " .. steamID .. " not found in gang " .. gangName)
        return
    end

    local membersJSON = util.TableToJSON(newMembers)
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(membersJSON) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to kick player: " .. sql.LastError())
        print("[RPMenu] KickPlayer: Failed to update members for " .. gangName .. ": " .. sql.LastError())
        return
    end

    if IsValid(targetPlayer) then
        targetPlayer:SetNWString("GangName", "")
        targetPlayer:ChatPrint("You have been kicked from the gang '" .. gangName .. "'!")
        net.Start("RPMenu_UpdateGangStatus")
        net.WriteString("")
        net.Send(targetPlayer)
    end

    ply:ChatPrint("Player has been kicked from the gang!")
    print("[RPMenu] KickPlayer: " .. steamID .. " kicked from gang " .. gangName .. " by " .. ply:Nick())

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_SetRank", function(len, ply)
    local gangName = ply:GetNWString("GangName", "")
    if gangName == "" then
        ply:ChatPrint("You are not in a gang!")
        print("[RPMenu] SetRank: " .. ply:Nick() .. " not in a gang")
        return
    end

    local gangData = sql.QueryRow("SELECT members FROM darkrp_gangs WHERE gang_name = " .. sql.SQLStr(gangName))
    if not gangData then
        ply:ChatPrint("Gang data not found!")
        print("[RPMenu] SetRank: Gang data not found for " .. gangName)
        return
    end

    local members = util.JSONToTable(gangData.members or "[]") or {}
    local playerRank = "Recruit"
    for _, member in ipairs(members) do
        if member.steamid == ply:SteamID() then
            playerRank = member.rank or "Recruit"
            break
        end
    end

    if playerRank ~= "Leader" and playerRank ~= "Vice Leader" then
        ply:ChatPrint("Only leaders and vice leaders can set ranks!")
        print("[RPMenu] SetRank: " .. ply:Nick() .. " is not a leader or vice leader")
        return
    end

    local steamID = net.ReadString()
    local newRank = net.ReadString()
    if not (newRank == "Recruit" or newRank == "Vice Leader" or newRank == "Leader") then
        ply:ChatPrint("Invalid rank!")
        print("[RPMenu] SetRank: Invalid rank " .. newRank .. " by " .. ply:Nick())
        return
    end

    local targetRank = "Recruit"
    local targetFound = false
    for _, member in ipairs(members) do
        if member.steamid == steamID then
            targetRank = member.rank or "Recruit"
            targetFound = true
            break
        end
    end

    if not targetFound then
        ply:ChatPrint("Player not found in gang!")
        print("[RPMenu] SetRank: Player " .. steamID .. " not found in gang " .. gangName)
        return
    end

    if (targetRank == "Leader" or targetRank == "Vice Leader") and playerRank ~= "Leader" then
        ply:ChatPrint("Only leaders can modify the rank of leaders and vice leaders!")
        print("[RPMenu] SetRank: " .. ply:Nick() .. " cannot modify rank of " .. targetRank)
        return
    end

    if newRank == "Leader" and playerRank ~= "Leader" then
        ply:ChatPrint("Only leaders can set the Leader rank!")
        print("[RPMenu] SetRank: " .. ply:Nick() .. " cannot set Leader rank")
        return
    end

    -- If setting a new Leader, demote the current Leader to Vice Leader
    if newRank == "Leader" then
        for _, member in ipairs(members) do
            if member.steamid == ply:SteamID() and member.rank == "Leader" then
                member.rank = "Vice Leader"
                break
            end
        end
    end

    for _, member in ipairs(members) do
        if member.steamid == steamID then
            member.rank = newRank
            break
        end
    end

    local membersJSON = util.TableToJSON(members)
    local updateQuery = sql.Query("UPDATE darkrp_gangs SET members = " .. sql.SQLStr(membersJSON) .. " WHERE gang_name = " .. sql.SQLStr(gangName))
    if updateQuery == false then
        ply:ChatPrint("Failed to set rank: " .. sql.LastError())
        print("[RPMenu] SetRank: Failed to update members for " .. gangName .. ": " .. sql.LastError())
        return
    end

    ply:ChatPrint("Set rank of player to " .. newRank .. "!")
    print("[RPMenu] SetRank: " .. steamID .. " rank set to " .. newRank .. " in gang " .. gangName .. " by " .. ply:Nick())

    for _, p in ipairs(player.GetAll()) do
        if p:GetNWString("GangName", "") == gangName then
            SendGangData(p)
        end
    end
end)

net.Receive("RPMenu_RequestGangData", function(len, ply)
    print("[RPMenu] RequestGangData: Requested by " .. ply:Nick())
    SendGangData(ply)
end)

hook.Add("PlayerInitialSpawn", "RPMenu_SendGangDataOnJoin", function(ply)
    print("[RPMenu] PlayerInitialSpawn: Checking gang for " .. ply:Nick())
    local gangs = sql.Query("SELECT gang_name, members FROM darkrp_gangs")
    local gangName = ""
    if gangs then
        for _, gang in ipairs(gangs) do
            local members = util.JSONToTable(gang.members or "[]") or {}
            for _, member in ipairs(members) do
                if member.steamid == ply:SteamID() then
                    gangName = gang.gang_name
                    break
                end
            end
            if gangName != "" then break end
        end
    end
    ply:SetNWString("GangName", gangName)
    print("[RPMenu] PlayerInitialSpawn: Set GangName to " .. gangName .. " for " .. ply:Nick())

    timer.Simple(1, function()
        if not IsValid(ply) then return end
        SendGangData(ply)
    end)
end)

print("[RPMenu] Server-side loaded successfully")