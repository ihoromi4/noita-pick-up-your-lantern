--- Player vision and limited visibility controller for Pick Up Your Lantern mod.
--- Adjusts player LightComponent, FogOfWarRadiusComponent, and post_final shader based on mod settings.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
local nxml = dofile_once("mods/" .. MOD_ID .. "/files/scripts/libs/nxml.lua")

local SETTING_ID = MOD_ID .. ".player_vision"
local PLAYER_BASE_PATH = "data/entities/player_base.xml"
local POST_FINAL_SHADER_PATH = "data/shaders/post_final.frag"

local VANILLA_FOG_RADIUS = 256
local VANILLA_LIGHT_RADIUS = 350

local last_applied_scale = nil

---Replaces the first occurrence of a plain substring in haystack.
---@param haystack string
---@param needle string
---@param replacement string
---@return string result, boolean replaced
local function ReplaceOnce(haystack, needle, replacement)
    local start_pos, end_pos = string.find(haystack, needle, 1, true)
    if not start_pos then
        return haystack, false
    end
    return string.sub(haystack, 1, start_pos - 1) .. replacement .. string.sub(haystack, end_pos + 1), true
end

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
    local content = ModTextFileGetContent(POST_FINAL_SHADER_PATH)
    if content == nil or content == "" then
        return
    end

    -- Idempotency check: avoid double-patching if already injected
    if string.find(content, "pul_vision", 1, true) ~= nil then
        return
    end

    -- Block 1: Uniform declarations
    -- `pul_vision`:
    --   x: Vision scale (1.0 = vanilla, 0.0 = pitch black)
    --   y: Shader fog radius in world pixels (0.0 on pitch black, scales up to 256.0)
    --   z: Underground ambient brightness multiplier (0.0 on pitch black, 1.0 on vanilla)
    --   w: Feature switch (1.0 = active, 0.0 = disabled / bypass to vanilla)
    -- `pul_player_pos`:
    --   xy: Player world coordinates (px, py), updated every frame in OnWorldPreUpdate
    local decl_target = "varying vec2 tex_coord_fogofwar;"
    local decl_replacement =
    "varying vec2 tex_coord_fogofwar;\r\nuniform vec4 pul_vision;\r\nuniform vec4 pul_player_pos;"
    local replaced1
    content, replaced1 = ReplaceOnce(content, decl_target, decl_replacement)

    -- Block 2: Dynamic fog of war restriction
    -- Injected right after `fade` calculation (fade = 0.0 at surface Y <= 250, 1.0 deep underground).
    -- Outside `pul_vision.y` distance from the player, re-imposes fog of war unless:
    -- - The fragment is above ground (fade == 0.0), preserving the surface sky.
    -- - The fragment is illuminated by an active light source (light_tex_sample.rgb or alpha hole),
    --   allowing held or thrown lanterns, torches, fires, and explosions to pierce the darkness.
    -- If `pul_vision.y == 0.0` (Pitch Black), `pul_edge` defaults to 1.0 to eliminate the foot halo.
    local fog_target = "fog_of_war_sky_ambient_amount *= 1.0-fade;"
    local fog_replacement = [[fog_of_war_sky_ambient_amount *= 1.0-fade;
	if (pul_vision.w > 0.5)
	{
		float pul_dist = distance(world_pos, pul_player_pos.xy);
		float pul_light = max(max(light_tex_sample.r, light_tex_sample.g), max(light_tex_sample.b, light_tex_sample.a));
		float pul_edge = pul_vision.y > 0.0 ? smoothstep(pul_vision.y * 0.75, pul_vision.y, pul_dist) : 1.0;
		float pul_darken = pul_edge * fade * (1.0 - clamp(pul_light * 2.0, 0.0, 1.0));
		fog_of_war_amount = clamp(fog_of_war_amount + pul_darken, 0.0, 1.0);
	}]]
    local replaced2
    content, replaced2 = ReplaceOnce(content, fog_target, fog_replacement)

    -- Block 3: Underground ambient baseline scaling
    -- Modulates the vanilla hardcoded 0.35 underground ambient lighting.
    -- When `pul_vision.z` is 0.0 (Pitch Black), ambient lighting drops to 0.0,
    -- producing true pitch black darkness in unlit explored caves.
    -- When `pul_vision.w <= 0.5` (vanilla / player dead), falls back to 100% (0.35).
    local ambient_target =
    "lights += max(0.35 - fog_of_war_sky_ambient_amount, 0.0) * dither_srgb( fog_of_war, noise.b, 128.0 );"
    local ambient_replacement = [[float pul_ambient_base = 0.35 * (pul_vision.w > 0.5 ? pul_vision.z : 1.0);
	lights += max(pul_ambient_base - fog_of_war_sky_ambient_amount, 0.0) * dither_srgb( fog_of_war, noise.b, 128.0 );]]
    local replaced3
    content, replaced3 = ReplaceOnce(content, ambient_target, ambient_replacement)

    -- Block 4: Background leakage prevention
    -- In cave areas where foreground materials have transparent holes (color_fg.a < 1.0),
    -- tex_bg (parallax/sky) could peek through in unexplored dark areas.
    -- This blends the background color with fog_of_war underground (scaled by 1.0 - pul_vision.z),
    -- ensuring background voids are completely black when fog is active.
    local bg_target = "color = mix(color , dither_srgb(color, noise.a, 64.0 ), fog_amount );"
    local bg_replacement = [[color = mix(color , dither_srgb(color, noise.a, 64.0 ), fog_amount );
	if (pul_vision.w > 0.5)
	{
		color = mix(color, color * fog_of_war, fade * (1.0 - pul_vision.z));
	}]]
    local replaced4
    content, replaced4 = ReplaceOnce(content, bg_target, bg_replacement)

    -- Only commit changes if all 4 anchors matched and were replaced successfully
    if replaced1 and replaced2 and replaced3 and replaced4 then
        ModTextFileSetContent(POST_FINAL_SHADER_PATH, content)
    else
        print(string.format(
            "[%s] ERROR: Failed to patch %s (block status: b1=%s, b2=%s, b3=%s, b4=%s)",
            MOD_ID,
            POST_FINAL_SHADER_PATH,
            tostring(replaced1),
            tostring(replaced2),
            tostring(replaced3),
            tostring(replaced4)
        ))
    end
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
