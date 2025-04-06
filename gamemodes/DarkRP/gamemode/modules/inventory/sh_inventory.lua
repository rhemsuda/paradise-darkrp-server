-- Initial Setup
print("[Inventory Module] sh_inventory.lua loaded successfully")

if SERVER then
    util.AddNetworkString("SyncInventory")
    util.AddNetworkString("DropItem")
    util.AddNetworkString("UseItem")
    util.AddNetworkString("DeleteItem")
    util.AddNetworkString("InventoryMessage")
    util.AddNetworkString("SyncResources")
    util.AddNetworkString("DropResource")
    util.AddNetworkString("UpdateInventoryPositions")
end

-- Resource Definitions
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

-- Utility Functions
local function GenerateUUID()
    return string.format("%08x-%04x-%04x-%04x-%12x", 
        math.random(0, 0xffffffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffff), 
        math.random(0, 0xffffffffffff))
end

-- Inventory Management
function AddResourceToInventory(ply, resourceID, amount, silent)
    if not IsValid(ply) or not ResourceItems[resourceID] then 
        print("[Debug] AddResourceToInventory failed: Invalid ply or resourceID " .. tostring(resourceID))
        return 
    end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1 }
    inv.resources[resourceID] = (inv.resources[resourceID] or 0) + (amount or 1)
    PlayerInventories[steamID] = inv
    if SERVER then
        net.Start("SyncResources")
        net.WriteTable(inv.resources)
        net.Send(ply)
        SavePlayerInventory(ply)
        if not silent then SendInventoryMessage(ply, "Mined a " .. ResourceItems[resourceID].name) end
    end
end

function AddItemToInventory(ply, itemID, amount, stats, page)
    if not IsValid(ply) or not InventoryItems[itemID] then return end
    local steamID = ply:SteamID()
    local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1 }
    page = tonumber(page) or 1 -- Ensure page is a number, default to 1
    inv.maxPages = inv.maxPages or 1 -- Ensure maxPages is set
    if page < 1 or page > inv.maxPages then 
        print("[Debug] Invalid page " .. page .. " for " .. steamID .. ", maxPages: " .. inv.maxPages)
        return 
    end
    inv.items[page] = inv.items[page] or {} -- Ensure page table exists
    inv.positions[page] = inv.positions[page] or {} -- Ensure positions table exists
    stats = stats or {durability = 100}
    for i = 1, (amount or 1) do
        local uniqueID = GenerateUUID()
        local itemInstance = { id = uniqueID, itemID = itemID, stats = stats }
        table.insert(inv.items[page], itemInstance)
        for row = 1, 6 do
            for col = 1, 10 do
                local slotTaken = false
                for _, pos in pairs(inv.positions[page]) do
                    if pos[1] == row and pos[2] == col then slotTaken = true break end
                end
                if not slotTaken then
                    inv.positions[page][uniqueID] = {row, col}
                    print("[Debug] Assigned " .. uniqueID .. " (" .. itemID .. ") to " .. row .. "," .. col .. " on page " .. page)
                    break
                end
            end
            if inv.positions[page][uniqueID] then break end
        end
    end
    PlayerInventories[steamID] = inv
    if SERVER then
        net.Start("SyncInventory")
        net.WriteUInt(page, 8)
        net.WriteTable(inv.items[page])
        net.WriteTable(inv.positions[page])
        net.Send(ply)
        SavePlayerInventory(ply)
        SendInventoryMessage(ply, "Added " .. (amount or 1) .. " " .. InventoryItems[itemID].name .. "(s) to your inventory on page " .. page .. ".")
    end
end

