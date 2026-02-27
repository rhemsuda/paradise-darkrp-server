-- cl_inventory_spawnmenu.lua  (client)
-- Registers the Inventory & Resources creation tab inside the Sandbox spawnmenu (Q)

if not CLIENT then return end

local TAB_NAME = "Inventory & Resources"
local REGISTERED = false

local function BuildInventoryTab()
    local root = vgui.Create("DPanel")
    local sheet = vgui.Create("DPropertySheet", root)
    sheet:Dock(FILL)

    -- Inventory grid (always safe)
    local items = vgui.Create("DPanel", sheet)
    sheet:AddSheet("Inventory", items, "icon16/box.png", false, false, "Your items")
    if Inventory and Inventory.BuildInventoryPanel then Inventory.BuildInventoryPanel(items) end

    -- Resources (optional, guard missing globals)
    local resOk = (istable(_G.resourceTemplates) or istable(resourceTemplates)) and isfunction(BuildResourcesMenu)
    local res = vgui.Create("DPanel", sheet)
    sheet:AddSheet("Resources", res, "icon16/coins.png", false, false, "Your resources")
    if resOk then
        local ok, err = pcall(BuildResourcesMenu, res)
        if not ok then
            res.Paint = function(self,w,h)
                draw.RoundedBox(4,0,0,w,h,Color(40,40,40,200))
                draw.SimpleText("Resources module not ready", "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            -- Resources sheet failed to load (err shown in console if needed)
        end
    else
        res.Paint = function(self,w,h)
            draw.RoundedBox(4,0,0,w,h,Color(40,40,40,200))
            draw.SimpleText("Resources module unavailable", "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Props (optional, guard function)
    local props = vgui.Create("DPanel", sheet)
    sheet:AddSheet("Props", props, "icon16/bricks.png", false, false, "Build props")
    if isfunction(BuildPropsPanel) then
        local ok, err = pcall(BuildPropsPanel, props)
        if not ok then
            props.Paint = function(self,w,h)
                draw.RoundedBox(4,0,0,w,h,Color(40,40,40,200))
                draw.SimpleText("Props panel error", "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            -- Props sheet failed to load
        end
    else
        props.Paint = function(self,w,h)
            draw.RoundedBox(4,0,0,w,h,Color(40,40,40,200))
            draw.SimpleText("Props module unavailable", "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    return root
end

local function RegisterTab()
    if REGISTERED then return end
    if not spawnmenu or not spawnmenu.AddCreationTab then return end
    spawnmenu.AddCreationTab(TAB_NAME, BuildInventoryTab, "icon16/box.png", 40)
    REGISTERED = true
end

-- Try early
timer.Simple(0, function()
    RegisterTab()
    -- if the menu already exists, refresh once to ensure visibility
    if IsValid(g_SpawnMenu) then RunConsoleCommand("spawnmenu_reload") end
end)

-- On menu creation
hook.Add("SpawnMenuCreated", "Inventory_RegisterCreationTab", RegisterTab)

-- On open, as a last resort
hook.Add("SpawnMenuOpen", "Inventory_RegisterCreationTab", RegisterTab)


