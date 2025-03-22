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
    local ToolFrame = nil

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
        if IsValid(InventoryFrame) then
            InventoryFrame:Remove()
            gui.EnableScreenClicker(false)
            print("[Debug] Existing InventoryFrame removed")
        end

        gui.EnableScreenClicker(true)
        InventoryFrame = vgui.Create("DFrame")
        print("[Debug] DFrame created")
        InventoryFrame:SetSize(1000, 650)
        InventoryFrame:SetPos(ScrW()/2 - 500, ScrH()/2 - 325)
        InventoryFrame:SetTitle("Inventory & Resources")
        InventoryFrame:SetDraggable(true)
        InventoryFrame:ShowCloseButton(true)
        InventoryFrame:SetVisible(true)
        InventoryFrame:MakePopup()
        InventoryFrame.OnClose = function()
            gui.EnableScreenClicker(false)
            for _, child in pairs(InventoryFrame:GetChildren()) do
                child:Remove()
            end
            print("[Debug] InventoryFrame closed")
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

        print("[Debug] Frame valid: " .. tostring(IsValid(InventoryFrame)))
        print("[Debug] Frame visible: " .. tostring(InventoryFrame:IsVisible()))
        print("[Debug] OpenCustomQMenu completed")
    end

    local function OpenToolSelector()
        -- Debug the contents of list.Get("Tool")
        print("[Debug] Available tools in list.Get('Tool'):")
        for k, v in pairs(list.Get("Tool")) do
            print("[Debug] Tool: " .. k .. " (Name: " .. (v.Name or "Unknown") .. ")")
        end

        print("[Debug] OpenToolSelector started")
        if IsValid(ToolFrame) then
            ToolFrame:Remove()
            gui.EnableScreenClicker(false)
            print("[Debug] Existing ToolFrame removed")
            return
        end

        gui.EnableScreenClicker(true)
        ToolFrame = vgui.Create("DFrame")
        print("[Debug] ToolFrame created")
        ToolFrame:SetSize(600, 400)
        ToolFrame:SetPos(ScrW()/2 - 300, ScrH()/2 - 200)
        ToolFrame:SetTitle("Toolgun Selector")
        ToolFrame:SetDraggable(true)
        ToolFrame:ShowCloseButton(true)
        ToolFrame:SetVisible(true)
        ToolFrame:MakePopup()
        ToolFrame.OnClose = function()
            gui.EnableScreenClicker(false)
            print("[Debug] ToolFrame closed")
        end
        ToolFrame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225))
        end
        local x, y = ToolFrame:GetPos()
        print("[Debug] ToolFrame position: " .. x .. ", " .. y)

        local tabPanel = vgui.Create("DPropertySheet", ToolFrame)
        tabPanel:Dock(FILL)
        print("[Debug] Tab panel created")

        -- Tools tab
        local toolsTab = vgui.Create("DPanel", tabPanel)
        toolsTab.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240))
        end
        print("[Debug] Tools tab panel created: " .. tostring(IsValid(toolsTab)))

        local leftPanel = vgui.Create("DPanel", toolsTab)
        leftPanel:Dock(LEFT)
        leftPanel:SetWide(200)
        leftPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
        end

        local rightPanel = vgui.Create("DPanel", toolsTab)
        rightPanel:Dock(FILL)
        rightPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
        end

        local scroll = vgui.Create("DScrollPanel", leftPanel)
        scroll:Dock(FILL)
        print("[Debug] Tool scroll panel created")

        -- Define the limited set of tools
        local allowedTools = {
            { Name = "Button", Class = "button" },
            { Name = "Fading Doors", Class = "fading_door" },
            { Name = "Keypad", Class = "keypad" }, -- Wiremod Keypad
            { Name = "Camera", Class = "gmod_camera" },
        }

        local categories = { ["Tools"] = allowedTools }

        -- Store Keypad settings locally
        local keypadSettings = {
            accessCode = "1234",
            denyCode = "0000",
            correctValue = 1,
            incorrectValue = 0,
            toggle = false
        }

        -- Store references to Keypad settings fields
        local keypadFields = {}

        for categoryName, tools in pairs(categories) do
            local cat = vgui.Create("DCollapsibleCategory", scroll)
            cat:Dock(TOP)
            cat:SetLabel(categoryName)
            cat:SetExpanded(true) -- Expand by default
            cat:DockMargin(0, 0, 0, 5)

            local toolList = vgui.Create("DPanelList", cat)
            toolList:EnableVerticalScrollbar(true)
            toolList:SetTall(100)
            toolList:Dock(FILL)
            cat:SetContents(toolList)

            for _, tool in ipairs(tools) do
                local toolButton = vgui.Create("DButton")
                toolButton:SetText(tool.Name)
                toolButton:Dock(TOP)
                toolButton:SetHeight(25)
                toolButton.DoClick = function()
                    -- Force tool mode switch
                    RunConsoleCommand("gmod_toolmode", tool.Class)
                    RunConsoleCommand("gmod_tool", tool.Class)
                    print("[Debug] Selected tool: " .. tool.Class)

                    -- Ensure tool mode updates
                    timer.Simple(0.1, function()
                        local currentMode = GetConVarString("gmod_toolmode")
                        print("[Debug] Current tool mode after delay: " .. currentMode)
                        if currentMode ~= tool.Class then
                            print("[Debug] Tool mode did not update, forcing again")
                            RunConsoleCommand("gmod_toolmode", tool.Class)
                            RunConsoleCommand("gmod_tool", tool.Class)
                        end
                    end)

                    -- Notify server of tool change
                    net.Start("SelectTool")
                    net.WriteString(tool.Class)
                    net.SendToServer()

                    surface.PlaySound("buttons/button14.wav")

                    -- Clear right panel and show tool settings
                    for _, child in pairs(rightPanel:GetChildren()) do
                        child:Remove()
                    end
                    local settings = vgui.Create("DPanel", rightPanel)
                    settings:Dock(FILL)
                    settings:DockMargin(5, 5, 5, 5)
                    settings.Paint = function(self, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, Color(150, 150, 150, 200)) -- Lighter background
                    end

                    -- Load the tool's control panel
                    local toolData = list.Get("Tool")[tool.Class]
                    if toolData then
                        print("[Debug] Tool data found for " .. tool.Class)
                        if toolData.BuildCPanel then
                            print("[Debug] BuildCPanel exists for " .. tool.Class)
                            local controlPanel = vgui.Create("DForm", settings)
                            controlPanel:Dock(FILL)
                            controlPanel:SetName(tool.Name .. " Settings")
                            controlPanel:SetExpanded(true)
                            toolData.BuildCPanel(controlPanel)
                        else
                            print("[Debug] BuildCPanel not found for " .. tool.Class)
                            local label = vgui.Create("DLabel", settings)
                            label:Dock(TOP)
                            label:SetText("No settings available for this tool (BuildCPanel missing).")
                            label:SizeToContents()
                        end
                    else
                        print("[Debug] Tool data not found for " .. tool.Class .. " in list.Get('Tool')")
                        -- Manual settings for each tool
                        local controlPanel = vgui.Create("DForm", settings)
                        controlPanel:Dock(FILL)
                        controlPanel:SetName(tool.Name .. " Settings")
                        controlPanel:SetExpanded(true)

                        if tool.Class == "button" then
                            controlPanel:NumSlider("Key to Simulate", nil, 0, 9, 0)
                            controlPanel:CheckBox("Toggle Mode")
                        elseif tool.Class == "fading_door" then
                            controlPanel:NumSlider("Fade Time", nil, 0, 10, 1)
                            controlPanel:TextEntry("Material", nil)
                            controlPanel:CheckBox("Toggle")
                        elseif tool.Class == "gmod_camera" then
                            controlPanel:NumSlider("Key to Simulate", nil, 0, 9, 0)
                            controlPanel:CheckBox("Static")
                        elseif tool.Class == "keypad" then
                            -- Access Code
                            keypadFields.accessCode = controlPanel:TextEntry("Access Code", nil)
                            keypadFields.accessCode:SetValue(keypadSettings.accessCode)
                            keypadFields.accessCode.OnChange = function(self)
                                keypadSettings.accessCode = self:GetValue()
                            end

                            -- Deny Code
                            keypadFields.denyCode = controlPanel:TextEntry("Deny Code", nil)
                            keypadFields.denyCode:SetValue(keypadSettings.denyCode)
                            keypadFields.denyCode.OnChange = function(self)
                                keypadSettings.denyCode = self:GetValue()
                            end

                            -- Correct Value
                            keypadFields.correctValue = controlPanel:NumSlider("Correct Value", nil, 0, 100, 0)
                            keypadFields.correctValue:SetValue(keypadSettings.correctValue)
                            keypadFields.correctValue.OnValueChanged = function(self, value)
                                keypadSettings.correctValue = value
                            end

                            -- Incorrect Value
                            keypadFields.incorrectValue = controlPanel:NumSlider("Incorrect Value", nil, 0, 100, 0)
                            keypadFields.incorrectValue:SetValue(keypadSettings.incorrectValue)
                            keypadFields.incorrectValue.OnValueChanged = function(self, value)
                                keypadSettings.incorrectValue = value
                            end

                            -- Toggle
                            keypadFields.toggle = controlPanel:CheckBox("Toggle")
                            keypadFields.toggle:SetValue(keypadSettings.toggle)
                            keypadFields.toggle.OnChange = function(self, value)
                                keypadSettings.toggle = value
                            end
                        end
                    end
                end
                toolButton.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240))
                    if self:IsHovered() then
                        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 240))
                    end
                end
                toolList:AddItem(toolButton)
            end
        end

        tabPanel:AddSheet("Tools", toolsTab, "icon16/wrench.png")
        print("[Debug] Tools tab added")

        -- Utilities tab (admin only)
        if LocalPlayer():IsAdmin() then
            local utilsTab = vgui.Create("DPanel", tabPanel)
            utilsTab.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240))
            end
            print("[Debug] Utilities tab panel created: " .. tostring(IsValid(utilsTab)))

            local utilsScroll = vgui.Create("DScrollPanel", utilsTab)
            utilsScroll:Dock(FILL)
            print("[Debug] Utilities scroll panel created: " .. tostring(IsValid(utilsScroll)))

            local utilsList = vgui.Create("DListLayout", utilsScroll)
            utilsList:Dock(FILL)
            print("[Debug] Utilities list created: " .. tostring(IsValid(utilsList)))

            local utils = {
                { name = "Admin Cleanup", cmd = "gmod_admin_cleanup" },
                { name = "User Cleanup", cmd = "gmod_cleanup" },
            }

            for _, util in ipairs(utils) do
                local utilButton = vgui.Create("DButton")
                utilButton:SetText(util.name)
                utilButton:Dock(TOP)
                utilButton:SetHeight(30)
                utilButton.DoClick = function()
                    RunConsoleCommand(unpack(string.Split(util.cmd, " ")))
                    print("[Debug] Ran utility: " .. util.name)
                    surface.PlaySound("buttons/button14.wav")
                end
                utilButton.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240))
                    if self:IsHovered() then
                        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 240))
                    end
                end
                if IsValid(utilsList) then
                    utilsList:Add(utilButton) -- Fixed: Use Add instead of AddItem for DListLayout
                    print("[Debug] Added utility button: " .. util.name)
                else
                    print("[Error] utilsList is not valid, cannot add utility button: " .. util.name)
                end
            end

            tabPanel:AddSheet("Utilities", utilsTab, "icon16/shield.png")
            print("[Debug] Utilities tab added (admin only)")
        end

        print("[Debug] Frame valid: " .. tostring(IsValid(ToolFrame)))
        print("[Debug] Frame visible: " .. tostring(ToolFrame:IsVisible()))
        print("[Debug] OpenToolSelector completed")
    end

    hook.Add("PlayerBindPress", "CustomMenuBinds", function(ply, bind, pressed)
        if bind == "+menu" and pressed then
            print("[Debug] Q key pressed, toggling custom menu")
            if IsValid(InventoryFrame) then
                InventoryFrame:Remove()
                gui.EnableScreenClicker(false)
            else
                OpenCustomQMenu()
            end
            return true
        elseif bind == "+menu_context" and pressed then
            print("[Debug] C key pressed, toggling tool selector")
            OpenToolSelector()
            return true
        end
    end)

    concommand.Add("open_inventory_menu", function()
        print("[Debug] Manual command triggered")
        OpenCustomQMenu()
    end)

    concommand.Add("open_tool_selector", function()
        print("[Debug] Manual tool selector command triggered")
        OpenToolSelector()
    end)

    net.Receive("SyncInventory", function()
        Inventory = net.ReadTable()
        print("[Debug] Received inventory: " .. table.ToString(Inventory))
        if IsValid(InventoryFrame) then
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
        if IsValid(InventoryFrame) then
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

-- Server-side (no changes needed)
if SERVER then
    util.AddNetworkString("SelectTool")

    net.Receive("SelectTool", function(len, ply)
        local toolClass = net.ReadString()
        print("[Server] Player " .. ply:Nick() .. " selected tool: " .. toolClass)
        -- Add any server-side validation or logic here if needed
    end)
end