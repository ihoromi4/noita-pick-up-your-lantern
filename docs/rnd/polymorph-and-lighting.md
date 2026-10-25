# Player Polymorph and Lighting System

[← Back to R&D Index](../rnd.md)

Investigation of the interaction between the limited vision and lighting systems of the **Pick Up Your Lantern** mod and player transformations into other entities (Polymorphine, Chaotic Polymorphine, Unstable Polymorphine, Cessation, etc.). The base visibility architecture is described in [Limited Player Vision and Darkness](player-vision-and-darkness.md).

## Contents

- [Discovered Bug](#discovered-bug)
- [How Polymorph Works in the Engine](#how-polymorph-works-in-the-engine)
- [Polytools Library](#polytools-library)
- [Impact on Mod Systems](#impact-on-mod-systems)
- [Fix Options](#fix-options)
- [Implemented Solution](#implemented-solution)
- [In-Game Verification](#in-game-verification)

## Discovered Bug

After the player transforms (observed with Chaotic Polymorphine) into another entity, the surrounding level becomes visible, and upon returning to the original form, visibility remains near-vanilla. Darkness is restored only after modifying mod settings. The bug reproduces across different biomes and is biome-independent. The bug is tracked in [version-0.2.md](../versions/version-0.2.md#known-issues-and-next-steps).

The root cause lies in `UpdatePlayerVision` ([player_vision.lua](../../pick_up_your_lantern/files/scripts/player_vision.lua)), which is called every frame from `OnWorldPreUpdate`:

```lua
local players = EntityGetWithTag("player_unit")
if players == nil or #players == 0 then
    GameSetPostFxParameter("pul_vision", 1.0, 256.0, 1.0, 0.0)
    return
end
...
if force_refresh or scale ~= last_applied_scale then
    ApplyPlayerVision(player)
end
```

1. During transformation, there is no entity with the `player_unit` tag, so the mod sends `pul_vision.w = 0.0` to the shader. This disables all shader patches: fog limitation, ambient 0.35 attenuation, and background darkening.
2. `last_applied_scale` is not reset.
3. Upon returning, `scale == last_applied_scale`, so `ApplyPlayerVision` is not called, and the shader remains disabled.
4. Only the reduced `LightComponent` and `FogOfWarRadiusComponent` on the player remain active, which is why the visual result is "near" vanilla rather than completely vanilla.
5. Changing settings triggers `OnModSettingsChanged` → `UpdatePlayerVision(true)`, and `force_refresh` restores the state.

The core of the problem is that shader state (which must be valid every frame) and player component state (which is updated only on changes) were tied to a single condition: changes in `scale`.

## How Polymorph Works in the Engine

Transformation is implemented via `GameEffectComponent` on a child effect entity. Vanilla effects in `data/entities/misc/`:

| File | `effect` | `polymorph_target` | Duration (frames) |
| --- | --- | --- | --- |
| `effect_polymorph.xml` | `POLYMORPH` | `data/entities/animals/sheep.xml` | 600 |
| `effect_polymorph_random.xml` | `POLYMORPH_RANDOM` (Chaotic Polymorphine) | `[RANDOM]` | 600 |
| `effect_polymorph_unstable.xml` | `POLYMORPH_UNSTABLE` | `data/entities/animals/sheep.xml` | 1200 |
| `effect_polymorph_cessation.xml` | `POLYMORPH_CESSATION` | `data/entities/animals/nibbana.xml` | 20 |

Known facts about the mechanics:

- **Serialization.** The original entity is serialized into the `GameEffectComponent.mSerializedData` field (base64), and an entity with `polymorph_target` is spawned in its place. When the effect expires, the original entity is restored from serialized data. The [polytools](#polytools-library) library is built on this mechanism.
- **Polymorphed player tags.** A transformed player has the tag `polymorphed_player`, or `polymorphed_cessation` in the case of Cessation, instead of `player_unit`. Vanilla itself searches for the player using these tags in `data/scripts/magic/null_room/check.lua` (lines 95–110).
- **Detecting active effects.** The active effect can be retrieved via `GameGetGameEffect(entity_id, "POLYMORPH")` and its equivalents for other effect types (`null_room/check.lua`, function `permapolymorph_entity`).
- **New entity IDs.** **[Needs verification]** According to comments in the Advanced Spell Inventory mod (`files/poly.lua`), both the polymorphed entity and the entity it reverts into have IDs distinct from the original entity. Thus, upon reverting, the player is a new entity.
- **Components on the creature.** **[Needs verification]** When replacing components of the transformed entity, `polytools/apply.lua` preserves `ControlsComponent` and `FogOfWarRadiusComponent`. This indicates that the engine automatically attaches `FogOfWarRadiusComponent` to the polymorphed player, likely with the vanilla radius rather than the mod-reduced radius.
- **Inventory.** **[Needs verification]** The player's child entities (inventory, held item) are serialized alongside the player and restored upon reverting. A held lantern disappears from the world for the duration of the polymorph along with its light and fog-of-war hole.
- **`OnPlayerSpawned`.** **[Needs verification]** This callback is most likely not reinvoked after returning from polymorph, so it cannot be relied upon.

## Polytools Library

There is no dedicated polymorph library in vanilla scripts. The third-party library **polytools** was found in the Advanced Spell Inventory mod: `other_mods/Advanced Spell Inventory/lib/polytools/`.

Key files:

- `polytools_init.lua` — `polytools.init(path)` substitutes the real path in place of the `[POLYTOOLS_PATH]` placeholder across all library files via `ModTextFileSetContent`. Called during mod initialization.
- `polytools.lua` — public API.
- `apply.lua` — script executed when the effect is applied. Removes components of the intermediate "sheep", loads target entity components, disables AI, and attaches player controls.
- `effect.xml` / `effect_silent.xml` — effect entities with `GameEffectComponent effect="POLYMORPH"`. The silent variant has `frames="1"` and an empty target `null.xml`.
- `depoly_death.lua` — terminates polymorph instead of killing the transformed creature upon death.
- `ui/` — components to preserve the player's UI (health, inventory) during polymorph.

API (`polytools.lua`):

| Function | Purpose |
| --- | --- |
| `polymorph(target, poly_into, duration, keep_ui, components_file, end_on_death)` | Transforms the entity into the specified target for the given number of frames. |
| `hide(target, duration)` | Transforms the entity into empty `null.xml`, temporarily hiding it. |
| `save(target)` | Serializes the entity via `hide(target, 1)` and returns the `mSerializedData` string. |
| `load(target, data)` | Restores the entity from the serialized string by writing it into the effect's `mSerializedData`. |
| `spawn(x, y, data, delay_load)` | Spawns a new entity from serialized data. |
| `getPath(target)` | Decodes the serialized data header and returns the entity XML path. |

The library depends on `disco_util` (an `Entity` wrapper around the ECS API). For this mod, it is primarily useful as reference documentation on polymorph mechanics and as a testing utility — for example, calling `polytools.polymorph` on the player without potions. Adding it as a project dependency to fix the bug is unnecessary: vanilla tags and `GameGetGameEffect` are sufficient.

## Impact on Mod Systems

| System | Behavior During Polymorph | Behavior After Reverting |
| --- | --- | --- |
| Post-processing shader `post_final.frag` (`pul_vision`) | Disabled (`w = 0.0`) because no `player_unit` entity is found. | Remains disabled until settings are modified (**bug**). |
| Player position (`pul_player_pos`) | Not updated because the function exits early. | Resumes updating. |
| Player `LightComponent` | Absent on the creature; creature may possess its own light (e.g., firebug). | Restored from serialized data or patched `player_base.xml`. |
| `FogOfWarRadiusComponent` | **[Needs verification]** Engine likely attaches its own component with vanilla radius. | Restored with reduced radius. |
| Handheld lantern | **[Needs verification]** Disappears along with inventory. | Returns; pendulum state is preserved in the lantern's `VariableStorageComponent`. |

## Fix Options

### Reset `last_applied_scale`

In the "no player" branch, add `last_applied_scale = nil`. Upon return, the change condition will trigger, and `ApplyPlayerVision` will reconfigure both components and the shader.

- Pros: minimal fix with low risk.
- Cons: darkness remains disabled during polymorph, turning polymorph into a way to see everything.

### Track the Player Entity ID

Store `last_applied_entity` and reapply if either `scale` or the entity ID has changed:

```lua
if force_refresh or scale ~= last_applied_scale or player ~= last_applied_entity then
    ApplyPlayerVision(player)
end
```

- Pros: covers any player entity replacement — respawns, other mods recreating the player.
- Pros: settings modified during polymorph will apply upon return.
- Dependency: only works if the ID is new upon return. Otherwise must be combined with another approach.

### Pass `pul_vision` Every Frame

Extract `GameSetPostFxParameter("pul_vision", ...)` from `ApplyPlayerVision` into `UpdatePlayerVision`, caching the result of `CalculateVisionParams`. Handled identically to how `pul_player_pos` is already passed.

- Pros: shader state never gets "stuck".
- Pros: single call per frame, very cheap.
- Cons: does not restore player components, so it must be paired with one of the options above.

### Support `polymorphed_player`

If `player_unit` is not found, search for `polymorphed_player` and `polymorphed_cessation`, exactly as vanilla does. For the polymorphed creature, update only `pul_player_pos` and keep `pul_vision` active, without modifying its components:

- `EntityGetFirstComponentIncludingDisabled(entity, "LightComponent")` would return the creature's native light, which the mod would modify or disable.
- Adding `FogOfWarRadiusComponent` to a third-party entity is risky: it is uncertain whether the component persists after reverting.

Pros: darkness does not vanish even during polymorph. Cons: requires verifying engine behavior.

### Recommendation

Combine three approaches: pass shader uniforms every frame, reconfigure components when `scale` or entity ID changes, and update only the shader for `polymorphed_player`. As a quick hotfix for 0.2, resetting `last_applied_scale` is sufficient.

## Implemented Solution

The recommended combination has been implemented in [player_vision.lua](../../pick_up_your_lantern/files/scripts/player_vision.lua). **[Confirmed]** in-game: darkness functions both during polymorph and after reverting without requiring settings changes.

- **Player detection**: `FindPlayerEntity` searches for `player_unit`, and if no such entity is present, falls back to `polymorphed_player` and `polymorphed_cessation`. Returns the entity ID and a polymorph flag. The moment of polymorph is detected as a change in this flag or entity ID between frames.
- **Shader per frame**: `ApplyShaderVision(scale)` sends `pul_vision` every frame, preventing shader state from ever getting stuck.
- **Player components**: `ApplyPlayerVision` is called only for `player_unit` when settings or the entity ID (`last_applied_entity`) have changed. This handles returning from polymorph regardless of whether the player receives a new entity ID.
- **Polymorphed creature**: Only `pul_player_pos` and `pul_vision` are updated. The creature's native `LightComponent` and `FogOfWarRadiusComponent` are untouched. The shader simply layers darkness on top of vanilla fog, so the limitation holds even if the engine assigns the creature a vanilla fog clearing radius.
- **Dedicated setting**: `polymorph_vision` in Mod Settings ("Polymorphed vision"): `Same as player` (default, reuses `player_vision`) or any vision preset. The scope is `MOD_SETTING_SCOPE_RUNTIME`, so changes apply immediately.

## In-Game Verification

1. Does the player ID change after polymorph (`print(player)` before and after).
2. Does the polymorphed creature receive the `polymorphed_player` tag across all effect types, including `POLYMORPH_RANDOM`.
3. Are mod-modified player component values preserved upon reverting, or are they re-read from `player_base.xml`.
4. Does the polymorphed creature have `FogOfWarRadiusComponent`, and with what radius.
5. Is `OnPlayerSpawned` invoked after reverting.
6. What happens to the held lantern: does it disappear during polymorph and return to hands afterward.
7. Behavior under permanent polymorph (null room, `permapolymorph_entity`), when the player never reverts.
