--- Pick Up Your Lantern mod entry point.

local MOD_ID = "pick_up_your_lantern"

dofile_once("mods/" .. MOD_ID .. "/files/scripts/patch_lighting.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/player_vision.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/patch_materials.lua")

---Appends mod translation keys into the global translation table.
local function AppendTranslations()
    local translations = ModTextFileGetContent("data/translations/common.csv")
    local mod_translations = ModTextFileGetContent("mods/" .. MOD_ID .. "/files/translations.csv")
    if translations ~= nil and mod_translations ~= nil then
        translations = translations .. "\n" .. mod_translations .. "\n"
        translations = translations:gsub("\r", ""):gsub("\n\n+", "\n")
        ModTextFileSetContent("data/translations/common.csv", translations)
    end
end

AppendTranslations()
PatchLighting()
PatchPlayerBaseVision()
PatchShaderVision()
PatchMaterialsGlow()
PatchBurningEntity()
PatchGlowShaders()

---Called when the player entity is spawned.
---@param player_entity number Entity ID of the spawned player.
function OnPlayerSpawned(player_entity)
    ApplyPlayerVision(player_entity)
end

---Called when mod settings are changed in the pause menu.
function OnModSettingsChanged()
    UpdatePlayerVision(true)
end

---Called once every frame before the game world is updated.
function OnWorldPreUpdate()
    UpdatePlayerVision()
end
