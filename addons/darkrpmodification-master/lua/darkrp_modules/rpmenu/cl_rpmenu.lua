print("[RPMenu] cl_rpmenu.lua loaded successfully")

if not CLIENT then return end

-- Define fonts
surface.CreateFont("RPMenuTitle", {
    font = "Orbitron",
    size = 40,
    weight = 700,
    antialias = true,
    shadow = true
})
surface.CreateFont("RPMenuText", {
    font = "Montserrat",
    size = 20,
    weight = 500,
    antialias = true,
    shadow = true
})
surface.CreateFont("TopGang1", {
    font = "Coolvetica",
    size = 20,
    weight = 500,
    antialias = true,
    shadow = true
})
surface.CreateFont("TopGang2", {
    font = "Impact",
    size = 20,
    weight = 500,
    antialias = true,
    shadow = true
})
surface.CreateFont("TopGang3", {
    font = "Bebas Neue",
    size = 20,
    weight = 500,
    antialias = true,
    shadow = true
})
surface.CreateFont("TopGang4", {
    font = "Futura",
    size = 20,
    weight = 500,
    antialias = true,
    shadow = true
})
surface.CreateFont("TopGang5", {
    font = "Montserrat",
    size = 20,
    weight = 700,
    antialias = true,
    shadow = true
})

-- Global state
local RPMenu = nil
local CurrentGangLevel = 1
local CurrentGangXP = 0
local IsDataLoaded = false
local CachedGangData = nil
local PendingGangData = nil -- Store data if panels aren't ready

