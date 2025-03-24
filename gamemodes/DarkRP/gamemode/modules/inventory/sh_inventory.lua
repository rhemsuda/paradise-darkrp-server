-- gamemodes/darkrp/gamemode/sh_inventory.lua

print("[Inventory Module] sh_inventory.lua loaded successfully")

-- Define network strings (server only)
if SERVER then
    util.AddNetworkString("SyncInventory")
    util.AddNetworkString("DropItem")
    util.AddNetworkString("UseItem")
    util.AddNetworkString("DeleteItem")
    util.AddNetworkString("InventoryMessage")
    util.AddNetworkString("SyncResources")
    util.AddNetworkString("DropResource")
end

-- Include shared items
if file.Exists("modules/inventory/sh_items.lua", "LUA") then
    include("modules/inventory/sh_items.lua")
    if SERVER then AddCSLuaFile("modules/inventory/sh_items.lua") end
end

-- Server-side logic
if SERVER then
    local PlayerInventories = {}
    local PickupCooldown = {}

    hook.Remove("PlayerLoadout", "DarkRP_PlayerLoadout")

    hook.Add("DarkRPDBInitialized", "InitCustomInventoryTable", function()
        MySQLite.begin()
        MySQLite.queueQuery([[
            CREATE TABLE IF NOT EXISTS darkrp_custom_inventory (
                steamid VARCHAR(20) NOT NULL PRIMARY KEY,
                items TEXT NOT NULL,
                resources TEXT NOT NULL DEFAULT '{}'
            );
        ]])
        MySQLite.queueQuery([[
            ALTER TABLE darkrp_custom_inventory ADD COLUMN resources TEXT NOT NULL DEFAULT '{}'
            WHERE NOT EXISTS (SELECT 1 FROM pragma_table_info('darkrp_custom_inventory') WHERE name = 'resources');
        ]])
        MySQLite.commit(function()
            print("[Custom Inventory] Table 'darkrp_custom_inventory' initialized or updated successfully!")
        end)
    end)

    hook.Add("InitPostEntity", "DebugRPExtraTeams", function()
        print("[Debug] RPExtraTeams count: " .. table.Count(RPExtraTeams))
        for k, v in pairs(RPExtraTeams) do
            print("[Debug] Team " .. k .. ": " .. v.name)
        end
    end)

    local function SendInventoryMessage(ply, message)
        if not IsValid(ply) then return end
        net.Start("InventoryMessage")
        net.WriteString(message)
        net.Send(ply)
        print("[Inventory Log] " .. ply:Nick() .. " (" .. ply:SteamID() .. "): " .. message)
    end

    local function LoadPlayerInventory(ply)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        MySQLite.query([[
            SELECT items, resources FROM darkrp_custom_inventory WHERE steamid = ]] .. MySQLite.SQLStr(steamID) .. [[
        ]], function(data)
            if data and data[1] then
                PlayerInventories[steamID] = {
                    items = util.JSONToTable(data[1].items or "{}") or {},
                    resources = util.JSONToTable(data[1].resources or "{}") or {}
                }
            else
                PlayerInventories[steamID] = { items = {}, resources = {} }
            end
            net.Start("SyncInventory")
            net.WriteTable(PlayerInventories[steamID].items)
            net.Send(ply)
            net.Start("SyncResources")
            net.WriteTable(PlayerInventories[steamID].resources)
            net.Send(ply)
        end, function(err)
            print("[Custom Inventory] Error loading inventory for " .. steamID .. ": " .. err)
            PlayerInventories[steamID] = { items = {}, resources = {} }
        end)
    end

    local function SavePlayerInventory(ply)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
        local itemsJson = util.TableToJSON(inv.items)
        local resourcesJson = util.TableToJSON(inv.resources)
        MySQLite.query([[
            REPLACE INTO darkrp_custom_inventory (steamid, items, resources) VALUES (]] .. 
            MySQLite.SQLStr(steamID) .. [[, ]] .. MySQLite.SQLStr(itemsJson) .. [[, ]] .. MySQLite.SQLStr(resourcesJson) .. [[)
        ]], nil, function(err)
            print("[Custom Inventory] Error saving inventory for " .. steamID .. ": " .. err)
        end)
    end

    function AddResourceToInventory(ply, resourceID, amount)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
        inv.resources[resourceID] = (inv.resources[resourceID] or 0) + (amount or 1)
        PlayerInventories[steamID] = inv
        net.Start("SyncResources")
        net.WriteTable(inv.resources)
        net.Send(ply)
        SavePlayerInventory(ply)
        SendInventoryMessage(ply, "Added " .. amount .. " " .. resourceID .. " to your resources.")
    end

    function RemoveResourceFromInventory(ply, resourceID, amount)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
        if not inv.resources[resourceID] or inv.resources[resourceID] < amount then return end
        inv.resources[resourceID] = inv.resources[resourceID] - amount
        if inv.resources[resourceID] <= 0 then
            inv.resources[resourceID] = nil
        end
        PlayerInventories[steamID] = inv
        net.Start("SyncResources")
        net.WriteTable(inv.resources)
        net.Send(ply)
        SavePlayerInventory(ply)
        SendInventoryMessage(ply, "Dropped " .. amount .. " " .. resourceID .. ".")
    end

    function AddItemToInventory(ply, itemID, amount)
        if not IsValid(ply) or not InventoryItems[itemID] then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
        local maxStack = InventoryItems[itemID].maxStack or 64
        local newAmount = math.min((inv.items[itemID] or 0) + (amount or 1), maxStack)
        inv.items[itemID] = newAmount
        PlayerInventories[steamID] = inv
        net.Start("SyncInventory")
        net.WriteTable(inv.items)
        net.Send(ply)
        SavePlayerInventory(ply)
        SendInventoryMessage(ply, "Added " .. amount .. " " .. InventoryItems[itemID].name .. "(s) to your inventory.")
    end

    local function RemoveItemFromInventory(ply, itemID, amount)
        if not IsValid(ply) or not InventoryItems[itemID] then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
        if not inv.items[itemID] or inv.items[itemID] < amount then return end
        inv.items[itemID] = inv.items[itemID] - amount
        if inv.items[itemID] <= 0 then
            inv.items[itemID] = nil
        end
        PlayerInventories[steamID] = inv
        net.Start("SyncInventory")
        net.WriteTable(inv.items)
        net.Send(ply)
        SavePlayerInventory(ply)
    end

    concommand.Add("addresource", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsSuperAdmin() then
            SendInventoryMessage(ply, "You must be a superadmin to use this command.")
            return
        end
        local resourceID = args[1]
        local amount = tonumber(args[2]) or 1
        if not resourceID then
            SendInventoryMessage(ply, "Specify a resource ID (e.g., 'addresource rock 10').")
            return
        end
        AddResourceToInventory(ply, resourceID, amount)
    end)

    concommand.Add("open_resources", function(ply)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
        net.Start("SyncResources")
        net.WriteTable(inv.resources)
        net.Send(ply)
    end)

    net.Receive("DropItem", function(len, ply)
        local itemID = net.ReadString()
        local amount = net.ReadUInt(8)
        if not InventoryItems[itemID] or amount < 1 then return end
        RemoveItemFromInventory(ply, itemID, amount)
        SendInventoryMessage(ply, "Dropped " .. amount .. " " .. InventoryItems[itemID].name .. "(s).")
        local itemData = InventoryItems[itemID]
        for i = 1, amount do
            local ent = ents.Create("prop_physics")
            if IsValid(ent) then
                ent:SetModel(itemData.model)
                ent:SetPos(ply:EyePos() + ply:GetForward() * 50 + Vector(0, 0, 10 * i))
                ent:Spawn()
                ent:SetNWString("ItemID", itemID)
                ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
            end
        end
    end)

    net.Receive("UseItem", function(len, ply)
        local itemID = net.ReadString()
        local itemData = InventoryItems[itemID]
        if not itemData or not itemData.useFunction then return end
        itemData.useFunction(ply)
        RemoveItemFromInventory(ply, itemID, 1)
        SendInventoryMessage(ply, "Used 1 " .. itemData.name .. ".")
    end)

    net.Receive("DeleteItem", function(len, ply)
        local itemID = net.ReadString()
        local amount = net.ReadUInt(8)
        if not InventoryItems[itemID] or amount < 1 then return end
        RemoveItemFromInventory(ply, itemID, amount)
        SendInventoryMessage(ply, "Deleted " .. amount .. " " .. InventoryItems[itemID].name .. "(s).")
    end)

    net.Receive("DropResource", function(len, ply)
        local resourceID = net.ReadString()
        local amount = net.ReadUInt(16)
        if amount < 1 then return end
        RemoveResourceFromInventory(ply, resourceID, amount)
    end)

    hook.Add("PlayerInitialSpawn", "Inventory_InitInventory", function(ply)
        if not IsValid(ply) then return end
        LoadPlayerInventory(ply)
        print("[Debug] InitialSpawn for " .. ply:Nick() .. " - Team: " .. ply:Team() .. " (" .. team.GetName(ply:Team()) .. ")")
    end)

    hook.Add("PlayerSpawn", "Inventory_SetupTeam", function(ply)
        if not IsValid(ply) then return end
        local currentTeam = ply:Team()
        local defaultTeam = TEAM_CITIZEN or 1
        if not RPExtraTeams[currentTeam] or currentTeam == TEAM_UNASSIGNED then
            if RPExtraTeams[defaultTeam] then
                ply:changeTeam(defaultTeam, true)
                print("[Debug] Forced " .. ply:Nick() .. " to TEAM_CITIZEN (Team " .. defaultTeam .. ") in PlayerSpawn")
            else
                for teamID, job in pairs(RPExtraTeams) do
                    if job and teamID then
                        ply:changeTeam(teamID, true)
                        print("[Debug] Forced " .. ply:Nick() .. " to fallback team " .. teamID .. " (" .. job.name .. ") in PlayerSpawn")
                        break
                    end
                end
            end
        end
        print("[Debug] Team after spawn: " .. ply:Team() .. " (" .. team.GetName(ply:Team()) .. ")")
    end)

    hook.Add("PlayerLoadout", "Inventory_GiveLoadout", function(ply)
        if not IsValid(ply) then return end
        print("[Debug] Running Custom PlayerLoadout for " .. ply:Nick() .. " - Team: " .. ply:Team())
        for k, v in pairs(GAMEMODE.Config.DefaultWeapons) do
            ply:Give(v)
        end
        local team = ply:Team()
        local jobTable = RPExtraTeams[team]
        if jobTable then
            if jobTable.weapons then
                for k, v in pairs(jobTable.weapons) do
                    ply:Give(v)
                end
            end
        else
            print("[Warning] " .. ply:Nick() .. " has invalid team " .. team .. " in PlayerLoadout")
        end
        return true
    end, -20)

    hook.Add("PlayerDisconnected", "SaveInventoryOnDisconnect", function(ply)
        SavePlayerInventory(ply)
    end)

    hook.Add("PlayerUse", "PickupInventoryItem", function(ply, ent)
        local itemID = ent:GetNWString("ItemID")
        if not itemID or itemID == "" then return end
        if InventoryItems[itemID] then
            AddItemToInventory(ply, itemID, 1)
            ent:Remove()
            SendInventoryMessage(ply, "Picked up 1 " .. InventoryItems[itemID].name .. ".")
            return true
        else
            local entIndex = ent:EntIndex()
            local steamID = ply:SteamID()
            PickupCooldown[steamID] = PickupCooldown[steamID] or {}
            local lastMessageTime = PickupCooldown[steamID][entIndex] or 0
            if CurTime() - lastMessageTime > 5 then
                SendInventoryMessage(ply, "You cannot pick up this item.")
                PickupCooldown[steamID][entIndex] = CurTime()
            end
        end
    end)

    concommand.Add("additem", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then
            SendInventoryMessage(ply, "You must be a superadmin to use this command.")
            return
        end
        local itemID = args[1]
        local amount = tonumber(args[2]) or 1
        AddItemToInventory(ply, itemID, amount)
    end)