-- Server-Side Logic
if SERVER then
    local PickupCooldown = {}
    local allowedTools = { "button", "fading_door", "keypad_willox", "camera", "nocollide", "remover", "stacker" }

    hook.Add("DarkRPDBInitialized", "InitCustomInventoryTable", function()
        MySQLite.begin()
        MySQLite.queueQuery([[
            CREATE TABLE IF NOT EXISTS darkrp_custom_inventory (
                steamid VARCHAR(20) NOT NULL PRIMARY KEY,
                items TEXT NOT NULL DEFAULT '{"1":[]}',
                resources TEXT NOT NULL DEFAULT '{}',
                positions TEXT NOT NULL DEFAULT '{"1":{}}',
                maxPages INTEGER NOT NULL DEFAULT 1
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
        MySQLite.query("SELECT items, resources, positions, maxPages FROM darkrp_custom_inventory WHERE steamid = " .. MySQLite.SQLStr(steamID), function(data)
            local inv = data and data[1] and {
                items = util.JSONToTable(data[1].items or '{"1":[]}') or { [1] = {} },
                resources = util.JSONToTable(data[1].resources or "{}") or {},
                positions = util.JSONToTable(data[1].positions or '{"1":{}}') or { [1] = {} },
                maxPages = tonumber(data[1].maxPages) or 1
            } or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1 }
            PlayerInventories[steamID] = inv
            net.Start("SyncInventory")
            net.WriteUInt(1, 8) -- Default to page 1
            net.WriteTable(inv.items[1])
            net.WriteTable(inv.positions[1])
            net.Send(ply)
            net.Start("SyncResources")
            net.WriteTable(inv.resources)
            net.Send(ply)
        end, function(err)
            print("[Custom Inventory] Error loading inventory for " .. steamID .. ": " .. err)
            PlayerInventories[steamID] = { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1 }
        end)
    end

    function SavePlayerInventory(ply)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1 }
        MySQLite.query("REPLACE INTO darkrp_custom_inventory (steamid, items, resources, positions, maxPages) VALUES (" .. 
            MySQLite.SQLStr(steamID) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.items)) .. ", " .. 
            MySQLite.SQLStr(util.TableToJSON(inv.resources)) .. ", " .. MySQLite.SQLStr(util.TableToJSON(inv.positions)) .. ", " .. 
            inv.maxPages .. ")", nil, function(err)
            print("[Custom Inventory] Error saving inventory for " .. steamID .. ": " .. err)
        end)
    end

    local function RemoveItemFromInventory(ply, uniqueID, page)
        if not IsValid(ply) then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1 }
        page = page or 1
        inv.items[page] = inv.items[page] or {}
        inv.positions[page] = inv.positions[page] or {}
        for i, item in ipairs(inv.items[page]) do
            if item.id == uniqueID then
                local itemData = InventoryItems[item.itemID]
                table.remove(inv.items[page], i)
                inv.positions[page][uniqueID] = nil
                PlayerInventories[steamID] = inv
                net.Start("SyncInventory")
                net.WriteUInt(page, 8)
                net.WriteTable(inv.items[page])
                net.WriteTable(inv.positions[page])
                net.Send(ply)
                SavePlayerInventory(ply)
                return item, itemData
            end
        end
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

    net.Receive("UpdateInventoryPositions", function(len, ply)
        local page = net.ReadUInt(8)
        local steamID = ply:SteamID()
        local newPositions = net.ReadTable()
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1 }
        inv.positions[page] = newPositions
        PlayerInventories[steamID] = inv
        SavePlayerInventory(ply)
        print("[Debug] Updated positions for " .. steamID .. " on page " .. page .. ": " .. table.ToString(newPositions))
    end)

    net.Receive("DropItem", function(len, ply)
        local uniqueID = net.ReadString()
        local page = net.ReadUInt(8)
        local item, itemData = RemoveItemFromInventory(ply, uniqueID, page)
        if not item or not itemData then return end
        SendInventoryMessage(ply, "Dropped 1 " .. itemData.name .. " from page " .. page .. ".")
        local ent = ents.Create("prop_physics")
        if IsValid(ent) then
            ent:SetModel(itemData.model or "models/error.mdl")
            ent:SetPos(ply:EyePos() + ply:GetForward() * 50)
            ent:Spawn()
            ent:SetNWString("UniqueID", uniqueID)
            ent:SetNWString("ItemID", item.itemID)
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then phys:Wake() phys:SetVelocity(Vector(0, 0, -100)) end
            ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        end
    end)

    net.Receive("UseItem", function(len, ply)
        local uniqueID = net.ReadString()
        local page = net.ReadUInt(8)
        local item, itemData = RemoveItemFromInventory(ply, uniqueID, page)
        if not item or not itemData or not itemData.useFunction then return end
        itemData.useFunction(ply)
        SendInventoryMessage(ply, "Used 1 " .. itemData.name .. " from page " .. page .. ".")
    end)

    net.Receive("DeleteItem", function(len, ply)
        local uniqueID = net.ReadString()
        local page = net.ReadUInt(8)
        local item, itemData = RemoveItemFromInventory(ply, uniqueID, page)
        if not item or not itemData then return end
        SendInventoryMessage(ply, "Deleted 1 " .. itemData.name .. " from page " .. page .. ".")
    end)

    net.Receive("DropResource", function(len, ply)
        local resourceID = net.ReadString()
        local amount = net.ReadUInt(16)
        if not ResourceItems[resourceID] or amount < 1 then return end
        local steamID = ply:SteamID()
        local inv = PlayerInventories[steamID] or { items = { [1] = {} }, resources = {}, positions = { [1] = {} }, maxPages = 1 }
        if not inv.resources[resourceID] or inv.resources[resourceID] < amount then return end
        inv.resources[resourceID] = inv.resources[resourceID] - amount
        if inv.resources[resourceID] <= 0 then inv.resources[resourceID] = nil end
        PlayerInventories[steamID] = inv
        net.Start("SyncResources")
        net.WriteTable(inv.resources)
        net.Send(ply)
        SavePlayerInventory(ply)
        SendInventoryMessage(ply, "Dropped " .. amount .. " " .. ResourceItems[resourceID].name .. ".")
        local ent = ents.Create("prop_physics")
        if IsValid(ent) then
            ent:SetModel(ResourceItems[resourceID].model or "models/props_junk/rock001a.mdl")
            ent:SetPos(ply:GetEyeTrace().HitPos + Vector(0, 0, 10))
            ent:Spawn()
            ent:GetPhysicsObject():SetVelocity(ply:GetAimVector() * 100)
        end
    end)

    hook.Add("PlayerInitialSpawn", "Inventory_InitInventory", LoadPlayerInventory)
    hook.Add("PlayerDisconnected", "SaveInventoryOnDisconnect", SavePlayerInventory)

    hook.Add("PlayerUse", "PickupInventoryItem", function(ply, ent)
        local uniqueID = ent:GetNWString("UniqueID")
        if not uniqueID or uniqueID == "" then return end
        local itemID = ent:GetNWString("ItemID")
        if not InventoryItems[itemID] then return end
        AddItemToInventory(ply, itemID, 1, nil, 1) -- Default to page 1
        ent:Remove()
        SendInventoryMessage(ply, "Picked up 1 " .. InventoryItems[itemID].name .. ".")
        return true
    end)

    concommand.Add("addresource", function(ply, _, args)
        if not ply:IsSuperAdmin() then return SendInventoryMessage(ply, "Superadmin only.") end
        AddResourceToInventory(ply, args[1], tonumber(args[2]) or 1)
    end)

    concommand.Add("additem", function(ply, _, args)
        if not ply:IsSuperAdmin() then return SendInventoryMessage(ply, "Superadmin only.") end
        AddItemToInventory(ply, args[1], tonumber(args[2]) or 1, nil, 1) -- Default to page 1
    end)

    concommand.Add("open_resources", function(ply)
        if not IsValid(ply) then return end
        net.Start("SyncResources")
        net.WriteTable(PlayerInventories[ply:SteamID()] and PlayerInventories[ply:SteamID()].resources or {})
        net.Send(ply)
    end)
