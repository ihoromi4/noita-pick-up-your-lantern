# Architecture

How the **Pick Up Your Lantern** mod is put together: what runs at startup, what runs every frame, and how lantern entities switch between the world, the inventory and the player's hand.

## Contents

- [Mod Layout](#mod-layout)
- [Startup Patches](#startup-patches)
- [Frame Hooks](#frame-hooks)
- [Entity Scripts](#entity-scripts)
- [Item Lifecycle Tags](#item-lifecycle-tags)
- [Entity Tags Used by the Mod](#entity-tags-used-by-the-mod)
- [Diff Patch Library](#diff-patch-library)
- [Item Radar Filter](#item-radar-filter)

## Mod Layout

All mod files live in `pick_up_your_lantern/`:

- `init.lua`: entry point. Applies startup patches and registers frame hooks.
- `settings.lua`: Mod Settings definitions and settings presets (`PRESETS`, each listing only the values that differ from the option defaults). Each option's `change_fn` re-syncs the `preset` setting to the matching preset or `custom`. `ModSettingsUpdate` also stores `false` defaults, which vanilla `mod_settings_update` skips. See [Settings](../guides/settings.md) for the player-facing description.
- `data/entities/props/`: full overrides of the vanilla light fixtures that become pickable lanterns, listed in `LANTERN_TYPES` of `files/scripts/lantern_properties_config.lua`. See [Lantern Entities](lantern-entities.md).
- `files/entities/lantern_belt.xml`: the belt lantern entity. See [Holding and Belt](holding-and-belt.md).
- `files/scripts/`: Lua modules and entity scripts.
- `files/scripts/libs/`: third-party and helper libraries (`nxml.lua`, `diff_patch.lua`).
- `files/patches/`: diff patches for vanilla shaders (`vision/`, `glow/`).
- `files/props_gfx/`: in-hand sprites, burnt-out sprites and inventory icons.
- `files/translations.csv`: translation keys appended to `data/translations/common.csv` at startup.

## Startup Patches

`init.lua` runs these functions once, in this order, before the world is loaded:

| Function | Module | What it does |
| --- | --- | --- |
| `AppendTranslations` | `init.lua` | Appends `files/translations.csv` to the game translations. |
| `PatchLighting` | `patch_lighting.lua` | Adds a fog of war hole to vanilla light sources and scales it by `Illuminated area size`. Removes the lantern fog of war holes when `Illuminate the darkness` is off. |
| `PatchPlayerBaseVision` | `player_vision.lua` | Makes the player light adjustable at runtime and adds `FogOfWarRadiusComponent` to `player_base.xml`. |
| `PatchShaderVision` | `player_vision.lua` | Applies the `files/patches/vision/` patches to `post_final.frag`. |
| `PatchXRayProjectile` | `all_seeing_eye.lua` | Tags the All-Seeing Eye spell projectile with `pul_xray`. |
| `PatchMaterialsGlow` | `patch_materials.lua` | Raises `gfx_glow` of fire, lava, molten metals, acid and sparks. |
| `PatchBurningEntity` | `patch_materials.lua` | Adds a light to the burning effect entity. |
| `PatchGlowShaders` | `patch_materials.lua` | Applies the `files/patches/glow/` patches to widen the glow blur. |
| `PatchItemRadar` | `patch_item_radar.lua` | Hooks the Item Radar perk script to hide lanterns. |

The vision and glow patches are described in [Vision and Lighting](vision-and-lighting.md).

## Frame Hooks

| Hook | Calls | Purpose |
| --- | --- | --- |
| `OnPlayerSpawned` | `ApplyPlayerVision` | Applies the vision preset to the new player entity and logs the shader patch status once. |
| `OnModSettingsChanged` | `UpdatePlayerVision(true)`, `UpdateLanternIllumination(true)` | Applies changed settings without restarting the run. |
| `OnWorldPreUpdate` | `UpdatePlayerVision`, `UpdateLanternHang`, `UpdateLanternIllumination` | Sends shader parameters every frame. Hangs a held lantern on the ceiling on a left click, or returns a lantern thrown with the left button to the hand. Scales lantern light; the lantern scan runs every 30 frames. |
| `OnWorldPostUpdate` | `UpdateLanternBelt`, `UpdateLanternLiquidState` | Updates the belt lantern in the same frame before rendering. Checks liquid states every 10 frames. |

## Entity Scripts

Scripts attached to lantern entities through `LuaComponent`:

| Script | When it runs | Purpose |
| --- | --- | --- |
| `lantern_anchor.lua` | In the world, every 20 frames and on kick | Detaches the lantern from the ceiling when kicked or when the ceiling is destroyed, then removes itself. |
| `lantern_in_world.lua` | Once each time the lantern returns to the world | Resets the mirrored transform scale after a throw or drop. |
| `lantern_throw.lua` | On throw (`Message_ThrowItem`) | Marks a lantern thrown with the left mouse button, so `UpdateLanternHang` returns it to the hand on the next frame. |
| `lantern_in_hand.lua` | In hand, every frame | Swings the lantern like a damped pendulum. Also drives the belt lantern. |
| `lantern_modifier.lua` | In the world and in hand, only on lit lanterns with a modifier | Runs the Flickering and Short-lived modifiers. |
| `lantern_death.lua`, `lantern_small_death.lua` | On death | Spill oil and fire and spawn the vanilla shatter particles. |
| `mining_lamp_death.lua` | On death | Spills oil and fire; the explosion comes from `ExplodeOnDamageComponent`. |

## Item Lifecycle Tags

The engine enables and disables item components by the system tags in their `_tags` attribute:

- `enabled_in_world`: active while the lantern hangs or lies in the world, disabled on pickup.
- `enabled_in_hand`: active while the lantern is the held item.
- `enabled_in_inventory`: stays active in the inventory.

The lantern light, fog of war hole and flame animator carry `enabled_in_world,enabled_in_hand`, so the lantern shines both in the world and in hand. Lantern state that must survive all three places, such as the pendulum state, quality tier and modifier, is kept in `VariableStorageComponent` with all three tags.

Vanilla lanterns have a `TorchComponent` that ignites nearby pixels and goes out in water. The mod removes it, so an intact lantern never sets anything on fire. Fire comes only from the oil spilled when a lantern shatters.

`ItemComponent` has `drinkable="0"`, so the player cannot drink the oil inside a lantern.

## Entity Tags Used by the Mod

- `lantern`: every pickable lantern, including other fixtures such as the mining lamp. The illumination scan, liquid states, belt and Item Radar filter look for it.
- `pul_belt`: the belt lantern entity. It deliberately does not contain `lantern`, so the illumination scan never treats it as a real lantern.
- `pul_xray`: the All-Seeing Eye spell projectile.

## Diff Patch Library

`files/scripts/libs/diff_patch.lua` applies unified diff patches to vanilla text files through `ModTextFileGetContent` and `ModTextFileSetContent`. Patches can contain `{{NAME}}` placeholders filled from a config table; unused config keys are ignored.

```lua
local DiffPatch = dofile_once("mods/" .. MOD_ID .. "/files/scripts/libs/diff_patch.lua")

local ok, err = DiffPatch.PatchFileBatch(POST_FINAL_SHADER_PATH, SHADER_PATCHES, {
    GLOW_BOOST = "1.5",
    LIGHT_CLAMP_MULT = "2.0",
})
```

> [!IMPORTANT]
> The Noita virtual file system only mounts mod files with known extensions (`.txt`, `.xml`, `.lua`, `.csv`, `.json`, `.frag`, `.vert`, `.png`). A `.patch` file is invisible to the engine and `ModTextFileGetContent()` returns `nil`. Name patch files `*.patch.txt`.

## Item Radar Filter

`patch_item_radar.lua` prepends a line to `data/scripts/perks/radar_item.lua` that replaces `EntityGetInRadiusWithTag` with the filter from `item_radar_filter.lua`. The filter removes entities tagged `lantern` from `item_pickup` results unless `Show lanterns on Item Radar` is on.
