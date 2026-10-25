dofile("data/scripts/lib/mod_settings.lua")

---Helper for retrieving localized text with fallback.
---@param key string
---@param fallback string
---@return string
local function GetText(key, fallback)
    local text = GameTextGet(key)
    if text == nil or text == "" or text == key then
        return fallback
    end
    return text
end

---Custom boolean setting UI renderer with localization support.
---@param mod_id string
---@param gui userdata
---@param in_main_menu boolean
---@param im_id number
---@param setting table
local function ModSettingBool(mod_id, gui, in_main_menu, im_id, setting)
    local setting_id = mod_setting_get_id(mod_id, setting)
    local value = ModSettingGetNextValue(setting_id)
    if type(value) ~= "boolean" then
        value = setting.value_default or false
    end

    local name = GetText(setting.ui_name, setting.name_fallback or setting.ui_name)
    local state = GameTextGet(value and "$option_on" or "$option_off")
    local text = name .. ": " .. state

    local clicked, right_clicked = GuiButton(gui, im_id, mod_setting_group_x_offset, 0, text)
    if clicked then
        ModSettingSetNextValue(setting_id, not value, false)
        mod_setting_handle_change_callback(mod_id, gui, in_main_menu, setting, value, not value)
    end
    if right_clicked and setting.value_default ~= nil then
        ModSettingSetNextValue(setting_id, setting.value_default, false)
        mod_setting_handle_change_callback(mod_id, gui, in_main_menu, setting, value, setting.value_default)
    end

    local description = GetText(setting.ui_description, setting.desc_fallback or "")
    if description and description ~= "" then
        local value_now = ModSettingGet(setting_id)
        if value ~= value_now and setting.scope == MOD_SETTING_SCOPE_NEW_GAME then
            GuiTooltip(gui, description, "$menu_modsettings_changes_worldgen")
        else
            GuiTooltip(gui, description, "")
        end
    end
end

---Custom enum setting UI renderer with localization support.
---@param mod_id string
---@param gui userdata
---@param in_main_menu boolean
---@param im_id number
---@param setting table
local function ModSettingEnum(mod_id, gui, in_main_menu, im_id, setting)
    local setting_id = mod_setting_get_id(mod_id, setting)
    local value = ModSettingGetNextValue(setting_id)
    if type(value) ~= "string" then
        value = setting.value_default or ""
    end

    local value_id = 1
    for i, val in ipairs(setting.values) do
        if val[1] == value then
            value_id = i
            break
        end
    end

    local name = GetText(setting.ui_name, setting.name_fallback or setting.ui_name)
    local option_raw = setting.values[value_id][2]
    local option_fallback = setting.values[value_id][3] or option_raw
    local option_name = GetText(option_raw, option_fallback)
    local text = name .. ": " .. option_name

    local clicked, right_clicked = GuiButton(gui, im_id, mod_setting_group_x_offset, 0, text)
    if clicked then
        local value_old = value
        value_id = value_id + 1
        if value_id > #setting.values then
            value_id = 1
        end
        value = setting.values[value_id][1]
        ModSettingSetNextValue(setting_id, value, false)
        mod_setting_handle_change_callback(mod_id, gui, in_main_menu, setting, value_old, value)
    end
    if right_clicked and setting.value_default ~= nil then
        ModSettingSetNextValue(setting_id, setting.value_default, false)
        mod_setting_handle_change_callback(mod_id, gui, in_main_menu, setting, value, setting.value_default)
    end

    local description = GetText(setting.ui_description, setting.desc_fallback or "")
    if description and description ~= "" then
        local value_now = ModSettingGet(setting_id)
        if value ~= value_now and setting.scope == MOD_SETTING_SCOPE_NEW_GAME then
            GuiTooltip(gui, description, "$menu_modsettings_changes_worldgen")
        else
            GuiTooltip(gui, description, "")
        end
    end
end

local MOD_ID = "pick_up_your_lantern"
local PRESET_SETTING = "preset"
local PRESET_CUSTOM = "custom"
local PRESET_DEFAULT = "light_touch"

