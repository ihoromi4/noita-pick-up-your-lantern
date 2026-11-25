--- Material and visual effect lighting patcher for Pick Up Your Lantern mod.
--- Modifies data/materials.xml, effect_on_fire.xml, and glow post-processing shaders.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
local nxml = dofile_once("mods/" .. MOD_ID .. "/files/scripts/libs/nxml.lua")
local DiffPatch = dofile_once("mods/" .. MOD_ID .. "/files/scripts/libs/diff_patch.lua")

local MATERIALS_PATH = "data/materials.xml"
local EFFECT_ON_FIRE_PATH = "data/entities/misc/effect_on_fire.xml"
local POST_GLOW1_PATH = "data/shaders/post_glow1.frag"
local POST_GLOW2_PATH = "data/shaders/post_glow2.frag"
local GLOW_PATCH_DIR = "mods/" .. MOD_ID .. "/files/patches/glow/"
local POST_GLOW1_PATCH_PATH = GLOW_PATCH_DIR .. "post_glow1.patch.txt"
local POST_GLOW2_PATCH_PATH = GLOW_PATCH_DIR .. "post_glow2.patch.txt"

---Table of materials to patch with enhanced glow and glow colors.
---@type table<string, {gfx_glow: string, gfx_glow_color?: string}>
local GLOW_PATCHES = {
    flame = { gfx_glow = "400", },
    fire = { gfx_glow = "500", },
    fire_blue = { gfx_glow = "400", gfx_glow_color = "7f82DCFF", },
    liquid_fire = { gfx_glow = "450", },
    liquid_fire_weak = { gfx_glow = "300", },
    burning_powder = { gfx_glow = "350", },
    lava = { gfx_glow = "450", },
    gold_molten = { gfx_glow = "400", },
    metal_molten = { gfx_glow = "400", },
    steel_molten = { gfx_glow = "400", },
    copper_molten = { gfx_glow = "400", },
    brass_molten = { gfx_glow = "400", },
    silver_molten = { gfx_glow = "400", },
    glass_molten = { gfx_glow = "350", },
    aluminium_molten = { gfx_glow = "400", },
    radioactive_liquid = { gfx_glow = "90", gfx_glow_color = "FF00FF00", },
    acid = { gfx_glow = "200", gfx_glow_color = "7f00FF40", },
    plasma_fading = { gfx_glow = "400", },
    plasma_fading_green = { gfx_glow = "400", gfx_glow_color = "7f96FF46", },
    plasma_fading_pink = { gfx_glow = "400", gfx_glow_color = "7fFF28A0", },
    plasma_fading_bright = { gfx_glow = "600", },
    spark = { gfx_glow = "300", },
    spark_red = { gfx_glow = "180", },
    spark_teal = { gfx_glow = "200", },
    spark_purple = { gfx_glow = "150", },
    spark_purple_bright = { gfx_glow = "255", },
    spark_yellow = { gfx_glow = "200", },
    spark_green = { gfx_glow = "200", },
    spark_blue = { gfx_glow = "200", },
    spark_blue_dark = { gfx_glow = "150", },
    spark_white = { gfx_glow = "200", },
    spark_player = { gfx_glow = "200", },
}

---Patches data/materials.xml to add or boost glow attributes for glowing materials.
---@return nil
function PatchMaterialsGlow()
    local content = ModTextFileGetContent(MATERIALS_PATH)
    if content == nil or content == "" then
        return
    end

    local success, xml = pcall(nxml.parse, content)
    if not success or xml == nil then
        return
    end

    local patched_count = 0
    for child in xml:each_child() do
        local name = child.attr and child.attr.name
        if name ~= nil then
            local patch = GLOW_PATCHES[name]
            if patch ~= nil then
                if patch.gfx_glow ~= nil then
                    child.attr.gfx_glow = patch.gfx_glow
                end
                if patch.gfx_glow_color ~= nil then
                    child.attr.gfx_glow_color = patch.gfx_glow_color
                end
                patched_count = patched_count + 1
            end
        end
    end

    if patched_count > 0 then
        ModTextFileSetContent(MATERIALS_PATH, nxml.tostring(xml))
    end
end

---Patches effect_on_fire.xml to attach a LightComponent to burning entities.
---@return nil
function PatchBurningEntity()
    local content = ModTextFileGetContent(EFFECT_ON_FIRE_PATH)
    if content == nil or content == "" then
        return
    end

    local success, xml = pcall(nxml.parse, content)
    if not success or xml == nil then
        return
    end

    local existing_light = xml:first_of("LightComponent")
    if existing_light == nil then
        local light_comp = nxml.new_element("LightComponent", {
            _enabled = "1",
            r = "255",
            g = "140",
            b = "40",
            radius = "180",
            fade_out_time = "1.0",
            update_properties = "1",
        })
        xml:add_child(light_comp)
    else
        existing_light.attr.radius = "180"
    end
    ModTextFileSetContent(EFFECT_ON_FIRE_PATH, nxml.tostring(xml))
end

---Patches post_glow1.frag and post_glow2.frag to increase blur radius to 10.0.
---@return nil
function PatchGlowShaders()
    local config1 = {
        BLUR_RADIUS = "10.0",
        DECAY_MULT = "0.05",
    }
    local ok1, err1 = DiffPatch.PatchFile(POST_GLOW1_PATH, POST_GLOW1_PATCH_PATH, config1)
    if not ok1 then
        print(string.format("[%s] ERROR: %s", MOD_ID, err1))
    end

    local config2 = {
        BLUR_RADIUS = "10.0",
        DECAY_MULT = "1.0 / 23.0",
    }
    local ok2, err2 = DiffPatch.PatchFile(POST_GLOW2_PATH, POST_GLOW2_PATCH_PATH, config2)
    if not ok2 then
        print(string.format("[%s] ERROR: %s", MOD_ID, err2))
    end
end
