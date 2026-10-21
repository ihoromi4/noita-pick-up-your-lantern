--- Player vision and limited visibility controller for Pick Up Your Lantern mod.
--- Adjusts player LightComponent, FogOfWarRadiusComponent, and post_final shader based on mod settings.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
local nxml = dofile_once("mods/" .. MOD_ID .. "/files/scripts/libs/nxml.lua")
local DiffPatch = dofile_once("mods/" .. MOD_ID .. "/files/scripts/libs/diff_patch.lua")

local SETTING_ID = MOD_ID .. ".player_vision"
local PLAYER_BASE_PATH = "data/entities/player_base.xml"
local POST_FINAL_SHADER_PATH = "data/shaders/post_final.frag"

local PATCH_DIR = "mods/" .. MOD_ID .. "/files/patches/vision/"
local VISION_SHADER_PATCHES = {
    PATCH_DIR .. "01_uniforms.patch.txt",
    PATCH_DIR .. "02_fog_restriction.patch.txt",
    PATCH_DIR .. "03_ambient_baseline.patch.txt",
    PATCH_DIR .. "04_bg_leakage.patch.txt",
}

local VANILLA_FOG_RADIUS = 256
local VANILLA_LIGHT_RADIUS = 350

local last_applied_scale = nil

---Retrieves the active player vision scale multiplier from mod settings.
---@return number
local function GetVisionScale()
    local val = ModSettingGet(SETTING_ID)
    if val == nil then
        val = ModSettingGetNextValue(SETTING_ID)
    end
    if val == nil then
        return 1.0
    end

    local num = tonumber(val)
    if num == nil or num < 0 then
        return 1.0
    end

    return num
end

---Computes calibrated vision parameters for a given multiplier.
---@param scale number Multiplier from 0.0 to 1.0+.
---@return number fog_radius, number light_radius, number ambient_mult, number shader_fog_radius, number enabled
local function CalculateVisionParams(scale)
    if scale >= 1.0 then
        return 256, 350, 1.0, 256.0, 0.0
    end

    if scale <= 0.001 then
        return 0, 0, 0.0, 0.0, 1.0
    end

    local fog_radius = math.max(0, math.floor(VANILLA_FOG_RADIUS * scale))
    local light_radius = math.max(0, math.floor(VANILLA_LIGHT_RADIUS * scale))
    local ambient_mult = math.max(0.0, scale)
    local shader_fog_radius = math.max(0.0, 256.0 * scale)
    local enabled = 1.0

    return fog_radius, light_radius, ambient_mult, shader_fog_radius, enabled
end

local shader_patch_error = nil

---Patches data/shaders/post_final.frag to inject limited vision and ambient lighting uniforms.
---Why this is necessary:
---1. Vanilla post_final.frag adds a hardcoded 0.35 (35%) ambient baseline to all explored areas:
---   `lights += max(0.35 - fog_of_war_sky_ambient_amount, 0.0) * dither_srgb(...)`
---   Even with LightComponent radius = 0, caves remain visible at 35% brightness.
---2. The C++ engine hardcodes a 256px clearing circle in tex_fog around the player.
---This patch injects shader logic to:
---- Modulate the 0.35 ambient baseline by `pul_vision.z` (0.0 on Pitch Black).
---- Re-impose fog of war outside the player's vision radius `pul_vision.y` underground.
---- Allow active light sources (lanterns, torches, explosions in tex_lights) to pierce the fog.
---- Darken background cutouts in caves when fog of war is active.
---@return nil
function PatchShaderVision()
    local shader_config = {
        GLOW_BOOST = "1.5",
        LIGHT_CLAMP_MULT = "2.0",
        AMBIENT_BASE = "0.35",
    }

    local ok, err = DiffPatch.PatchFileBatch(POST_FINAL_SHADER_PATH, VISION_SHADER_PATCHES, shader_config)
    if not ok then
        shader_patch_error = err
        print(string.format("[%s] ERROR: %s", MOD_ID, err))
    end
end

---Returns any error encountered during post_final shader patching.
---@return string?
function GetShaderPatchError()
    return shader_patch_error
end

---Patches data/entities/player_base.xml with initial FogOfWarRadiusComponent and LightComponent.
---@return nil
function PatchPlayerBaseVision()
    local content = ModTextFileGetContent(PLAYER_BASE_PATH)
    if content == nil or content == "" then
        return
    end

    local success, xml = pcall(nxml.parse, content)
    if not success or xml == nil then
        return
    end

    local scale = GetVisionScale()
    local fog_radius, light_radius = CalculateVisionParams(scale)

    local light_comp = xml:first_of("LightComponent")
    if light_comp ~= nil then
        light_comp.attr.radius = tostring(light_radius)
        light_comp.attr.update_properties = "1"
        if light_radius <= 0 then
            light_comp.attr._enabled = "0"
        end
    end

    local fog_comp = xml:first_of("FogOfWarRadiusComponent")
    if fog_comp ~= nil then
        fog_comp.attr.radius = tostring(fog_radius)
        if fog_radius <= 0 then
            fog_comp.attr._enabled = "0"
        end
    else
        local new_fog = nxml.new_element("FogOfWarRadiusComponent", {
            _enabled = fog_radius > 0 and "1" or "0",
            radius = tostring(fog_radius),
        })
        xml:add_child(new_fog)
    end

    ModTextFileSetContent(PLAYER_BASE_PATH, nxml.tostring(xml))
end

---Applies calibrated vision settings to a specific player entity at runtime.
---@param player_entity number Entity ID of the player.
---@return nil
function ApplyPlayerVision(player_entity)
    if player_entity == nil or not EntityGetIsAlive(player_entity) then
        return
    end

    local scale = GetVisionScale()
    local fog_radius, light_radius, ambient_mult, shader_fog_radius, enabled = CalculateVisionParams(scale)

    local light_comp = EntityGetFirstComponentIncludingDisabled(player_entity, "LightComponent")
    if light_comp ~= nil then
        ComponentSetValue2(light_comp, "update_properties", true)
        ComponentSetValue2(light_comp, "radius", light_radius)
        EntitySetComponentIsEnabled(player_entity, light_comp, light_radius > 0)
    end

    local fog_comp = EntityGetFirstComponentIncludingDisabled(player_entity, "FogOfWarRadiusComponent")
    if fog_comp ~= nil then
        ComponentSetValue2(fog_comp, "radius", fog_radius)
        EntitySetComponentIsEnabled(player_entity, fog_comp, fog_radius > 0)
    else
        EntityAddComponent2(player_entity, "FogOfWarRadiusComponent", {
            _enabled = fog_radius > 0,
            radius = fog_radius,
        })
    end

    GameSetPostFxParameter("pul_vision", scale, shader_fog_radius, ambient_mult, enabled)
    last_applied_scale = scale
end

---Updates player position and vision parameters every frame in OnWorldPreUpdate.
---@param force_refresh boolean? Whether to force re-evaluating settings and components.
---@return nil
function UpdatePlayerVision(force_refresh)
    local players = EntityGetWithTag("player_unit")
    if players == nil or #players == 0 then
        GameSetPostFxParameter("pul_vision", 1.0, 256.0, 1.0, 0.0)
        return
    end

    local player = players[1]
    local px, py = EntityGetTransform(player)
    if px ~= nil and py ~= nil then
        GameSetPostFxParameter("pul_player_pos", px, py, 0.0, 0.0)
    end

    local scale = GetVisionScale()
    if force_refresh or scale ~= last_applied_scale then
        ApplyPlayerVision(player)
    end
end