---Settings presets in the order they are cycled through.
---Each preset lists only the option values that differ from the option defaults.
local PRESETS = {
    {
        id = "light_touch",
        ui_name = "$pick_up_your_lantern_preset_light_touch",
        name_fallback = "Light Touch",
        ui_description = "$pick_up_your_lantern_preset_light_touch_desc",
        desc_fallback = "Minimal changes: vanilla vision, ordinary lanterns.",
        overrides = {},
    },
    {
        id = "atmospheric",
        ui_name = "$pick_up_your_lantern_preset_atmospheric",
        name_fallback = "Atmospheric",
        ui_description = "$pick_up_your_lantern_preset_atmospheric_desc",
        desc_fallback = "Dark (50%) vision, lantern progression.",
        overrides = {
            player_vision = "0.5",
            lantern_progression = true,
        },
    },
    {
        id = "survival",
        ui_name = "$pick_up_your_lantern_preset_survival",
        name_fallback = "Survival",
        ui_description = "$pick_up_your_lantern_preset_survival_desc",
        desc_fallback = "Minimal (10%) vision, faint (25%) belt light, lantern progression.",
        overrides = {
            player_vision = "0.1",
            belt_light_scale = "0.25",
            lantern_progression = true,
        },
    },
    {
        id = "pitch_black",
        ui_name = "$pick_up_your_lantern_preset_pitch_black",
        name_fallback = "Pitch Black",
        ui_description = "$pick_up_your_lantern_preset_pitch_black_desc",
        desc_fallback = "Pitch black (0%) vision, faint (25%) belt light, lantern progression.",
        overrides = {
            player_vision = "0.0",
            belt_light_scale = "0.25",
            lantern_progression = true,
        },
    },
}

---Returns all option settings (every setting inside a category).
---@return table[]
local function GetOptionSettings()
    local options = {}
    for _, entry in ipairs(mod_settings) do
        if entry.category_id ~= nil then
            for _, setting in ipairs(entry.settings) do
                table.insert(options, setting)
            end
        end
    end
    return options
end

---Returns the option settings controlled by presets, skipping options marked with `preset_excluded`.
---@return table[]
local function GetPresetSettings()
    local options = {}
    for _, setting in ipairs(GetOptionSettings()) do
        if not setting.preset_excluded then
            table.insert(options, setting)
        end
    end
    return options
end

---Returns the preset with the given ID, or nil.
---@param preset_id string
---@return table|nil
local function GetPreset(preset_id)
    for _, preset in ipairs(PRESETS) do
        if preset.id == preset_id then
            return preset
        end
    end
    return nil
end

---Returns the value a preset gives to an option: its override or the option default.
---@param preset table
---@param setting table
---@return boolean|string
local function GetPresetValue(preset, setting)
    local value = preset.overrides[setting.id]
    if value == nil then
        value = setting.value_default
    end
    return value
end

---Writes all option values of a preset as the next values of the settings.
---@param mod_id string
---@param preset table
local function ApplyPreset(mod_id, preset)
    for _, setting in ipairs(GetPresetSettings()) do
        ModSettingSetNextValue(mod_setting_get_id(mod_id, setting), GetPresetValue(preset, setting), false)
    end
end

---Stores `false` defaults that vanilla `mod_settings_update` skips, so every option has a stored value.
---@param mod_id string
local function InitFalseDefaults(mod_id)
    for _, setting in ipairs(GetOptionSettings()) do
        if setting.value_default == false then
            ModSettingSetNextValue(mod_setting_get_id(mod_id, setting), false, true)
        end
    end
end

---Sets the preset setting to the preset matching the current option values, or to Custom.
---@param mod_id string
local function SyncPreset(mod_id)
    local settings = GetPresetSettings()
    local matched_id = PRESET_CUSTOM
    for _, preset in ipairs(PRESETS) do
        local is_match = true
        for _, setting in ipairs(settings) do
            local value = ModSettingGetNextValue(mod_setting_get_id(mod_id, setting))
            if value == nil then
                value = setting.value_default
            end
            if value ~= GetPresetValue(preset, setting) then
                is_match = false
                break
            end
        end
        if is_match then
            matched_id = preset.id
            break
        end
    end
    ModSettingSetNextValue(mod_id .. "." .. PRESET_SETTING, matched_id, false)
end

---Change callback of option settings: keeps the preset setting in sync.
---@param mod_id string
local function OnOptionChanged(mod_id)
    SyncPreset(mod_id)
end

---Checks whether any new-game option has a pending value for the next run.
---@param mod_id string
---@return boolean
local function HasPendingNewGameChanges(mod_id)
    for _, setting in ipairs(GetOptionSettings()) do
        if setting.scope == MOD_SETTING_SCOPE_NEW_GAME then
            local setting_id = mod_setting_get_id(mod_id, setting)
            if ModSettingGetNextValue(setting_id) ~= ModSettingGet(setting_id) then
                return true
            end
        end
    end
    return false
