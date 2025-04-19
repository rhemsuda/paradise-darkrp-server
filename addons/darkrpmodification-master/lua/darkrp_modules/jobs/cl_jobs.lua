print("[JobsMenu] cl_jobs.lua loaded successfully")

if not CLIENT then return end

-- Constants for layout
local FRAME_WIDTH, FRAME_HEIGHT = 1000, 700
local PADDING = 10
local QUADRANT_WIDTH = (FRAME_WIDTH - 3 * PADDING) / 2
local BUTTON_HEIGHT = 30

-- Define fonts using built-in Garry's Mod fonts
local function CreateFonts()
    surface.CreateFont("JobsMenuTitle", {
        font = "Trebuchet24", size = 40, weight = 700, antialias = true, shadow = true
    })
    surface.CreateFont("JobsMenuText", {
        font = "Trebuchet18", size = 20, weight = 500, antialias = true, shadow = true
    })
    surface.CreateFont("JobsMenuTextSmall", {
        font = "Trebuchet18", size = 18, weight = 500, antialias = true, shadow = true
    })
end
CreateFonts()

-- Global state
local JobsMenu = nil

-- Helper function to create a rounded box panel
local function CreateRoundedPanel(parent, x, y, w, h, color)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(x, y)
    panel:SetSize(w, h)
    panel.Paint = function(self, pw, ph)
        draw.RoundedBox(4, 0, 0, pw, ph, color)
    end
    return panel
end

-- Helper function to create a button
local function CreateButton(parent, x, y, w, h, text, onClick, bgColor)
    local button = vgui.Create("DButton", parent)
    button:SetPos(x, y)
    button:SetSize(w, h)
    button:SetText(text)
    button:SetFont("JobsMenuTextSmall")
    button:SetTextColor(Color(255, 255, 255))
    button:SetContentAlignment(5)
    button.Paint = function(self, pw, ph)
        draw.RoundedBox(4, 0, 0, pw, ph, bgColor or Color(70, 70, 70, 150))
    end
    button.DoClick = onClick
    return button
end

-- Create the Jobs Menu
local function CreateJobsMenu()
    if IsValid(JobsMenu) then JobsMenu:Remove() end

    print("[JobsMenu] Creating custom F1 menu")

    JobsMenu = vgui.Create("DFrame")
    JobsMenu:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    JobsMenu:SetPos((ScrW() - FRAME_WIDTH) / 2, (ScrH() - FRAME_HEIGHT) / 2)
    JobsMenu:SetTitle("")
    JobsMenu:SetDraggable(false)
    JobsMenu:ShowCloseButton(true)
    JobsMenu:MakePopup()
    JobsMenu.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 255))
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, Color(50, 50, 50, 255))
    end

    local sheet = vgui.Create("DPropertySheet", JobsMenu)
    sheet:Dock(FILL)
    sheet:DockMargin(PADDING, PADDING, PADDING, PADDING)
    sheet.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 50, 255))
    end

    -- Jobs Tab
    local jobsPanel = vgui.Create("DPanel", sheet)
    jobsPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
    end
    sheet:AddSheet("Jobs", jobsPanel, "icon16/user.png", false, false, "Select your job")

    local jobList = vgui.Create("DPanelList", jobsPanel)
    jobList:SetPos(0, 0)
    jobList:SetSize(QUADRANT_WIDTH, FRAME_HEIGHT - 2 * PADDING)
    jobList:SetSpacing(5)
    jobList:EnableVerticalScrollbar(true)
    jobList:SetPadding(5)

    local infoPanel = vgui.Create("DPanel", jobsPanel)
    infoPanel:SetPos(QUADRANT_WIDTH, 0)
    infoPanel:SetSize(QUADRANT_WIDTH, FRAME_HEIGHT - 2 * PADDING)
    infoPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
    end

    local infoBackground = CreateRoundedPanel(infoPanel, 0, 0, QUADRANT_WIDTH - PADDING, 200, Color(70, 70, 70, 150))

    local infoLabel = vgui.Create("DLabel", infoBackground)
    infoLabel:SetPos(PADDING, PADDING)
    infoLabel:SetSize(QUADRANT_WIDTH - 3 * PADDING, 180)
    infoLabel:SetFont("JobsMenuText")
    infoLabel:SetText("Select a job for details")
    infoLabel:SetTextColor(Color(255, 255, 255))
    infoLabel:SetWrap(true)

    local selectedJob = nil
    local becomeButton = CreateButton(infoPanel, 0, 210, QUADRANT_WIDTH - PADDING, BUTTON_HEIGHT, "Become [job]", function()
        if selectedJob then
            net.Start("JobsMenu_JobChange")
            net.WriteUInt(selectedJob.team, 16)
            net.SendToServer()
            JobsMenu:Close()
        end
    end)

    local fixedJobs = {"Forager", "Miner", "Citizen", "Drug Dealer", "Police", "Banker", "Gun Dealer", "Medic", "Cook"}
    local currentJob = LocalPlayer():Team()

    for _, jobName in ipairs(fixedJobs) do
        local job = nil
        for _, j in pairs(RPExtraTeams) do
            if j.name == jobName then job = j break end
        end
        if job and job.team == currentJob then continue end

        local jobButton = vgui.Create("DButton")
        jobButton:SetText(jobName)
        jobButton:SetFont("JobsMenuText")
        jobButton:SetSize(QUADRANT_WIDTH - PADDING, 40)
        jobButton.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 255))
        end

        local icon = vgui.Create("DModelPanel", jobButton)
        icon:SetSize(32, 32)
        icon:SetPos(5, 4)
        local modelPath = "models/error.mdl"
        if job then
            if jobName == "Miner" then modelPath = "models/props_mining/pickaxe01.mdl"
            elseif jobName == "Forager" then modelPath = "models/weapons/w_crowbar.mdl"
            elseif jobName == "Banker" then modelPath = "models/props_lab/monitor01a.mdl"
            elseif jobName == "Police" then modelPath = "models/weapons/w_stunbaton.mdl"
            elseif jobName == "Drug Dealer" then modelPath = "models/props/de_inferno/potted_plant2.mdl"
            elseif jobName == "Medic" then modelPath = "models/Items/HealthKit.mdl"
            elseif jobName == "Citizen" then
                if type(job.model) == "table" and #job.model > 0 then modelPath = job.model[1]
                elseif type(job.model) == "string" then modelPath = job.model end
            elseif jobName == "Gun Dealer" then modelPath = "models/weapons/w_pist_deagle.mdl"
            elseif jobName == "Cook" then modelPath = "models/props_interiors/pot02a.mdl"
            end
        end
        pcall(function() icon:SetModel(modelPath) end)
        icon:SetCamPos(Vector(30, 0, 5))
        icon:SetLookAt(Vector(0, 0, 5))
        icon:SetFOV(45)

        jobButton.DoClick = function()
            selectedJob = job
            if job then
                local desc = job.description or "No description available."
                infoLabel:SetText("Job: " .. jobName .. "\nModel: " .. modelPath .. "\nDescription: " .. desc)
            else
                infoLabel:SetText("Job not found: " .. jobName)
            end
            becomeButton:SetText("Become " .. jobName)
        end

        jobList:AddItem(jobButton)
    end