local function CreateRPMenu()
    if IsValid(RPMenu) then RPMenu:Remove() end

    print("[RPMenu] Creating custom F4 menu")

    RPMenu = vgui.Create("DFrame")
    local width, height = 800, 600
    RPMenu:SetSize(width, height)
    RPMenu:SetPos((ScrW() - width) / 2, (ScrH() - height) / 2)
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
    jobList:SetSize(400, height)
    jobList:SetSpacing(5)
    jobList:EnableVerticalScrollbar(true)
    jobList:SetPadding(5)

    local infoPanel = vgui.Create("DPanel", jobsPanel)
    infoPanel:SetPos(400, 0)
    infoPanel:SetSize(400, height)
    infoPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
    end

    local infoBackground = vgui.Create("DPanel", infoPanel)
    infoBackground:SetPos(10, 10)
    infoBackground:SetSize(380, 200)
    infoBackground.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
    end

    local infoLabel = vgui.Create("DLabel", infoBackground)
    infoLabel:SetPos(10, 10)
    infoLabel:SetSize(360, 180)
    infoLabel:SetFont("RPMenuText")
    infoLabel:SetText("Select a job for details")
    infoLabel:SetTextColor(Color(255, 255, 255))
    infoLabel:SetWrap(true)

    local becomeButton = vgui.Create("DButton", infoPanel)
    becomeButton:SetPos(10, 220)
    becomeButton:SetSize(380, 40)
    becomeButton:SetText("Become [job]")
    becomeButton:SetFont("RPMenuText")
    becomeButton:SetTextColor(Color(255, 255, 255))
    becomeButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 255))
    end
    becomeButton.DoClick = function()
        if selectedJob then
            net.Start("RPMenu_JobChange")
            net.WriteUInt(selectedJob.team, 16)
            net.SendToServer()
            RPMenu:Close()
        end
    end

    local selectedJob = nil
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
        jobButton:SetSize(380, 40)
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
    gangsPanel:DockPadding(10, 10, 10, 10)

    sheet.OnActiveTabChanged = function(self, oldTab, newTab)
        if newTab:GetText() == "Gangs" and not IsDataLoaded and not CachedGangData then
            print("[RPMenu] Gangs tab selected, requesting gang data")
            net.Start("RPMenu_RequestGangData")
            net.SendToServer()
        end
        -- Apply pending data when switching to Gangs tab
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
        local creationPanel = vgui.Create("DPanel", gangsPanel)
        creationPanel:SetSize(400, 400)
        creationPanel:SetPos(width / 2 - 200, height / 2 - 200)
        creationPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
        end

        local nameLabel = vgui.Create("DLabel", creationPanel)
        nameLabel:SetPos(10, 10)
        nameLabel:SetSize(100, 20)
        nameLabel:SetFont("RPMenuText")
        nameLabel:SetText("Gang Name:")
        nameLabel:SetTextColor(Color(255, 255, 255))

        local nameEntry = vgui.Create("DTextEntry", creationPanel)
        nameEntry:SetPos(120, 10)
        nameEntry:SetSize(270, 20)
        nameEntry:SetPlaceholderText("Enter gang name")

        local colorLabel = vgui.Create("DLabel", creationPanel)
        colorLabel:SetPos(10, 40)
        colorLabel:SetSize(100, 20)
        colorLabel:SetFont("RPMenuText")
        colorLabel:SetText("Clan Color:")
        colorLabel:SetTextColor(Color(255, 255, 255))

        local colorMixer = vgui.Create("DColorMixer", creationPanel)
        colorMixer:SetPos(120, 40)
        colorMixer:SetSize(270, 100)
        colorMixer:SetPalette(true)
        colorMixer:SetAlphaBar(false)
        colorMixer:SetWangs(true)
        colorMixer:SetColor(Color(255, 255, 255))

        local passwordLabel = vgui.Create("DLabel", creationPanel)
        passwordLabel:SetPos(10, 150)
        passwordLabel:SetSize(100, 20)
        passwordLabel:SetFont("RPMenuText")
        passwordLabel:SetText("Gang Password:")
        passwordLabel:SetTextColor(Color(255, 255, 255))

        local passwordEntry = vgui.Create("DTextEntry", creationPanel)
        passwordEntry:SetPos(120, 150)
        passwordEntry:SetSize(270, 20)
        passwordEntry:SetPlaceholderText("Enter gang password")

        local levelLabel = vgui.Create("DLabel", creationPanel)
        levelLabel:SetPos(10, 180)
        levelLabel:SetSize(100, 20)
        levelLabel:SetFont("RPMenuText")
        levelLabel:SetText("Initial Level:")
        levelLabel:SetTextColor(Color(255, 255, 255))

        local levelEntry = vgui.Create("DNumberWang", creationPanel)
        levelEntry:SetPos(120, 180)
        levelEntry:SetSize(270, 20)
        levelEntry:SetMin(1)
        levelEntry:SetMax(20)
        levelEntry:SetValue(1)

        local iconLabel = vgui.Create("DLabel", creationPanel)
        iconLabel:SetPos(10, 210)
        iconLabel:SetSize(100, 20)
        iconLabel:SetFont("RPMenuText")
        iconLabel:SetText("Gang Icon:")
        iconLabel:SetTextColor(Color(255, 255, 255))

        local iconPlaceholder = vgui.Create("DPanel", creationPanel)
        iconPlaceholder:SetPos(120, 210)
        iconPlaceholder:SetSize(32, 32)
        iconPlaceholder.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 50))
        end

        local createButton = vgui.Create("DButton", creationPanel)
        createButton:SetPos(10, 250)
        createButton:SetSize(380, 40)
        createButton:SetText("Create Gang")
        createButton:SetFont("RPMenuText")
        createButton:SetTextColor(Color(255, 255, 255))
        createButton.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(0, 255, 0, 100))
        end
        createButton.DoClick = function()
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
        end

        local recoverButton = vgui.Create("DButton", creationPanel)
        recoverButton:SetPos(10, 300)
        recoverButton:SetSize(380, 40)
        recoverButton:SetText("Recover Gang")
        recoverButton:SetFont("RPMenuText")
        recoverButton:SetTextColor(Color(255, 255, 255))
        recoverButton.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(255, 165, 0, 100))
        end
        recoverButton.DoClick = function()
            Derma_StringRequest(
                "Recover Gang",
                "Enter the gang name",
                "",
                function(gangName)
                    Derma_StringRequest(
                        "Recover Gang",
                        "Enter the gang password",
                        "",
                        function(password)
                            net.Start("RPMenu_RecoverGang")
                            net.WriteString(gangName)
                            net.WriteString(password)
                            net.SendToServer()
                        end,
                        function() end,
                        "Submit",
                        "Cancel"
                    )
                end,
                function() end,
                "Next",
                "Cancel"
            )
        end
        return
    end

    -- XP Bar
    local xpBar = vgui.Create("DPanel", gangsPanel)
    xpBar:SetPos(10, 10)
    xpBar:SetSize(width - 40, 30)
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
    local quadrantWidth = width / 2
    local topOffset = 40
    local infoHeight = 200
    local upgradeHeight = 185 -- 5 upgrades * 30 + 4 * 5 spacing + 10 padding
    local topGangsHeight = height - topOffset - upgradeHeight - 30

    local gangInfoPanel = vgui.Create("DPanel", gangsPanel)
    gangInfoPanel:SetPos(10, topOffset + 10)
    gangInfoPanel:SetSize(quadrantWidth - 20, infoHeight)
    gangInfoPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
        if not IsDataLoaded and not CachedGangData then
            draw.SimpleText("Fetching data...", "RPMenuText", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local namePrefixLabel = vgui.Create("DLabel", gangInfoPanel)
    namePrefixLabel:SetPos(10, 10)
    namePrefixLabel:SetSize(60, 20)
    namePrefixLabel:SetFont("RPMenuText")
    namePrefixLabel:SetText("Name:")
    namePrefixLabel:SetTextColor(Color(255, 255, 255))

    local nameLabel = vgui.Create("DLabel", gangInfoPanel)
    nameLabel:SetPos(70, 10)
    nameLabel:SetSize(quadrantWidth - 100, 20)
    nameLabel:SetFont("RPMenuText")
    nameLabel:SetText("Loading...")
    nameLabel:SetTextColor(Color(255, 255, 255))

    local levelLabel = vgui.Create("DLabel", gangInfoPanel)
    levelLabel:SetPos(10, 40)
    levelLabel:SetSize(quadrantWidth - 40, 20)
    levelLabel:SetFont("RPMenuText")
    levelLabel:SetText("Level: Loading...")
    levelLabel:SetTextColor(Color(255, 255, 255))

    local capacityLabel = vgui.Create("DLabel", gangInfoPanel)
    capacityLabel:SetPos(10, 70)
    capacityLabel:SetSize(quadrantWidth - 40, 20)
    capacityLabel:SetFont("RPMenuText")
    capacityLabel:SetText("Gang Capacity: Loading...")
    capacityLabel:SetTextColor(Color(255, 255, 255))

    local bankLabel = vgui.Create("DLabel", gangInfoPanel)
    bankLabel:SetPos(10, 100)
    bankLabel:SetSize(quadrantWidth - 40, 20)
    bankLabel:SetFont("RPMenuText")
    bankLabel:SetText("Gang Bank: 0")
    bankLabel:SetTextColor(Color(255, 255, 255))

    local pointsLabel = vgui.Create("DLabel", gangInfoPanel)
    pointsLabel:SetPos(10, 130)
    pointsLabel:SetSize(quadrantWidth - 40, 20)
    pointsLabel:SetFont("RPMenuText")
    pointsLabel:SetText("Upgrade Points: Loading...")
    pointsLabel:SetTextColor(Color(255, 255, 255))

    -- Player List (bottom left)
    local playerListView = vgui.Create("DListView", gangsPanel)
    playerListView:SetPos(10, topOffset + 10 + infoHeight + 10)
    playerListView:SetSize(quadrantWidth - 20, height - topOffset - infoHeight - 30)
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

    -- Upgrade List (top right)
    local upgradeListPanel = vgui.Create("DPanelList", gangsPanel)
    upgradeListPanel:SetPos(quadrantWidth + 10, topOffset + 10)
    upgradeListPanel:SetSize(quadrantWidth - 20, upgradeHeight)
    upgradeListPanel:SetSpacing(5)
    upgradeListPanel:EnableVerticalScrollbar(false)
    upgradeListPanel:SetPadding(5)
    upgradeListPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
    end

    -- Top Gangs List (bottom right)
    local topGangsPanel = vgui.Create("DPanel", gangsPanel)
    topGangsPanel:SetPos(quadrantWidth + 10, topOffset + 10 + upgradeHeight + 10)
    topGangsPanel:SetSize(quadrantWidth - 20, topGangsHeight)
    topGangsPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
    end

    -- UpdateGangUI as a method of gangsPanel
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
        bankLabel:SetText("Gang Bank: 0")
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
        local orderedUpgrades = {"Health", "Armor", "Damage", "Speed", "Luck"}
        local iconPaths = {
            Health = "icon16/heart.png",
            Armor = "icon16/shield.png",
            Damage = "icon16/bomb.png",
            Speed = "icon16/lightning.png",
            Luck = "icon16/star.png"
        }
        for _, upgrade in ipairs(orderedUpgrades) do
            local level = data.upgrades[upgrade] or 0
            local upgradePanel = vgui.Create("DPanel")
            upgradePanel:SetSize(quadrantWidth - 48, 30)
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
                Derma_Query(
                    "Upgrade " .. upgrade .. " to level " .. (level + 1) .. " for 1 upgrade point?",
                    "Upgrade Confirmation",
                    "Yes",
                    function()
                        net.Start("RPMenu_UpgradeGang")
                        net.WriteString(upgrade)
                        net.SendToServer()
                    end,
                    "No",
                    function() end
                )
            end

            local upgradeLabel = vgui.Create("DLabel", upgradePanel)
            upgradeLabel:SetPos(30, 5)
            upgradeLabel:SetSize(150, 20)
            upgradeLabel:SetFont("RPMenuText")
            upgradeLabel:SetText(upgrade .. ": " .. level .. "/10")
            upgradeLabel:SetTextColor(Color(255, 255, 255))

            upgradeListPanel:AddItem(upgradePanel)
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

-- Network handlers
net.Receive("RPMenu_SendGangData", function()
    print("[RPMenu] Received RPMenu_SendGangData")
    local gangName = net.ReadString()
    local gangLevel = net.ReadUInt(8)
    local gangColor = util.JSONToTable(net.ReadString()) or {r = 255, g = 255, b = 255}
    local members = net.ReadTable()
    local upgrades = util.JSONToTable(net.ReadString()) or {}
    local upgradePoints = net.ReadUInt(8)

    local localGangName = LocalPlayer():GetNWString("GangName", "")
    print("[RPMenu] Data - Name: " .. gangName .. ", Level: " .. gangLevel .. ", Members: " .. #members .. ", Points: " .. upgradePoints)

    if gangName == localGangName then
        CachedGangData = {
            gangName = gangName,
            gangLevel = gangLevel,
            gangColor = gangColor,
            members = members,
            upgrades = upgrades,
            upgradePoints = upgradePoints
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

net.Receive("RPMenu_SendTopGangs", function()
    print("[RPMenu] Received RPMenu_SendTopGangs")
    local topGangs = net.ReadTable()
    if not IsValid(topGangsPanel) then
        print("[RPMenu] TopGangsPanel not valid")
        return
    end
    topGangsPanel:Clear()

    local titleLabel = vgui.Create("DLabel", topGangsPanel)
    titleLabel:SetPos(10, 10)
    titleLabel:SetSize(quadrantWidth - 40, 20)
    titleLabel:SetFont("RPMenuText")
    titleLabel:SetText("Top 5 Gangs")
    titleLabel:SetTextColor(Color(255, 255, 255))

    local fonts = {"TopGang1", "TopGang2", "TopGang3", "TopGang4", "TopGang5"}
    for i, gang in ipairs(topGangs) do
        if i > 5 then break end
        local gangLabel = vgui.Create("DLabel", topGangsPanel)
        gangLabel:SetPos(10, 40 + (i - 1) * 30)
        gangLabel:SetSize(quadrantWidth - 40, 20)
        gangLabel:SetFont(fonts[i])
        gangLabel:SetText(i .. ". " .. gang.gang_name .. " (Level " .. gang.gang_level .. ")")
        gangLabel:SetTextColor(Color(255, 255, 255))
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

-- Override DarkRP's F4 menu
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