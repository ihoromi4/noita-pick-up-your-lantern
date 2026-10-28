# Lantern Entities

Which vanilla entities the mod turns into pickable items, how they are rebuilt for the item system, and how they hang from the ceiling.

## Contents

- [Pickable Lanterns](#pickable-lanterns)
- [Physics System](#physics-system)
- [Ceiling Anchors](#ceiling-anchors)
- [Sprite Geometry](#sprite-geometry)
- [Other Light Sources](#other-light-sources)
- [Duplicate Torch Entities](#duplicate-torch-entities)

## Pickable Lanterns

The mod overrides the vanilla light fixtures below with full copies in `pick_up_your_lantern/data/entities/props/`. They are registered in `LANTERN_TYPES` of `files/scripts/lantern_properties_config.lua`, which gives each type its files, inventory icon and hang offset:

| File | Lantern | Where it spawns |
| --- | --- | --- |
| `physics/lantern_small.xml` | Small Lantern, the most common one | Most biomes, e.g. `coalmine`, `excavationsite`, `snowcastle`, `vault` |
| `physics_lantern_small.xml` | Small Lantern, older variant | `snowcave`, `sandcave`, `meat`, `tower`, `lake_statue`, `temple_altar_secret` |
| `physics_lantern.xml` | Lantern (large) | `liquidcave`, `town` |
| `physics_mining_lamp.xml` | Mining Lamp | `hills`, `winter`, `mountain_tree`, `lake` |
| `physics_tubelamp.xml` | Tube Lamp | `snowcastle` (Hiisi Base), `vault`, `vault_frozen`, `robobase`, `rainforest`, `dragoncave`, `sandcave` |

Each entity carries the `lantern` tag, an `ItemComponent` that puts it into the Quick Inventory, and an `AbilityComponent` for throwing. Their light and durability are described in [Lantern Properties and Progression](lantern-properties-and-progression.md).

## Physics System

Noita has two physics component families, and the item system works only with the older one:

- `ItemComponent`, `AbilityComponent` with `throw_as_item="1"`, `PhysicsThrowableComponent`, `ProjectileComponent` and `VelocityComponent` work with `PhysicsBodyComponent` only, not with `PhysicsBody2Component`.
- With `PhysicsBody2Component` left on the entity, picking the lantern up takes only the flame sprite; the glass body stays on the ceiling.
- Adding `base_item_physics.xml` to an entity that has `PhysicsBody2Component` creates two physics bodies for one lantern: one falls, the other keeps hanging.

So `physics/lantern_small.xml`, which uses `PhysicsBody2Component` in vanilla, is rewritten to use `PhysicsBodyComponent` and `PhysicsJointComponent`. The tube lamp, a tube and two wires on `PhysicsBody2Component` in vanilla, becomes one `PhysicsBodyComponent` body. The mining lamp already uses the older family in vanilla. All files are full overrides with the `base_item_physics.xml` components expanded inline, not runtime XML edits.

The body material must not have `platform_type="1"` in `data/materials.xml`, otherwise the player bumps into the lantern and stands on it. `glass_box2d` has `platform_type="0"`, and the `*_nohit` materials inherit none from `aluminium`. The vanilla mining lamp is made of `wood_prop` (`platform_type="1"`), so its override uses the twin `wood_prop_noplayerhit`.

## Ceiling Anchors

A lantern hangs on a `PhysicsJointComponent` with `nail_to_wall="1"`.

- **Pickup needs no extra script.** `PhysicsBodyComponent` has the `enabled_in_world` tag. Disabling it on pickup destroys the Box2D body together with its joint. When the lantern is thrown, a new body is created without a joint, because the joint is created only once on first spawn.
- **Engine joints cannot detach the lantern on their own.** `breakable="1"` does not let a kick tear the lantern off: the lantern is too light for the kick to exceed the engine's break threshold. `grid_joint="1"` does not help either: the joint still binds to the static world body, and the lantern keeps hanging in the air after the ceiling is gone.

`files/scripts/lantern_anchor.lua` handles both cases:

- **Kick** (`script_kick`, driven by the vanilla kick message): removes the joint, cleans up with `PhysicsRemoveJoints`, pushes the lantern with `PhysicsApplyForce` and removes its own `LuaComponent`.
- **Ceiling destroyed** (every 20 frames): `RaytraceSurfaces` checks 6 pixels above the lantern. If the ceiling is gone, the lantern detaches and falls.
- **Ceiling check distance**: 6 pixels by default. A type whose joint sits higher above its origin declares its own distance in the `lantern_ceiling_check_distance` storage of its XML file. The mining lamp keeps its vanilla origin in the centre, 6 pixels below the joint, and biomes spawn it 6 pixels below the spawn marker, so it checks 10 pixels.
- **Self-removal**: once the lantern is detached, or has no joint, the script removes its `LuaComponent`. A lantern on the floor, in hand or in the inventory runs no anchor code.

## Sprite Geometry

- The biome spawn marker for lamps (`spawn_lamp`, color `0xffffff00`) is the first air pixel right under the solid ceiling pixels.
- `lantern_small.png` is 9×13 pixels. Rows `y = 0..2` are transparent, the loop is at `y = 3`, the lid at `y = 4` and the glass at `y = 5..10`.
- With `centered="1"` on `PhysicsImageShapeComponent`, the engine forces `offset_x = 4.5` and `offset_y = 6.5` and ignores manual offsets. This pushes the top of a small lantern into the ceiling, which:
  - lifts the lantern 2–3 pixels too high;
  - makes it fall right after spawning under wooden beams, because the ceiling pixels modify its embedded body;
  - prevents kicking it loose, because its top is stuck in solid pixels.
- `centered="0"`, `offset_x="4.5"`, `offset_y="3.5"` on `PhysicsImageShapeComponent`, and `offset_y="3.5"` on the world flame `SpriteComponent`, place a small lantern right under the ceiling without overlap.
- `minelamp.png` (mining lamp) is 5×8 pixels: the wooden cap at `y = 0..1`, the glass with a bright wick at `y = 2..7`. `centered="0"`, `offset_x="2.5"`, `offset_y="4"` keep the vanilla origin in the centre, so the lamp hangs as in vanilla: `hills`, `winter` and `mountain_tree` spawn it 6 pixels below the marker, `lake` right at the marker.
- `tube_lamp.png` (tube lamp, in `files/props_gfx/`) is 19×5 pixels: 2-pixel wire stubs at `x = 4` and `x = 14` (`y = 0..1`) drawn on top of the vanilla `tubelamp.png` tube (`y = 2..4`). The stubs replace the two vanilla wire bodies: the lamp hangs 2 pixels below the ceiling and keeps the stubs when it falls. `centered="0"`, `offset_x="9.5"`, `offset_y="0.5"` put the origin at the top of the wires; `snowcastle` spawns it right at the marker (`x + 5` or `x`).
- The tube lamp has one `LightComponent` (radius 200) instead of the two vanilla ones (radius 150, 6 pixels left and right of the centre), as the illumination, modifier and belt code scales the first light only. The vanilla damage effects (blinking, electric sparks, a breaking wire) are left out: the electric pulses would shock the player holding it.
- In hand, the tube lamp hangs down from the hand by its end, like a sword held point down: `tube_lamp_in_hand.png` is the unlit tube without wire stubs turned by 90° (3×19 pixels), with the origin at its upper end (`offset_x="1.5"`, `offset_y="1.5"`), drawn at 70% (`special_scale_x/y="0.7"`). The belt uses the same sprite. Without the `lantern_in_hand.lua` pendulum, which sets the rotation every frame, the engine turns the held tube by 180° when the player faces left.
- The tube lamp breaks with a burst like the vanilla propane tank, scaled down to radius 24 and damage 3, and has no death script.
- `LANTERN_TYPES` gives the tube lamp no `hang_offset_y`, so the left mouse button throws it as usual instead of hanging it: it needs a power cable. See [Tube Lamp and Electricity](../rnd/tube-lamp-electricity.md).
- The mining lamp and the tube lamp have no flame sprite: the lit wick is part of its physics image, so a burnt-out mining lamp changes only its in-hand sprite (`mining_lamp_out.png`).
- **Power.** The tube lamp has `needs_power` in `LANTERN_TYPES`: it shines only while it hangs. `UpdateLanternPower()` (`lantern_traits.lua`, called by the illumination scan every 30 frames) cuts the power for good once the lamp is no longer a root entity (picked up) or has no `PhysicsJointComponent` (detached by `lantern_anchor.lua`), and the `lantern_power_lost` storage is set. `GetLanternPowerFactor()` then turns the light radius and the fog of war hole to 0 in hand, in the world, on the belt and in the modifier script, so attraction, fear and enemy study ignore the lamp as well.
- The physics image cannot change on an existing body, so `UpdateLanternPower()` switches `PhysicsImageShapeComponent.image_file` to `unpowered_image_file` (`tube_lamp_unlit.png`), and the engine uses it for the next body, created when the lamp is thrown or dropped. A lamp kicked down keeps the lit-looking image until it is picked up and thrown again. The in-hand sprite, belt sprite and inventory icon show the unlit tube.
- The tube lamp spins in flight: `min_torque="4"`, `max_torque="10"` on `PhysicsThrowableComponent`, as on the vanilla broken wand.

## Other Light Sources

Besides the lanterns, `patch_lighting.lua` adds a fog of war hole to light sources that are not pickable, so they also dispel fog of war under limited vision:

- chain torches: `chain_torch`, `chain_torch_blue`, `chain_torch_ghostly` and their duplicates;
- torch stands: `physics_torch_stand.xml`, `physics_torch_stand_blue.xml`;
- `physics/temple_lantern.xml`, `physics_barrel_burning.xml`.

The hole is scaled by `Illuminated area size` when the game starts. It is added only when `Illuminate the darkness` is on.

## Duplicate Torch Entities

Each chain torch exists in two files with different paths, and different biomes spawn different files:

| `physics/` variant | Duplicate in `props/` | Where the duplicate spawns |
| --- | --- | --- |
| `physics/chain_torch.xml` | `physics_chain_torch.xml` | `mountain_center`, `endgame_end` |
| `physics/chain_torch_blue.xml` | `physics_chain_torch_blue.xml` | No vanilla biome |
| `physics/chain_torch_ghostly.xml` | `physics_chain_torch_ghostly.xml` | 24 biomes, including `excavationsite` (Coal Pits), `desert`, `rainforest`, `vault`, `snowcastle`, `tower`, `the_end` |

The duplicates are an older version without `<Base file="data/entities/base_chain_torch.xml">`: the physics body and scripts are declared inline, and `LightComponent` and `TorchComponent` are tagged `enabled_in_world,enabled_in_hand`. The light still sits in a nested `Entity`, as in the `physics/` variants, so the same patch applies to both. Patch both paths whenever you patch a chain torch.
