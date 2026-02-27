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
-- Expanded "Become job" button under one icon at a time; stored so we can collapse when another is clicked
local ExpandedButton = nil

-- Show "Become X" or "Level X required" to the right of the clicked job icon; collapse previous if any
local function showExpandedButton(panel, job, jobIndex)
    local iconSize, iconSpace = 72, 8
    if IsValid(ExpandedButton) then
        ExpandedButton:Remove()
        ExpandedButton = nil
    end
    local layout = panel:GetParent()
    if not IsValid(layout) then return end
    local px, py = panel:GetPos()
    local playerLevel = LocalPlayer():GetNWInt("DarkRP_Level", 1)
    local requiredLevel = job.level or 0
    local isLocked = requiredLevel > 0 and playerLevel < requiredLevel

    local btn = vgui.Create(isLocked and "DLabel" or "DButton", layout)
    btn:SetSize(iconSize, 32)
    btn:SetPos(px + iconSize + 4, py + (iconSize - 32) / 2)
    if isLocked then
        btn:SetText("Level " .. requiredLevel .. " required")
        btn:SetFont("DermaDefaultBold")
        btn:SetColor(Color(180, 100, 100))
        btn:SetWrap(true)
    else
        btn:SetText("Become →")
        btn:SetTextColor(Color(0, 0, 0))
        btn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(100, 200, 100, 240) or Color(50, 150, 50, 240))
        end
        btn.DoClick = function()
            if not job or not jobIndex then return end
            net.Start("RequestJobChange")
            net.WriteUInt(jobIndex, 16)
            net.SendToServer()
            if IsValid(ExpandedButton) then ExpandedButton:Remove() end
            ExpandedButton = nil
        end
    end
    ExpandedButton = btn
end

