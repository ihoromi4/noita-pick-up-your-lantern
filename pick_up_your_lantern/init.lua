--- Pick Up Your Lantern mod entry point.

local MOD_ID = "pick_up_your_lantern"

dofile_once("mods/" .. MOD_ID .. "/files/scripts/patch_lighting.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/player_vision.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/all_seeing_eye.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/patch_materials.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/patch_item_radar.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_belt.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_liquid_state.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_hang.lua")

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
PatchXRayProjectile()
PatchMaterialsGlow()
PatchBurningEntity()
PatchGlowShaders()
PatchItemRadar()

local has_logged_init = false

---Called when the player entity is spawned.
---@param player_entity number Entity ID of the spawned player.
function OnPlayerSpawned(player_entity)
    ApplyPlayerVision(player_entity)

    if not has_logged_init then
        has_logged_init = true
        local err = GetShaderPatchError()
        if err ~= nil then
            print(string.format("[%s] ERROR: Shader patch failed: %s", MOD_ID, err))
        else
            print(string.format("[%s] Shader patch status: OK", MOD_ID))
        end
    end
end

---Called when mod settings are changed in the pause menu.
function OnModSettingsChanged()
    UpdatePlayerVision(true)
    UpdateLanternIllumination(true)
end

---Called once every frame before the game world is updated.
function OnWorldPreUpdate()
    UpdatePlayerVision()
    UpdateLanternHang()
    UpdateLanternIllumination()
end

---Called once every frame after the game world is updated.
function OnWorldPostUpdate()
    UpdateLanternBelt()
    UpdateLanternLiquidState()
end
