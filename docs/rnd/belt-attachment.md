# Belt Attachment and Passive Illumination

[← Back to R&D Index](../rnd.md)

## Table of Contents

- [Extra Backpack Reference Analysis](#extra-backpack-reference-analysis)
- [What Can Be Used as a Pattern](#what-can-be-used-as-a-pattern)
- [Differences for the Lantern](#differences-for-the-lantern)
- [Implementation](#implementation)
- [Open Questions](#open-questions)

## Extra Backpack Reference Analysis

The "Extra Backpack" mod (Steam ID: `3807317449`, version 0.8). The visual part of the belt bag takes ~150 lines in `files/backpack_control.lua` (`update_back_visual`, `ensure_child_entity`, `apply_visual_transform`) and three XML files in `data/`. The rest of the mod (GUI panel, item storage, Entangled Worlds synchronization) is not needed for our purposes.

How it works:

- **Separate child entity of the player.** `data/backpack_visual.xml` is loaded via `EntityLoad` at the **player's coordinates** (not `(0, 0)`), followed by `EntityRemoveFromParent` + `EntityAddChild(player, visual)`. The backpack item itself remains in the inventory unchanged.
- **Attachment to the belt.** The entity root has an `InheritTransformComponent` with `parent_hotspot_tag="belt_root"`. This is the standard player hotspot (belt, pixel `(4, 12)` in a 12×19 frame from `player_hotspots.png`), the same one used by the vanilla rat tail.
- **Swaying.** The root has a `VerletPhysicsComponent` with 2 points: an empty "hinge" and a segment with a `SpriteComponent`. The setup mirrors the vanilla `data/entities/verlet_chains/tail/verlet_tail.xml`. Key parameters:
  - `follow_entity_transform="1"`: The chain is simulated in world coordinates, and this flag drags it along with the entity.
  - `gets_entity_velocity_coeff="1"`: Removes jitter caused by the hotspot's "breathing" animation.
  - `velocity_dampening="0.2"`, `mass_min/max="2"`, `resting_distance="6"`, `stiffness="3.0"`: High damping, heavy short pendulum.
  - `simulate_wind="0"`, `collide_with_cells="0"`.
- **Sprite on the chain segment.** Has `update_transform="0"` and `update_transform_rotation="0"` because position and rotation are driven by the verlet simulation. The engine rotates the segment along the chain (downward = +90°), so the PNG is drawn **rotated 90° counterclockwise** (`player_backpack_pre.png`, 6×2). `z_index="0.7"`, meaning in front of the player (`0.6`), just like the vanilla cape.
- **Flipping/Mirroring.** `rotate_based_on_x_scale` is disabled because it flips the entire chain by 180° and causes a jarring jerk when turning around. Instead, every frame, `special_scale_x = ±1` and `offset_x * facing` are written to the segment's `SpriteComponent` based on the player's `scale_x`. Since values from XML are overwritten by the verlet simulation after loading, they must be updated from Lua every frame.
- **Lifecycle.** Every frame (`OnWorldPostUpdate`), the mod evaluates `wanted = backpack belongs to player (EntityGetRootEntity) and is not in hands (Inventory2Component.mActiveItem)`. The entity is located by tag, and created or destroyed via `EntityKill`.
- **Additional components — only on a separate entity.** Verlet chain segments support only a single `SpriteComponent`: the author experienced sprite disappearance when adding a particle emitter to a segment. In vanilla files, 144 out of 162 segments only have a `SpriteComponent`. Therefore, particles are separated into a child entity `backpack_sparkle.xml` with the same `InheritTransformComponent` on `belt_root`.

## What Can Be Used as a Pattern

Yes, this implementation can be used as a **design pattern**: entity hierarchy, verlet parameters, and engine pitfalls. We do not copy code or graphics directly: the mod has no license, and its style (Lua modules, Chinese comments) differs from ours. The approach itself is built upon vanilla mechanics (rat tail, `text_above_head`), so writing our own implementation following the same architecture is appropriate.

What we adopt:

- Player child entity with `InheritTransformComponent` targeting `belt_root`, spawned at player coordinates, with `EntityRemoveFromParent` before `EntityAddChild`.
- A 2-point verlet chain for swaying. For a lantern hanging on a hook, this is even more natural than for a bag, fulfilling the requirement to "synchronize motion with player locomotion."
- Flipping via `special_scale_x` every frame, without `rotate_based_on_x_scale`.
- Separation of concerns: the verlet segment only renders the sprite, while light and `fog_of_war_hole` reside on a separate child entity.
- The "desired state → create/destroy" lifecycle pattern evaluated every frame.

What we skip: GUI, item storage, Entangled Worlds synchronization.

> [!NOTE]
> The author claims that `EntityGetWithTag` matches tag substrings. This claim is doubtful. However, it is prudent to give belt entities unique tags that do not contain `lantern` (specifically, `pul_belt` in our implementation) to avoid interfering with the `UpdateLanternIllumination` loop that iterates over `EntityGetWithTag("lantern")`.

## Differences for the Lantern

- **Lantern selection.** Instead of "our backpack", we look for the first lantern among `inventory_quick` children ordered by slot index (`ItemComponent.inventory_slot`). There is never more than one lantern on the belt.
- **Lantern held in hands.** If the active item (`mActiveItem`) is any lantern, **no** lantern is displayed on the belt and belt light is disabled (`wanted = false`), even if there are other lanterns in the inventory. A belt lantern appears only when holding a wand, flask, another item, or nothing.
- **Flame animation.** The in-hand lantern sprite is an animated `.xml` (`lantern_in_hand.xml`). Vanilla verlet segments use static PNGs. Whether an animated `.xml` works on a segment with `update_transform="0"` was not tested: the implementation avoided verlet entirely (see [Implementation](#implementation)).
- **Lantern state.** The belt appearance must reflect the specific item's state: an extinguished lantern (`IsLanternExtinguished`) shows the `*_out` sprite and emits no light; the small lantern has its own sprite.
- **Light.** A `LightComponent` with reduced radius accounting for quality tier and the `illumination_scale` setting, plus a `SpriteComponent` with `fog_of_war_hole` and reduced `special_scale`. Without a verlet chain, these can be kept on the same entity as the sprite. Our `post_final.frag` patch passes `tex_lights` sources through fog, so belt light functions properly even in limited visibility mode.
- **Modifiers.** Flickering should flicker on the belt as well, and Short-lived must consume burn time while on the belt since it is actively burning. Modifier logic must be applicable to the belt's `LightComponent`.
- **Polymorph.** After transformation, the player is a different entity, while the original is hidden. Safeguard: if the belt entity does not belong to the current player or references a different lantern, it is killed and recreated. Verified in-game.

## Implementation

The attachment mechanism is borrowed from the reference, while swinging is powered by our in-hand pendulum. We moved away from the verlet chain: it requires a sprite rotated by 90°, and animated flames on verlet segments are untested. Our pendulum already works reliably with animated `lantern_in_hand.xml` and responds to player movement.

```text
player
└── pul_belt_lantern  (tag pul_belt)
    ├── InheritTransformComponent  belt_root, only_position="1"
    ├── LuaComponent               lantern_in_hand.lua (pendulum)
    ├── SpriteComponent            copy of in-hand lantern sprite, scale 0.6
    ├── LightComponent             only for lit lantern
    └── SpriteComponent            fog_of_war_hole, if present on lantern
```

- `files/entities/lantern_belt.xml` — entity with attachment and pendulum; sprite, light, and fog hole are injected dynamically by Lua based on the specific lantern's data.
- `files/scripts/lantern_belt.lua` — `UpdateLanternBelt()` is called from `OnWorldPostUpdate` so that mirroring is applied in the same frame right before rendering.
  - If any lantern is held in hands, all `pul_belt` entities are killed.
  - Otherwise, the lantern with the lowest `inventory_slot` in `inventory_quick` is selected.
  - The belt entity stores the lantern ID and lit/unlit state. If they do not match current values (different lantern, lantern extinguished, player reloaded or reverted from polymorph), the entity is recreated.
  - `only_position="1"` leaves rotation and scale unconstrained: rotation is driven by the pendulum, and `scale_x = ±1` is written every frame from player's `scale_x`.
  - Light radius: `GetLanternLightRadius(lantern_id, illumination_scale * tier * belt_light_scale) * GetLanternModifierFactor()`. Fog hole: `GetLanternFogHoleScale(lantern_id, illumination_scale * tier * belt_light_scale)`. Both values use the base values of the lantern type carried by the player, and light color is copied from its `LightComponent`. `belt_light_scale` is the `Belt lantern light` setting in Mod Settings (0–100%, default 50%), applied immediately.
- Modifiers: flickering calculations and fuel consumption were extracted from `lantern_modifier.lua` into `lantern_traits.lua` (`ConsumeLanternFuel`, `GetLanternModifierFactor`). A lantern on the belt consumes Short-lived fuel. When fuel is exhausted, the belt displays the extinguished sprite, and the item itself is extinguished (`ExtinguishLantern`) the next time it is picked into hands or thrown — avoiding modifying disabled components of an item inside the inventory.
- Configurable constants in `lantern_belt.lua`: `SPRITE_SCALE`, `SPRITE_Z_INDEX`.

## Open Questions

- **[Verified]** Lantern position and size relative to `belt_root`, `z_index` relative to player and hands.
- **[Verified]** That `InheritTransformComponent` with `only_position="1"` does not overwrite rotation from the pendulum.
- **[Verified]** Player child behavior during polymorph and after reverting.
- **[Verified]** Whether the belt lantern visually conflicts with the cape (`cape`) and rat tail (also `belt_root`, position `x=1.5`).
