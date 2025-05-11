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

    if not job then
        local label = vgui.Create("DLabel", InfoPanel)
        label:SetText("Select a job to view details.")
        label:SetPos(10, 10)
        label:SetSize(280, 20)
        label:SetColor(Color(255, 255, 255))
        return
    end

    local yPos = 10

    -- Job Name
    local nameLabel = vgui.Create("DLabel", InfoPanel)
    nameLabel:SetText("Job: " .. job.name)
    nameLabel:SetPos(10, yPos)
    nameLabel:SetSize(280, 20)
    nameLabel:SetColor(Color(255, 255, 255))
    yPos = yPos + 40

    -- Description
    local descLabel = vgui.Create("DLabel", InfoPanel)
    descLabel:SetText("Description: " .. (job.description or "No description available."))
    descLabel:SetPos(10, yPos)
    descLabel:SetSize(280, 120)
    descLabel:SetWrap(true)
    descLabel:SetColor(Color(255, 255, 255))
    yPos = yPos + 130

    -- Loadout (Base + Job-specific weapons, displayed as a vertical list)
    local baseLoadout = {"weapon_physcannon", "weapon_physgun", "gmod_tool", "gmod_camera"}
    local loadout = table.Copy(baseLoadout)
    if job.candropweapons then
        loadout = {"Weapon Shipments"}
    elseif job.weapons and #job.weapons > 0 then
        table.Add(loadout, job.weapons)
    end
    if #loadout > 0 then
        local loadoutHeader = vgui.Create("DLabel", InfoPanel)
        loadoutHeader:SetText("Loadout:")
        loadoutHeader:SetPos(10, yPos)
        loadoutHeader:SetSize(280, 20)
        loadoutHeader:SetColor(Color(255, 255, 255))
        yPos = yPos + 30

        for _, weapon in ipairs(loadout) do
            local weaponLabel = vgui.Create("DLabel", InfoPanel)
            weaponLabel:SetText("- " .. weapon)
            weaponLabel:SetPos(20, yPos)
            weaponLabel:SetSize(260, 20)
            weaponLabel:SetColor(Color(255, 255, 255))
            yPos = yPos + 25
        end
        yPos = yPos + 10
    end

    -- Salary
    local salaryLabel = vgui.Create("DLabel", InfoPanel)
    salaryLabel:SetText("Salary: $" .. job.salary)
    salaryLabel:SetPos(10, yPos)
    salaryLabel:SetSize(280, 20)
    salaryLabel:SetColor(Color(0, 255, 0))
    yPos = yPos + 40

    -- Players
    local currentPlayers = #team.GetPlayers(job.team)
    local maxPlayers = job.max == 0 and "∞" or job.max
    local playersLabel = vgui.Create("DLabel", InfoPanel)
    playersLabel:SetText("Players: " .. currentPlayers .. "/" .. maxPlayers)
    playersLabel:SetPos(10, yPos)
    playersLabel:SetSize(280, 20)
    playersLabel:SetColor(Color(255, 255, 255))
    yPos = yPos + 40

    -- Admin Requirements
    if job.admin > 0 then
        local adminLabel = vgui.Create("DLabel", InfoPanel)
        adminLabel:SetText("Requires Admin (Level " .. job.admin .. ")")
        adminLabel:SetPos(10, yPos)
        adminLabel:SetSize(280, 20)
        adminLabel:SetColor(Color(255, 0, 0))
        yPos = yPos + 40
    end

    -- Become Job Button
    local becomeButton = vgui.Create("DButton", InfoPanel)
    becomeButton:SetSize(150, 40)
    becomeButton:SetPos(140, yPos)
    becomeButton:SetText("Become " .. job.name)
    becomeButton:SetTextColor(Color(0, 0, 0))
    becomeButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(100, 200, 100, 240) or Color(50, 150, 50, 240))
    end
    becomeButton.DoClick = function()
        if not SelectedJob then return end
        net.Start("RequestJobChange")
        net.WriteUInt(SelectedJob.index, 16)
        net.SendToServer()
        DebugPrint("[Jobs Module] Requested to change to job: " .. SelectedJob.data.name)
    end
