local PerksMenuFrame = nil

local PERKS_PANEL_W = 420
local PERKS_PANEL_H = 640

local function OpenPerksMenu()
    if IsValid(PerksMenuFrame) then
        PerksMenuFrame:SetVisible(true)
        PerksMenuFrame:MakePopup()
        return
    end
    print("[Perks] Attempting to open Perks Menu")
    local frame = vgui.Create("DFrame")
    if not IsValid(frame) then print("[Perks] Failed to create DFrame") return end
    PerksMenuFrame = frame
    frame.OnRemove = function() PerksMenuFrame = nil end
    frame:SetSize(PERKS_PANEL_W, PERKS_PANEL_H)
    frame:Center()
    frame:SetTitle("Perks Menu")
    frame:SetVisible(true)
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(28, 32, 40, 245))
        surface.SetDrawColor(0, 200, 255, 60)
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, Color(0, 0, 0, 0))
    end

    local mainPanel = vgui.Create("DPanel", frame)
    mainPanel:Dock(FILL)
    mainPanel:DockMargin(8, 8, 8, 8)
    mainPanel.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(40, 44, 52, 220))
    end

    local pointsLabel = vgui.Create("DLabel", mainPanel)
    pointsLabel:Dock(TOP)
    pointsLabel:SetTall(36)
    pointsLabel:SetText("Points: 0")
    pointsLabel:SetFont("DermaDefaultBold")
    pointsLabel:SetTextColor(Color(255, 255, 255))
    pointsLabel:SetContentAlignment(5)

    -- Single panel for grid layout (no scroll so everything fits)
    local layout = vgui.Create("DPanel", mainPanel)
    layout:Dock(FILL)
    layout:DockMargin(0, 4, 0, 0)
    layout.Paint = function() end

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
        if not IsValid(layout) then return end
        local perkData = net.ReadTable()
        local perks = {
            { name = "Endurance", icon = "icon16/clock.png",
                subperks = {
                    { name = "Level", desc = "Current endurance level: " .. (perkData.endurance_level or 0), icon = "icon16/clock.png" },
                    { name = "Total Time Played", desc = formatTime(perkData.endurance_time_played or 0), icon = "icon16/time.png" }
                }
            },
            { name = "Combat", icon = "icon16/bomb.png",
                subperks = {
                    { name = "Attack", desc = "Improves attack capabilities. Level: " .. (perkData.combat_attack_level or 0), icon = "icon16/bomb.png" },
                    { name = "Defence", desc = "Enhances defensive abilities. Level: " .. (perkData.combat_defence_level or 0), icon = "icon16/shield.png" },
                    { name = "Speed", desc = "Boosts movement speed. Level: " .. (perkData.combat_speed_level or 0), icon = "icon16/lightning.png" }
                }
            },
            { name = "Medical", icon = "icon16/heart.png",
                subperks = {
                    { name = "Healing", desc = "Improves healing skills. Level: " .. (perkData.medical_healing_level or 0), icon = "icon16/heart_add.png" },
                    { name = "Revive", desc = "Enhances revive capabilities. Level: " .. (perkData.medical_revive_level or 0), icon = "icon16/heart_add.png" }
                }
            },
            { name = "Contraband", icon = "icon16/money_add.png",
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

        local pad = 8
        local contentW = PERKS_PANEL_W - 8 * 2 - 8
        local contentH = PERKS_PANEL_H - 8 - 36 - 8 - 44 - 8
        local cols = 2
        local cellW = math.floor((contentW - pad * (cols + 1)) / cols)
        local cellH = math.floor((contentH - pad * 3) / 2)
        local catHeaderH = 28
        local subTitleH = 18
        local subCols = 2
        local subSlotW = math.floor((cellW - pad * 3) / subCols)
        local subSlotH = 44

        for i, perk in ipairs(perks) do
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols
            local x = pad + col * (cellW + pad)
            local y = pad + row * (cellH + pad)

            local catPanel = vgui.Create("DPanel", layout)
            catPanel:SetPos(x, y)
            catPanel:SetSize(cellW, cellH)
            catPanel.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, Color(48, 52, 60, 220))
            end

            local icon = vgui.Create("DImage", catPanel)
            icon:SetPos(pad, (catHeaderH - 18) / 2)
            icon:SetSize(18, 18)
            icon:SetImage(perk.icon or "icon16/help.png")

            local nameLabel = vgui.Create("DLabel", catPanel)
            nameLabel:SetPos(pad + 24, 0)
            nameLabel:SetSize(cellW - pad * 2 - 24, catHeaderH)
            nameLabel:SetText(perk.name)
            nameLabel:SetFont("DermaDefaultBold")
            nameLabel:SetTextColor(Color(255, 255, 255))
            nameLabel:SetContentAlignment(4)

            local subTitle = vgui.Create("DLabel", catPanel)
            subTitle:SetPos(pad, catHeaderH)
            subTitle:SetSize(cellW - pad * 2, subTitleH)
            subTitle:SetText(perk.name .. " Perks")
            subTitle:SetFont("DermaDefault")
            subTitle:SetTextColor(Color(0, 200, 255))
            subTitle:SetContentAlignment(4)

            for j, subperk in ipairs(perk.subperks) do
                local subRow = math.floor((j - 1) / subCols)
                local subCol = (j - 1) % subCols
                local subX = pad + subCol * (subSlotW + pad)
                local subY = catHeaderH + subTitleH + pad + subRow * (subSlotH + 4)
                local subPanel = vgui.Create("DPanel", catPanel)
                subPanel:SetPos(subX, subY)
                subPanel:SetSize(subSlotW, subSlotH)
                subPanel.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(32, 36, 42, 220))
                end

                local subIcon = vgui.Create("DImage", subPanel)
                subIcon:SetPos(4, (subSlotH - 16) / 2)
                subIcon:SetSize(16, 16)
                subIcon:SetImage(subperk.icon)

                local subName = vgui.Create("DLabel", subPanel)
                subName:SetPos(24, 4)
                subName:SetSize(subSlotW - 28, 14)
                subName:SetText(subperk.name)
                subName:SetFont("DermaDefault")
                subName:SetTextColor(Color(255, 255, 255))

                local subDesc = vgui.Create("DLabel", subPanel)
                subDesc:SetPos(24, 18)
                subDesc:SetSize(subSlotW - 28, 22)
                subDesc:SetText(subperk.desc)
                subDesc:SetWrap(true)
                subDesc:SetFont("DermaDefault")
                subDesc:SetTextColor(Color(200, 200, 200))
                subDesc:SetContentAlignment(4)
            end
        end
    end)

    local resetButton = vgui.Create("DButton", mainPanel)
    resetButton:Dock(BOTTOM)
    resetButton:SetTall(44)
    resetButton:DockMargin(0, 8, 0, 0)
    resetButton:SetText("Reset")
    resetButton:SetTextColor(Color(255, 255, 255))
    resetButton.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(60, 64, 72, 220))
        if self:IsHovered() then
            draw.RoundedBox(6, 0, 0, w, h, Color(0, 200, 255, 40))
        end
    end
end

concommand.Add("rp_perks", function()
    print("[Perks] rp_perks command executed")
    OpenPerksMenu()
end)

-- Escape closes perks menu so it doesn't stay open and bug when escape/console is used
hook.Add("Think", "Perks_EscapeClose", function()
    if input.IsKeyDown(KEY_ESCAPE) and IsValid(PerksMenuFrame) then
        PerksMenuFrame:Close()
        PerksMenuFrame = nil
    end
end)

-- Only refresh when the menu is already open; never auto-open on join/spawn
net.Receive("UpdatePerkData", function()
    if IsValid(PerksMenuFrame) then
        print("[Perks] Updating perk data for existing menu")
        net.Start("RequestPerkData")
        net.SendToServer()
    end
end)