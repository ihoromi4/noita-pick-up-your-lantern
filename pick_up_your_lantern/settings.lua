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
            GuiTooltip(gui, description, "$menu_modsettings_changes_restart")
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
            GuiTooltip(gui, description, "$menu_modsettings_changes_restart")
        else
            GuiTooltip(gui, description, "")
        end
    end
end

local MOD_ID = "pick_up_your_lantern"
mod_settings_version = 1
mod_settings = {
    {
        category_id = "lighting",
        ui_name = "$pick_up_your_lantern_category_lighting",
        ui_description = "$pick_up_your_lantern_category_lighting_desc",
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
            },
        },
    },
    {
        category_id = "gameplay",
        ui_name = "$pick_up_your_lantern_category_gameplay",
        ui_description = "$pick_up_your_lantern_category_gameplay_desc",
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
            },
        },
    },
}

---Updates mod settings when entering menus or starting a game.
---@param init_scope number
function ModSettingsUpdate(init_scope)
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
    mod_settings[1].ui_name = GetText(
        "$pick_up_your_lantern_category_lighting",
        "Lighting"
    )
    mod_settings[1].ui_description = GetText(
        "$pick_up_your_lantern_category_lighting_desc",
        "Configure illumination and dynamic light mechanics."
    )
    mod_settings[2].ui_name = GetText(
        "$pick_up_your_lantern_category_gameplay",
        "Gameplay"
    )
    mod_settings[2].ui_description = GetText(
        "$pick_up_your_lantern_category_gameplay_desc",
        "Configure how lanterns interact with other game mechanics."
    )
    mod_settings_gui(MOD_ID, mod_settings, gui, in_main_menu)
end
