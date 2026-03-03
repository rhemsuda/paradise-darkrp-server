-- Debug print to confirm the file is loading
print("[Jobs Module] cl_jobs.lua loaded successfully")

if not CLIENT then return end

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug") and GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Store job data received from the server
local JobsData = {}

-- Currently selected job (for the info panel)
local SelectedJob = nil
local InfoPanel = nil

-- Function to update the information panel with the selected job's details
local function UpdateInfoPanel(job, jobIndex)
    if not IsValid(InfoPanel) then return end
    for _, child in pairs(InfoPanel:GetChildren()) do child:Remove() end

    SelectedJob = { data = job, index = jobIndex }

    local function loadoutDisplayName(class)
        if class == "Weapon Shipments" then return class end
        local s = class:gsub("^weapon_", ""):gsub("^gmod_", "")
        return s:sub(1, 1):upper() .. s:sub(2):lower()
    end

    -- Get world model for loadout item (weapon/tool class or "Weapon Shipments")
    -- Prefer runtime WorldModel so we use the game's actual paths; fallback to known paths then generic pistol
    local FALLBACK_MODEL = "models/weapons/w_pist_p228.mdl"
    local function loadoutModel(class)
        if class == "Weapon Shipments" then return "models/items/boxsniperrounds.mdl" end
        local swep = (weapons.GetStored and weapons.GetStored(class)) or (list.Get("Weapon") and list.Get("Weapon")[class])
        if swep and swep.WorldModel and swep.WorldModel ~= "" then return swep.WorldModel end
        -- Base GMod tools often don't register WorldModel; use known paths (GMod wiki: Common_Weapon_Models)
        local known = {
            ["weapon_physcannon"] = "models/weapons/w_Physics.mdl",  -- Gravity Gun (no w_physcannon.mdl)
            ["weapon_physgun"]   = "models/weapons/w_Physics.mdl", -- Physics Gun
            ["gmod_tool"]        = "models/weapons/w_toolgun.mdl",
            ["gmod_camera"]      = "models/MaxOfS2D/camera.mdl",
        }
        -- Try known path first; if this install uses different casing, util.IsValidModel can't run client-side for all, so we try alternates
        local path = known[class]
        if path then return path end
        return FALLBACK_MODEL
    end

    if not job then
        local label = vgui.Create("DLabel", InfoPanel)
        label:SetText("Select a job to view details.")
        label:SetPos(10, 10)
        label:SetSize(280, 20)
        label:SetFont("DermaDefaultBold")
        label:SetColor(Color(255, 255, 255))
        return
    end

    local contentPanel = vgui.Create("DPanel", InfoPanel)
    contentPanel:Dock(FILL)
    contentPanel.Paint = function() end

    local panelW = math.max(200, (IsValid(InfoPanel) and InfoPanel:GetWide() or 280) - 24)
    local pad = 12
    local yPos = pad

    -- Job Name
    local nameLabel = vgui.Create("DLabel", contentPanel)
    nameLabel:SetText(job.name)
    nameLabel:SetPos(pad, yPos)
    nameLabel:SetSize(panelW - pad * 2, 22)
    nameLabel:SetFont("DermaDefaultBold")
    nameLabel:SetColor(Color(255, 255, 255))
    yPos = yPos + 26

    -- Description: enough height so text is never cut off (4–5 lines)
    local descH = 78
    local descLabel = vgui.Create("DLabel", contentPanel)
    descLabel:SetText(job.description or "No description available.")
    descLabel:SetPos(pad, yPos)
    descLabel:SetSize(panelW - pad * 2, descH)
    descLabel:SetWrap(true)
    descLabel:SetFont("DermaDefault")
    descLabel:SetColor(Color(220, 220, 220))
    yPos = yPos + descH + 6

    -- Loadout: larger icons so they fit the panel and aren't crammed
    local baseLoadout = {"weapon_physcannon", "weapon_physgun", "gmod_tool", "gmod_camera"}
    local loadout = table.Copy(baseLoadout)
    if job.candropweapons then
        loadout = {"Weapon Shipments"}
    elseif job.weapons and #job.weapons > 0 then
        table.Add(loadout, job.weapons)
    end
    local iconSize, iconGap = 52, 8
    if #loadout > 0 then
        local loadoutHeader = vgui.Create("DLabel", contentPanel)
        loadoutHeader:SetText("Loadout")
        loadoutHeader:SetPos(pad, yPos)
        loadoutHeader:SetSize(panelW - pad * 2, 20)
        loadoutHeader:SetFont("DermaDefaultBold")
        loadoutHeader:SetColor(Color(255, 255, 255))
        yPos = yPos + 24

        local cols = math.max(1, math.floor((panelW - pad * 2) / (iconSize + iconGap)))
        for i, weapon in ipairs(loadout) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cell = vgui.Create("DPanel", contentPanel)
            cell:SetPos(pad + col * (iconSize + iconGap), yPos + row * (iconSize + iconGap))
            cell:SetSize(iconSize, iconSize)
            cell.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(30, 35, 45, 240))
            end
            local mdl = loadoutModel(weapon)
            local icon = vgui.Create("SpawnIcon", cell)
            icon:Dock(FILL)
            icon:DockMargin(3, 3, 3, 3)
            icon:SetModel(mdl)
            icon:SetMouseInputEnabled(false)
            cell:SetTooltip(loadoutDisplayName(weapon))
        end
        local loadoutRows = math.ceil(#loadout / cols)
        yPos = yPos + loadoutRows * (iconSize + iconGap) + 10
    end

    -- Salary
    local salaryLabel = vgui.Create("DLabel", contentPanel)
    salaryLabel:SetText("Salary: $" .. job.salary)
    salaryLabel:SetPos(pad, yPos)
    salaryLabel:SetSize(panelW - pad * 2, 20)
    salaryLabel:SetFont("DermaDefaultBold")
    salaryLabel:SetColor(Color(0, 255, 0))
    yPos = yPos + 24

    -- Level
    local requiredLevel = job.level or 0
    if requiredLevel > 0 then
        local playerLevel = LocalPlayer():GetNWInt("DarkRP_Level", 1)
        local levelLabel = vgui.Create("DLabel", contentPanel)
        levelLabel:SetText(playerLevel >= requiredLevel and ("Unlocked (Lv." .. requiredLevel .. ")") or ("Requires Lv." .. requiredLevel))
        levelLabel:SetColor(playerLevel >= requiredLevel and Color(100, 255, 100) or Color(255, 180, 100))
        levelLabel:SetPos(pad, yPos)
        levelLabel:SetSize(panelW - pad * 2, 18)
        levelLabel:SetFont("DermaDefaultBold")
        yPos = yPos + 22
    end

    -- Players
    local currentPlayers = #team.GetPlayers(job.team)
    local maxPlayers = job.max == 0 and "∞" or job.max
    local playersLabel = vgui.Create("DLabel", contentPanel)
    playersLabel:SetText("Players: " .. currentPlayers .. "/" .. maxPlayers)
    playersLabel:SetPos(pad, yPos)
    playersLabel:SetSize(panelW - pad * 2, 18)
    playersLabel:SetFont("DermaDefaultBold")
    playersLabel:SetColor(Color(255, 255, 255))
    yPos = yPos + 24

    if job.admin > 0 then
        local adminLabel = vgui.Create("DLabel", contentPanel)
        adminLabel:SetText("Requires Admin (Lv." .. job.admin .. ")")
        adminLabel:SetPos(pad, yPos)
        adminLabel:SetSize(panelW - pad * 2, 18)
        adminLabel:SetFont("DermaDefaultBold")
        adminLabel:SetColor(Color(255, 0, 0))
        yPos = yPos + 24
    end

    -- Become button at bottom of info panel
    local bottomBar = vgui.Create("DPanel", InfoPanel)
    bottomBar:Dock(BOTTOM)
    bottomBar:SetTall(50)
    bottomBar:DockMargin(10, 10, 10, 10)
    bottomBar.Paint = function() end

    local playerLevel = LocalPlayer():GetNWInt("DarkRP_Level", 1)
    local requiredLevel = job.level or 0
    local isLocked = requiredLevel > 0 and playerLevel < requiredLevel

    if isLocked then
        local lockLabel = vgui.Create("DLabel", bottomBar)
        lockLabel:SetText("Level " .. requiredLevel .. " required")
        lockLabel:SetFont("DermaDefaultBold")
        lockLabel:SetColor(Color(180, 100, 100))
        lockLabel:Dock(FILL)
        lockLabel:SetContentAlignment(5)
    else
        local becomeBtn = vgui.Create("DButton", bottomBar)
        becomeBtn:SetText("Become →")
        becomeBtn:SetTextColor(Color(0, 0, 0))
        becomeBtn:Dock(FILL)
        becomeBtn.DoClick = function()
            if not job or not jobIndex then return end
            net.Start("RequestJobChange")
            net.WriteUInt(jobIndex, 16)
            net.SendToServer()
        end
        becomeBtn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(100, 200, 100, 240) or Color(50, 150, 50, 240))
        end
    end