end

-- Function to build the Jobs panel (called from cl_inventory.lua)
function BuildJobsPanel(parent)
    if not IsValid(parent) then return end
    for _, child in pairs(parent:GetChildren()) do child:Remove() end

    -- Left panel: Scrollable list of jobs
    local leftPanel = vgui.Create("DPanel", parent)
    leftPanel:SetSize(620, 640)
    leftPanel:SetPos(10, 10)
    leftPanel.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200)) end

    local scroll = vgui.Create("DScrollPanel", leftPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(5, 5, 20, 5)
    scroll:GetVBar():SetWide(10)

    -- Right panel: Information panel for selected job
    InfoPanel = vgui.Create("DPanel", parent)
    InfoPanel:SetSize(300, 640)
    InfoPanel:SetPos(650, 10)
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

    -- Get the player's current team
    local playerTeam = LocalPlayer():Team()

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
        layout:SetTall(math.ceil(#categories[category] / 2) * 130)
        layout:DockMargin(5, 5, 5, 5)
        layout.Paint = function() end

        cat:SetContents(layout)

        -- Sort jobs within the category by name
        table.sort(categories[category], function(a, b) return a.data.name < b.data.name end)

        -- Add each job to the category, two per row
        for i, jobEntry in ipairs(categories[category]) do
            local job = jobEntry.data
            local jobIndex = jobEntry.index

            local panel = vgui.Create("DPanel", layout)
            panel:SetSize(280, 120)
            -- Position: Two per row
            local row = math.floor((i - 1) / 2)
            local col = (i - 1) % 2
            panel:SetPos(col * (280 + 10) + 5, row * (120 + 10) + 5)
            panel.Job = job
            panel.JobIndex = jobIndex
            panel.Paint = function(self, w, h)
                local bgColor = (SelectedJob and SelectedJob.index == jobIndex) and Color(60, 60, 60, 240) or Color(40, 40, 40, 200)
                draw.RoundedBox(4, 0, 0, w, h, bgColor)
            end

            -- Job model preview (focus on face)
            local modelPanel = vgui.Create("DModelPanel", panel)
            modelPanel:SetSize(80, 80)
            modelPanel:SetPos(10, 20)
            modelPanel:SetModel(job.model or "models/player/kleiner.mdl")
            modelPanel:SetFOV(20)
            modelPanel:SetCamPos(Vector(25, 25, 70))
            modelPanel:SetLookAt(Vector(0, 0, 65))

            -- Job details
            local nameLabel = vgui.Create("DLabel", panel)
            nameLabel:SetPos(100, 20)
            nameLabel:SetSize(170, 20)
            nameLabel:SetText(job.name)
            nameLabel:SetColor(Color(255, 255, 255))

            local salaryLabel = vgui.Create("DLabel", panel)
            salaryLabel:SetPos(100, 50)
            salaryLabel:SetSize(170, 20)
            salaryLabel:SetText("Salary: $" .. job.salary)
            salaryLabel:SetColor(Color(0, 255, 0))

            local playersLabel = vgui.Create("DLabel", panel)
            playersLabel:SetPos(100, 80)
            playersLabel:SetSize(170, 20)
            local currentPlayers = #team.GetPlayers(job.team)
            local maxPlayers = job.max == 0 and "∞" or job.max
            playersLabel:SetText("Players: " .. currentPlayers .. "/" .. maxPlayers)
            playersLabel:SetColor(Color(255, 255, 255))

            -- Clicking the panel selects the job and updates the info panel
            panel.OnMousePressed = function(self, code)
                if code == MOUSE_LEFT then
                    UpdateInfoPanel(self.Job, self.JobIndex)
                end
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