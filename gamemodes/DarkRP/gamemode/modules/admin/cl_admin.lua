-- Debug print to confirm the file is loading (this one will always print for initial load confirmation)
print("[Admin Module] cl_admin.lua is loading...")

if not CLIENT then return end

-- Refs for Ban List / Logs tabs (set when panel is built; net receivers update these)
Admin = Admin or {}
Admin.CurrentBanListView = nil
Admin.CurrentLogsListView = nil
Admin.CurrentLogsData = {}
Admin.CurrentLogCategoryFilter = nil

net.Receive("Admin_SendBanList", function()
    if not IsValid(Admin.CurrentBanListView) then return end
    Admin.CurrentBanListView:Clear()
    local n = net.ReadUInt(16)
    for i = 1, n do
        Admin.CurrentBanListView:AddLine(net.ReadString())
    end
end)

net.Receive("Admin_RankChanged", function()
    net.Start("Admin_RequestUserList")
    net.SendToServer()
end)

net.Receive("Admin_SendLogs", function()
    Admin.CurrentLogsData = {}
    local n = net.ReadUInt(16)
    for i = 1, n do
        local t = net.ReadUInt(32)
        local cat = net.ReadString()
        local msg = net.ReadString()
        table.insert(Admin.CurrentLogsData, { t = t, cat = cat, msg = msg })
    end
    if not IsValid(Admin.CurrentLogsListView) then return end
    local filter = (IsValid(Admin.CurrentLogCategoryFilter) and Admin.CurrentLogCategoryFilter:GetValue()) or "All"
    Admin.CurrentLogsListView:Clear()
    for _, e in ipairs(Admin.CurrentLogsData) do
        if filter == "All" or e.cat == filter then
            Admin.CurrentLogsListView:AddLine(os.date("%H:%M:%S", e.t), e.cat, e.msg)
        end
    end
end)

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Tabs: Server (online players + Player Info + actions), Users (Member+ Dlist + Add by SteamID), Ban List, Logs, Settings.
function BuildAdminPanel(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end

    local isSuperAdmin = LocalPlayer():IsSuperAdmin()
    local contentArea = vgui.Create("DPanel", parent)
    contentArea:Dock(FILL)
    contentArea:DockMargin(8, 8, 8, 8)
    contentArea.Paint = function() end

    local sheet = vgui.Create("DPropertySheet", contentArea)
    sheet:Dock(FILL)

    -- Server tab: online players list + Player Info + action buttons (Kick, Ban, etc.)
    local playersPanel = vgui.Create("DPanel", sheet)
    playersPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    local listArea = vgui.Create("DPanel", playersPanel)
    listArea:Dock(LEFT)
    listArea:SetWide(280)
    listArea:DockMargin(8, 8, 8, 8)
    listArea.Paint = function() end

    local refreshBtn = vgui.Create("DButton", listArea)
    refreshBtn:Dock(TOP)
    refreshBtn:DockMargin(0, 0, 0, 6)
    refreshBtn:SetTall(28)
    refreshBtn:SetText("Refresh")
    refreshBtn.DoClick = function()
        net.Start("Admin_RequestOnlineList")
        net.SendToServer()
    end

    local listWrap = vgui.Create("DPanel", listArea)
    listWrap:Dock(FILL)
    listWrap:DockMargin(0, 0, 0, 0)
    listWrap.Paint = function() end

    local onlineList = vgui.Create("DListView", listWrap)
    onlineList:Dock(FILL)
    onlineList:DockMargin(0, 0, 0, 0)
    onlineList:AddColumn("Name"):SetFixedWidth(82)
    onlineList:AddColumn("SteamID"):SetFixedWidth(120)
    onlineList:AddColumn("Rank"):SetFixedWidth(80)
    onlineList:SetMultiSelect(false)

    -- Right: selected player info panel (fills remaining space, aligned)
    local infoPanel = vgui.Create("DPanel", playersPanel)
    infoPanel:Dock(FILL)
    infoPanel:DockMargin(6, 8, 8, 8)
    infoPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 35, 45, 220))
        surface.SetDrawColor(60, 70, 90, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local infoHeader = vgui.Create("DPanel", infoPanel)
    infoHeader:Dock(TOP)
    infoHeader:SetTall(32)
    infoHeader.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 48, 60, 255))
        surface.SetDrawColor(60, 70, 90, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("Player Info", "DermaDefaultBold", 10, h/2, Color(200, 210, 220), 0, 1)
    end

    local infoContent = vgui.Create("DPanel", infoPanel)
    infoContent:Dock(FILL)
    infoContent:DockMargin(10, 10, 10, 10)
    infoContent.Paint = function() end

    local infoName = vgui.Create("DLabel", infoContent)
    infoName:SetText("Select a player from the list")
    infoName:Dock(TOP)
    infoName:SetTall(20)
    infoName:DockMargin(0, 0, 0, 2)
    infoName:SetColor(Color(180, 190, 200))
    infoName:SetWrap(true)
    local infoSteamID = vgui.Create("DLabel", infoContent)
    infoSteamID:SetText("")
    infoSteamID:Dock(TOP)
    infoSteamID:SetTall(16)
    infoSteamID:DockMargin(0, 0, 0, 8)
    infoSteamID:SetFont("DermaDefault")
    infoSteamID:SetColor(Color(120, 130, 145))
    infoSteamID:SetWrap(true)
    local infoRank = vgui.Create("DLabel", infoContent)
    infoRank:SetText("")
    infoRank:SetPos(0, 0)
    infoRank:SetSize(1, 1)
    infoRank:SetVisible(false)

    -- Helper: get selected player from Server tab list (works on left-click selection)
    local function getSelectedPlayer()
        local lineID, line = onlineList:GetSelectedLine()
        if not line or not IsValid(line) then
            LocalPlayer():ChatPrint("Select a player from the list first.")
            return nil, nil
        end
        local name = line:GetColumnText(1)
        local steamid = line:GetColumnText(2)
        return steamid, name
    end

    -- Four rows of 3 buttons: compact labels so nothing overflows
    local btnRow1 = vgui.Create("DPanel", infoContent)
    btnRow1:Dock(TOP)
    btnRow1:DockMargin(0, 0, 0, 4)
    btnRow1:SetTall(28)
    btnRow1.Paint = function() end
    local btnRow2 = vgui.Create("DPanel", infoContent)
    btnRow2:Dock(TOP)
    btnRow2:DockMargin(0, 0, 0, 4)
    btnRow2:SetTall(28)
    btnRow2.Paint = function() end
    local btnRow3 = vgui.Create("DPanel", infoContent)
    btnRow3:Dock(TOP)
    btnRow3:DockMargin(0, 0, 0, 4)
    btnRow3:SetTall(28)
    btnRow3.Paint = function() end
    local btnRow4 = vgui.Create("DPanel", infoContent)
    btnRow4:Dock(TOP)
    btnRow4:DockMargin(0, 0, 0, 0)
    btnRow4:SetTall(28)
    btnRow4.Paint = function() end

    local function makeActionBtn(parent, text, icon, fn)
        local b = vgui.Create("DButton", parent)
        b:Dock(LEFT)
        b:DockMargin(0, 0, 5, 0)
        b:SetWide(68)
        b:SetTall(24)
        b:SetText("")
        b._label = text
        b._icon = icon
        b._fn = fn
        b:SetVisible(false)
        b.Paint = function(self, w, h)
            local bg = self:IsHovered() and Color(50, 60, 75) or Color(40, 48, 58)
            draw.RoundedBox(4, 0, 0, w, h, bg)
            surface.SetDrawColor(70, 85, 100, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(self._label, "DermaDefault", w/2, h/2, Color(200, 210, 220), 1, 1)
        end
        b.DoClick = function()
            if b._fn then b._fn() end
        end
        return b
    end

    local kickBtn, banBtn, muteBtn, gagBtn, demoteBtn, reviveBtn, respawnBtn, spectateBtn, giveItemBtn
    local gotoBtn, bringBtn, freezeBtn
    kickBtn = makeActionBtn(btnRow1, "Kick", nil, function()
        local sid, name = getSelectedPlayer()
        if not sid then return end
        Derma_StringRequest("Kick player", "Reason (optional):", "Kicked by admin", function(reason)
            net.Start("Admin_Kick") net.WriteString(sid) net.WriteString(reason or "") net.SendToServer()
        end)
    end)
    banBtn = makeActionBtn(btnRow1, "Ban", nil, function()
        local sid, name = getSelectedPlayer()
        if not sid then return end
            local frame = vgui.Create("DFrame")
            frame:SetSize(340, 180)
            frame:Center()
            frame:SetTitle("Ban player – reason & duration")
            frame:MakePopup()
            frame.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(28, 34, 44, 250))
                surface.SetDrawColor(60, 72, 88, 255)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            local pad, y = 10, 36
            local reasonL = vgui.Create("DLabel", frame)
            reasonL:SetPos(pad, y - 14)
            reasonL:SetText("Reason")
            reasonL:SetColor(Color(200, 208, 220))
            local reasonE = vgui.Create("DTextEntry", frame)
            reasonE:SetPos(pad, y)
            reasonE:SetSize(320, 22)
            reasonE:SetValue("Banned by admin")
            y = y + 36
            local durL = vgui.Create("DLabel", frame)
            durL:SetPos(pad, y - 14)
            durL:SetText("Duration (minutes, 0 = permanent)")
            durL:SetColor(Color(200, 208, 220))
            local durE = vgui.Create("DNumberWang", frame)
            durE:SetPos(pad, y)
            durE:SetSize(100, 22)
            durE:SetMin(0)
            durE:SetMax(99999)
            durE:SetValue(0)
            y = y + 36
            local ok = vgui.Create("DButton", frame)
            ok:SetPos(pad, y)
            ok:SetSize(100, 26)
            ok:SetText("Ban")
            ok.DoClick = function()
                local reason = reasonE:GetValue() or ""
                local duration = math.floor(tonumber(durE:GetValue()) or 0)
                frame:Close()
                net.Start("Admin_Ban")
                net.WriteString(sid)
                net.WriteString(reason)
                net.WriteUInt(math.Clamp(duration, 0, 65535), 16)
                net.SendToServer()
            end
            local cancel = vgui.Create("DButton", frame)
            cancel:SetPos(pad + 110, y)
            cancel:SetSize(80, 26)
            cancel:SetText("Cancel")
            cancel.DoClick = function() frame:Close() end
    end)
    muteBtn = makeActionBtn(btnRow1, "Mute", nil, function()
        local sid, _ = getSelectedPlayer()
        if not sid then return end
        local targetPly
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:SteamID() == sid then targetPly = p break end
        end
        if not IsValid(targetPly) then LocalPlayer():ChatPrint("Player must be online.") return end
        Derma_StringRequest("Mute (voice)", "Duration (minutes):", "10", function(minStr)
            local min = tonumber(minStr)
            if min and min > 0 then RunConsoleCommand("_FAdmin", "Voicemute", targetPly:UserID(), math.floor(min * 60)) end
        end)
    end)
    gotoBtn = makeActionBtn(btnRow2, "Goto", nil, function()
        local sid, _ = getSelectedPlayer()
        if sid then RunConsoleCommand("paradise_goto", sid) end
    end)
    bringBtn = makeActionBtn(btnRow2, "Bring", nil, function()
        local sid, _ = getSelectedPlayer()
        if sid then RunConsoleCommand("paradise_bring", sid) end
    end)
    freezeBtn = makeActionBtn(btnRow2, "Freeze", nil, function()
        local sid, _ = getSelectedPlayer()
        if sid then RunConsoleCommand("paradise_freeze", sid) end
    end)
    demoteBtn = makeActionBtn(btnRow3, "Demote", nil, function()
        local sid, name = getSelectedPlayer()
        if not sid then return end
        Derma_Query("Demote " .. (name or sid) .. " to Citizen (job)?", "Demote job", "Yes", function()
            net.Start("Admin_Demote") net.WriteString(sid) net.SendToServer()
        end, "No", nil)
    end)
    -- Revive dropdown: Revive (at body) = respawn at death position; Spawn (at spawn) = teleport to job spawn
    reviveBtn = makeActionBtn(btnRow3, "Revive", nil, function()
        local sid, _ = getSelectedPlayer()
        if not sid then return end
        local menu = Derma_Menu()
        menu:AddOption("Revive (at body)", function()
            RunConsoleCommand("rp_respawn", sid)
        end)
        menu:AddOption("Spawn (at spawn)", function()
            net.Start("Admin_Spawn") net.WriteString(sid) net.SendToServer()
        end)
        menu:Open()
    end)
    respawnBtn = makeActionBtn(btnRow3, "Respawn", nil, function()
        local sid, _ = getSelectedPlayer()
        if sid then RunConsoleCommand("rp_respawn", sid) end
    end)
    gagBtn = makeActionBtn(btnRow4, "Gag", nil, function()
        local sid, _ = getSelectedPlayer()
        if not sid then return end
        local targetPly
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:SteamID() == sid then targetPly = p break end
        end
        if not IsValid(targetPly) then LocalPlayer():ChatPrint("Player must be online.") return end
        Derma_StringRequest("Gag (chat)", "Duration (minutes):", "10", function(minStr)
            local min = tonumber(minStr)
            if min and min > 0 then RunConsoleCommand("_FAdmin", "chatmute", targetPly:UserID(), math.floor(min * 60)) end
        end)
    end)
    spectateBtn = makeActionBtn(btnRow4, "Spectate", nil, function()
        local sid, _ = getSelectedPlayer()
        if sid then RunConsoleCommand("FSpectate", sid) end
    end)
    giveItemBtn = makeActionBtn(btnRow4, "Give Item", nil, function()
        local sid, name = getSelectedPlayer()
        if sid then BuildAdminItemBrowser(nil, sid, name) end
    end)

    local selectedSteamID = nil
    local selectedName = nil
    local function updateInfoPanel(name, steamid, rank)
        selectedSteamID = steamid
        selectedName = name
        if not name or not steamid then
            infoName:SetText("Select a player from the list")
            infoSteamID:SetText("")
            infoRank:SetText("")
            kickBtn:SetVisible(false)
            banBtn:SetVisible(false)
            if muteBtn then muteBtn:SetVisible(false) end
            if gagBtn then gagBtn:SetVisible(false) end
            if gotoBtn then gotoBtn:SetVisible(false) end
            if bringBtn then bringBtn:SetVisible(false) end
            if freezeBtn then freezeBtn:SetVisible(false) end
            if demoteBtn then demoteBtn:SetVisible(false) end
            if reviveBtn then reviveBtn:SetVisible(false) end
            if respawnBtn then respawnBtn:SetVisible(false) end
            spectateBtn:SetVisible(false)
            giveItemBtn:SetVisible(false)
            return
        end
        local displayRank = (Admin.RankDisplayNames and Admin.RankDisplayNames[rank or "user"]) or (rank or "User")
        infoName:SetText((name or "—") .. "  ·  " .. displayRank)
        infoSteamID:SetText(steamid or "")
        kickBtn:SetVisible(true)
        banBtn:SetVisible(true)
        if muteBtn then muteBtn:SetVisible(true) end
        if gagBtn then gagBtn:SetVisible(true) end
        if gotoBtn then gotoBtn:SetVisible(true) end
        if bringBtn then bringBtn:SetVisible(true) end
        if freezeBtn then freezeBtn:SetVisible(true) end
        if demoteBtn then demoteBtn:SetVisible(true) end
        if reviveBtn then reviveBtn:SetVisible(true) end
        if respawnBtn then respawnBtn:SetVisible(true) end
        spectateBtn:SetVisible(true)
        giveItemBtn:SetVisible(true)
    end

    -- Get the selected row from the Server list (callback args vary by engine; use GetSelectedLine/GetLines to be safe).
    onlineList.OnRowSelected = function()
        local lineID, line = onlineList:GetSelectedLine()
        if not line or not IsValid(line) then return end
        if line.GetColumnText then
            local name = line:GetColumnText(1)
            local steamid = line:GetColumnText(2)
            local rank = line:GetColumnText(3)
            updateInfoPanel(name, steamid, rank)
        else
            local lines = onlineList:GetLines()
            if lines and lines[lineID] and IsValid(lines[lineID]) and lines[lineID].GetColumnText then
                line = lines[lineID]
                updateInfoPanel(line:GetColumnText(1), line:GetColumnText(2), line:GetColumnText(3))
            end
        end
    end

    onlineList.OnRowRightClick = function(lineID, line)
        -- DListView may pass (lineID, linePanel) or (line, lineID); second arg can be a number (index)
        if type(line) == "number" then
            lineID = line
            line = nil
        end
        if not line or not IsValid(line) then
            local lines = onlineList:GetLines()
            if lines and lines[lineID] and IsValid(lines[lineID]) then
                line = lines[lineID]
            else
                local _, sel = onlineList:GetSelectedLine()
                if sel and IsValid(sel) then line = sel end
            end
        end
        if not line or not IsValid(line) or not line.GetColumnText then return end
        local name = line:GetColumnText(1)
        local steamID = line:GetColumnText(2)
        local m = DermaMenu()
        m:AddOption("Copy SteamID", function()
            SetClipboardText(steamID)
            LocalPlayer():ChatPrint("SteamID copied")
        end):SetIcon("icon16/page_copy.png")
        if isSuperAdmin then
            local setRankSub = m:AddSubMenu("Set Rank", "icon16/user_edit.png")
            local ranks = {
                {"User", "user"},
                {"Member", "member"},
                {"Donator", "donator"},
                {"Super Donator", "sdonator"},
                {"Admin", "admin"},
                {"Super Admin", "superadmin"},
            }
            for _, r in ipairs(ranks) do
                setRankSub:AddOption(r[1], function()
                    net.Start("Admin_SetRank")
                    net.WriteString(steamID)
                    net.WriteString(r[2])
                    net.SendToServer()
                end)
            end
        end
        m:AddSpacer()
        m:AddOption("Spectate", function()
            RunConsoleCommand("FSpectate", steamID)
        end):SetIcon("icon16/eye.png")
        m:AddOption("Spawn (at spawn)", function()
            net.Start("Admin_Spawn") net.WriteString(steamID) net.SendToServer()
        end):SetIcon("icon16/map.png")
        m:AddOption("Respawn (at body)", function()
            RunConsoleCommand("rp_respawn", steamID)
        end):SetIcon("icon16/heart.png")
        m:AddOption("Give Item", function()
            BuildAdminItemBrowser(nil, steamID, name)
        end):SetIcon("icon16/add.png")
        m:AddSpacer()
        m:AddOption("Kick...", function()
            Derma_StringRequest("Kick player", "Reason (optional):", "Kicked by admin", function(reason)
                net.Start("Admin_Kick") net.WriteString(steamID) net.WriteString(reason or "") net.SendToServer()
            end)
        end):SetIcon("icon16/user_delete.png")
        m:AddOption("Ban...", function()
            selectedSteamID = steamID
            selectedName = name
            -- Reuse same Ban dialog logic (open dialog with reason + duration)
            local frame = vgui.Create("DFrame")
            frame:SetSize(340, 180)
            frame:Center()
            frame:SetTitle("Ban player – reason & duration")
            frame:MakePopup()
            frame.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(28, 34, 44, 250))
                surface.SetDrawColor(60, 72, 88, 255)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            local pad, y = 10, 36
            local reasonE = vgui.Create("DTextEntry", frame)
            reasonE:SetPos(pad, y)
            reasonE:SetSize(320, 22)
            reasonE:SetValue("Banned by admin")
            y = y + 36
            local durE = vgui.Create("DNumberWang", frame)
            durE:SetPos(pad, y)
            durE:SetSize(100, 22)
            durE:SetMin(0)
            durE:SetMax(99999)
            durE:SetValue(0)
            y = y + 36
            local ok = vgui.Create("DButton", frame)
            ok:SetPos(pad, y)
            ok:SetSize(100, 26)
            ok:SetText("Ban")
            ok.DoClick = function()
                local reason = reasonE:GetValue() or ""
                local duration = math.floor(tonumber(durE:GetValue()) or 0)
                frame:Close()
                net.Start("Admin_Ban")
                net.WriteString(steamID)
                net.WriteString(reason)
                net.WriteUInt(math.Clamp(duration, 0, 65535), 16)
                net.SendToServer()
            end
            local cancel = vgui.Create("DButton", frame)
            cancel:SetPos(pad + 110, y)
            cancel:SetSize(80, 26)
            cancel:SetText("Cancel")
            cancel.DoClick = function() frame:Close() end
        end):SetIcon("icon16/error.png")
        m:AddOption("Mute (voice)...", function()
            local targetPly
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID() == steamID then targetPly = p break end
            end
            if not IsValid(targetPly) then LocalPlayer():ChatPrint("Player must be online.") return end
            Derma_StringRequest("Mute (voice)", "Duration (minutes):", "10", function(minStr)
                local min = tonumber(minStr)
                if min and min > 0 then RunConsoleCommand("_FAdmin", "Voicemute", targetPly:UserID(), math.floor(min * 60)) end
            end)
        end):SetIcon("icon16/sound_mute.png")
        m:AddOption("Gag (chat)...", function()
            local targetPly
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID() == steamID then targetPly = p break end
            end
            if not IsValid(targetPly) then LocalPlayer():ChatPrint("Player must be online.") return end
            Derma_StringRequest("Gag (chat)", "Duration (minutes):", "10", function(minStr)
                local min = tonumber(minStr)
                if min and min > 0 then RunConsoleCommand("_FAdmin", "chatmute", targetPly:UserID(), math.floor(min * 60)) end
            end)
        end):SetIcon("icon16/user_delete.png")
        m:AddOption("Goto", function() RunConsoleCommand("paradise_goto", steamID) end):SetIcon("icon16/map_go.png")
        m:AddOption("Bring", function() RunConsoleCommand("paradise_bring", steamID) end):SetIcon("icon16/map_link.png")
        m:AddOption("Freeze", function() RunConsoleCommand("paradise_freeze", steamID) end):SetIcon("icon16/cancel.png")
        m:AddOption("Demote (Job)...", function()
            Derma_Query("Demote " .. (name or steamID) .. " to Citizen (job)?", "Demote job", "Yes", function()
                net.Start("Admin_Demote") net.WriteString(steamID) net.SendToServer()
            end, "No", nil)
        end):SetIcon("icon16/user_go.png")
        m:Open()
    end

    net.Receive("Admin_SendOnlineList", function()
        onlineList:Clear()
        updateInfoPanel(nil, nil, nil)
        local n = net.ReadUInt(16)
        for i = 1, n do
            local steamid = net.ReadString()
            local rank = net.ReadString()
            local name = net.ReadString()
            local displayRank = (Admin.RankDisplayNames and Admin.RankDisplayNames[rank]) or rank
            onlineList:AddLine(name, steamid, displayRank)
        end
    end)

    -- Users tab: Dlist of Member+ only (saved ranked users for donator system) + Add by SteamID
    local usersPanel = vgui.Create("DPanel", sheet)
    usersPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end
    local usersListArea = vgui.Create("DPanel", usersPanel)
    usersListArea:Dock(FILL)
    usersListArea:DockMargin(8, 8, 8, 8)
    usersListArea.Paint = function() end
    local usersRefreshBtn = vgui.Create("DButton", usersListArea)
    usersRefreshBtn:Dock(TOP)
    usersRefreshBtn:DockMargin(0, 0, 0, 6)
    usersRefreshBtn:SetTall(28)
    usersRefreshBtn:SetText("Refresh")
    usersRefreshBtn.DoClick = function()
        net.Start("Admin_RequestUserList")
        net.SendToServer()
    end
    local usersListWrap = vgui.Create("DPanel", usersListArea)
    usersListWrap:Dock(FILL)
    usersListWrap:DockMargin(0, 0, 0, 6)
    usersListWrap.Paint = function() end
    local userList = vgui.Create("DListView", usersListWrap)
    userList:Dock(FILL)
    userList:DockMargin(0, 0, 0, 0)
    userList:AddColumn("Name"):SetFixedWidth(100)
    userList:AddColumn("SteamID"):SetFixedWidth(120)
    userList:AddColumn("Rank"):SetFixedWidth(90)
    userList:SetMultiSelect(false)
    if isSuperAdmin then
        if Inventory then Inventory.AdminPanelSteamIDFocused = false end
        local addSection = vgui.Create("DPanel", usersListArea)
        addSection:Dock(BOTTOM)
        addSection:SetTall(36)
        addSection:DockMargin(0, 6, 0, 0)
        addSection.Paint = function() end
        local steamidEntry = vgui.Create("DTextEntry", addSection)
        steamidEntry:Dock(LEFT)
        steamidEntry:SetWide(180)
        steamidEntry:SetPlaceholderText("Add by SteamID")
        steamidEntry:DockMargin(0, 0, 6, 0)
        steamidEntry.OnFocusGained = function()
            if Inventory then Inventory.AdminPanelSteamIDFocused = true end
        end
        steamidEntry.OnFocusLost = function()
            if Inventory then Inventory.AdminPanelSteamIDFocused = false end
        end
        local addRankBtn = vgui.Create("DButton", addSection)
        addRankBtn:Dock(LEFT)
        addRankBtn:SetWide(72)
        addRankBtn:SetText("Set Rank")
        addRankBtn.DoClick = function()
            local sid = steamidEntry:GetValue()
            if sid then sid = sid:gsub("^%s+", ""):gsub("%s+$", "") end
            if not sid or sid == "" then LocalPlayer():ChatPrint("Enter a SteamID") return end
            local menu = DermaMenu()
            for _, r in ipairs({{"User", "user"}, {"Member", "member"}, {"Donator", "donator"}, {"Super Donator", "sdonator"}, {"Admin", "admin"}, {"Super Admin", "superadmin"}}) do
                menu:AddOption(r[1], function()
                    net.Start("Admin_SetRank")
                    net.WriteString(sid)
                    net.WriteString(r[2])
                    net.SendToServer()
                end)
            end
            menu:Open()
        end
    end

    net.Receive("Admin_SendUserList", function()
        userList:Clear()
        local n = net.ReadUInt(16)
        for i = 1, n do
            local steamid = net.ReadString()
            local rank = net.ReadString()
            local name = net.ReadString()
            local displayRank = (Admin.RankDisplayNames and Admin.RankDisplayNames[rank]) or rank
            userList:AddLine(name, steamid, displayRank)
        end
    end)

    sheet:AddSheet("Server", playersPanel, "icon16/computer.png")
    sheet:AddSheet("Users", usersPanel, "icon16/group.png")
    timer.Simple(0, function()
        net.Start("Admin_RequestOnlineList")
        net.SendToServer()
    end)

    -- Ban List tab: request server to send banned_user.cfg lines; Add ban (SteamID/Name, reason, time)
    local banListPanel = vgui.Create("DPanel", sheet)
    banListPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end
    local banRefreshBtn = vgui.Create("DButton", banListPanel)
    banRefreshBtn:SetPos(10, 10)
    banRefreshBtn:SetSize(90, 28)
    banRefreshBtn:SetText("Refresh")
    banRefreshBtn.DoClick = function()
        net.Start("Admin_RequestBanList")
        net.SendToServer()
    end
    local banAddBtn = vgui.Create("DButton", banListPanel)
    banAddBtn:SetPos(108, 10)
    banAddBtn:SetSize(90, 28)
    banAddBtn:SetText("Add ban")
    banAddBtn.DoClick = function()
        if not LocalPlayer():IsAdmin() then LocalPlayer():ChatPrint("Admin only.") return end
        local frame = vgui.Create("DFrame")
        frame:SetSize(440, 280)
        frame:Center()
        frame:SetTitle("Add to ban list")
        frame:MakePopup()
        frame.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(28, 34, 44, 250))
            surface.SetDrawColor(60, 72, 88, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        local pad, rowH, y = 12, 52, 28
        local labelW = 416
        local colorLabel = Color(200, 208, 220)

        -- Player: dropdown (pick from online) + text entry (SteamID or name)
        local idL = vgui.Create("DLabel", frame)
        idL:SetPos(pad, y)
        idL:SetSize(labelW, 18)
        idL:SetText("Player (must be online) — pick from list or type SteamID / name")
        idL:SetColor(colorLabel)
        idL:SetWrap(true)
        y = y + 18
        local playerCombo = vgui.Create("DComboBox", frame)
        playerCombo:SetPos(pad, y)
        playerCombo:SetSize(labelW, 22)
        playerCombo:SetValue("Select player...")
        playerCombo:AddChoice("— Type below —", nil)
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then
                playerCombo:AddChoice(p:Nick() .. "  (" .. p:SteamID() .. ")", p:SteamID())
            end
        end
        playerCombo.OnSelect = function(_, idx, val, data)
            if data then
                idE:SetValue(data)
            end
        end
        y = y + 26
        local idE = vgui.Create("DTextEntry", frame)
        idE:SetPos(pad, y)
        idE:SetSize(labelW, 22)
        idE:SetPlaceholderText("STEAM_0:0:12345 or player name")
        y = y + rowH

        -- Reason
        local reasonL = vgui.Create("DLabel", frame)
        reasonL:SetPos(pad, y)
        reasonL:SetSize(labelW, 18)
        reasonL:SetText("Reason")
        reasonL:SetColor(colorLabel)
        y = y + 18
        local reasonE = vgui.Create("DTextEntry", frame)
        reasonE:SetPos(pad, y)
        reasonE:SetSize(labelW, 22)
        reasonE:SetValue("Banned by admin")
        y = y + rowH

        -- Duration
        local durL = vgui.Create("DLabel", frame)
        durL:SetPos(pad, y)
        durL:SetSize(labelW, 18)
        durL:SetText("Duration (minutes) — 0 = permanent")
        durL:SetColor(colorLabel)
        y = y + 18
        local durE = vgui.Create("DNumberWang", frame)
        durE:SetPos(pad, y)
        durE:SetSize(120, 22)
        durE:SetMin(0)
        durE:SetMax(99999)
        durE:SetValue(0)
        y = y + 32

        local ok = vgui.Create("DButton", frame)
        ok:SetPos(pad, y)
        ok:SetSize(90, 28)
        ok:SetText("Add ban")
        ok.DoClick = function()
            local sidOrName = string.Trim(idE:GetValue() or "")
            local reason = string.Trim(reasonE:GetValue() or "")
            local duration = math.Clamp(math.floor(tonumber(durE:GetValue()) or 0), 0, 65535)
            frame:Close()
            if sidOrName == "" then LocalPlayer():ChatPrint("Enter SteamID or name.") return end
            net.Start("Admin_AddBan")
            net.WriteString(sidOrName)
            net.WriteString(reason)
            net.WriteUInt(duration, 16)
            net.SendToServer()
        end
        local cancel = vgui.Create("DButton", frame)
        cancel:SetPos(pad + 98, y)
        cancel:SetSize(80, 28)
        cancel:SetText("Cancel")
        cancel.DoClick = function() frame:Close() end
    end
    local banListView = vgui.Create("DListView", banListPanel)
    banListView:Dock(FILL)
    banListView:DockMargin(10, 44, 10, 10)
    banListView:AddColumn("Ban entry (banid duration userid reason) – export cfg/banned_user.cfg for website")
    Admin.CurrentBanListView = banListView
    sheet:AddSheet("Ban List", banListPanel, "icon16/user_delete.png")

    -- Logs tab: item abuse, kills (who/time/where/weapon), etc.
    local logsPanel = vgui.Create("DPanel", sheet)
    logsPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end
    local logRefreshBtn = vgui.Create("DButton", logsPanel)
    logRefreshBtn:SetPos(10, 10)
    logRefreshBtn:SetSize(90, 28)
    logRefreshBtn:SetText("Refresh")
    logRefreshBtn.DoClick = function()
        net.Start("Admin_RequestLogs")
        net.SendToServer()
    end
    local logCategoryFilter = vgui.Create("DComboBox", logsPanel)
    logCategoryFilter:SetPos(110, 10)
    logCategoryFilter:SetSize(120, 28)
    logCategoryFilter:SetValue("All")
    logCategoryFilter:AddChoice("All")
    logCategoryFilter:AddChoice("kill")
    logCategoryFilter:AddChoice("item")
    logCategoryFilter:AddChoice("misc")
    Admin.CurrentLogCategoryFilter = logCategoryFilter
    local logsListView = vgui.Create("DListView", logsPanel)
    logsListView:Dock(FILL)
    logsListView:DockMargin(10, 44, 10, 10)
    logsListView:AddColumn("Time"):SetFixedWidth(80)
    logsListView:AddColumn("Category"):SetFixedWidth(60)
    logsListView:AddColumn("Message")
    Admin.CurrentLogsListView = logsListView
    logCategoryFilter.OnSelect = function(self, index, value)
        if not IsValid(logsListView) then return end
        logsListView:Clear()
        for _, e in ipairs(Admin.CurrentLogsData) do
            if value == "All" or e.cat == value then
                logsListView:AddLine(os.date("%H:%M:%S", e.t), e.cat, e.msg)
            end
        end
    end
    sheet:AddSheet("Logs", logsPanel, "icon16/script.png")

    -- Settings tab (Super Admin only): ranks, gangs, player levels, RP, server limits, NPC spawns
    local settingsPanel = vgui.Create("DPanel", sheet)
    settingsPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end
    local settingsLabel = vgui.Create("DLabel", settingsPanel)
    settingsLabel:SetText(isSuperAdmin and "Settings – Super Admin only.\nAdd/change/remove user ranks • Gangs • Player levels • RP • Server limits (coming soon)." or "Access denied – Super Admin only.")
    settingsLabel:SetPos(10, 10)
    settingsLabel:SetWrap(true)
    settingsLabel:SetSize(400, 60)
    settingsLabel:SetColor(isSuperAdmin and Color(200, 200, 210) or Color(200, 100, 100))
    if isSuperAdmin then
        local npcSpawnsBtn = vgui.Create("DButton", settingsPanel)
        npcSpawnsBtn:SetPos(10, 78)
        npcSpawnsBtn:SetSize(160, 28)
        npcSpawnsBtn:SetText("NPC spawns")
        npcSpawnsBtn.DoClick = function()
            if OpenNPCSpawnEditor then OpenNPCSpawnEditor() end
        end
    end
    sheet:AddSheet("Settings", settingsPanel, "icon16/cog.png")

    -- Request user list on open
    timer.Simple(0.1, function()
        if IsValid(parent) then
            net.Start("Admin_RequestUserList")
            net.SendToServer()
        end
    end)
    -- Admin panel: 3 tabs (Players=user list, Logs, Settings=Super Admin only) above
end

-- Give Item menu: Items tab + Resources tab. Pass targetSteamID + targetName to give to selected player.
-- parent is optional (unused; creates own frame). Called as BuildAdminItemBrowser(nil, steamID, name) from admin panel.
function BuildAdminItemBrowser(parent, targetSteamID, targetName)
    local targetLabel = targetSteamID and targetName and ("Give to: " .. targetName) or "Give to self"
    local frame = vgui.Create("DFrame")
    frame:SetSize(720, 520)
    frame:Center()
    frame:SetTitle("Give Item – " .. targetLabel)
    frame:MakePopup()
    frame:ShowCloseButton(true)
    function frame:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(22, 28, 38, 250))
        surface.SetDrawColor(70, 85, 100, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end
    Inventory = Inventory or {}
    Inventory.UIOverlayOpen = true
    frame.OnClose = function()
        if Inventory then Inventory.UIOverlayOpen = false end
    end

    local function giveItem(id, count)
        count = count or 1
        if targetSteamID then
            RunConsoleCommand("inv_giveitem_to", targetSteamID, id, tostring(count))
        else
            RunConsoleCommand("inv_giveitem", id, tostring(count))
        end
    end

    local function giveResource(resourceID, amount)
        amount = amount or 1
        local sid = targetSteamID or (IsValid(LocalPlayer()) and LocalPlayer():SteamID())
        if sid then
            RunConsoleCommand("inv_giveresource", sid, resourceID, tostring(amount))
        end
    end

    -- Single panel: items list + Give resource bar (no Resources tab)
    local itemsPanel = vgui.Create("DPanel", frame)
    itemsPanel:Dock(FILL)
    itemsPanel:DockMargin(8, 8, 8, 8)
    itemsPanel.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 36, 48, 200)) end

    local searchWrap = vgui.Create("DPanel", itemsPanel)
    searchWrap:Dock(TOP)
    searchWrap:SetTall(32)
    searchWrap.Paint = function() end
    local search = vgui.Create("DTextEntry", searchWrap)
    search:Dock(FILL)
    search:DockMargin(0, 2, 0, 2)
    search:SetPlaceholderText("Search items...")

    local list = vgui.Create("DListView", itemsPanel)
    list:Dock(FILL)
    list:DockMargin(8, 2, 8, 4)
    list:AddColumn("ID"):SetFixedWidth(200)
    list:AddColumn("Name"):SetFixedWidth(180)
    list:AddColumn("Class/Model"):SetFixedWidth(120)

    local function refreshItems()
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
    search.OnValueChange = refreshItems
    refreshItems()

    local function openCreateItemDialog(itemId)
        local sid = targetSteamID or (IsValid(LocalPlayer()) and LocalPlayer():SteamID() or "")
        if sid == "" then return end
        local dlg = vgui.Create("DFrame")
        dlg:SetSize(300, 250)
        -- Position left of content so it doesn't cover the item list
        if IsValid(frame) then
            local fx, fy = frame:GetPos()
            dlg:SetPos(fx + 12, fy + 44)
        else
            dlg:Center()
        end
        dlg:SetTitle("Create item – " .. (Inventory.Items and Inventory.Items[itemId] and (Inventory.Items[itemId].name or itemId) or itemId))
        dlg:MakePopup()
        dlg:ShowCloseButton(true)
        function dlg:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(28, 34, 44, 250))
            surface.SetDrawColor(60, 72, 88, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        local y = 36
        local pad = 10
        local rarities = Inventory.Rarities or { "Common", "Rare", "Epic", "Legendary", "Unique" }
        local rarityCombo = vgui.Create("DComboBox", dlg)
        rarityCombo:SetPos(pad, y)
        rarityCombo:SetSize(200, 22)
        rarityCombo:SetValue("(default)")
        rarityCombo:AddChoice("(default)")
        for _, r in ipairs(rarities) do
            rarityCombo:AddChoice(r)
        end
        local rarityLabel = vgui.Create("DLabel", dlg)
        rarityLabel:SetPos(pad, y - 14)
        rarityLabel:SetText("Rarity")
        rarityLabel:SetColor(Color(200, 208, 220))
        y = y + 36
        local randomRarityCheck = vgui.Create("DCheckBoxLabel", dlg)
        randomRarityCheck:SetPos(pad, y)
        randomRarityCheck:SetText("Random rarity (roll on create)")
        randomRarityCheck:SetChecked(false)
        randomRarityCheck:SetTextColor(Color(200, 208, 220))
        y = y + 28
        local slotsLabel = vgui.Create("DLabel", dlg)
        slotsLabel:SetPos(pad, y - 14)
        slotsLabel:SetText("Slots (0–6)")
        slotsLabel:SetColor(Color(200, 208, 220))
        local slotsWang = vgui.Create("DNumberWang", dlg)
        slotsWang:SetPos(pad, y)
        slotsWang:SetSize(80, 22)
        slotsWang:SetMin(0)
        slotsWang:SetMax(6)
        slotsWang:SetValue(0)
        y = y + 36
        local crafterLabel = vgui.Create("DLabel", dlg)
        crafterLabel:SetPos(pad, y - 14)
        crafterLabel:SetText("Crafter name")
        crafterLabel:SetColor(Color(200, 208, 220))
        local crafterEntry = vgui.Create("DTextEntry", dlg)
        crafterEntry:SetPos(pad, y)
        crafterEntry:SetSize(200, 22)
        crafterEntry:SetPlaceholderText("(optional)")
        y = y + 36
        local countLabel = vgui.Create("DLabel", dlg)
        countLabel:SetPos(pad, y - 14)
        countLabel:SetText("Count")
        countLabel:SetColor(Color(200, 208, 220))
        local countWang = vgui.Create("DNumberWang", dlg)
        countWang:SetPos(pad, y)
        countWang:SetSize(80, 22)
        countWang:SetMin(1)
        countWang:SetMax(999)
        countWang:SetValue(1)
        y = y + 40
        local giveBtn = vgui.Create("DButton", dlg)
        giveBtn:SetPos(pad, y)
        giveBtn:SetSize(120, 28)
        giveBtn:SetText("Give item")
        giveBtn.DoClick = function()
            local count = math.Clamp(tonumber(countWang:GetValue()) or 1, 1, 999)
            local rarity = ""
            if randomRarityCheck:GetChecked() then
                rarity = rarities[math.random(#rarities)]
            else
                local val = rarityCombo:GetValue()
                if val ~= "(default)" then rarity = val end
            end
            local slots = math.Clamp(tonumber(slotsWang:GetValue()) or 0, 0, 6)
            local crafterName = string.Trim(crafterEntry:GetValue() or "")
            net.Start(Inventory.NET.AdminCreateItemFor)
            net.WriteString(sid)
            net.WriteString(itemId)
            net.WriteUInt(count, 16)
            net.WriteString(rarity)
            net.WriteUInt(0, 16)
            net.WriteBool(true)
            net.WriteString(crafterName)
            net.WriteUInt(slots, 4)
            net.WriteString("")
            net.SendToServer()
            dlg:Close()
        end
    end

    list.OnRowRightClick = function(self, lineId, line)
        local id = line:GetColumnText(1)
        local m = DermaMenu()
        m:AddOption("Give 1x", function() giveItem(id, 1) end):SetIcon("icon16/add.png")
        m:AddOption("Give 10x", function() giveItem(id, 10) end):SetIcon("icon16/add.png")
        m:AddOption("Create with options...", function() openCreateItemDialog(id) end):SetIcon("icon16/cog.png")
        m:AddOption("Copy ID", function() SetClipboardText(id) end):SetIcon("icon16/page_copy.png")
        m:Open()
    end

    list.OnRowDoubleClick = function(self, lineId, line)
        giveItem(line:GetColumnText(1), 1)
    end

    -- Give resource bar (single row: resource dropdown + amount + Give)
    local defaultResources = {
        { id = "rock", name = "Rock" }, { id = "copper", name = "Copper" },
        { id = "iron", name = "Iron" }, { id = "steel", name = "Steel" },
        { id = "titanium", name = "Titanium" }, { id = "emerald", name = "Emerald" },
        { id = "ruby", name = "Ruby" }, { id = "sapphire", name = "Sapphire" },
        { id = "obsidian", name = "Obsidian" }, { id = "diamond", name = "Diamond" }
    }
    local resBar = vgui.Create("DPanel", itemsPanel)
    resBar:Dock(BOTTOM)
    resBar:SetTall(36)
    resBar:DockMargin(8, 4, 8, 8)
    resBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(38, 44, 56, 220))
        surface.SetDrawColor(55, 65, 80, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    local resCombo = vgui.Create("DComboBox", resBar)
    resCombo:Dock(LEFT)
    resCombo:SetWide(140)
    resCombo:DockMargin(8, 6, 6, 6)
    for _, data in ipairs(defaultResources) do
        resCombo:AddChoice(data.name, data.id)
    end
    resCombo:ChooseOption(defaultResources[1].name)
    local resAmount = vgui.Create("DNumberWang", resBar)
    resAmount:Dock(LEFT)
    resAmount:SetWide(60)
    resAmount:DockMargin(0, 6, 6, 6)
    resAmount:SetMin(1)
    resAmount:SetMax(9999)
    resAmount:SetValue(1)
    local resGiveBtn = vgui.Create("DButton", resBar)
    resGiveBtn:Dock(LEFT)
    resGiveBtn:SetWide(80)
    resGiveBtn:DockMargin(0, 6, 8, 6)
    resGiveBtn:SetText("Give")
    resGiveBtn.DoClick = function()
        local _, resId = resCombo:GetSelected()
        if resId then giveResource(resId, tonumber(resAmount:GetValue()) or 1) end
    end

    local hint = vgui.Create("DLabel", frame)
    hint:Dock(BOTTOM)
    hint:SetTall(20)
    hint:SetText(targetSteamID and ("Target: " .. (targetName or targetSteamID)) or "No target – giving to self")
    hint:SetColor(Color(150, 160, 180))
    hint:DockMargin(8, 0, 8, 4)
end