local function OpenPerksMenu()
    print("[Perks] Attempting to open Perks Menu")
    local frame = vgui.Create("DFrame")
    if not IsValid(frame) then print("[Perks] Failed to create DFrame") return end
    frame:SetSize(280, 700) -- Adjusted height to fit content
    frame:Center()
    frame:SetTitle("Perks Menu")
    frame:SetVisible(true)
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 200)) -- Rounded transparent black background
    end

    local mainPanel = vgui.Create("DPanel", frame)
    mainPanel:Dock(FILL)
    mainPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 50, 200)) -- Rounded dark panel background
    end

    local pointsLabel = vgui.Create("DLabel", mainPanel)
    pointsLabel:Dock(TOP)
    pointsLabel:SetTall(40)
    pointsLabel:SetText("Points: 0") -- Will be updated with server data
    pointsLabel:SetFont("DermaDefaultBold")
    pointsLabel:SetTextColor(Color(255, 255, 255))
    pointsLabel:SetContentAlignment(5) -- Center the text horizontally

    local layout = vgui.Create("DPanel", mainPanel)
    layout:Dock(FILL)
    layout.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 50, 200)) -- Rounded matches main panel
    end

    local function formatTime(totalMinutes)
        local years = math.floor(totalMinutes / (365 * 24 * 60))
        local remainingMinutes = totalMinutes % (365 * 24 * 60)
        local days = math.floor(remainingMinutes / (24 * 60))
        remainingMinutes = remainingMinutes % (24 * 60)
        local hours = math.floor(remainingMinutes / 60)
        local minutes = remainingMinutes % 60
        return string.format("%d Years, %d Days, %d Hours, %d Minutes", years, days, hours, minutes)
    end

    -- Request perk data from server
    print("[Perks] Requesting perk data from server")
    net.Start("RequestPerkData")
    net.SendToServer()

    net.Receive("SendPerkData", function()
        print("[Perks] Received perk data from server")
        local perkData = net.ReadTable()
        local perks = {
            {
                name = "Endurance",
                subperks = {
                    { name = "Level", desc = "Current endurance level: " .. (perkData.endurance_level or 0), icon = "icon16/clock.png" },
                    { name = "Total Time Played", desc = formatTime(perkData.endurance_time_played or 0), icon = "icon16/time.png" }
                }
            },
            {
                name = "Combat",
                subperks = {
                    { name = "Attack", desc = "Improves attack capabilities. Level: " .. (perkData.combat_attack_level or 0), icon = "icon16/bomb.png" },
                    { name = "Defence", desc = "Enhances defensive abilities. Level: " .. (perkData.combat_defence_level or 0), icon = "icon16/shield.png" },
                    { name = "Speed", desc = "Boosts movement speed. Level: " .. (perkData.combat_speed_level or 0), icon = "icon16/lightning.png" }
                }
            },
            {
                name = "Medical",
                subperks = {
                    { name = "Healing", desc = "Improves healing skills. Level: " .. (perkData.medical_healing_level or 0), icon = "icon16/plus.png" },
                    { name = "Revive", desc = "Enhances revive capabilities. Level: " .. (perkData.medical_revive_level or 0), icon = "icon16/heart_add.png" }
                }
            },
            {
                name = "Contraband",
                subperks = {
                    { name = "Printers", desc = "Enhances printer production. Level: " .. (perkData.contraband_printers_level or 0), icon = "icon16/money_add.png" },
                    { name = "Drugs", desc = "Improves drug production. Level: " .. (perkData.contraband_drugs_level or 0), icon = "icon16/pill_add.png" }
                }
            }
        }

        pointsLabel:SetText("Points: " .. (perkData.total_points or 0))

        for _, oldPanel in ipairs(layout:GetChildren()) do
            oldPanel:Remove()
        end

        local baseHeight = 610 / 4 -- Base height for 4 main categories
        for i, perk in ipairs(perks) do
            local categoryPanel = vgui.Create("DPanel", layout)
            categoryPanel:Dock(TOP)
            categoryPanel:SetTall(baseHeight - 2) -- Reduced spacing
            categoryPanel.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 200)) -- Darker category background
            end

            local icon = vgui.Create("DImage", categoryPanel)
            icon:SetPos(10, 5)
            icon:SetSize(24, 24)
            icon:SetImage(perk.icon or "icon16/help.png") -- Default icon if none

            local nameLabel = vgui.Create("DLabel", categoryPanel)
            nameLabel:SetPos(40, 5)
            nameLabel:SetSize(230, 20)
            nameLabel:SetText(perk.name)
            nameLabel:SetFont("DermaDefaultBold")
            nameLabel:SetTextColor(Color(255, 255, 255))
            nameLabel:SetContentAlignment(4) -- Left-align text

            if perk.subperks then
                local titleLabel = vgui.Create("DLabel", categoryPanel)
                titleLabel:SetPos(10, 30)
                titleLabel:SetSize(260, 20)
                titleLabel:SetText(perk.name .. " Perks")
                titleLabel:SetFont("DermaDefaultBold")
                titleLabel:SetTextColor(Color(0, 191, 255)) -- Cool cyan color
                titleLabel:SetContentAlignment(5) -- Center the title

                local subLayout = vgui.Create("DPanel", categoryPanel)
                subLayout:SetPos(10, 50)
                subLayout:SetSize(260, baseHeight - 52) -- Adjusted to reduce open space
                subLayout.Paint = function(self, w, h)
                    draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 200)) -- Subcategory background
                end

                local subHeight = (baseHeight - 52) / #perk.subperks
                for j, subperk in ipairs(perk.subperks) do
                    local subPanel = vgui.Create("DPanel", subLayout)
                    subPanel:SetPos(0, (j - 1) * subHeight)
                    subPanel:SetSize(260, subHeight - 2) -- Reduced spacing
                    subPanel.Paint = function(self, w, h)
                        draw.RoundedBox(8, 0, 0, w, h, Color(25, 25, 25, 200)) -- Even darker subpanel
                    end

                    local subIcon = vgui.Create("DImage", subPanel)
                    subIcon:SetPos(10, 5)
                    subIcon:SetSize(24, 24)
                    subIcon:SetImage(subperk.icon)

                    local subNameLabel = vgui.Create("DLabel", subPanel)
                    subNameLabel:SetPos(40, 5)
                    subNameLabel:SetSize(210, 20)
                    subNameLabel:SetText(subperk.name)
                    subNameLabel:SetFont("DermaDefault")
                    subNameLabel:SetTextColor(Color(255, 255, 255))
                    subNameLabel:SetContentAlignment(4) -- Left-align text

                    local subDescLabel = vgui.Create("DLabel", subPanel)
                    subDescLabel:SetPos(40, 25)
                    subDescLabel:SetSize(210, subHeight - 30) -- Increased height to prevent cutoff
                    subDescLabel:SetText(subperk.desc)
                    subDescLabel:SetWrap(true)
                    subDescLabel:SetTextColor(Color(200, 200, 200))
                    subDescLabel:SetContentAlignment(4) -- Left-align text
                end
            end
        end
    end)

    local resetButton = vgui.Create("DButton", mainPanel)
    resetButton:Dock(BOTTOM)
    resetButton:SetTall(40)
    resetButton:SetText("Reset")
    resetButton:SetTextColor(Color(255, 255, 255))
    resetButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(100, 100, 100, 200)) -- Rounded button background
    end
end

concommand.Add("rp_perks", function()
    print("[Perks] rp_perks command executed")
    OpenPerksMenu()
end)

net.Receive("UpdatePerkData", function()
    local frame = vgui.GetControlByID("PerksMenu") -- Note: This was incorrect, using SetID was wrong
    if IsValid(frame) then
        print("[Perks] Updating perk data for existing menu")
        net.Start("RequestPerkData")
        net.SendToServer()
    else
        print("[Perks] No valid PerksMenu frame found, opening new menu")
        OpenPerksMenu()
    end
end)