-- Function to update the information panel with the selected job's details
local function UpdateInfoPanel(job, jobIndex)
    if not IsValid(InfoPanel) then return end
    for _, child in pairs(InfoPanel:GetChildren()) do child:Remove() end

    SelectedJob = { data = job, index = jobIndex }

    -- Friendly name for loadout items (weapon_physgun -> Physgun, gmod_tool -> Toolgun)
    local function loadoutDisplayName(class)
        if class == "Weapon Shipments" then return class end
        local s = class:gsub("^weapon_", ""):gsub("^gmod_", "")
        return s:sub(1, 1):upper() .. s:sub(2):lower()
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

    local yPos = 10

    -- Job Name
    local nameLabel = vgui.Create("DLabel", InfoPanel)
    nameLabel:SetText(job.name)
    nameLabel:SetPos(10, yPos)
    nameLabel:SetSize(280, 22)
    nameLabel:SetFont("DermaDefaultBold")
    nameLabel:SetColor(Color(255, 255, 255))
    yPos = yPos + 28

    -- Description
    local descLabel = vgui.Create("DLabel", InfoPanel)
    descLabel:SetText(job.description or "No description available.")
    descLabel:SetPos(10, yPos)
    descLabel:SetSize(280, 120)
    descLabel:SetWrap(true)
    descLabel:SetFont("DermaDefault")
    descLabel:SetColor(Color(220, 220, 220))
    yPos = yPos + 125

    -- Loadout - clean bold header and one line per item
    local baseLoadout = {"weapon_physcannon", "weapon_physgun", "gmod_tool", "gmod_camera"}
    local loadout = table.Copy(baseLoadout)
    if job.candropweapons then
        loadout = {"Weapon Shipments"}
    elseif job.weapons and #job.weapons > 0 then
        table.Add(loadout, job.weapons)
    end
    if #loadout > 0 then
        local loadoutHeader = vgui.Create("DLabel", InfoPanel)
        loadoutHeader:SetText("Loadout -")
        loadoutHeader:SetPos(10, yPos)
        loadoutHeader:SetSize(280, 20)
        loadoutHeader:SetFont("DermaDefaultBold")
        loadoutHeader:SetColor(Color(255, 255, 255))
        yPos = yPos + 24

        for _, weapon in ipairs(loadout) do
            local weaponLabel = vgui.Create("DLabel", InfoPanel)
            weaponLabel:SetText(loadoutDisplayName(weapon))
            weaponLabel:SetPos(14, yPos)
            weaponLabel:SetSize(260, 20)
            weaponLabel:SetFont("DermaDefaultBold")
            weaponLabel:SetColor(Color(255, 255, 255))
            yPos = yPos + 22
        end
        yPos = yPos + 8
    end

    -- Salary
    local salaryLabel = vgui.Create("DLabel", InfoPanel)
    salaryLabel:SetText("Salary: $" .. job.salary)
    salaryLabel:SetPos(10, yPos)
    salaryLabel:SetSize(280, 20)
    salaryLabel:SetFont("DermaDefaultBold")
    salaryLabel:SetColor(Color(0, 255, 0))
    yPos = yPos + 28

    -- Level requirement and unlock status
    local requiredLevel = job.level or 0
    if requiredLevel > 0 then
        local playerLevel = LocalPlayer():GetNWInt("DarkRP_Level", 1)
        local levelLabel = vgui.Create("DLabel", InfoPanel)
        if playerLevel >= requiredLevel then
            levelLabel:SetText("Unlocked (Level " .. requiredLevel .. ")")
            levelLabel:SetColor(Color(100, 255, 100))
        else
            levelLabel:SetText("Requires level " .. requiredLevel .. " (you: " .. playerLevel .. ")")
            levelLabel:SetColor(Color(255, 180, 100))
        end
        levelLabel:SetPos(10, yPos)
        levelLabel:SetSize(280, 20)
        levelLabel:SetFont("DermaDefaultBold")
        yPos = yPos + 24
    end

    -- Players
    local currentPlayers = #team.GetPlayers(job.team)
    local maxPlayers = job.max == 0 and "∞" or job.max
    local playersLabel = vgui.Create("DLabel", InfoPanel)
    playersLabel:SetText("Players: " .. currentPlayers .. "/" .. maxPlayers)
    playersLabel:SetPos(10, yPos)
    playersLabel:SetSize(280, 20)
    playersLabel:SetFont("DermaDefaultBold")
    playersLabel:SetColor(Color(255, 255, 255))
    yPos = yPos + 40

    -- Admin Requirements
    if job.admin > 0 then
        local adminLabel = vgui.Create("DLabel", InfoPanel)
        adminLabel:SetText("Requires Admin (Level " .. job.admin .. ")")
        adminLabel:SetPos(10, yPos)
        adminLabel:SetSize(280, 20)
        adminLabel:SetFont("DermaDefaultBold")
        adminLabel:SetColor(Color(255, 0, 0))
        yPos = yPos + 40
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
            -- Jobs list gets ~55%, info panel gets the rest, so both fit on the page
            leftPanel:SetWide(math.max(280, math.floor(pw * 0.55)))
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
        -- Skip the player's current job
        if job.team == playerTeam then
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

    -- Create a collapsible category for each job category
    for _, category in ipairs(sortedCategories) do
        local cat = vgui.Create("DCollapsibleCategory", scroll)
        cat:Dock(TOP)
        cat:SetLabel(category)
        cat:SetExpanded(true)
        cat:DockMargin(5, 5, 5, 0)

        local layout = vgui.Create("DPanel", cat)
        layout:Dock(FILL)
        -- Icon-only grid: each job is a small model icon (no text on the icon)
        local iconSize, iconSpace = 72, 8
        local leftW = (IsValid(leftPanel) and leftPanel:GetWide() or 400) - 30
        local cols = math.max(1, math.floor(leftW / (iconSize + iconSpace)))
        local rows = math.ceil(#categories[category] / cols)
        layout:SetTall(rows * (iconSize + iconSpace) + iconSpace)
        layout:DockMargin(5, 5, 5, 5)
        layout.Paint = function() end

        cat:SetContents(layout)

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

            -- Single click: show info + expand Become / Level required. Double click: become job (only if unlocked).
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
                showExpandedButton(self, job, jobIndex)
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