end

-- Client-Side Logic
if CLIENT then
    local Resources, Inventory, InventoryPositions = {}, {}, {}
    local InventoryFrame, ToolSelectorFrame, resourcesTab
    local isInventoryOpen, isToolSelectorOpen, isQKeyHeld = false, false, false
    local currentTooltip
    local activeMenus = {}
    local allowedTools = { "button", "fading_door", "keypad_willox", "camera", "nocollide", "remover", "stacker" }
    local currentPage = 1

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
        ToolSelectorFrame:SetSize(300, 700)
        ToolSelectorFrame:SetPos(ScrW()/2 + 510, ScrH()/2 - 350)
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
        toolList:SetTall(650)
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

    local function BuildInventoryUI(parent, page)
        if not IsValid(parent) then return end
        for _, child in pairs(parent:GetChildren()) do child:Remove() end

        local tabPanel = vgui.Create("DPanel", parent)
        tabPanel:SetSize(980, 50)
        tabPanel:SetPos(5, 5)
        tabPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

        local pageTab = vgui.Create("DButton", tabPanel)
        pageTab:SetSize(100, 40)
        pageTab:SetPos(10, 5)
        pageTab:SetText("Page 1")
        pageTab.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, currentPage == 1 and Color(70, 70, 70, 240) or Color(50, 50, 50, 240))
        end
        pageTab.DoClick = function() currentPage = 1 BuildInventoryUI(parent, currentPage) end

        local gridPanel = vgui.Create("DPanel", parent)
        gridPanel:SetSize(980, 640)
        gridPanel:SetPos(5, 55)
        gridPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

        local slotWidth, slotHeight = 97, 97
        local slots = {}
        for row = 1, 6 do
            slots[row] = {}
            for col = 1, 10 do
                local slot = vgui.Create("DPanel", gridPanel)
                slot:SetSize(slotWidth, slotHeight)
                slot:SetPos((col - 1) * (slotWidth + 1), (row - 1) * (slotHeight + 1))
                slot.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 150)) end
                slot:Receiver("inventory_item", function(self, panels, dropped)
                    if not dropped or not panels[1] then return end
                    local draggedUniqueID = panels[1].UniqueID
                    local newPos = {row, col}
                    local occupiedItem
                    for uniqueID, pos in pairs(InventoryPositions) do
                        if pos[1] == row and pos[2] == col and uniqueID ~= draggedUniqueID then
                            occupiedItem = uniqueID
                            break
                        end
                    end
                    if occupiedItem then
                        local oldPos = InventoryPositions[draggedUniqueID]
                        InventoryPositions[draggedUniqueID] = newPos
                        InventoryPositions[occupiedItem] = oldPos
                    else
                        InventoryPositions[draggedUniqueID] = newPos
                    end
                    net.Start("UpdateInventoryPositions")
                    net.WriteUInt(currentPage, 8)
                    net.WriteTable(InventoryPositions)
                    net.SendToServer()
                    BuildInventoryUI(parent, currentPage)
                end)
                slots[row][col] = slot
            end
        end

        for _, item in ipairs(Inventory) do
            local itemID = item.itemID
            local uniqueID = item.id
            if not InventoryItems[itemID] or not InventoryPositions[uniqueID] then continue end
            local pos = InventoryPositions[uniqueID]
            local row, col = pos[1], pos[2]
            if not slots[row] or not slots[row][col] then continue end

            local panel = vgui.Create("DPanel", slots[row][col])
            panel:SetSize(slotWidth, slotHeight)
            panel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200)) end

            local model = vgui.Create("DModelPanel", panel)
            model:SetSize(75, 75)
            model:SetPos((slotWidth - 75) / 2, 5)
            model:SetModel(InventoryItems[itemID].model or "models/error.mdl")
            model:SetFOV(30)
            model:SetCamPos(Vector(30, 30, 30))
            model:SetLookAt(Vector(0, 0, 0))
            model:SetMouseInputEnabled(true)
            model:Droppable("inventory_item")
            model.UniqueID = uniqueID
            model.DoClick = function(self)
                if not isInventoryOpen then return end
                local menu = DermaMenu()
                table.insert(activeMenus, menu)
                if InventoryItems[itemID].useFunction then
                    menu:AddOption("Use", function()
                        net.Start("UseItem")
                        net.WriteString(uniqueID)
                        net.WriteUInt(currentPage, 8)
                        net.SendToServer()
                    end)
                end
                menu:AddOption("Drop", function()
                    net.Start("DropItem")
                    net.WriteString(uniqueID)
                    net.WriteUInt(currentPage, 8)
                    net.SendToServer()
                end)
                menu:AddOption("Delete", function()
                    net.Start("DeleteItem")
                    net.WriteString(uniqueID)
                    net.WriteUInt(currentPage, 8)
                    net.SendToServer()
                end)
                menu:Open(self:LocalToScreen(10, 75))
                menu.OnRemove = function()
                    for i, m in ipairs(activeMenus) do
                        if m == menu then table.remove(activeMenus, i) break end
                    end
                end
            end

            local label = vgui.Create("DLabel", panel)
            label:SetPos(5, slotHeight - 20)
            label:SetSize(slotWidth - 10, 20)
            label:SetText(InventoryItems[itemID].name)
            label:SetContentAlignment(5)
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
                if appearance.material != "" then resIcon.Entity:SetMaterial(appearance.material) end
                if appearance.color then resIcon:SetColor(appearance.color) end
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
        InventoryFrame:SetSize(1000, 700)
        InventoryFrame:SetPos(ScrW()/2 - 500, ScrH()/2 - 350)
        InventoryFrame:SetTitle("Inventory & Resources")
        InventoryFrame:SetDraggable(false)
        InventoryFrame:ShowCloseButton(false)
        InventoryFrame:MakePopup()
        InventoryFrame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 225)) end
        InventoryFrame.OnClose = function()
            gui.EnableScreenClicker(false)
            isInventoryOpen = false
            if IsValid(currentTooltip) then currentTooltip:Remove() end
            for _, menu in ipairs(activeMenus) do if IsValid(menu) then menu:Remove() end end
            activeMenus = {}
            InventoryFrame = nil
            resourcesTab = nil
            if isToolSelectorOpen and IsValid(ToolSelectorFrame) then ToolSelectorFrame:Close() end
        end

        local tabPanel = vgui.Create("DPropertySheet", InventoryFrame)
        tabPanel:Dock(FILL)
        inventoryTab = vgui.Create("DPanel", tabPanel)
        inventoryTab.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 240)) end
        BuildInventoryUI(inventoryTab, currentPage)
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
        local page = net.ReadUInt(8)
        Inventory = net.ReadTable()
        InventoryPositions = net.ReadTable()
        if isInventoryOpen and IsValid(InventoryFrame) and IsValid(inventoryTab) and page == currentPage then
            BuildInventoryUI(inventoryTab, currentPage)
        end
    end)

    net.Receive("SyncResources", function()
        Resources = net.ReadTable()
        if isInventoryOpen and IsValid(InventoryFrame) and IsValid(resourcesTab) then
            BuildResourcesMenu(resourcesTab)
        end
    end)

    net.Receive("InventoryMessage", function()
        chat.AddText(Color(255, 215, 0), "[Inventory] ", Color(255, 255, 255), net.ReadString())
    end)

    concommand.Add("open_inventory_menu", OpenCustomQMenu)
end