end

---Custom preset setting UI renderer: cycles presets and applies them to all options.
---@param mod_id string
---@param gui userdata
---@param in_main_menu boolean
---@param im_id number
---@param setting table
local function ModSettingPreset(mod_id, gui, in_main_menu, im_id, setting)
    local setting_id = mod_setting_get_id(mod_id, setting)
    local value = ModSettingGetNextValue(setting_id)
    if type(value) ~= "string" then
        value = setting.value_default
    end

    local preset_index = 0
    for i, preset in ipairs(PRESETS) do
        if preset.id == value then
            preset_index = i
            break
        end
    end
    local preset = PRESETS[preset_index]

    local name = GetText(setting.ui_name, setting.name_fallback)
    local option_name = preset and GetText(preset.ui_name, preset.name_fallback)
        or GetText("$pick_up_your_lantern_preset_custom", "Custom")
    local text = name .. ": " .. option_name

    local clicked, right_clicked = GuiButton(gui, im_id, mod_setting_group_x_offset, 0, text)
    local next_preset = nil
    if clicked then
        next_preset = PRESETS[preset_index % #PRESETS + 1]
    end
    if right_clicked then
        next_preset = GetPreset(setting.value_default)
    end
    if next_preset ~= nil then
        ModSettingSetNextValue(setting_id, next_preset.id, false)
        ApplyPreset(mod_id, next_preset)
        preset = next_preset
    end

    local description = GetText(setting.ui_description, setting.desc_fallback)
    local preset_description = preset and GetText(preset.ui_description, preset.desc_fallback)
        or GetText("$pick_up_your_lantern_preset_custom_desc", "Options changed by hand.")
    description = description .. "\n" .. preset_description
    if HasPendingNewGameChanges(mod_id) then
        GuiTooltip(gui, description, "$menu_modsettings_changes_worldgen")
    else
        GuiTooltip(gui, description, "")
    end
end

mod_settings_version = 1
mod_settings = {
    {
        id = PRESET_SETTING,
        ui_name = "$pick_up_your_lantern_preset_name",
        ui_description = "$pick_up_your_lantern_preset_desc",
        name_fallback = "Preset",
        desc_fallback =
        "Sets all options except Enemy Study at once. Changing an option by hand switches the preset to Custom.\nNew-game options take effect in the next run.",
        value_default = PRESET_DEFAULT,
        scope = MOD_SETTING_SCOPE_RUNTIME,
        ui_fn = ModSettingPreset,
    },
    {
        category_id = "lighting",
        ui_name_key = "$pick_up_your_lantern_category_lighting",
        ui_description_key = "$pick_up_your_lantern_category_lighting_desc",
        name_fallback = "Lighting",
        desc_fallback = "Configure illumination and dynamic light mechanics.",
        foldable = true,
        _folded = false,
        settings = {
            {
                id = "illuminate_the_darkness",
                ui_name = "$pick_up_your_lantern_illuminate_the_darkness_name",
                ui_description = "$pick_up_your_lantern_illuminate_the_darkness_desc",
                name_fallback = "Illuminate the darkness",
                desc_fallback =
                "Lanterns and light sources dispel fog of war around themselves in the world and when held in hand.\nRequires starting a new game.",
                value_default = true,
                scope = MOD_SETTING_SCOPE_NEW_GAME,
                ui_fn = ModSettingBool,
                change_fn = OnOptionChanged,
            },
            {
                id = "illumination_scale",
                ui_name = "$pick_up_your_lantern_illumination_scale_name",
                ui_description = "$pick_up_your_lantern_illumination_scale_desc",
                name_fallback = "Illuminated area size",
                desc_fallback =
                "Scale of the light radius and the fog of war area dispelled by lanterns and light sources.\nLanterns update immediately, other light sources after restarting the game.",
                value_default = "1.0",
                values = {
                    { "1.0", "$pick_up_your_lantern_scale_standard", "Standard (100%)", },
                    { "2.0", "$pick_up_your_lantern_scale_expanded", "Expanded (200%)", },
                    { "3.0", "$pick_up_your_lantern_scale_huge",     "Huge (300%)", },
                    { "5.0", "$pick_up_your_lantern_scale_massive",  "Massive (500%)", },
                },
                scope = MOD_SETTING_SCOPE_RUNTIME,
                ui_fn = ModSettingEnum,
                change_fn = OnOptionChanged,
            },
            {
                id = "belt_light_scale",
                ui_name = "$pick_up_your_lantern_belt_light_scale_name",
                ui_description = "$pick_up_your_lantern_belt_light_scale_desc",
                name_fallback = "Belt lantern light",
                desc_fallback =
                "Light radius and fog of war area of a lantern carried on the belt, relative to holding it in hand.",
                value_default = "0.5",
                values = {
                    { "0.0",  "$pick_up_your_lantern_belt_light_off",      "Off (0%)", },
                    { "0.25", "$pick_up_your_lantern_belt_light_faint",    "Faint (25%)", },
                    { "0.5",  "$pick_up_your_lantern_belt_light_moderate", "Moderate (50%)", },
                    { "0.75", "$pick_up_your_lantern_belt_light_bright",   "Bright (75%)", },
                    { "1.0",  "$pick_up_your_lantern_belt_light_full",     "Full (100%)", },
                },
                scope = MOD_SETTING_SCOPE_RUNTIME,
                ui_fn = ModSettingEnum,
                change_fn = OnOptionChanged,
            },
            {
                id = "player_vision",
                ui_name = "$pick_up_your_lantern_player_vision_name",
                ui_description = "$pick_up_your_lantern_player_vision_desc",
                name_fallback = "Player vision",
                desc_fallback =
                "Controls the player's personal visibility and lighting radius in dark biomes.\nLower settings make handheld lanterns vital for exploration.",
                value_default = "1.0",
                values = {
                    { "1.0",  "$pick_up_your_lantern_vision_vanilla",     "Vanilla (100%)", },
                    { "0.75", "$pick_up_your_lantern_vision_dim",         "Dim (75%)", },
                    { "0.5",  "$pick_up_your_lantern_vision_dark",        "Dark (50%)", },
                    { "0.25", "$pick_up_your_lantern_vision_very_dark",   "Very Dark (25%)", },
                    { "0.1",  "$pick_up_your_lantern_vision_minimal",     "Minimal (10%)", },
                    { "0.0",  "$pick_up_your_lantern_vision_pitch_black", "Pitch Black (0%)", },
                },
                scope = MOD_SETTING_SCOPE_RUNTIME,
                ui_fn = ModSettingEnum,
                change_fn = OnOptionChanged,
            },
            {
                id = "polymorph_vision",
                ui_name = "$pick_up_your_lantern_polymorph_vision_name",
                ui_description = "$pick_up_your_lantern_polymorph_vision_desc",
                name_fallback = "Polymorphed vision",
                desc_fallback =
                "Controls visibility while the player is polymorphed into another creature.",
                value_default = "player",
                values = {
                    { "player", "$pick_up_your_lantern_vision_same_as_player", "Same as player", },
                    { "1.0",    "$pick_up_your_lantern_vision_vanilla",        "Vanilla (100%)", },
                    { "0.75",   "$pick_up_your_lantern_vision_dim",            "Dim (75%)", },
                    { "0.5",    "$pick_up_your_lantern_vision_dark",           "Dark (50%)", },
                    { "0.25",   "$pick_up_your_lantern_vision_very_dark",      "Very Dark (25%)", },
                    { "0.1",    "$pick_up_your_lantern_vision_minimal",        "Minimal (10%)", },
                    { "0.0",    "$pick_up_your_lantern_vision_pitch_black",    "Pitch Black (0%)", },
                },
                scope = MOD_SETTING_SCOPE_RUNTIME,
                ui_fn = ModSettingEnum,
                change_fn = OnOptionChanged,
            },
        },
    },
    {
        category_id = "gameplay",
        ui_name_key = "$pick_up_your_lantern_category_gameplay",
        ui_description_key = "$pick_up_your_lantern_category_gameplay_desc",
        name_fallback = "Gameplay",
        desc_fallback = "Configure how lanterns interact with other game mechanics.",
        foldable = true,
        _folded = false,
        settings = {
            {
                id = "show_lanterns_on_item_radar",
                ui_name = "$pick_up_your_lantern_show_lanterns_on_item_radar_name",
                ui_description = "$pick_up_your_lantern_show_lanterns_on_item_radar_desc",
                name_fallback = "Show lanterns on Item Radar",
                desc_fallback =
                "Allows the Item Radar perk to point to nearby lanterns.",
                value_default = false,
                scope = MOD_SETTING_SCOPE_RUNTIME,
                ui_fn = ModSettingBool,
                change_fn = OnOptionChanged,
            },
            {
                id = "lantern_progression",
                ui_name = "$pick_up_your_lantern_lantern_progression_name",
                ui_description = "$pick_up_your_lantern_lantern_progression_desc",
                name_fallback = "Lantern progression",
                desc_fallback =
                "Lanterns spawn with a quality from dim to masterwork; deeper biomes hold brighter lanterns.\nRarely a lantern gets modifiers: it may flicker or slowly burn out, and a damaged lantern may crack and leak fire.\nThe quality and modifiers of a lantern are told in its description.\nOff in the Light Touch preset, on in all other presets.\nRequires starting a new game.",
                value_default = false,
                scope = MOD_SETTING_SCOPE_NEW_GAME,
                ui_fn = ModSettingBool,
                change_fn = OnOptionChanged,
            },
        },
    },
    {
        category_id = "enemy_study_category",
        ui_name_key = "$pick_up_your_lantern_category_enemy_study",
        ui_description_key = "$pick_up_your_lantern_category_enemy_study_desc",
        name_fallback = "Enemy Study",
        desc_fallback = "Configure studying enemies in lantern light. Presets do not change these options.",
        foldable = true,
        _folded = false,
        settings = {
            {
                id = "enemy_study",
                ui_name = "$pick_up_your_lantern_enemy_study_name",
                ui_description = "$pick_up_your_lantern_enemy_study_desc",
                name_fallback = "Enemy study",
                desc_fallback =
                "Watching an enemy in lantern light studies it and raises your damage against it.\nA dot above the enemy shows its study: yellow while studied, red while paused, green once studied.\nThe more you study enemies of a type, the faster you study the next ones.",
                value_default = false,
                scope = MOD_SETTING_SCOPE_RUNTIME,
                ui_fn = ModSettingBool,
                preset_excluded = true,
            },
            {
                id = "enemy_study_damage_bonus",
                ui_name = "$pick_up_your_lantern_enemy_study_damage_bonus_name",
                ui_description = "$pick_up_your_lantern_enemy_study_damage_bonus_desc",
                name_fallback = "Studied enemy damage bonus",
                desc_fallback =
                "Extra damage you deal to a fully studied enemy.",
                value_default = "0.25",
                values = {
                    { "0.1",  "$pick_up_your_lantern_study_bonus_low",    "+10%", },
                    { "0.25", "$pick_up_your_lantern_study_bonus_medium", "+25%", },
                    { "0.5",  "$pick_up_your_lantern_study_bonus_high",   "+50%", },
                    { "1.0",  "$pick_up_your_lantern_study_bonus_double", "+100%", },
                },
                scope = MOD_SETTING_SCOPE_RUNTIME,
                ui_fn = ModSettingEnum,
                preset_excluded = true,
            },
            {
                id = "enemy_study_duration",
                ui_name = "$pick_up_your_lantern_enemy_study_duration_name",
                ui_description = "$pick_up_your_lantern_enemy_study_duration_desc",
                name_fallback = "Base study time",
                desc_fallback =
                "Time to study an enemy of a type you know nothing about.\nKnowing a type and its relatives shortens it down to 0.5 seconds. Bosses always take 120 seconds.",
                value_default = "10",
                values = {
                    { "3",  "$pick_up_your_lantern_study_duration_3",  "3 s", },
                    { "5",  "$pick_up_your_lantern_study_duration_5",  "5 s", },
                    { "10", "$pick_up_your_lantern_study_duration_10", "10 s", },
                    { "30", "$pick_up_your_lantern_study_duration_30", "30 s", },
                },
                scope = MOD_SETTING_SCOPE_RUNTIME,
                ui_fn = ModSettingEnum,
                preset_excluded = true,
            },
        },
    },
}

---Updates mod settings when entering menus or starting a game.
---@param init_scope number
function ModSettingsUpdate(init_scope)
    InitFalseDefaults(MOD_ID)
    SyncPreset(MOD_ID)
    mod_settings_update(MOD_ID, mod_settings, init_scope)
end

---Returns the count of visible GUI elements in settings.
---@return number
function ModSettingsGuiCount()
    return mod_settings_gui_count(MOD_ID, mod_settings)
end

---Renders settings GUI in the options menu.
---@param gui userdata
---@param in_main_menu boolean
function ModSettingsGui(gui, in_main_menu)
    for _, entry in ipairs(mod_settings) do
        if entry.category_id ~= nil then
            entry.ui_name = GetText(entry.ui_name_key, entry.name_fallback)
            entry.ui_description = GetText(entry.ui_description_key, entry.desc_fallback)
        end
    end
    mod_settings_gui(MOD_ID, mod_settings, gui, in_main_menu)
end
