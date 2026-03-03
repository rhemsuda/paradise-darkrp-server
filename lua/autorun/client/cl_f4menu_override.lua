if not CLIENT then return end

-- Hook into F4MenuTabs to modify the tabs
hook.Add("F4MenuTabs", "RemoveWeaponsTab", function(tabs)
    -- Remove the "Weapons" tab
    for i, tab in ipairs(tabs) do
        if tab.name == DarkRP.getPhrase("weapons") then
            table.remove(tabs, i)
            break
        end
    end
end)