-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Admin Module] cl_admin.lua is loading...")

if not CLIENT then return end

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Function to build the admin panel (used by sh_inventory.lua)
function BuildAdminPanel(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end

    -- Full list of panel options
    local allOptions = {"Players", "Gangs", "Logs"}
    local currentOption = "Players" -- Default panel

    local topBar = vgui.Create("DPanel", parent)
    topBar:Dock(TOP)
    topBar:SetTall(36)
    topBar:DockMargin(10, 10, 10, 6)
    topBar.Paint = function() end

    local dropdown = vgui.Create("DComboBox", topBar)
    dropdown:SetPos(0, 3)
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

    -- Settings button (tool/cog icon) opens DarkRP Admin Settings
    local settingsBtn = vgui.Create("DButton", topBar)
    settingsBtn:SetText(" Settings")
    settingsBtn:SetFont("DermaDefaultBold")
    settingsBtn:SetContentAlignment(4)
    settingsBtn:SetTall(30)
    settingsBtn:SetWide(120)
    settingsBtn:SetPos(210, 3)
    settingsBtn:SetImage("icon16/cog.png")
    settingsBtn:SetTextColor(Color(255, 255, 255))
    settingsBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(70, 70, 90, 220) or Color(50, 50, 60, 200))
    end
    settingsBtn.DoClick = function()
        local frame = vgui.Create("DFrame")
        frame:SetSize(520, 420)
        frame:Center()
        frame:SetTitle("DarkRP / Admin Settings")
        frame:MakePopup()
        function frame:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(28, 30, 36, 250))
            surface.SetDrawColor(70, 70, 80, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
        local sheet = vgui.Create("DPropertySheet", frame)
        sheet:Dock(FILL)
        sheet:DockMargin(6, 30, 6, 6)
        local users = vgui.Create("DPanel", sheet)
        users.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(35, 37, 42, 200)) end
        local usersLbl = vgui.Create("DLabel", users)
        usersLbl:SetText("Users – manage user groups and permissions (placeholder)")
        usersLbl:SetPos(10, 10)
        usersLbl:SetColor(Color(200, 200, 210))
        sheet:AddSheet("Users", users, "icon16/user.png")
        local ranks = vgui.Create("DPanel", sheet)
        ranks.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(35, 37, 42, 200)) end
        local ranksLbl = vgui.Create("DLabel", ranks)
        ranksLbl:SetText("Ranks – configure ranks (placeholder)")
        ranksLbl:SetPos(10, 10)
        ranksLbl:SetColor(Color(200, 200, 210))
        sheet:AddSheet("Ranks", ranks, "icon16/award_star_gold_1.png")
        local banlist = vgui.Create("DPanel", sheet)
        banlist.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(35, 37, 42, 200)) end
        local banLbl = vgui.Create("DLabel", banlist)
        banLbl:SetText("Banlist – view and manage bans (placeholder)")
        banLbl:SetPos(10, 10)
        banLbl:SetColor(Color(200, 200, 210))
        sheet:AddSheet("Banlist", banlist, "icon16/delete.png")
        local playerlist = vgui.Create("DPanel", sheet)
        playerlist.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(35, 37, 42, 200)) end
        local plistLbl = vgui.Create("DLabel", playerlist)
        plistLbl:SetText("Player list – all players from SQL (stats / EXP / items / bank – not made yet)")
        plistLbl:SetPos(10, 10)
        plistLbl:SetWrap(true)
        plistLbl:SetSize(480, 60)
        plistLbl:SetColor(Color(200, 200, 210))
        sheet:AddSheet("Player list", playerlist, "icon16/group.png")
    end

    -- Initial dropdown setup (exclude "Players")
    UpdateDropdownOptions(currentOption)

    -- Create panels for each option (hidden by default)
    local panels = {}

    local contentArea = vgui.Create("DScrollPanel", parent)
    contentArea:Dock(FILL)
    contentArea:DockMargin(10, 0, 10, 10)
    contentArea.Paint = function() end
    contentArea:GetCanvas():DockPadding(0, 0, 0, 0)

    -- Players Panel: list then options stacked; scroll so all buttons visible and nothing under Tool Selector
    panels["Players"] = vgui.Create("DPanel", contentArea:GetCanvas())
    panels["Players"]:Dock(TOP)
    panels["Players"]:SetTall(600)
    panels["Players"].Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end

    local playerListPanel = vgui.Create("DPanel", panels["Players"])
    playerListPanel:Dock(TOP)
    playerListPanel:DockMargin(10, 10, 10, 6)
    playerListPanel:SetTall(240)
    playerListPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
    end

    local playerList = vgui.Create("DListView", playerListPanel)
    playerList:Dock(FILL)
    playerList:DockMargin(5, 5, 5, 5)
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

    local playerInfoPanel = vgui.Create("DPanel", panels["Players"])
    playerInfoPanel:Dock(TOP)
    playerInfoPanel:SetTall(70)
    playerInfoPanel:DockMargin(10, 6, 10, 10)
    playerInfoPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60, 200))
    end

    -- Player info buttons (copyable; actions are on right-click menu)
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

    -- Helpers to open admin windows (used by right-click menu)
    local function OpenItemCreationEditor()
        local frame = vgui.Create("DFrame")
        frame:SetSize(820, 560)
        frame:Center()
        frame:SetTitle("Inventory Editor")
        frame:MakePopup()
        function frame:Paint(w,h)
            surface.SetDrawColor(20,20,22,245) surface.DrawRect(0,0,w,h)
            surface.SetDrawColor(70,70,80,255) surface.DrawOutlinedRect(0,0,w,h,2)
        end
        local left = vgui.Create("DPanel", frame)
        left:Dock(LEFT)
        left:SetWide(360)
        function left:Paint(w,h) surface.SetDrawColor(28,29,33,255) surface.DrawRect(0,0,w,h) end
        local search = vgui.Create("DTextEntry", left)
        search:Dock(TOP)
        search:DockMargin(8,8,8,4)
        search:SetTall(28)
        search:SetPlaceholderText("Search items...")
        local list = vgui.Create("DListView", left)
        list:Dock(FILL)
        list:DockMargin(8,4,8,8)
        list:AddColumn("ID"):SetFixedWidth(180)
        list:AddColumn("Name")
        local function refresh()
            list:Clear()
            local q = string.lower(search:GetValue() or "")
            for id, def in pairs(Inventory.Items or {}) do
                local nm = def.name or id
                if q == "" or string.find(string.lower(nm), q, 1, true) or string.find(string.lower(id), q, 1, true) then
                    list:AddLine(id, nm)
                end
            end
        end
        search.OnValueChange = refresh
        refresh()
        local right = vgui.Create("DScrollPanel", frame)
        right:Dock(FILL)
        right:DockMargin(6,8,8,8)
        local fields = {
            { key="id",          label="Item ID",        type="text" },
            { key="name",        label="Name",          type="text" },
            { key="desc",        label="Description",   type="text" },
            { key="icon",        label="Icon (material)", type="text" },
            { key="model",       label="Model",         type="text" },
            { key="class",       label="SWEP Class",    type="text" },
            { key="category",    label="Category",      type="text" },
            { key="rarity",      label="Rarity",        type="combo", choices=Inventory.Rarities or {} },
            { key="baseDamage",  label="Base Damage",    type="number" },
            { key="count",       label="Count",         type="number", default=1 },
            { key="crafter",     label="Crafter Name",  type="text" },
            { key="slots",       label="Slots (0-6)",   type="combo", choices={"0","1","2","3","4","5","6"} },
            { key="loadoutSlot", label="Equip Slot (weapons)", type="combo", choices={"Auto","Primary","Sidearm"} },
            { key="admin",       label="Mark Admin Spawn", type="check" },
        }
        local inputs = {}
        for _, f in ipairs(fields) do
            local row = vgui.Create("DPanel", right)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(0,0,0,6)
            function row:Paint(w,h) surface.SetDrawColor(34,35,39,255) surface.DrawRect(0,0,w,h) end
            local lbl = vgui.Create("DLabel", row)
            lbl:Dock(LEFT) lbl:SetWide(160) lbl:SetText(" "..f.label)
            local input
            if f.type == "text" then input = vgui.Create("DTextEntry", row) input:Dock(FILL)
            elseif f.type == "number" then input = vgui.Create("DTextEntry", row) input:Dock(FILL) input:SetNumeric(true) if f.default then input:SetText(tostring(f.default)) end
            elseif f.type == "combo" then input = vgui.Create("DComboBox", row) input:Dock(FILL) for _, c in ipairs(f.choices or {}) do input:AddChoice(c) end
            elseif f.type == "check" then input = vgui.Create("DCheckBoxLabel", row) input:Dock(LEFT) input:SetText("")
            end
            inputs[f.key] = input
            if f.key == "loadoutSlot" then input._row = row end
        end
        local playerSel = vgui.Create("DComboBox", right)
        playerSel:Dock(TOP) playerSel:SetTall(24) playerSel:DockMargin(0,8,0,4)
        local sidByIndex = { [1] = nil }
        playerSel:AddChoice("Self")
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p ~= LocalPlayer() then
                sidByIndex[#sidByIndex + 1] = p:SteamID()
                playerSel:AddChoice(p:Nick() .. " (" .. (p:SteamID() or "?") .. ")")
            end
        end
        playerSel:ChooseOptionID(1)
        local btnRow = vgui.Create("DPanel", right)
        btnRow:Dock(TOP) btnRow:SetTall(36) btnRow:DockMargin(0,4,0,0)
        function btnRow:Paint() end
        local createSelf = vgui.Create("DButton", btnRow)
        createSelf:Dock(LEFT) createSelf:SetWide(160) createSelf:SetText("Give to Self")
        createSelf.DoClick = function()
            local id = inputs.id:GetText()
            if id == "" then chat.AddText(Color(255,100,100), "Item ID required") return end
            local count = tonumber(inputs.count:GetText() or "1") or 1
            local rarity = inputs.rarity and inputs.rarity:GetValue() or ""
            local baseDamage = tonumber(inputs.baseDamage:GetText() or "0") or 0
            local admin = inputs.admin and inputs.admin:GetChecked() or false
            local crafter = inputs.crafter and inputs.crafter:GetText() or ""
            local slotsVal = inputs.slots and inputs.slots.GetValue and tonumber(inputs.slots:GetValue() or "0") or 0
            local loadoutSlot = (inputs.loadoutSlot and inputs.loadoutSlot.GetValue) and inputs.loadoutSlot:GetValue() or "Auto"
            if loadoutSlot ~= "Primary" and loadoutSlot ~= "Sidearm" then loadoutSlot = "" end
            net.Start(Inventory.NET.AdminCreateItem)
                net.WriteString(id)
                net.WriteUInt(math.max(1, math.min(count, 65535)), 16)
                net.WriteString(rarity or "")
                net.WriteUInt(math.max(0, math.min(baseDamage, 65535)), 16)
                net.WriteBool(admin)
                net.WriteString(crafter)
                net.WriteUInt(math.Clamp(slotsVal, 0, 6), 4)
                net.WriteString(loadoutSlot or "")
            net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
            chat.AddText(Color(150,200,255), string.format("Created %dx %s (self)", count, id))
        end
        local createTarget = vgui.Create("DButton", btnRow)
        createTarget:Dock(LEFT) createTarget:DockMargin(10,0,0,0) createTarget:SetWide(180) createTarget:SetText("Give to Selected")
        createTarget.DoClick = function()
            local id = inputs.id:GetText()
            if id == "" then chat.AddText(Color(255,100,100), "Item ID required") return end
            local idx = playerSel:GetSelectedID()
            local targetSid = (idx and idx > 1 and sidByIndex[idx]) or nil
            if not targetSid then
                chat.AddText(Color(255,100,100), "Select a player (or use Give to Self)")
                return
            end
            local count = tonumber(inputs.count:GetText() or "1") or 1
            local rarity = inputs.rarity and inputs.rarity:GetValue() or ""
            local baseDamage = tonumber(inputs.baseDamage:GetText() or "0") or 0
            local admin = inputs.admin and inputs.admin:GetChecked() or false
            local crafter = inputs.crafter and inputs.crafter:GetText() or ""
            local slotsVal = inputs.slots and inputs.slots.GetValue and tonumber(inputs.slots:GetValue() or "0") or 0
            local loadoutSlot = (inputs.loadoutSlot and inputs.loadoutSlot.GetValue) and inputs.loadoutSlot:GetValue() or "Auto"
            if loadoutSlot ~= "Primary" and loadoutSlot ~= "Sidearm" then loadoutSlot = "" end
            net.Start(Inventory.NET.AdminCreateItemFor)
                net.WriteString(targetSid)
                net.WriteString(id)
                net.WriteUInt(math.max(1, math.min(count, 65535)), 16)
                net.WriteString(rarity or "")
                net.WriteUInt(math.max(0, math.min(baseDamage, 65535)), 16)
                net.WriteBool(admin)
                net.WriteString(crafter)
                net.WriteUInt(math.Clamp(slotsVal, 0, 6), 4)
                net.WriteString(loadoutSlot or "")
            net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
            chat.AddText(Color(150,200,255), string.format("Gave %dx %s to selected player", count, id))
        end
        function list:OnRowSelected(_, line)
            local id = line:GetColumnText(1)
            local def = Inventory.Items and Inventory.Items[id]
            if not def then return end
            inputs.id:SetText(id)
            -- Show Equip Slot field only for weapons (items with class)
            if inputs.loadoutSlot and inputs.loadoutSlot._row then
                inputs.loadoutSlot._row:SetVisible(def.class and def.class ~= "")
            end
            if inputs.name then inputs.name:SetText(def.name or id) end
            if inputs.desc then inputs.desc:SetText(def.desc or "") end
            if inputs.icon then inputs.icon:SetText(def.icon or "") end
            if inputs.model then inputs.model:SetText(def.model or "") end
            if inputs.class then inputs.class:SetText(def.class or "") end
            if inputs.category then inputs.category:SetText(def.category or "Misc") end
            if inputs.rarity and def.rarity then inputs.rarity:SetValue(def.rarity) else if inputs.rarity then inputs.rarity:SetValue("") end end
            if inputs.baseDamage then inputs.baseDamage:SetText(tostring(def.baseDamage or 0)) end
            if inputs.slots then inputs.slots:SetValue("0") end
        end
    end

    local function OpenInventoryManager()
        local frame = vgui.Create("DFrame")
        frame:SetSize(860, 560)
        frame:Center()
        frame:SetTitle("Inventory Manager")
        frame:MakePopup()
        function frame:Paint(w,h)
            surface.SetDrawColor(20,20,22,245) surface.DrawRect(0,0,w,h)
            surface.SetDrawColor(70,70,80,255) surface.DrawOutlinedRect(0,0,w,h,2)
        end
        local gridPanel = vgui.Create("DScrollPanel", frame)
        gridPanel:Dock(LEFT) gridPanel:SetWide(520) gridPanel:DockMargin(8,8,6,8)
        local list = vgui.Create("DListView", gridPanel)
        list:Dock(FILL)
        list:AddColumn("UID"):SetFixedWidth(200)
        list:AddColumn("ID")
        list:AddColumn("x,y")
        local function refresh()
            list:Clear()
            local items = Inventory and Inventory.Client and Inventory.Client.Items or {}
            if not items then return end
            for _, it in ipairs(items) do
                list:AddLine(it.uid or "?", it.id or "?", string.format("%d,%d", it.x or 0, it.y or 0))
            end
        end
        refresh()
        local right = vgui.Create("DScrollPanel", frame)
        right:Dock(FILL) right:DockMargin(6,8,8,8)
        local selected
        local fields = {
            { key="rarity",     label="Rarity",      type="combo", choices=Inventory.Rarities or {} },
            { key="baseDamage", label="Base Damage",  type="number" },
            { key="slots",      label="Slots (0-6)", type="combo", choices={"0","1","2","3","4","5","6"} },
            { key="crafter",    label="Crafter Name", type="text" },
            { key="admin",      label="Mark Admin Spawn", type="check" },
        }
        local inputs = {}
        for _, f in ipairs(fields) do
            local row = vgui.Create("DPanel", right)
            row:Dock(TOP) row:SetTall(28) row:DockMargin(0,0,0,6)
            function row:Paint(w,h) surface.SetDrawColor(34,35,39,255) surface.DrawRect(0,0,w,h) end
            local lbl = vgui.Create("DLabel", row) lbl:Dock(LEFT) lbl:SetWide(160) lbl:SetText(" "..f.label)
            local input
            if f.type == "text" then input = vgui.Create("DTextEntry", row) input:Dock(FILL)
            elseif f.type == "number" then input = vgui.Create("DTextEntry", row) input:Dock(FILL) input:SetNumeric(true)
            elseif f.type == "combo" then input = vgui.Create("DComboBox", row) input:Dock(FILL) for _, c in ipairs(f.choices or {}) do input:AddChoice(c) end
            elseif f.type == "check" then input = vgui.Create("DCheckBoxLabel", row) input:Dock(LEFT) input:SetText("")
            end
            inputs[f.key] = input
        end
        local btnRow = vgui.Create("DPanel", right)
        btnRow:Dock(TOP) btnRow:SetTall(34) btnRow:DockMargin(0,8,0,0)
        function btnRow:Paint() end
        local apply = vgui.Create("DButton", btnRow)
        apply:Dock(LEFT) apply:SetWide(160) apply:SetText("Apply Changes")
        apply.DoClick = function()
            if not selected then return end
            local rarity = inputs.rarity and inputs.rarity:GetValue() or ""
            local baseDamage = tonumber(inputs.baseDamage and inputs.baseDamage:GetText() or "0") or 0
            local slots = tonumber(inputs.slots and inputs.slots:GetValue() or "0") or 0
            local crafter = inputs.crafter and inputs.crafter:GetText() or ""
            local admin = inputs.admin and inputs.admin:GetChecked() or false
            net.Start(Inventory.NET.AdminModifyItem)
                net.WriteString(selected)
                net.WriteString(rarity)
                net.WriteUInt(math.max(0, math.min(baseDamage, 65535)), 16)
                net.WriteUInt(math.Clamp(slots, 0, 6), 4)
                net.WriteString(crafter)
                net.WriteBool(admin)
            net.SendToServer()
            chat.AddText(Color(200,220,255), "Modified item "..selected)
            timer.Simple(0.25, refresh)
        end
        local del = vgui.Create("DButton", btnRow)
        del:Dock(LEFT) del:DockMargin(8,0,0,0) del:SetWide(140) del:SetText("Delete Item")
        del.DoClick = function()
            if not selected then return end
            net.Start(Inventory.NET.AdminDeleteInstance)
                net.WriteString(selected)
            net.SendToServer()
            chat.AddText(Color(255,160,160), "Deleted item "..selected)
            timer.Simple(0.25, refresh)
        end
        function list:OnRowSelected(_, line) selected = line:GetColumnText(1) end
    end

    -- Right-click menu: actions moved from buttons to here
    playerList.OnRowRightClick = function(self, lineID, line)
        local playerName = line:GetColumnText(1)
        local steamID = line:GetColumnText(2)
        local menu = DermaMenu()

        menu:AddOption("Info", function()
            self:SelectItem(line)
        end):SetIcon("icon16/information.png")

        menu:AddOption("Item Creation", function()
            OpenItemCreationEditor()
        end):SetIcon("icon16/add.png")

        menu:AddOption("Inventory", function()
            OpenInventoryManager()
        end):SetIcon("icon16/briefcase.png")

        menu:AddOption("Gang", function()
            LocalPlayer():ChatPrint("Gang functionality not implemented yet.")
        end):SetIcon("icon16/group.png")

        menu:AddOption("Kick", function()
            LocalPlayer():ChatPrint("Kick functionality not implemented yet for " .. playerName)
        end):SetIcon("icon16/door_out.png")

        menu:AddOption("Ban", function()
            LocalPlayer():ChatPrint("Ban functionality not implemented yet for " .. playerName)
        end):SetIcon("icon16/cancel.png")

        menu:AddOption("Spectate", function()
            LocalPlayer():ChatPrint("Spectate functionality not implemented yet for " .. playerName)
        end):SetIcon("icon16/eye.png")

        menu:Open()
    end

    -- Update player info when a row is selected
    playerList.OnRowSelected = function(self, lineID, line)
        local steamID = line:GetColumnText(2)
        UpdatePlayerInfo(steamID)
    end

    -- (Action buttons removed; use right-click on player list for Item Creation, Inventory, Gang)

    -- Gangs Panel (stacked below Players so scroll shows one at a time)
    panels["Gangs"] = vgui.Create("DPanel", contentArea:GetCanvas())
    panels["Gangs"]:Dock(TOP)
    panels["Gangs"]:SetTall(0)
    panels["Gangs"]:SetVisible(false)
    panels["Gangs"].Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    local gangsLabel = vgui.Create("DLabel", panels["Gangs"])
    gangsLabel:Dock(TOP)
    gangsLabel:SetTall(30)
    gangsLabel:DockMargin(10, 10, 10, 0)
    gangsLabel:SetText("Gangs Panel - Add functionality here")
    gangsLabel:SetColor(Color(255, 255, 255))

    -- Logs Panel
    panels["Logs"] = vgui.Create("DPanel", contentArea:GetCanvas())
    panels["Logs"]:Dock(TOP)
    panels["Logs"]:SetTall(0)
    panels["Logs"]:SetVisible(false)
    panels["Logs"].Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    local logsLabel = vgui.Create("DLabel", panels["Logs"])
    logsLabel:Dock(TOP)
    logsLabel:SetTall(30)
    logsLabel:DockMargin(10, 10, 10, 0)
    logsLabel:SetText("Logs Panel - Add functionality here")
    logsLabel:SetColor(Color(255, 255, 255))

    local panelHeights = { Players = 600, Gangs = 400, Logs = 400 }
    dropdown.OnSelect = function(self, index, value)
        for panelName, panel in pairs(panels) do
            local visible = (panelName == value)
            panel:SetVisible(visible)
            panel:SetTall(visible and (panelHeights[panelName] or 400) or 0)
        end
        currentOption = value
        UpdateDropdownOptions(currentOption)
        if IsValid(contentArea) and IsValid(contentArea:GetVBar()) then
            contentArea:GetVBar():SetScroll(0)
        end
    end
end

-- This print will always show to confirm successful load
print("[Admin Module] Loaded successfully (Client).")

-- Admin: Item Browser panel (searchable list with right-click actions)
function BuildAdminItemBrowser(parent)
    if not IsValid(parent) then return end
    local frame = vgui.Create("DFrame")
    frame:SetSize(700, 500)
    frame:Center()
    frame:SetTitle("Item Browser")
    frame:MakePopup()
    frame:ShowCloseButton(true)
    function frame:Paint(w,h)
        surface.SetDrawColor(20,20,22,245) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(70,70,80,255) surface.DrawOutlinedRect(0,0,w,h,2)
    end
    Inventory = Inventory or {}
    Inventory.UIOverlayOpen = true
    frame.OnClose = function()
        if Inventory then Inventory.UIOverlayOpen = false end
    end

    local top = vgui.Create("DPanel", frame)
    top:Dock(TOP)
    top:SetTall(36)
    function top:Paint(w,h)
        surface.SetDrawColor(28,29,33,255) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(70,70,80,255) surface.DrawOutlinedRect(0,0,w,h,1)
    end
    local search = vgui.Create("DTextEntry", top)
    search:Dock(FILL)
    search:DockMargin(8,6,8,6)
    search:SetPlaceholderText("Search items...")

    local list = vgui.Create("DListView", frame)
    list:Dock(FILL)
    list:DockMargin(8,6,8,8)
    list:AddColumn("ID"):SetFixedWidth(240)
    list:AddColumn("Name")
    list:AddColumn("Class/Model")

    local function refresh()
        if not Inventory or not Inventory.Items then return end
        list:Clear()
        local q = string.lower(search:GetValue() or "")
        for id, def in pairs(Inventory.Items) do
            local nm = def.name or id
            if q == "" or string.find(string.lower(nm), q, 1, true) or string.find(string.lower(id), q, 1, true) then
                list:AddLine(id, nm, def.class or def.model or "")
            end
        end
    end
    search.OnValueChange = refresh
    refresh()

    function list:OnRowRightClick(lineId, line)
        local id = line:GetColumnText(1)
        local m = DermaMenu()
        m:AddOption("Give to self", function() RunConsoleCommand("inv_giveitem", id, "1") end):SetIcon("icon16/add.png")
        m:AddOption("Copy spawn id", function() SetClipboardText(id) end):SetIcon("icon16/page_copy.png")
        m:Open()
    end
end