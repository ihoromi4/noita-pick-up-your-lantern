# Diff Patch

[← Back to R&D Index](../rnd.md)

Single-file library: `pick_up_your_lantern/files/scripts/libs/diff_patch.lua`

> [!IMPORTANT]
> Noita's virtual file system (VFS) mounts mod files exclusively from an allowed list of extensions (`.txt`, `.xml`, `.lua`, `.csv`, `.json`, `.frag`, `.vert`, `.png`). Files with a `.patch` extension are ignored by the engine, so calling `ModTextFileGetContent()` returns `nil`. All patch files must use the `.patch.txt` or `.txt` extension.

Example `path/to/some.patch.txt`:

```patch
# Restricting fog of war radius and piercing darkness with light sources.
# Uses variables GLOW_BOOST and LIGHT_CLAMP_MULT.
--- data/shaders/post_final.frag
+++ data/shaders/post_final.frag
@@ -85,3 +87,14 @@
 fog_of_war_sky_ambient_amount *= 1.0-fade;
+ if (pul_vision.w > 0.5)
+ {
+  float pul_dist = distance(world_pos, pul_player_pos.xy);
+  float pul_light = max(max(light_tex_sample.r, light_tex_sample.g), max(light_tex_sample.b, light_tex_sample.a));
+  float pul_glow = max(max(glow.r, glow.g), glow.b);
+  pul_light = max(pul_light, pul_glow * {{GLOW_BOOST}});
+  float pul_edge = pul_vision.y > 0.0 ? smoothstep(pul_vision.y * 0.75, pul_vision.y, pul_dist) : 1.0;
+  float pul_darken = pul_edge * fade * (1.0 - clamp(pul_light * {{LIGHT_CLAMP_MULT}}, 0.0, 1.0));
+  fog_of_war_amount = clamp(fog_of_war_amount + pul_darken, 0.0, 1.0);
+ }
```

Example of applying patches in code:

```lua
local DiffPatch = dofile_once("mods/" .. MOD_ID .. "/files/scripts/libs/diff_patch.lua")

local SHADER_PATCHES = {
    "mods/" .. MOD_ID .. "/files/patches/vision/01_uniforms.patch.txt",
    "mods/" .. MOD_ID .. "/files/patches/vision/02_fog_restriction.patch.txt",
    "mods/" .. MOD_ID .. "/files/patches/vision/03_ambient_baseline.patch.txt",
    "mods/" .. MOD_ID .. "/files/patches/vision/04_bg_leakage.patch.txt",
}

function PatchShaderVision()
    local shader_config = {
        GLOW_BOOST       = "1.5",
        LIGHT_CLAMP_MULT = "2.0",
        AMBIENT_BASE     = "0.35",
        UNUSED_PARAM     = 42, -- Will be ignored without errors
    }

    local ok, err = DiffPatch.PatchFileBatch(POST_FINAL_SHADER_PATH, SHADER_PATCHES, shader_config)
    if not ok then
        print(string.format("[%s] ERROR: %s", MOD_ID, err))
    end
end
```