end

-- Override DarkRP's default F1 menu functionality
if DarkRP and DarkRP.openHelp then
    print("[JobsMenu] Overriding DarkRP.openHelp")
    local oldOpenHelp = DarkRP.openHelp
    DarkRP.openHelp = function()
        if input.IsKeyDown(KEY_F1) then
            print("[JobsMenu] DarkRP.openHelp called by F1, redirecting to custom jobs menu")
            CreateJobsMenu()
            return true -- Prevent default DarkRP help menu
        end
    end
end

-- Hook to open the Jobs Menu with F1 and block default behavior
hook.Add("ShowHelp", "CustomJobsMenu", function()
    print("[JobsMenu] ShowHelp hook triggered")
    CreateJobsMenu()
    return true -- Block the default ShowHelp behavior
end, -1000) -- High priority to ensure it runs before other hooks

-- Block the default F1 bind (gm_showhelp)
hook.Add("PlayerBindPress", "BlockDefaultF1Menu", function(ply, bind, pressed)
    if bind == "gm_showhelp" and pressed then
        print("[JobsMenu] F1 key pressed, opening custom jobs menu")
        CreateJobsMenu()
        return true -- Suppress the default F1 action
    end
end, -1000) -- High priority to ensure it runs before other hooks

-- Ensure DarkRP's F1 menu is disabled on client initialization
hook.Add("InitPostEntity", "DisableDarkRPF1Menu", function()
    print("[JobsMenu] InitPostEntity hook triggered, attempting to disable DarkRP F1 menu")
    if DarkRP and DarkRP.toggleHelp then
        DarkRP.toggleHelp(false)
        print("[JobsMenu] DarkRP F1 menu disabled via toggleHelp")
    else
        print("[JobsMenu] DarkRP.toggleHelp not found, relying on hooks to block F1")
    end
    timer.Simple(1, function()
        if IsValid(JobsMenu) then
            print("[JobsMenu] Closing auto-opened menu")
            JobsMenu:Remove()
        end
    end)
end)

-- Command to manually open the Jobs Menu
concommand.Add("open_jobsmenu", function()
    print("[JobsMenu] Manual command triggered")
    CreateJobsMenu()
end)

print("[JobsMenu] Client-side loaded successfully")