end

-- Function to build the Jobs panel (called from cl_inventory.lua). Jobs list and info panel fit to the tab area.
function BuildJobsPanel(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end

    local pad = 10
    local leftPanel = vgui.Create("DPanel", parent)
    leftPanel:Dock(LEFT)
    leftPanel:DockMargin(pad, pad, pad * 0.5, pad)
    leftPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end
    local function layoutJobsPanels()
        if not IsValid(parent) or not IsValid(leftPanel) or not IsValid(InfoPanel) then return end
        local pw = parent:GetWide()
        if pw > 0 then
            -- Jobs list wide enough for a proper grid (min ~5 columns of 80px) so no huge vertical list
            local minWidthForGrid = 5 * (72 + 8) + 30
            leftPanel:SetWide(math.max(minWidthForGrid, math.floor(pw * 0.55)))
        end
    end
    if parent.PerformLayout then
        local old = parent.PerformLayout
        parent.PerformLayout = function(self) if old then old(self) end layoutJobsPanels() end
    else
        parent.PerformLayout = layoutJobsPanels
    end
    layoutJobsPanels()

    local scroll = vgui.Create("DScrollPanel", leftPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(5, 5, 8, 5)
    scroll:GetVBar():SetWide(10)

    InfoPanel = vgui.Create("DPanel", parent)
    InfoPanel:Dock(FILL)
    InfoPanel:DockMargin(pad * 0.5, pad, pad, pad)
    InfoPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    -- If we haven't received job data yet, show a loading message and request data
    if table.IsEmpty(JobsData) then
        local label = vgui.Create("DLabel", scroll)
        label:SetText("Loading jobs...")
        label:SetPos(10, 10)
        label:SetSize(280, 20)
        label:SetColor(Color(255, 255, 255))

        -- Retry mechanism: Keep requesting and refreshing until data is received
        timer.Create("RetryJobsDataRequest", 1, 0, function()
            if not IsValid(parent) then
                timer.Remove("RetryJobsDataRequest")
                return
            end
            if not table.IsEmpty(JobsData) then
                BuildJobsPanel(parent)
                timer.Remove("RetryJobsDataRequest")
                DebugPrint("[Jobs Module] Successfully loaded jobs data after retry")
                return
            end
            net.Start("RequestJobsData")
            net.SendToServer()
            DebugPrint("[Jobs Module] Retrying jobs data request")
        end)

        UpdateInfoPanel(nil, nil) -- Initialize info panel with no selection
        return
    end

    -- Get the player's current team and level (for fade/unlock)
    local playerTeam = LocalPlayer():Team()
    local playerLevel = LocalPlayer():GetNWInt("DarkRP_Level", 1)

    -- Organize jobs by category
    local categories = {}
    for jobIndex, job in pairs(JobsData) do
        -- Skip the player's current job, but always show Citizen so players can switch back to it
        if job.team == playerTeam and (job.name or "") ~= "Citizen" then
            DebugPrint("[Jobs Module] Skipping job " .. job.name .. " as it is the player's current job")
            continue
        end
        local category = job.category or "Other"
        if not categories[category] then
            categories[category] = {}
        end
        table.insert(categories[category], {index = jobIndex, data = job})
    end

    -- Sort categories alphabetically
    local sortedCategories = {}
    for category, _ in pairs(categories) do
        table.insert(sortedCategories, category)
    end
    table.sort(sortedCategories)

    local iconSize, iconSpace = 72, 8
    local leftW = (IsValid(leftPanel) and leftPanel:GetWide() or 430) - 30
    local cols = math.max(5, math.floor(leftW / (iconSize + iconSpace)))

    -- Custom headers + grids (no collapsibles); one scroll for the whole panel
    for _, category in ipairs(sortedCategories) do
        -- Header: simple bar with category name
        local header = vgui.Create("DPanel", scroll)
        header:Dock(TOP)
        header:SetTall(28)
        header:DockMargin(0, 12, 0, 4)
        header.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(35, 45, 60, 250))
            surface.SetDrawColor(0, 160, 220, 180)
            surface.DrawOutlinedRect(0, 0, w, h)
        end
        local headerLabel = vgui.Create("DLabel", header)
        headerLabel:SetText(category)
        headerLabel:SetFont("DermaDefaultBold")
        headerLabel:SetTextColor(Color(255, 255, 255))
        headerLabel:Dock(FILL)
        headerLabel:DockMargin(8, 0, 0, 0)
        headerLabel:SetContentAlignment(4)

        -- Grid of job icons under this category
        local rows = math.ceil(#categories[category] / cols)
        local layout = vgui.Create("DPanel", scroll)
        layout:Dock(TOP)
        layout:SetTall(rows * (iconSize + iconSpace) + iconSpace)
        layout:DockMargin(8, 0, 8, 8)
        layout.Paint = function() end

        -- Sort by level first (level 1 base jobs at top); no level (0) = last
        table.sort(categories[category], function(a, b)
            local lvA, lvB = a.data.level or 0, b.data.level or 0
            if lvA == 0 then lvA = 999 end
            if lvB == 0 then lvB = 999 end
            if lvA ~= lvB then return lvA < lvB end
            return (a.data.name or "") < (b.data.name or "")
        end)

        for i, jobEntry in ipairs(categories[category]) do
            local job = jobEntry.data
            local jobIndex = jobEntry.index
            local requiredLevel = job.level or 0
            local isLocked = requiredLevel > 0 and playerLevel < requiredLevel

            local panel = vgui.Create("DPanel", layout)
            panel:SetSize(iconSize, iconSize)
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols
            panel:SetPos(col * (iconSize + iconSpace) + iconSpace, row * (iconSize + iconSpace) + iconSpace)
            panel.Job = job
            panel.JobIndex = jobIndex
            panel.IsLocked = isLocked
            panel.RequiredLevel = requiredLevel
            -- Faded when locked, full brightness when unlocked
            panel:SetAlpha(isLocked and 130 or 255)
            panel.Paint = function(self, w, h)
                local bgColor = (SelectedJob and SelectedJob.index == jobIndex) and Color(70, 70, 80, 240) or Color(40, 40, 40, 200)
                draw.RoundedBox(4, 0, 0, w, h, bgColor)
            end

            -- Job name on hover; add level hint when locked
            panel:SetTooltip(isLocked and (job.name .. " (Level " .. requiredLevel .. " required)") or job.name)

            -- Icon: playermodel for the job
            local modelPanel = vgui.Create("DModelPanel", panel)
            modelPanel:Dock(FILL)
            modelPanel:DockMargin(4, 4, 4, 4)
            modelPanel:SetModel(job.model or "models/player/kleiner.mdl")
            modelPanel:SetFOV(28)
            modelPanel:SetCamPos(Vector(25, 25, 70))
            modelPanel:SetLookAt(Vector(0, 0, 65))
            modelPanel:SetMouseInputEnabled(false)

            -- Overlay: "Level X" when locked, "Unlocked" when level met and job has level requirement
            local overlay = vgui.Create("DLabel", panel)
            overlay:SetPos(2, 2)
            overlay:SetSize(iconSize - 4, 16)
            overlay:SetFont("DermaDefault")
            overlay:SetContentAlignment(5)
            overlay:SetTextInset(2, 0)
            if isLocked then
                overlay:SetText("Lv." .. requiredLevel)
                overlay:SetColor(Color(255, 220, 100))
            elseif requiredLevel > 0 then
                overlay:SetText("Unlocked")
                overlay:SetColor(Color(150, 255, 150))
            else
                overlay:SetText("")
            end

            -- Single click: show info in panel on the right. Double click: become job (only if unlocked).
            panel.OnMousePressed = function(self, code)
                if code ~= MOUSE_LEFT then return end
                if not self.Job or not self.JobIndex then return end
                local now = CurTime()
                if self._lastClick and (now - self._lastClick) < 0.35 then
                    self._lastClick = nil
                    if not self.IsLocked then
                        net.Start("RequestJobChange")
                        net.WriteUInt(self.JobIndex, 16)
                        net.SendToServer()
                    end
                    return
                end
                self._lastClick = now
                UpdateInfoPanel(self.Job, self.JobIndex)
            end
        end
    end

    -- Initialize the info panel with no selection
    UpdateInfoPanel(nil, nil)
end

-- Receive job data from the server
net.Receive("SendJobsData", function()
    JobsData = net.ReadTable()
    DebugPrint("[Jobs Module] Received jobs data: " .. table.ToString(JobsData))

    -- Rebuild the Jobs panel if it's open
    if IsValid(jobsTab) then
        BuildJobsPanel(jobsTab)
    end
end)

print("[Jobs Module] Client-side loaded successfully.")