print("[Inventory Module] sh_inventory.lua loaded successfully")

if SERVER then
    util.AddNetworkString("SyncInventory")
    util.AddNetworkString("DropItem")
    util.AddNetworkString("UseItem")
    util.AddNetworkString("DeleteItem")
    util.AddNetworkString("InventoryMessage")
    util.AddNetworkString("SyncResources")
    util.AddNetworkString("DropResource")
end

ResourceItems = ResourceItems or {}
local resourceTemplates = {
    minerals = {
        { id = "rock", name = "Rock", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "copper", name = "Copper", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "iron", name = "Iron", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "steel", name = "Steel", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "titanium", name = "Titanium", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" }
    },
    gems = {
        { id = "emerald", name = "Emerald", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "ruby", name = "Ruby", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "sapphire", name = "Sapphire", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "obsidian", name = "Obsidian", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" },
        { id = "diamond", name = "Diamond", icon = "models/props_junk/rock001a.mdl", model = "models/props_junk/rock001a.mdl" }
    },
    lumber = {
        { id = "ash", name = "Ash", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "birch", name = "Birch", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "oak", name = "Oak", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "mahogany", name = "Mahogany", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" },
        { id = "yew", name = "Yew", icon = "icon16/brick.png", model = "models/props_junk/rock001a.mdl" }
    }
}
for _, category in pairs(resourceTemplates) do
    for _, data in ipairs(category) do
        ResourceItems[data.id] = { name = data.name, icon = data.icon, model = data.model }
    end
end

if file.Exists("modules/inventory/sh_items.lua", "LUA") then
    include("modules/inventory/sh_items.lua")
    if SERVER then AddCSLuaFile("modules/inventory/sh_items.lua") end
end

PlayerInventories = PlayerInventories or {}

function AddResourceToInventory(ply, resourceID, amount, silent)
    if not IsValid(ply) or not ResourceItems[resourceID] then 
        print("[Debug] AddResourceToInventory failed: Invalid ply or resourceID " .. tostring(resourceID))
        return 
    end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
    inv.resources[resourceID] = (inv.resources[resourceID] or 0) + (amount or 1)
    PlayerInventories[steamID] = inv
    if SERVER then
        print("[Debug] AddResourceToInventory: Updated " .. steamID .. " resources to " .. table.ToString(inv.resources))
        net.Start("SyncResources")
        net.WriteTable(inv.resources)
        net.Send(ply)
        SavePlayerInventory(ply)
        if not silent then SendInventoryMessage(ply, "Mined a " .. ResourceItems[resourceID].name) end
    end
end

function AddItemToInventory(ply, itemID, amount)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
    local maxStack = InventoryItems[itemID].maxStack or 64
    inv.items[itemID] = math.min((inv.items[itemID] or 0) + (amount or 1), maxStack)
    PlayerInventories[steamID] = inv
    if SERVER then
        net.Start("SyncInventory")
        net.WriteTable(inv.items)
        net.Send(ply)
        SavePlayerInventory(ply)
        SendInventoryMessage(ply, "Added " .. amount .. " " .. InventoryItems[itemID].name .. "(s) to your inventory.")
    end
end

if SERVER then
    local PickupCooldown = {}
    local allowedTools = { "button", "fading_door", "keypad_willox", "camera", "nocollide", "remover", "stacker" }

    hook.Remove("PlayerLoadout", "DarkRP_PlayerLoadout")

    hook.Add("DarkRPDBInitialized", "InitCustomInventoryTable", function()
        MySQLite.begin()
        MySQLite.queueQuery([[
            CREATE TABLE IF NOT EXISTS darkrp_custom_inventory (
                steamid VARCHAR(20) NOT NULL PRIMARY KEY,
                items TEXT NOT NULL DEFAULT '{}',
                resources TEXT NOT NULL DEFAULT '{}'
            )
        ]])
        MySQLite.commit(function()
            print("[Custom Inventory] Table 'darkrp_custom_inventory' initialized or updated successfully!")
        end)
    end)

    function SendInventoryMessage(ply, message)
        if not IsValid(ply) then return end
        net.Start("InventoryMessage")
        net.WriteString(message)
        net.Send(ply)
        print("[Inventory Log] " .. ply:Nick() .. " (" .. ply:SteamID() .. "): " .. message)
    end

    local function LoadPlayerInventory(ply)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        MySQLite.query("SELECT items, resources FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
            PlayerInventories[steamID] = data and data[1] and {
                items = util.JSONToTable(data[1].items or "{}") or {},
                resources = util.JSONToTable(data[1].resources or "{}") or {}
            } or { items = {}, resources = {} }
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

    function SavePlayerInventory(ply)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
        MySQLite.query("REPLACE INTO darkrp_custom_inventory (steamid, items, resources) VALUES (" .. 
            MySQLite.SQLStr(steamID) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.items)) .. ", " .. 
            MySQLite.SQLStr(util.TableToJSON(inv.resources)) .. ")", nil, function(err)
            print("[Custom Inventory] Error saving inventory for " .. steamID .. ": " .. err)
        end)
    end

    local function RemoveResourceFromInventory(ply, resourceID, amount)
        if not IsValid(ply) or not ResourceItems[resourceID] then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
        if not inv.resources[resourceID] or inv.resources[resourceID] < amount then return end
        inv.resources[resourceID] = inv.resources[resourceID] - amount
        if inv.resources[resourceID] <= 0 then inv.resources[resourceID] = nil end
        PlayerInventories[steamID] = inv
        net.Start("SyncResources")
        net.WriteTable(inv.resources)
        net.Send(ply)
        SavePlayerInventory(ply)
        SendInventoryMessage(ply, "Dropped " .. amount .. " " .. ResourceItems[resourceID].name .. ".")
    end

    local function RemoveItemFromInventory(ply, itemID, amount)
        if not IsValid(ply) or not InventoryItems[itemID] then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = {}, resources = {} }
        if not inv.items[itemID] or inv.items[itemID] < amount then return end
        inv.items[itemID] = inv.items[itemID] - amount
        if inv.items[itemID] <= 0 then inv.items[itemID] = nil end
        PlayerInventories[steamID] = inv
        net.Start("SyncInventory")
        net.WriteTable(inv.items)
        net.Send(ply)
        SavePlayerInventory(ply)
    end

    hook.Add("Initialize", "PrepareToolLoading", function()
        timer.Simple(5, function()
            if not SWEP then print("[Error] SWEP global is nil!") return end
            if file.Exists("weapons/gmod_tool/shared.lua", "LUA") then
                AddCSLuaFile("weapons/gmod_tool/shared.lua")
                include("weapons/gmod_tool/shared.lua")
                print("[Debug] Loaded gmod_tool/shared.lua")
            else
                print("[Error] gmod_tool/shared.lua not found!")
            end
            if not TOOL then print("[Error] TOOL global is nil!") return end
            for _, tool in ipairs(allowedTools) do
                local toolFile = "weapons/gmod_tool/stools/" .. tool .. ".lua"
                if file.Exists(toolFile, "LUA") then
                    AddCSLuaFile(toolFile)
                    include(toolFile)
                    print("[Debug] Loaded tool: " .. tool)
                else
                    print("[Debug] Tool file not found: " .. toolFile)
                end
            end
        end)
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
                ent:SetModel(itemData.model or "models/error.mdl")
                ent:SetPos(ply:EyePos() + ply:GetForward() * 50 + Vector(0, 0, 10 * i))
                ent:Spawn()
                ent:SetNWString("ItemID", itemID)
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    phys:Wake()
                    phys:SetVelocity(Vector(0, 0, -100))
                else
                    print("[Drop Debug] Failed to create physics for "..itemID)
                end
                ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                print("[Drop Debug] Dropped "..itemID.." at "..tostring(ent:GetPos()))
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
        print("[Debug] Dropping resource: " .. resourceID .. ", amount = " .. amount)
        if not ResourceItems[resourceID] or amount < 1 then
            print("[Inventory Error] Invalid resourceID or amount: " .. resourceID .. ", " .. amount)
            return
        end
        RemoveResourceFromInventory(ply, resourceID, amount)
        local resourceData = ResourceItems[resourceID]
        local entityMap = {
            rock = "resource_item",
            copper = "resource_copper",
            iron = "resource_iron",
            steel = "resource_steel",
            titanium = "resource_titanium",
            emerald = "resource_emerald",
            ruby = "resource_ruby",
            sapphire = "resource_sapphire",
            obsidian = "resource_obsidian",
            diamond = "resource_diamond"
        }
        local entClass = entityMap[resourceID] or "resource_item"
        local ent = ents.Create(entClass)
        if not IsValid(ent) then
            print("[Inventory Error] Failed to create '" .. entClass .. "' for " .. resourceID)
            return
        end
        ent:SetPos(ply:GetEyeTrace().HitPos + Vector(0, 0, 10))
        ent:SetNWString("ResourceType", resourceID)
        ent:SetModel(resourceData.model or "models/props_junk/rock001a.mdl")
        ent:SetNWInt("Amount", amount)
        ent:Spawn()
        ent:GetPhysicsObject():SetVelocity(ply:GetAimVector() * 100)
        print("[Debug] Spawned " .. entClass .. ": " .. resourceID .. ", amount = " .. amount)
    end)

    hook.Add("PlayerInitialSpawn", "Inventory_InitInventory", LoadPlayerInventory)
    hook.Add("PlayerDisconnected", "SaveInventoryOnDisconnect", SavePlayerInventory)

    hook.Add("PlayerSpawn", "Inventory_SetupTeam", function(ply)
        if not IsValid(ply) then return end
        local currentTeam = ply:Team()
        local defaultTeam = TEAM_CITIZEN or 1
        if not RPExtraTeams[currentTeam] or currentTeam == TEAM_UNASSIGNED then
            ply:changeTeam(RPExtraTeams[defaultTeam] and defaultTeam or next(RPExtraTeams), true)
        end
    end)

    hook.Add("PlayerLoadout", "Inventory_GiveLoadout", function(ply)
        if not IsValid(ply) then return end
        for _, wep in pairs(GAMEMODE.Config.DefaultWeapons) do ply:Give(wep) end
        local jobTable = RPExtraTeams[ply:Team()]
        if jobTable and jobTable.weapons then
            for _, wep in pairs(jobTable.weapons) do ply:Give(wep) end
        end
        return true
    end, -20)

    hook.Add("PlayerUse", "PickupInventoryItem", function(ply, ent)
        if ent:GetClass():match("^resource_") then return end
        local itemID = ent:GetNWString("ItemID")
        if not itemID or itemID == "" or not InventoryItems[itemID] then
            local steamID = ply:SteamID()
            PickupCooldown[steamID] = PickupCooldown[steamID] or {}
            if CurTime() - (PickupCooldown[steamID][ent:EntIndex()] or 0) > 5 then
                SendInventoryMessage(ply, "You cannot pick up this item.")
                PickupCooldown[steamID][ent:EntIndex()] = CurTime()
            end
            return
        end
        AddItemToInventory(ply, itemID, 1)
        ent:Remove()
        SendInventoryMessage(ply, "Picked up 1 " .. InventoryItems[itemID].name .. ".")
        return true
    end)

    concommand.Add("addresource", function(ply, _, args)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return SendInventoryMessage(ply, "Superadmin only.") end
        local resourceID, amount = args[1], tonumber(args[2]) or 1
        if not resourceID then return SendInventoryMessage(ply, "Specify a resource ID.") end
        AddResourceToInventory(ply, resourceID, amount)
    end)

    concommand.Add("additem", function(ply, _, args)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return SendInventoryMessage(ply, "Superadmin only.") end
        AddItemToInventory(ply, args[1], tonumber(args[2]) or 1)
    end)

    concommand.Add("open_resources", function(ply)
        if not IsValid(ply) then return end
        net.Start("SyncResources")
        net.WriteTable(PlayerInventories[ply:SteamID()] and PlayerInventories[ply:SteamID()].resources or {})
        net.Send(ply)
    end)
end

if CLIENT then
    local Resources, Inventory = {}, {}
    local InventoryFrame, ToolSelectorFrame
    local isInventoryOpen, isToolSelectorOpen, isQKeyHeld = false, false, false
    local currentTooltip
    local resourcesTab
    local allowedTools = { "button", "fading_door", "keypad_willox", "camera", "nocollide", "remover", "stacker" }
    local activeMenus = {}
    local sortMode = "name" -- Default sort mode: "name", "quantity", "category"

    local resourceAppearances = {
        rock = { material = "", color = nil },
        copper = { material = "models/shiny", color = Color(184, 115, 51, 100) },
        iron = { material = "models/shiny", color = Color(169, 169, 169, 255) },
        steel = { material = "models/shiny", color = Color(192, 192, 192, 255) },
        titanium = { material = "models/shiny", color = Color(46, 139, 87, 255) },
        emerald = { material = "models/shiny", color = Color(0, 255, 127, 200) },
        ruby = { material = "models/shiny", color = Color(255, 36, 0, 200) },
        sapphire = { material = "models/shiny", color = Color(0, 191, 255, 200) },
        obsidian = { material = "models/shiny", color = Color(47, 79, 79, 200) },
        diamond = { material = "models/shiny", color = Color(240, 248, 255, 200) }
    }

    local function OpenToolSelector()
        if isToolSelectorOpen and IsValid(ToolSelectorFrame) then return end
        gui.EnableScreenClicker(true)
        ToolSelectorFrame = vgui.Create("DFrame")
        ToolSelectorFrame:SetSize(300, 650)
        ToolSelectorFrame:SetPos(ScrW()/2 + 510, ScrH()/2 - 325)
        ToolSelectorFrame:SetTitle("Tool Selector")
        ToolSelectorFrame:SetDraggable(false)
        ToolSelectorFrame:ShowCloseButton(false)
        ToolSelectorFrame:MakePopup()
        ToolSelectorFrame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225)) end
        ToolSelectorFrame.OnClose = function() gui.EnableScreenClicker(false) isToolSelectorOpen = false ToolSelectorFrame = nil end

        local scroll = vgui.Create("DScrollPanel", ToolSelectorFrame)
        scroll:Dock(FILL)
        local cat = vgui.Create("DCollapsibleCategory", scroll)
        cat:Dock(TOP)
        cat:SetLabel("Tools")
        cat:SetExpanded(true)
        local toolList = vgui.Create("DPanelList", cat)
        toolList:EnableVerticalScrollbar(true)
        toolList:SetTall(600)
        toolList:Dock(FILL)
        cat:SetContents(toolList)

        local toolNames = { 
            button = "Button", 
            fading_door = "Fading Door", 
            keypad_willox = "Keypad", 
            camera = "Camera", 
            nocollide = "No-Collide", 
            remover = "Remover", 
            stacker = "Stacker" 
        }
        for _, toolClass in ipairs(allowedTools) do
            local toolData = list.Get("Tool")[toolClass]
            local btn = vgui.Create("DButton")
            btn:SetText(toolData and toolData.Name or toolNames[toolClass] or toolClass)
            btn:Dock(TOP)
            btn:SetHeight(25)
            btn.DoClick = function()
                RunConsoleCommand("use", "gmod_tool")
                RunConsoleCommand("gmod_toolmode", toolClass)
                RunConsoleCommand("gmod_tool", toolClass)
                surface.PlaySound("buttons/button14.wav")
            end
            btn.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(70, 70, 70, 240) or Color(50, 50, 50, 240))
            end
            toolList:AddItem(btn)
        end
        isToolSelectorOpen = true
    end

    local function BuildInventoryUI(parent)
        if not IsValid(parent) then return end
        for _, child in pairs(parent:GetChildren()) do child:Remove() end
        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)
        local layout = vgui.Create("DIconLayout", scroll)
        layout:Dock(FILL)
        layout:SetSpaceX(10)
        layout:SetSpaceY(10)

        local itemList = {}
        for itemID, amount in pairs(Inventory) do
            if InventoryItems[itemID] then
                table.insert(itemList, { id = itemID, amount = amount, name = InventoryItems[itemID].name, category = InventoryItems[itemID].category or "Misc" })
            end
        end

        if sortMode == "name" then
            table.sort(itemList, function(a, b) return a.name < b.name end)
        elseif sortMode == "quantity" then
            table.sort(itemList, function(a, b) return a.amount > b.amount end)
        elseif sortMode == "category" then
            table.sort(itemList, function(a, b)
                if a.category == b.category then return a.name < b.name end
                return a.category < b.category
            end)
        end

        for _, item in ipairs(itemList) do
            local itemID, amount = item.id, item.amount
            local panel = layout:Add("DPanel")
            panel:SetSize(100, 110)
            panel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200)) end

            local model = vgui.Create("DModelPanel", panel)
            model:SetSize(80, 80)
            model:SetPos(10, 5)
            model:SetModel(InventoryItems[itemID].model or "models/error.mdl")
            model:SetFOV(30)
            model:SetCamPos(Vector(30, 30, 30))
            model:SetLookAt(Vector(0, 0, 0))
            model.OnMousePressed = function(self, code)
                if code ~= MOUSE_LEFT or not isInventoryOpen then return end
                local menu = DermaMenu()
                table.insert(activeMenus, menu)
                if InventoryItems[itemID].useFunction then
                    menu:AddOption("Use", function()
                        if not isInventoryOpen then return end
                        net.Start("UseItem")
                        net.WriteString(itemID)
                        net.SendToServer()
                    end)
                end
                menu:AddOption("Drop", function()
                    if not isInventoryOpen then return end
                    net.Start("DropItem")
                    net.WriteString(itemID)
                    net.WriteUInt(1, 8)
                    net.SendToServer()
                end)
                menu:AddOption("Delete", function()
                    if not isInventoryOpen then return end
                    net.Start("DeleteItem")
                    net.WriteString(itemID)
                    net.WriteUInt(1, 8)
                    net.SendToServer()
                end)
                menu:Open(self:LocalToScreen(10, 80))
                menu.OnRemove = function()
                    for i, m in ipairs(activeMenus) do
                        if m == menu then table.remove(activeMenus, i) break end
                    end
                end
            end

            local label = vgui.Create("DLabel", panel)
            label:SetPos(10, 85)
            label:SetText(InventoryItems[itemID].name .. " x" .. amount)
            label:SizeToContents()
            label.Think = function(self) self:SetText(InventoryItems[itemID].name .. " x" .. (Inventory[itemID] or 0)) end
        end
    end

    local function BuildResourcesMenu(parent)
        if not IsValid(parent) then return end
        for _, child in pairs(parent:GetChildren()) do child:Remove() end
        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)
        local layout = vgui.Create("DIconLayout", scroll)
        layout:Dock(FILL)
        layout:SetSpaceX(10)
        layout:SetSpaceY(10)

        local categories = {
            { name = "Minerals", items = resourceTemplates.minerals },
            { name = "Gems", items = resourceTemplates.gems },
            { name = "Lumber", items = resourceTemplates.lumber }
        }
        for _, cat in ipairs(categories) do
            local catPanel = layout:Add("DPanel")
            catPanel:SetSize(300, 60 + table.Count(cat.items) * 50)
            catPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

            local catLabel = vgui.Create("DLabel", catPanel)
            catLabel:SetPos(10, 10)
            catLabel:SetText(cat.name)
            catLabel:SetSize(280, 20)
            catLabel:SetColor(Color(255, 215, 0))

            local i = 1
            for _, data in ipairs(cat.items) do
                local resourceID = data.id
                local resPanel = vgui.Create("DPanel", catPanel)
                resPanel:SetPos(10, 40 + (i - 1) * 50)
                resPanel:SetSize(280, 40)
                resPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200)) end

                local resIcon = vgui.Create("DModelPanel", resPanel)
                resIcon:SetPos(5, 0)
                resIcon:SetSize(40, 40)
                resIcon:SetModel(data.icon)
                resIcon:SetFOV(30)
                resIcon:SetCamPos(Vector(30, 30, 30))
                resIcon:SetLookAt(Vector(0, 0, 0))
                local appearance = resourceAppearances[resourceID] or { material = "models/shiny", color = Color(255, 255, 255) }
                print("[Debug] Setting up "..resourceID.." with model "..data.icon)
                if appearance.material != "" then
                    resIcon.Entity:SetMaterial(appearance.material)
                    print("[Debug] Set "..resourceID.." material to "..appearance.material)
                end
                if appearance.color then
                    resIcon:SetColor(appearance.color)
                    print("[Debug] Set "..resourceID.." DModelPanel color to "..tostring(appearance.color).." with alpha "..appearance.color.a)
                else
                    print("[Debug] Set "..resourceID.." to default appearance (no color)")
                end
                resIcon.OnCursorEntered = function(self)
                    if IsValid(currentTooltip) then currentTooltip:Remove() end
                    currentTooltip = vgui.Create("DLabel", resPanel)
                    currentTooltip:SetText(data.name)
                    currentTooltip:SetPos(50, 10)
                    currentTooltip:SetSize(100, 20)
                    currentTooltip:SetZPos(10000)
                    currentTooltip.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
                end
                resIcon.OnCursorExited = function() if IsValid(currentTooltip) then currentTooltip:Remove() currentTooltip = nil end end
                resIcon.OnMousePressed = function(self, code)
                    if (Resources[resourceID] or 0) <= 0 then return end
                    if code == MOUSE_LEFT then
                        net.Start("DropResource")
                        net.WriteString(resourceID)
                        net.WriteUInt(1, 16)
                        net.SendToServer()
                    elseif code == MOUSE_RIGHT then
                        Derma_StringRequest("Drop " .. data.name, "How many to drop? (Max: " .. (Resources[resourceID] or 0) .. ")", "1",
                            function(text)
                                local amount = math.min(math.floor(tonumber(text) or 0), Resources[resourceID] or 0)
                                if amount > 0 then
                                    net.Start("DropResource")
                                    net.WriteString(resourceID)
                                    net.WriteUInt(amount, 16)
                                    net.SendToServer()
                                end
                            end, nil, "Drop", "Cancel")
                    end
                end

                local resAmount = vgui.Create("DLabel", resPanel)
                resAmount:SetPos(50, 10)
                resAmount:SetText(": " .. (Resources[resourceID] or 0))
                resAmount:SetSize(220, 20)
                resAmount.Think = function(self) self:SetText(": " .. (Resources[resourceID] or 0)) end
                i = i + 1
            end
        end
    end

    local function OpenCustomQMenu()
        if isInventoryOpen and IsValid(InventoryFrame) then return end
        gui.EnableScreenClicker(true)
        InventoryFrame = vgui.Create("DFrame")
        InventoryFrame:SetSize(1000, 650)
        InventoryFrame:SetPos(ScrW()/2 - 500, ScrH()/2 - 325)
        InventoryFrame:SetTitle("Inventory & Resources")
        InventoryFrame:SetDraggable(false)
        InventoryFrame:ShowCloseButton(false)
        InventoryFrame:MakePopup()
        InventoryFrame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225)) end
        InventoryFrame.OnClose = function()
            gui.EnableScreenClicker(false)
            isInventoryOpen = false
            if IsValid(currentTooltip) then currentTooltip:Remove() currentTooltip = nil end
            for _, menu in ipairs(activeMenus) do
                if IsValid(menu) then menu:Remove() end
            end
            activeMenus = {}
            InventoryFrame = nil
            resourcesTab = nil
            if isToolSelectorOpen and IsValid(ToolSelectorFrame) then ToolSelectorFrame:Close() end
        end

        -- Sorting controls (top-right)
        local sortPanel = vgui.Create("DPanel", InventoryFrame)
        sortPanel:SetSize(250, 30)
        sortPanel:SetPos(ScrW()/2 + 350, 5) -- Top-right corner relative to frame center
        sortPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

        local sortLabel = vgui.Create("DLabel", sortPanel)
        sortLabel:SetPos(5, 5)
        sortLabel:SetText("Sort by:")
        sortLabel:SizeToContents()

        local sortCombo = vgui.Create("DComboBox", sortPanel)
        sortCombo:SetPos(60, 5)
        sortCombo:SetSize(180, 20)
        sortCombo:AddChoice("Name", "name", true)
        sortCombo:AddChoice("Quantity", "quantity")
        sortCombo:AddChoice("Category", "category")
        sortCombo.OnSelect = function(_, _, value, data)
            sortMode = data
            if IsValid(inventoryTab) then BuildInventoryUI(inventoryTab) end
        end

        local tabPanel = vgui.Create("DPropertySheet", InventoryFrame)
        tabPanel:Dock(FILL)
        inventoryTab = vgui.Create("DPanel", tabPanel)
        inventoryTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
        BuildInventoryUI(inventoryTab)
        tabPanel:AddSheet("Inventory", inventoryTab, "icon16/briefcase.png")
        resourcesTab = vgui.Create("DPanel", tabPanel)
        resourcesTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
        BuildResourcesMenu(resourcesTab)
        tabPanel:AddSheet("Resources", resourcesTab, "icon16/box.png")
        isInventoryOpen = true
        OpenToolSelector()
    end

    hook.Add("PlayerBindPress", "CustomMenuBinds", function(_, bind, pressed)
        if bind == "+menu" and pressed then
            isQKeyHeld = true
            OpenCustomQMenu()
            return true
        end
    end)

    hook.Add("Think", "CheckQKeyRelease", function()
        if isQKeyHeld and not input.IsKeyDown(KEY_Q) and isInventoryOpen and IsValid(InventoryFrame) then
            InventoryFrame:Close()
            isQKeyHeld = false
        end
    end)

    net.Receive("SyncInventory", function()
        Inventory = net.ReadTable()
        if isInventoryOpen and IsValid(InventoryFrame) and IsValid(inventoryTab) then
            BuildInventoryUI(inventoryTab)
        end
    end)

    net.Receive("SyncResources", function()
        Resources = net.ReadTable()
        print("[Debug] Received resources: " .. table.ToString(Resources))
        if isInventoryOpen and IsValid(InventoryFrame) and IsValid(resourcesTab) then
            BuildResourcesMenu(resourcesTab)
        end
    end)

    net.Receive("InventoryMessage", function()
        chat.AddText(Color(255, 215, 0), "[Inventory] ", Color(255, 255, 255), net.ReadString())
    end)

    concommand.Add("open_inventory_menu", OpenCustomQMenu)
end