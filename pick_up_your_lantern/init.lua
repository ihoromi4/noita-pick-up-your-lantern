--- Pick Up Your Lantern mod entry point.

---Appends mod translation keys into the global translation table.
local function AppendTranslations()
    local translations = ModTextFileGetContent("data/translations/common.csv")
    local mod_translations = ModTextFileGetContent("mods/pick_up_your_lantern/files/translations.csv")
    if translations ~= nil and mod_translations ~= nil then
        translations = translations .. "\n" .. mod_translations .. "\n"
        translations = translations:gsub("\r", ""):gsub("\n\n+", "\n")
        ModTextFileSetContent("data/translations/common.csv", translations)
    end
end

AppendTranslations()
