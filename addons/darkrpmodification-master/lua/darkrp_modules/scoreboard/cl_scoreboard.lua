-- Debug print to confirm the file is loading
print("[Scoreboard] cl_scoreboard.lua loaded successfully")

if not CLIENT then return end

-- Helper function to print debug messages conditionally
local function DebugPrint(...)
    if GetConVar("rp_debug") and GetConVar("rp_debug"):GetInt() == 1 then
        print(...)
    end
end

-- Define futuristic fonts
surface.CreateFont("ScoreboardTitle", {
    font = "Orbitron", -- Futuristic font (install in garrysmod/resource/fonts/ if needed)
    size = 60,
    weight = 700,
    antialias = true,
    shadow = true
})

surface.CreateFont("ScoreboardText", {
    font = "Montserrat", -- Sleek, modern font (install if needed)
    size = 24,
    weight = 500,
    antialias = true,
    shadow = true
})

surface.CreateFont("CategoryHeader", {
    font = "Montserrat",
    size = 24,
    weight = 700,
    antialias = true,
    shadow = true
})

-- Load icons for donator and admin
local heartIcon = Material("icon16/heart.png")
local starIcon = Material("icon16/star.png")

-- Scoreboard panel
local Scoreboard = nil

local function CreateScoreboard()
    if IsValid(Scoreboard) then Scoreboard:Remove() end

    DebugPrint("[Scoreboard] Building scoreboard")
    Scoreboard = vgui.Create("DFrame")
    local width, height = 800, 600 -- Larger size
    Scoreboard:SetSize(width, height)
    Scoreboard:SetPos((ScrW() - width) / 2, (ScrH() - height) / 2) -- Centered on screen
    Scoreboard:SetTitle("")
    Scoreboard:SetDraggable(false)
    Scoreboard:ShowCloseButton(false)
    Scoreboard:MakePopup()
    Scoreboard.Paint = function(self, w, h)
        DebugPrint("[Scoreboard] Paint function called for DFrame")
        -- Black background with rounded edges
        surface.SetDrawColor(0, 0, 0, 220)
        draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 220))
        -- Teal neon accent
        surface.SetDrawColor(0, 255, 255, 50)
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, Color(0, 0, 0, 0))
        -- Title with glow effect
        draw.SimpleText("Paradise RP", "ScoreboardTitle", w / 2, 30, Color(0, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("Paradise RP", "ScoreboardTitle", w / 2 + 1, 31, Color(255, 255, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    -- Scroll panel for player list
    local scroll = vgui.Create("DScrollPanel", Scoreboard)
    scroll:SetPos(10, 100)
    scroll:SetSize(width - 20, height - 150) -- Full width to prevent cutoff
    scroll.VBar:SetWide(10)

    -- Flat list of players with collapsible categories
    for _, ply in ipairs(player.GetAll()) do
        local gang = team.GetName(ply:Team()) or "None"
        DebugPrint("[Scoreboard] Player: " .. ply:Nick() .. ", Gang: " .. gang)
        local rowColor = Color(30, 30, 30, 200)

        local adminLevel = ply:IsAdmin() and "Admin" or "33"
        local job = ply:getDarkRPVar("job") or "Unknown"
        local ping = ply:Ping()
        local steamID = ply:SteamID()
        local props = 0 -- Placeholder; requires server-side tracking

        -- Determine rank (ULX/FAdmin)
        local rank = "User"
        local nameColor = Color(255, 255, 108) -- Default white
        local glowColor = nil
        local icon = nil
        if ply:IsAdmin() then
            rank = "Admin"
            nameColor = Color(0, 0, 255) -- Blue for admins
            glowColor = Color(0, 0, 128, 100) -- Darker blue glow
            icon = starIcon -- Star for admins
        elseif (ULX and ply:IsUserGroup("donator")) or (FAdmin and ply:FAdmin_GetGlobal("fadmin_donator")) then
            rank = "Donator"
            nameColor = Color(0, 255, 0) -- Green for donators
            icon = heartIcon -- Heart for donators
        end

        -- Collapsible category for each player
        local category = vgui.Create("DCollapsibleCategory", scroll)
        category:Dock(TOP)
        category:DockMargin(5, 0, 5, 5)
        category:SetLabel("") -- Empty label to hide default text
        category:SetTall(25) -- Height for header
        category:SetExpanded(false)
        category.Paint = function(self, w, h)
            DebugPrint("[Scoreboard] Paint function called for category: " .. ply:Nick())
            draw.RoundedBox(8, 0, 0, w, h, rowColor) -- Rounded edges
            surface.SetDrawColor(0, 255, 255, 50) -- Teal outline
            draw.RoundedBox(8, 1, 1, w - 2, h - 2, Color(0, 0, 0, 0))
            -- Draw name with glow at fixed position
            local headerText = ply:Nick() .. (ply:Nick() == "Nicknmb" and " ★" or "")
            surface.SetFont("CategoryHeader")
            local textWidth, textHeight = surface.GetTextSize(headerText)
            draw.SimpleText(headerText, "CategoryHeader", 10, 10, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if glowColor then
                draw.SimpleText(headerText, "CategoryHeader", 11, 11, glowColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) -- Dark glow
            end
            -- Draw icon centered relative to the category header
            if icon then
                local iconX = w / 2 - 8 -- Center the icon horizontally in the header
                surface.SetMaterial(icon)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(iconX, 2, 16, 16) -- 16x16 icon, adjusted vertically
            end
        end

        -- Content panel inside the category
        local content = vgui.Create("DPanel")
        content:SetSize(width - 20, 150) -- Reduced height since ping is removed
        content.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 200)) -- Dark gray content area
        end
        category:SetContents(content)

        -- Player details inside the content panel (Job, Rank, Level, Gang, SteamID)
        local jobLabel = vgui.Create("DLabel", content)
        jobLabel:SetPos(10, 10)
        jobLabel:SetSize(300, 20)
        jobLabel:SetText("Job: " .. job)
        jobLabel:SetFont("ScoreboardText")
        jobLabel:SetTextColor(Color(255, 255, 255))

        local rankLabel = vgui.Create("DLabel", content)
        rankLabel:SetPos(10, 40)
        rankLabel:SetSize(300, 20)
        rankLabel:SetText("Rank: " .. rank)
        rankLabel:SetFont("ScoreboardText")
        rankLabel:SetTextColor(Color(255, 255, 255))

        local levelLabel = vgui.Create("DLabel", content)
        levelLabel:SetPos(10, 70)
        levelLabel:SetSize(300, 20)
        levelLabel:SetText("Level: " .. adminLevel)
        levelLabel:SetFont("ScoreboardText")
        levelLabel:SetTextColor(Color(255, 255, 255))

        local gangLabel = vgui.Create("DLabel", content)
        gangLabel:SetPos(10, 100)
        gangLabel:SetSize(300, 20)
        gangLabel:SetText("Gang: ")
        gangLabel:SetFont("ScoreboardText")
        gangLabel:SetTextColor(Color(255, 255, 255))

        local steamIDLabel = vgui.Create("DLabel", content)
        steamIDLabel:SetPos(10, 130)
        steamIDLabel:SetSize(300, 20)
        steamIDLabel:SetText("SteamID: " .. steamID)
        steamIDLabel:SetFont("ScoreboardText")
        steamIDLabel:SetTextColor(Color(255, 255, 255))

        local propsLabel = vgui.Create("DLabel", content)
        propsLabel:SetPos(310, 10)
        propsLabel:SetSize(300, 20)
        propsLabel:SetText("Props: " .. tostring(props))
        propsLabel:SetFont("ScoreboardText")
        propsLabel:SetTextColor(Color(255, 255, 255))
    end

    -- Stats panel (ping only, smaller box)
    local statsPanel = vgui.Create("DPanel", Scoreboard)
    local pingText = "ping: " .. LocalPlayer():Ping() .. "ms"
    local textWidth, textHeight = surface.GetTextSize(pingText)
    statsPanel:SetSize(textWidth + 20, 30) -- Fit to text with padding
    statsPanel:SetPos(width - textWidth - 30, height - 40) -- Bottom right corner with margin
    statsPanel.Paint = function(self, w, h)
        DebugPrint("[Scoreboard] Paint function called for statsPanel")
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 200)) -- Rounded edges
        local ply = LocalPlayer()
        draw.SimpleText("ping: " .. ply:Ping() .. "ms", "ScoreboardText", w / 2, h / 2, Color(0, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- Toggle scoreboard with DarkRP hooks
hook.Add("ScoreboardShow", "CustomScoreboardShow", function()
    DebugPrint("[Scoreboard] ScoreboardShow triggered")
    gui.EnableScreenClicker(true)
    CreateScoreboard()
    return true
end)

hook.Add("ScoreboardHide", "CustomScoreboardHide", function()
    DebugPrint("[Scoreboard] ScoreboardHide triggered")
    if IsValid(Scoreboard) then Scoreboard:Remove() end
    gui.EnableScreenClicker(false)
    return true
end)

-- This print will always show to confirm successful load
print("[Scoreboard] Client-side loaded successfully")