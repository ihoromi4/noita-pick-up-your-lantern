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
- `files/entities/`: entities added by the mod. These are the belt lantern (`lantern_belt.xml`, see [Holding and Belt](holding-and-belt.md)), the chain and cable pieces and the shared chain torch base (see [Lantern Entities](lantern-entities.md)), and the study marker and the looks of fear and rage (see [Creatures and Light](creatures-and-light.md)).
- `files/scripts/`: Lua modules and entity scripts.
- `files/scripts/libs/`: third-party and helper libraries (`nxml.lua`, `diff_patch.lua`).
- `files/patches/`: diff patches for vanilla shaders (`vision/`, `glow/`).
- `files/props_gfx/`: in-hand sprites, burnt-out sprites and inventory icons.
- `files/ui_gfx/`: dot images of the study marker.
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
| `PatchLightSources` | `patch_light_sources.lua` | Tags the light of the Light spell modifier with `pul_light_source`, so it lights enemies for study. |

The vision and glow patches are described in [Vision and Lighting](vision-and-lighting.md).

## Frame Hooks

| Hook | Calls | Purpose |
| --- | --- | --- |
| `OnPlayerSpawned` | `ApplyPlayerVision` | Applies the vision preset to the new player entity and logs the shader patch status once. |
| `OnModSettingsChanged` | `UpdatePlayerVision(true)`, `UpdateLanternIllumination(true)` | Applies changed settings without restarting the run. |
| `OnWorldPreUpdate` | `UpdatePlayerVision`, `UpdateLanternHang`, `UpdateLanternIllumination`, `UpdateEnemyStudy`, `UpdateFireEnemyGlow`, `UpdateLanternAttraction`, `UpdateLanternFear` | Sends shader parameters every frame. Hangs a held lantern on the ceiling on a left click, or returns a lantern thrown with the left button to the hand. Scales lantern light; the lantern scan runs every 30 frames. Studies enemies every 10 frames, gives fire enemies their glow every 30 frames, lures enemies to lanterns every 20 frames and scares them every 30 frames. See [Creatures and Light](creatures-and-light.md). |
| `OnWorldPostUpdate` | `UpdateLanternBelt`, `UpdateLanternLiquidState`, `UpdateTubeLampCables`, `UpdateLanternChains` | Updates the belt lantern in the same frame before rendering. Checks liquid states every 10 frames. Cuts the power of tube lamps that leave the ceiling and moves their cables. Simulates the chains of temple lanterns and chain torches. |

## Entity Scripts

Scripts attached to lantern entities through `LuaComponent`:

| Script | When it runs | Purpose |
| --- | --- | --- |
| `lantern_anchor.lua` | In the world, every 20 frames and on kick | Detaches the lantern from the ceiling when kicked or when the ceiling is destroyed, then removes itself. |
| `lantern_chain_kick.lua` | On kick, on chained lanterns | Marks a lantern to be taken off its chain by `lantern_chain.lua` and pushes it away from the kicker. |
| `lantern_in_world.lua` | Once each time the lantern returns to the world | Resets the mirrored transform scale after a throw or drop. |
| `lantern_throw.lua` | On throw (`Message_ThrowItem`) | Marks a lantern thrown with the left mouse button, so `UpdateLanternHang` returns it to the hand on the next frame. Types that cannot be hung (no `hang_offset_y` in `LANTERN_TYPES`) are not marked and fly away. |
| `lantern_in_hand.lua` | In hand, every frame | Swings the lantern like a damped pendulum. Also drives the belt lantern. |
| `lantern_modifier.lua` | In the world and in hand, only on lit lanterns with a modifier | Runs the Flickering, Short-lived and Cracked modifiers. |
| `lantern_damage.lua` | On damage (`script_damage_received`) | Cracks a lantern that takes damage without breaking. |
| `chain_torch_fire.lua` | Chain torches, every 10 frames in the world and in hand | Douses a torch whose coals are in a liquid and lights it again from fire. |
| `lantern_death.lua`, `lantern_small_death.lua` | On death | Spill oil and fire and spawn the vanilla shatter particles. |
| `mining_lamp_death.lua` | On death | Spills oil and fire; the explosion comes from `ExplodeOnDamageComponent`. |
| `temple_lantern_death.lua` | On death | Spills fading plasma; the explosion comes from `ExplodeOnDamageComponent`. |
| `chain_torch_death.lua` | On death | Scatters fire and sparks of the torch type from the coals. |

Scripts that the mod attaches to other entities at runtime:

| Script | Attached to | Purpose |
| --- | --- | --- |
| `enemy_study_damage.lua` | An enemy whose study has begun | Raises the player's damage against it by its study bonus. |
| `light_source_tag.lua` | The entity of the Light spell modifier | Tags the projectile with `pul_light_source`, then removes itself. |

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
- `pul_light_source`: an entity and its `LightComponent` whose light counts for enemy study, luring and fear. Lanterns declare it in their XML files.
- `pul_xray`: the All-Seeing Eye spell projectile.
- `pul_cable`: a tube lamp cable entity at its ceiling anchor.
- `pul_cable_segment`: a segment sprite of a tube lamp cable.
- `pul_chain`, `pul_mounted_chain`: the anchor entity of a temple lantern chain and of a chain torch chain.
- `pul_chain_link`: a link sprite of any lantern chain.
- `pul_fire_glow`: the light and fog of war hole added to a fire enemy.
- `pul_fire_glow_checked`: an enemy the fire enemy glow has already checked.
- `pul_fire_enemy`: an enemy the fire enemy glow has lit. Lanterns lure such enemies.
- `pul_lantern_attracted`: an enemy that a lantern lures.
- `pul_lantern_scared`, `pul_lantern_enraged`: an enemy that fears lantern light, and one that rages at a lantern.
- `pul_lantern_fear_effect`, `pul_lantern_rage_effect`: the looks of fear and rage, child entities of the enemy.
- `pul_study_marker`: the study marker above an enemy. Its sprites carry `pul_study_in_progress`, `pul_study_paused` and `pul_study_done`.

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
