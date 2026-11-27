--- Shader patches of Pick Up Your Lantern: the target shaders, the patch files, and the template values.
--- The mod applies them at startup. scripts/check-shaders builds the same shaders outside the game
--- and compiles them with glslang, so this table is the single source of both.

local PATCH_DIR = "mods/pick_up_your_lantern/files/patches/"

---@class ShaderPatchConfig
---@field name string Short name of the value set, used for the output folder of the offline build.
---@field values table<string, string> Values of the {{placeholders}} in the patches. Each value is GLSL code.

---@class ShaderPatchJob
---@field target string Path of the vanilla shader in the virtual file system.
---@field patches string[] Patch files, applied in order.
---@field config table<string, string> Values that the mod uses in the game.
---@field extra_configs ShaderPatchConfig[]? Other values that the mod can use, for example under other settings.

---@type table<string, ShaderPatchJob>
local SHADER_PATCHES = {
    vision = {
        target = "data/shaders/post_final.frag",
        patches = {
            PATCH_DIR .. "vision/01_uniforms.patch.txt",
            PATCH_DIR .. "vision/02_fog_restriction.patch.txt",
            PATCH_DIR .. "vision/03_ambient_baseline.patch.txt",
            PATCH_DIR .. "vision/04_bg_leakage.patch.txt",
            PATCH_DIR .. "vision/05_biome_ambient.patch.txt",
        },
        config = {
            GLOW_BOOST = "1.5",
            LIGHT_CLAMP_MULT = "2.0",
            AMBIENT_BASE = "0.35",
        },
    },
    glow1 = {
        target = "data/shaders/post_glow1.frag",
        patches = {
            PATCH_DIR .. "glow/post_glow1.patch.txt",
        },
        config = {
            BLUR_RADIUS = "10.0",
            DECAY_MULT = "0.05",
        },
    },
    glow2 = {
        target = "data/shaders/post_glow2.frag",
        patches = {
            PATCH_DIR .. "glow/post_glow2.patch.txt",
        },
        config = {
            BLUR_RADIUS = "10.0",
            DECAY_MULT = "1.0 / 23.0",
        },
    },
}

return SHADER_PATCHES
