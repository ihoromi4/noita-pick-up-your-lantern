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

The mod overrides three vanilla hanging oil lanterns with full copies in `pick_up_your_lantern/data/entities/props/`:

| File | Lantern | Where it spawns |
| --- | --- | --- |
| `physics/lantern_small.xml` | Small Lantern, the most common one | Most biomes, e.g. `coalmine`, `excavationsite`, `snowcastle`, `vault` |
| `physics_lantern_small.xml` | Small Lantern, older variant | `snowcave`, `sandcave`, `meat`, `tower`, `lake_statue`, `temple_altar_secret` |
| `physics_lantern.xml` | Lantern (large) | `liquidcave`, `town` |

Each entity carries the `lantern` tag, an `ItemComponent` that puts it into the Quick Inventory, and an `AbilityComponent` for throwing. Their light and durability are described in [Lantern Properties and Progression](lantern-properties-and-progression.md).

## Physics System

Noita has two physics component families, and the item system works only with the older one:

- `ItemComponent`, `AbilityComponent` with `throw_as_item="1"`, `PhysicsThrowableComponent`, `ProjectileComponent` and `VelocityComponent` work with `PhysicsBodyComponent` only, not with `PhysicsBody2Component`.
- With `PhysicsBody2Component` left on the entity, picking the lantern up takes only the flame sprite; the glass body stays on the ceiling.
- Adding `base_item_physics.xml` to an entity that has `PhysicsBody2Component` creates two physics bodies for one lantern: one falls, the other keeps hanging.

So `physics/lantern_small.xml`, which uses `PhysicsBody2Component` in vanilla, is rewritten to use `PhysicsBodyComponent` and `PhysicsJointComponent`. All three files are full overrides with the `base_item_physics.xml` components expanded inline, not runtime XML edits.

## Ceiling Anchors

A lantern hangs on a `PhysicsJointComponent` with `nail_to_wall="1"`.

- **Pickup needs no extra script.** `PhysicsBodyComponent` has the `enabled_in_world` tag. Disabling it on pickup destroys the Box2D body together with its joint. When the lantern is thrown, a new body is created without a joint, because the joint is created only once on first spawn.
- **Engine joints cannot detach the lantern on their own.** `breakable="1"` does not let a kick tear the lantern off: the lantern is too light for the kick to exceed the engine's break threshold. `grid_joint="1"` does not help either: the joint still binds to the static world body, and the lantern keeps hanging in the air after the ceiling is gone.

`files/scripts/lantern_anchor.lua` handles both cases:

- **Kick** (`script_kick`, driven by the vanilla kick message): removes the joint, cleans up with `PhysicsRemoveJoints`, pushes the lantern with `PhysicsApplyForce` and removes its own `LuaComponent`.
- **Ceiling destroyed** (every 20 frames): `RaytraceSurfaces` checks 6 pixels above the lantern. If the ceiling is gone, the lantern detaches and falls.
- **Self-removal**: once the lantern is detached, or has no joint, the script removes its `LuaComponent`. A lantern on the floor, in hand or in the inventory runs no anchor code.

## Sprite Geometry

- The biome spawn marker for lamps (`spawn_lamp`, color `0xffffff00`) is the first air pixel right under the solid ceiling pixels.
- `lantern_small.png` is 9×13 pixels. Rows `y = 0..2` are transparent, the loop is at `y = 3`, the lid at `y = 4` and the glass at `y = 5..10`.
- With `centered="1"` on `PhysicsImageShapeComponent`, the engine forces `offset_x = 4.5` and `offset_y = 6.5` and ignores manual offsets. This pushes the top of a small lantern into the ceiling, which:
  - lifts the lantern 2–3 pixels too high;
  - makes it fall right after spawning under wooden beams, because the ceiling pixels modify its embedded body;
  - prevents kicking it loose, because its top is stuck in solid pixels.
- `centered="0"`, `offset_x="4.5"`, `offset_y="3.5"` on `PhysicsImageShapeComponent`, and `offset_y="3.5"` on the world flame `SpriteComponent`, place a small lantern right under the ceiling without overlap.

## Other Light Sources

Besides the lanterns, `patch_lighting.lua` adds a fog of war hole to light sources that are not pickable, so they also dispel fog of war under limited vision:

- chain torches: `chain_torch`, `chain_torch_blue`, `chain_torch_ghostly` and their duplicates;
- torch stands: `physics_torch_stand.xml`, `physics_torch_stand_blue.xml`;
- `physics_mining_lamp.xml`, `physics/temple_lantern.xml`, `physics_barrel_burning.xml`, `physics_tubelamp.xml`.

The hole is scaled by `Illuminated area size` when the game starts. It is added only when `Illuminate the darkness` is on.

## Duplicate Torch Entities

Each chain torch exists in two files with different paths, and different biomes spawn different files:

| `physics/` variant | Duplicate in `props/` | Where the duplicate spawns |
| --- | --- | --- |
| `physics/chain_torch.xml` | `physics_chain_torch.xml` | `mountain_center`, `endgame_end` |
| `physics/chain_torch_blue.xml` | `physics_chain_torch_blue.xml` | No vanilla biome |
| `physics/chain_torch_ghostly.xml` | `physics_chain_torch_ghostly.xml` | 24 biomes, including `excavationsite` (Coal Pits), `desert`, `rainforest`, `vault`, `snowcastle`, `tower`, `the_end` |

The duplicates are an older version without `<Base file="data/entities/base_chain_torch.xml">`: the physics body and scripts are declared inline, and `LightComponent` and `TorchComponent` are tagged `enabled_in_world,enabled_in_hand`. The light still sits in a nested `Entity`, as in the `physics/` variants, so the same patch applies to both. Patch both paths whenever you patch a chain torch.