end

-- Client-side logic
if CLIENT then
    local Resources = {}
    local Inventory = {}
    local InventoryFrame = nil
    local ToolSelectorFrame = nil
    local isInventoryOpen = false
    local isToolSelectorOpen = false
    local isQKeyHeld = false -- Track whether the Q key is being held

    -- List of allowed tools
    local allowedTools = {
        "button",
        "fading_door",
        "keypad",
        "camera",
        "nocollide",
        "remover"
    }

    -- Debug available tools early on client initialization
    hook.Add("InitPostEntity", "DebugAvailableTools", function()
        print("[Debug] Available tools in list.Get('Tool') at InitPostEntity:")
        local toolList = list.Get("Tool")
        if not toolList or table.IsEmpty(toolList) then
            print("[Debug] Tool list is empty or nil!")
        else
            for toolClass, toolData in pairs(toolList) do
                print("[Debug] Tool: " .. toolClass .. " (Name: " .. (toolData.Name or "Unknown") .. ")")
            end
        end
    end)

    -- Function to open the Tool Selector menu
    local function OpenToolSelector()
        print("[Debug] OpenToolSelector started")

        -- If the menu is already open, don't create a new one
        if isToolSelectorOpen and IsValid(ToolSelectorFrame) then
            print("[Debug] ToolSelectorFrame already open, skipping creation")
            return
        elseif ToolSelectorFrame ~= nil then
            print("[Debug] ToolSelectorFrame was invalid, resetting")
            ToolSelectorFrame = nil
        end

        -- Ensure the screen clicker is enabled
        gui.EnableScreenClicker(true)
        print("[Debug] gui.EnableScreenClicker(true) called for Tool Selector")

        -- Create the tool selector frame
        ToolSelectorFrame = vgui.Create("DFrame")
        print("[Debug] ToolSelectorFrame created: " .. tostring(ToolSelectorFrame))
        print("[Debug] IsValid(ToolSelectorFrame): " .. tostring(IsValid(ToolSelectorFrame)))

        ToolSelectorFrame:SetSize(300, 650) -- Match the height of the inventory menu
        ToolSelectorFrame:SetPos(ScrW()/2 + 510, ScrH()/2 - 325) -- Position to the right of the inventory menu
        ToolSelectorFrame:SetTitle("Tool Selector")
        ToolSelectorFrame:SetDraggable(false) -- Make non-draggable
        ToolSelectorFrame:ShowCloseButton(false) -- No close button, closes with inventory
        ToolSelectorFrame:SetVisible(true)
        ToolSelectorFrame:MakePopup()
        print("[Debug] ToolSelectorFrame after MakePopup: " .. tostring(IsValid(ToolSelectorFrame)))

        -- Explicitly set focus on the Tool Selector menu
        ToolSelectorFrame:SetMouseInputEnabled(true)
        ToolSelectorFrame:SetKeyboardInputEnabled(true)
        ToolSelectorFrame:RequestFocus()
        print("[Debug] Focus requested on ToolSelectorFrame")
        print("[Debug] ToolSelectorFrame has focus: " .. tostring(ToolSelectorFrame:HasFocus()))

        ToolSelectorFrame.OnClose = function()
            gui.EnableScreenClicker(false)
            print("[Debug] gui.EnableScreenClicker(false) called (ToolSelectorFrame closed)")
            isToolSelectorOpen = false
            ToolSelectorFrame = nil
            print("[Debug] ToolSelectorFrame closed")
            -- Reset VGUI focus to ensure no lingering focus issues
            if gui.IsGameUIVisible() then
                gui.EnableScreenClicker(false)
                gui.EnableScreenClicker(true)
                print("[Debug] Reset VGUI focus after closing Tool Selector")
            end
        end

        -- Match the color scheme to the inventory menu
        ToolSelectorFrame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225)) -- Match inventory frame background
        end

        local x, y = ToolSelectorFrame:GetPos()
        print("[Debug] ToolSelectorFrame position: " .. x .. ", " .. y)

        -- Create a scroll panel for the tools
        local scroll = vgui.Create("DScrollPanel", ToolSelectorFrame)
        scroll:Dock(FILL)
        print("[Debug] Tool scroll panel created")

        -- Create a category for the tools
        local cat = vgui.Create("DCollapsibleCategory", scroll)
        cat:Dock(TOP)
        cat:SetLabel("Tools")
        cat:SetExpanded(true)
        cat:DockMargin(0, 0, 0, 5)

        local toolList = vgui.Create("DPanelList", cat)
        toolList:EnableVerticalScrollbar(true)
        toolList:SetTall(600) -- Adjust to fit the frame
        toolList:Dock(FILL)
        cat:SetContents(toolList)
        print("[Debug] Tool list created")

        -- Debug the tool list before creating buttons
        local toolDataList = list.Get("Tool")
        print("[Debug] Checking available tools before creating buttons:")
        if not toolDataList or table.IsEmpty(toolDataList) then
            print("[Debug] Tool list is empty or nil in OpenToolSelector!")
        else
            for toolClass, toolData in pairs(toolDataList) do
                print("[Debug] Available Tool: " .. toolClass .. " (Name: " .. (toolData.Name or "Unknown") .. ")")
            end
        end

        -- Add buttons for each allowed tool
        for _, toolClass in ipairs(allowedTools) do
            local toolData = list.Get("Tool")[toolClass]
            local toolName = toolData and toolData.Name or toolClass

            -- Debug: Log tool availability
            if not toolData then
                print("[Error] Tool not found in list.Get('Tool'): " .. toolClass)
            else
                print("[Debug] Tool found: " .. toolClass .. " (Name: " .. toolName .. ")")
            end

            local toolButton = vgui.Create("DButton")
            toolButton:SetText(toolName)
            toolButton:Dock(TOP)
            toolButton:SetHeight(25)
            toolButton.DoClick = function()
                -- Ensure the toolgun is equipped
                RunConsoleCommand("use", "gmod_tool")
                print("[Debug] Ran 'use gmod_tool' to ensure toolgun is equipped")

                -- Check the active weapon after attempting to equip the toolgun
                timer.Simple(0.05, function()
                    local activeWeapon = LocalPlayer():GetActiveWeapon()
                    if IsValid(activeWeapon) then
                        print("[Debug] Active weapon after 'use gmod_tool': " .. activeWeapon:GetClass())
                    else
                        print("[Debug] No active weapon after 'use gmod_tool'!")
                    end
                end)

                -- Update the player's tool mode
                RunConsoleCommand("gmod_toolmode", toolClass)
                RunConsoleCommand("gmod_tool", toolClass)
                print("[Debug] Selected tool: " .. toolClass)

                -- Ensure tool mode updates
                timer.Simple(0.1, function()
                    local currentMode = GetConVarString("gmod_toolmode")
                    print("[Debug] Current tool mode after delay: " .. currentMode)
                    if currentMode ~= toolClass then
                        print("[Debug] Tool mode did not update to " .. toolClass .. ", forcing again")
                        RunConsoleCommand("use", "gmod_tool")
                        RunConsoleCommand("gmod_toolmode", toolClass)
                        RunConsoleCommand("gmod_tool", toolClass)

                        -- Additional debug for Keypad specifically
                        if toolClass == "keypad" then
                            print("[Debug] Keypad tool mode still not set. Current mode: " .. (currentMode or "nil"))
                            local toolList = list.Get("Tool")
                            if toolList["keypad"] then
                                print("[Debug] Keypad tool exists in tool list, but mode not set!")
                            else
                                print("[Debug] Keypad tool does not exist in tool list!")
                            end
                        end
                    end
                end)

                -- Play a sound for tool selection
                surface.PlaySound("buttons/button14.wav")
            end
            -- Match the button color scheme to the inventory menu
            toolButton.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 50, 240)) -- Match inventory tab background
                if self:IsHovered() then
                    draw.RoundedBox(8, 0, 0, w, h, Color(70, 70, 70, 240)) -- Slightly lighter on hover
                end
            end
            toolList:AddItem(toolButton)
            print("[Debug] Added tool button: " .. toolName)
        end

        isToolSelectorOpen = true
        print("[Debug] Frame valid: " .. tostring(IsValid(ToolSelectorFrame)))
        print("[Debug] Frame visible: " .. tostring(ToolSelectorFrame:IsVisible()))
        print("[Debug] OpenToolSelector completed")
    end

    local function BuildInventoryUI(parent)
        if not IsValid(parent) then
            print("[Debug] BuildInventoryUI: Parent is nil or invalid, aborting")
            return
        end
        print("[Debug] Building Inventory UI")
        -- Clear existing children to prevent lingering panels
        for _, child in pairs(parent:GetChildren()) do
            child:Remove()
        end
        print("[Debug] Cleared existing children from inventory tab")

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)
        print("[Debug] Scroll panel created")

        local layout = vgui.Create("DIconLayout", scroll)
        layout:Dock(FILL)
        layout:SetSpaceX(8)
        layout:SetSpaceY(8)
        print("[Debug] Layout created")

        local activeMenu = nil

        for itemID, amount in pairs(Inventory) do
            if InventoryItems[itemID] then
                local itemPanel = layout:Add("DPanel")
                itemPanel:SetSize(90, 101)
                itemPanel.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200))
                end
                print("[Debug] Item panel created for " .. itemID)

                local model = vgui.Create("DModelPanel", itemPanel)
                model:SetSize(70, 70)
                model:SetPos(10, 5)
                model:SetModel(InventoryItems[itemID].model or "models/error.mdl")
                model:SetFOV(20)
                model:SetCamPos(Vector(15, 15, 15))
                model:SetLookAt(Vector(0, 0, 0))
                local x, y = model:GetPos()
                print("[Debug] DModelPanel created for " .. itemID .. " at position " .. x .. ", " .. y)
                model.OnMousePressed = function(self, code)
                    if code == MOUSE_LEFT then
                        if IsValid(activeMenu) then
                            activeMenu:Remove()
                        end
                        local menu = DermaMenu()
                        menu:AddOption("Use", function()
                            print("[Debug] Selected Use for " .. itemID)
                            net.Start("UseItem")
                            net.WriteString(itemID)
                            net.SendToServer()
                        end)
                        menu:AddOption("Drop", function()
                            print("[Debug] Selected Drop for " .. itemID)
                            net.Start("DropItem")
                            net.WriteString(itemID)
                            net.WriteUInt(1, 8)
                            net.SendToServer()
                        end)
                        menu:AddOption("Delete", function()
                            print("[Debug] Selected Delete for " .. itemID)
                            net.Start("DeleteItem")
                            net.WriteString(itemID)
                            net.WriteUInt(1, 8)
                            net.SendToServer()
                        end)
                        local x, y = self:LocalToScreen(10, 71)
                        menu:Open(x, y)
                        activeMenu = menu
                        menu.OnRemove = function()
                            activeMenu = nil
                        end
                    end
                end

                local name = vgui.Create("DLabel", itemPanel)
                name:SetText(InventoryItems[itemID].name .. " x" .. amount)
                name:SetPos(10, 76)
                name:SizeToContents()
                name.Think = function(self)
                    local currentAmount = Inventory[itemID] or 0
                    self:SetText(InventoryItems[itemID].name .. " x" .. currentAmount)
                end
                local x, y = name:GetPos()
                print("[Debug] Label created for " .. itemID .. " at position " .. x .. ", " .. y)
            else
                print("[Inventory Error] Unknown item ID: " .. itemID)
            end
        end
        print("[Debug] Inventory UI built")
    end

    local function BuildResourcesMenu(parent)
        if not IsValid(parent) then
            print("[Debug] BuildResourcesMenu: Parent is nil or invalid, aborting")
            return
        end
        print("[Debug] Building Resources UI")
        -- Clear existing children to prevent lingering panels
        for _, child in pairs(parent:GetChildren()) do
            child:Remove()
        end
        print("[Debug] Cleared existing children from resources tab")

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)
        print("[Debug] Resources scroll panel created")

        local categories = {
            { name = "Minerals", items = { "rock", "copper", "iron", "steel", "titanium" } },
            { name = "Gems", items = { "emerald", "ruby", "sapphire", "obsidian", "diamond" } },
            { name = "Lumber", items = { "ash", "birch", "oak", "mahogany", "yew" } }
        }

        local layout = vgui.Create("DIconLayout", scroll)
        layout:Dock(FILL)
        layout:SetSpaceX(10)
        layout:SetSpaceY(10)
        print("[Debug] Resources layout created")

        for _, category in ipairs(categories) do
            local catPanel = layout:Add("DPanel")
            catPanel:SetSize(240, 40 + #category.items * 40)
            catPanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
            end

            local catLabel = vgui.Create("DLabel", catPanel)
            catLabel:SetPos(10, 10)
            catLabel:SetText(category.name)
            catLabel:SetSize(220, 20)
            catLabel:SetColor(Color(255, 215, 0))

            for i, resourceID in ipairs(category.items) do
                local resPanel = vgui.Create("DPanel", catPanel)
                resPanel:SetPos(10, 30 + (i - 1) * 40)
                resPanel:SetSize(220, 30)
                resPanel.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200))
                end

                local displayName = string.upper(resourceID:sub(1,1)) .. resourceID:sub(2)
                local resLabel = vgui.Create("DLabel", resPanel)
                resLabel:SetPos(10, 5)
                resLabel:SetText(displayName .. ": " .. (Resources[resourceID] or 0))
                resLabel:SetSize(200, 20)
                resLabel:SetColor(Color(255, 255, 255))
                resLabel.Think = function(self)
                    local currentAmount = Resources[resourceID] or 0
                    self:SetText(displayName .. ": " .. currentAmount)
                end
                resLabel.OnMousePressed = function(self, code)
                    if code == MOUSE_LEFT and (Resources[resourceID] or 0) > 0 then
                        local menu = DermaMenu()
                        menu:AddOption("Drop Amount", function()
                            Derma_StringRequest(
                                "Drop " .. displayName,
                                "How many " .. displayName .. " to drop? (Max: " .. (Resources[resourceID] or 0) .. ")",
                                "1",
                                function(text)
                                    local dropAmount = math.min(tonumber(text) or 1, Resources[resourceID] or 0)
                                    if dropAmount > 0 then
                                        net.Start("DropResource")
                                        net.WriteString(resourceID)
                                        net.WriteUInt(dropAmount, 16)
                                        net.SendToServer()
                                    end
                                end
                            )
                        end)
                        local x, y = self:LocalToScreen(0, 30)
                        menu:Open(x, y)
                    end
                end
            end
        end
        print("[Debug] Resources UI built")
    end

    local function OpenCustomQMenu()
        print("[Debug] OpenCustomQMenu started")
        if isInventoryOpen and IsValid(InventoryFrame) then
            print("[Debug] InventoryFrame already open, skipping creation")
            return
        elseif InventoryFrame ~= nil then
            print("[Debug] InventoryFrame was invalid, resetting")
            InventoryFrame = nil
        end

        gui.EnableScreenClicker(true)
        InventoryFrame = vgui.Create("DFrame")
        print("[Debug] DFrame created")
        InventoryFrame:SetSize(1000, 650)
        InventoryFrame:SetPos(ScrW()/2 - 500, ScrH()/2 - 325)
        InventoryFrame:SetTitle("Inventory & Resources")
        InventoryFrame:SetDraggable(false) -- Make non-draggable
        InventoryFrame:ShowCloseButton(false) -- No close button, closes on Q release
        InventoryFrame:SetVisible(true)
        InventoryFrame:MakePopup()
        InventoryFrame.OnClose = function()
            gui.EnableScreenClicker(false)
            for _, child in pairs(InventoryFrame:GetChildren()) do
                child:Remove()
            end
            isInventoryOpen = false
            InventoryFrame = nil
            print("[Debug] InventoryFrame closed")

            -- Close the Tool Selector menu when the inventory closes
            print("[Debug] Checking ToolSelectorFrame: isToolSelectorOpen = " .. tostring(isToolSelectorOpen) .. ", ToolSelectorFrame = " .. tostring(ToolSelectorFrame))
            if ToolSelectorFrame ~= nil then
                print("[Debug] IsValid(ToolSelectorFrame): " .. tostring(IsValid(ToolSelectorFrame)))
            end
            if isToolSelectorOpen and ToolSelectorFrame ~= nil then
                ToolSelectorFrame:Close()
                ToolSelectorFrame = nil
                isToolSelectorOpen = false
                print("[Debug] ToolSelectorFrame closed with InventoryFrame")
            else
                print("[Debug] ToolSelectorFrame not closed: isToolSelectorOpen = " .. tostring(isToolSelectorOpen) .. ", ToolSelectorFrame = " .. tostring(ToolSelectorFrame))
            end

            -- Reset VGUI focus to ensure no lingering focus issues
            if gui.IsGameUIVisible() then
                gui.EnableScreenClicker(false)
                gui.EnableScreenClicker(true)
                print("[Debug] Reset VGUI focus after closing Inventory")
            end
        end
        InventoryFrame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225))
        end
        local x, y = InventoryFrame:GetPos()
        print("[Debug] DFrame position: " .. x .. ", " .. y)

        local tabPanel = vgui.Create("DPropertySheet", InventoryFrame)
        tabPanel:Dock(FILL)
        print("[Debug] Tab panel created")

        local inventoryTab = vgui.Create("DPanel", tabPanel)
        inventoryTab.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240))
        end
        BuildInventoryUI(inventoryTab)
        tabPanel:AddSheet("Inventory", inventoryTab, "icon16/briefcase.png")
        print("[Debug] Inventory tab added")

        local resourcesTab = vgui.Create("DPanel", tabPanel)
        resourcesTab.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240))
        end
        BuildResourcesMenu(resourcesTab)
        tabPanel:AddSheet("Resources", resourcesTab, "icon16/box.png")
        print("[Debug] Resources tab added")

        isInventoryOpen = true
        print("[Debug] Frame valid: " .. tostring(IsValid(InventoryFrame)))
        print("[Debug] Frame visible: " .. tostring(InventoryFrame:IsVisible()))
        print("[Debug] OpenCustomQMenu completed")

        -- Open the Tool Selector menu alongside the inventory
        OpenToolSelector()
    end

    -- Use PlayerBindPress to open the menu
    hook.Add("PlayerBindPress", "CustomMenuBinds", function(ply, bind, pressed)
        if bind == "+menu" then
            print("[Debug] PlayerBindPress: +menu detected, pressed = " .. tostring(pressed))
            if pressed then
                print("[Debug] Q key pressed, opening custom menu")
                isQKeyHeld = true
                OpenCustomQMenu()
            end
            return true
        end
    end)

    -- Use a Think hook to check if the Q key is released
    hook.Add("Think", "CheckQKeyRelease", function()
        -- Check if the Q key (or whatever key is bound to +menu) is no longer held
        if isQKeyHeld and not input.IsKeyDown(KEY_Q) then
            print("[Debug] Q key released (via Think hook), closing custom menu")
            if isInventoryOpen and InventoryFrame ~= nil then
                if IsValid(InventoryFrame) then
                    InventoryFrame:Close() -- Use Close() instead of Remove() to trigger OnClose
                else
                    -- If the frame is invalid, ensure state is reset
                    isInventoryOpen = false
                    InventoryFrame = nil
                    print("[Debug] InventoryFrame was invalid, state reset")
                end
            end
            isQKeyHeld = false
        end
    end)

    concommand.Add("open_inventory_menu", function()
        print("[Debug] Manual command triggered")
        OpenCustomQMenu()
    end)

    net.Receive("SyncInventory", function()
        Inventory = net.ReadTable()
        print("[Debug] Received inventory: " .. table.ToString(Inventory))
        if isInventoryOpen and IsValid(InventoryFrame) then
            local tabPanel = InventoryFrame:GetChild(0)
            if IsValid(tabPanel) then
                local inventoryTab = tabPanel:GetChild(0)
                if IsValid(inventoryTab) then
                    BuildInventoryUI(inventoryTab)
                else
                    print("[Debug] SyncInventory: inventoryTab is nil or invalid")
                end
            else
                print("[Debug] SyncInventory: tabPanel is nil or invalid")
            end
        else
            print("[Debug] SyncInventory: InventoryFrame is nil or invalid")
        end
    end)

    net.Receive("SyncResources", function()
        Resources = net.ReadTable()
        print("[Debug] Received resources: " .. table.ToString(Resources))
        if isInventoryOpen and IsValid(InventoryFrame) then
            local tabPanel = InventoryFrame:GetChild(0)
            if IsValid(tabPanel) then
                local resourcesTab = tabPanel:GetChild(1)
                if IsValid(resourcesTab) then
                    BuildResourcesMenu(resourcesTab)
                else
                    print("[Debug] SyncResources: resourcesTab is nil or invalid")
                end
            else
                print("[Debug] SyncResources: tabPanel is nil or invalid")
            end
        else
            print("[Debug] SyncResources: InventoryFrame is nil or invalid")
        end
    end)

    net.Receive("InventoryMessage", function()
        local msg = net.ReadString()
        chat.AddText(Color(255, 215, 0), "[Inventory] ", Color(255, 255, 255), msg)
    end)
end