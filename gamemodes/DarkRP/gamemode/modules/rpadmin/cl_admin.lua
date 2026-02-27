if not CLIENT then return end

-- Helper function to print debug messages conditionally (set rp_debug 1 to see)
local function DebugPrint(...)
    local cv = GetConVar("rp_debug")
    if cv and cv:GetInt() == 1 then print(...) end
end

-- Function to build the admin panel (used by sh_inventory.lua)
function BuildAdminPanel(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end

    -- Full list of panel options
    local allOptions = {"Players", "Gangs", "Logs"}
    local currentOption = "Players" -- Default panel

    -- Create a dropdown for admin options
    local dropdown = vgui.Create("DComboBox", parent)
    dropdown:SetPos(10, 10)
    dropdown:SetSize(200, 30)
    dropdown:SetValue(currentOption)

    -- Function to update dropdown options based on the current selection
    local function UpdateDropdownOptions(selectedOption)
        dropdown:Clear()
        for _, option in ipairs(allOptions) do
            if option != selectedOption then
                dropdown:AddChoice(option)
            end
        end
        dropdown:SetValue(selectedOption)
    end

    -- Initial dropdown setup (exclude "Players")
    UpdateDropdownOptions(currentOption)

    -- Create panels for each option (hidden by default)
    local panels = {}

    -- Players Panel
    panels["Players"] = vgui.Create("DPanel", parent)
    panels["Players"]:SetPos(10, 50)
    panels["Players"]:SetSize(960, 560)
    panels["Players"].Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end

    -- Split into two sub-panels: left (player list) and right (options)
    local playerListPanel = vgui.Create("DPanel", panels["Players"])
    playerListPanel:SetPos(10, 40)
    playerListPanel:SetSize(470, 520)
    playerListPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
    end

    local playerOptionsPanel = vgui.Create("DPanel", panels["Players"])
    playerOptionsPanel:SetPos(490, 40)
    playerOptionsPanel:SetSize(470, 520)
    playerOptionsPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
    end

    -- Player List (DListView) on the left
    local playerList = vgui.Create("DListView", playerListPanel)
    playerList:SetPos(5, 5)
    playerList:SetSize(460, 500)
    playerList:SetMultiSelect(false)
    playerList:AddColumn("Name")
    playerList:AddColumn("SteamID")
    playerList:SetHeaderHeight(20)
    playerList.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 150))
    end
    playerList.VBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 150))
    end
    playerList.VBar.btnUp.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 150))
    end
    playerList.VBar.btnDown.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 150))
    end
    playerList.VBar.btnGrip.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(200, 200, 200, 150))
    end

    -- Populate the player list
    for _, ply in ipairs(player.GetAll()) do
        playerList:AddLine(ply:Nick(), ply:SteamID())
    end

    -- Right panel: Split into info (top) and tools (bottom)
    local playerInfoPanel = vgui.Create("DPanel", playerOptionsPanel)
    playerInfoPanel:SetPos(5, 5)
    playerInfoPanel:SetSize(460, 70) -- Reduced height for 2 rows
    playerInfoPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60, 200))
    end

    local playerToolsPanel = vgui.Create("DPanel", playerOptionsPanel)
    playerToolsPanel:SetPos(5, 80) -- 70 (info panel height) + 5 (padding)
    playerToolsPanel:SetSize(460, 435) -- Adjusted height (520 - 70 - 10 - 5)
    playerToolsPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60, 200))
    end

    -- Player info buttons (copyable, in a grid layout)
    local infoButtons = {}
    local infoFields = {
        {label = "Name: N/A", value = "N/A"},
        {label = "SteamID: N/A", value = "N/A"},
        {label = "Rank: N/A", value = "N/A"},
        {label = "Gang: N/A", value = "N/A"}
    }
    for i, field in ipairs(infoFields) do
        local row = math.floor((i - 1) / 2) -- 0, 0, 1, 1
        local col = (i - 1) % 2 -- 0, 1, 0, 1
        local xPos = 10 + col * 235
        local yPos = 10 + row * 25 -- 10, 35

        local button = vgui.Create("DButton", playerInfoPanel)
        button:SetPos(xPos, yPos)
        button:SetSize(220, 20)
        button:SetText(field.label)
        button:SetTextColor(Color(255, 255, 255))
        button.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
        end
        button.DoClick = function()
            SetClipboardText(field.value)
            LocalPlayer():ChatPrint(field.label .. " copied to clipboard!")
        end
        infoButtons[i] = {button = button, field = field}
    end

    -- Function to update player info
    local function UpdatePlayerInfo(steamID)
        local ply = nil
        for _, p in ipairs(player.GetAll()) do
            if p:SteamID() == steamID then
                ply = p
                break
            end
        end
        if not IsValid(ply) then
            for i, btn in ipairs(infoButtons) do
                btn.button:SetText(infoFields[i].label)
                btn.field.value = "N/A"
            end
            return
        end

        -- Update Name
        infoButtons[1].button:SetText("Name: " .. ply:Nick())
        infoButtons[1].field.value = ply:Nick()

        -- Update SteamID
        infoButtons[2].button:SetText("SteamID: " .. ply:SteamID())
        infoButtons[2].field.value = ply:SteamID()

        -- Update Rank (check admin, superadmin, ULX donator ranks)
        local rank = "user"
        if ply:IsSuperAdmin() then
            rank = "superadmin"
        elseif ply:IsAdmin() then
            rank = "admin"
        else
            local userGroup = ply:GetUserGroup() or "user"
            if userGroup == "donator" or userGroup == "vip" then
                rank = userGroup
            end
        end
        infoButtons[3].button:SetText("Rank: " .. rank)
        infoButtons[3].field.value = rank

        -- Update Gang (from darkrp_gangs)
        local gang = ply:GetNWString("GangName", "None")
        infoButtons[4].button:SetText("Gang: " .. gang)
        infoButtons[4].field.value = gang
    end

    -- Right-click menu for the player list
    playerList.OnRowRightClick = function(self, lineID, line)
        local playerName = line:GetColumnText(1)
        local steamID = line:GetColumnText(2)
        local menu = DermaMenu()

        menu:AddOption("Info", function()
            self:SelectItem(line) -- Select the row to trigger OnRowSelected
        end):SetIcon("icon16/information.png")

        menu:AddOption("Kick", function()
            -- Placeholder for kick functionality
            LocalPlayer():ChatPrint("Kick functionality not implemented yet for " .. playerName)
        end):SetIcon("icon16/door_out.png")

        menu:AddOption("Ban", function()
            -- Placeholder for ban functionality
            LocalPlayer():ChatPrint("Ban functionality not implemented yet for " .. playerName)
        end):SetIcon("icon16/cancel.png")

        menu:AddOption("Spectate", function()
            -- Placeholder for spectate functionality
            LocalPlayer():ChatPrint("Spectate functionality not implemented yet for " .. playerName)
        end):SetIcon("icon16/eye.png")

        menu:Open()
    end

    -- Update player info when a row is selected
    playerList.OnRowSelected = function(self, lineID, line)
        local steamID = line:GetColumnText(2)
        UpdatePlayerInfo(steamID)
    end

    -- Player admin management buttons in the tools panel
    local inventoryButton = vgui.Create("DButton", playerToolsPanel)
    inventoryButton:SetPos(10, 10)
    inventoryButton:SetSize(440, 30)
    inventoryButton:SetText("Inventory")
    inventoryButton:SetTextColor(Color(255, 255, 255))
    inventoryButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
    end
    inventoryButton.DoClick = function()
        LocalPlayer():ChatPrint("Inventory functionality not implemented yet.")
    end

    local gangButton = vgui.Create("DButton", playerToolsPanel)
    gangButton:SetPos(10, 45) -- 10 + 30 + 5
    gangButton:SetSize(440, 30)
    gangButton:SetText("Gang")
    gangButton:SetTextColor(Color(255, 255, 255))
    gangButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 150))
    end
    gangButton.DoClick = function()
        LocalPlayer():ChatPrint("Gang functionality not implemented yet.")
    end

    -- Gangs Panel
    panels["Gangs"] = vgui.Create("DPanel", parent)
    panels["Gangs"]:SetPos(10, 50)
    panels["Gangs"]:SetSize(960, 560)
    panels["Gangs"]:SetVisible(false)
    panels["Gangs"].Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    local gangsLabel = vgui.Create("DLabel", panels["Gangs"])
    gangsLabel:SetPos(10, 10)
    gangsLabel:SetSize(940, 30)
    gangsLabel:SetText("Gangs Panel - Add functionality here")
    gangsLabel:SetColor(Color(255, 255, 255))

    -- Logs Panel
    panels["Logs"] = vgui.Create("DPanel", parent)
    panels["Logs"]:SetPos(10, 50)
    panels["Logs"]:SetSize(960, 560)
    panels["Logs"]:SetVisible(false)
    panels["Logs"].Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    local logsLabel = vgui.Create("DLabel", panels["Logs"])
    logsLabel:SetPos(10, 10)
    logsLabel:SetSize(940, 30)
    logsLabel:SetText("Logs Panel - Add functionality here")
    logsLabel:SetColor(Color(255, 255, 255))

    -- Show the selected panel when an option is chosen
    dropdown.OnSelect = function(self, index, value)
        for panelName, panel in pairs(panels) do
            panel:SetVisible(panelName == value)
        end
        currentOption = value
        UpdateDropdownOptions(currentOption)
        DebugPrint("[Admin Module] Admin panel switched to: " .. value)
    end
end

DebugPrint("[Admin Module] Loaded successfully (Client).")