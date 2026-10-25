# Vanilla Light Fixture Types

[← Back to R&D Index](../rnd.md)

The game files (`data/entities/props/`) contain three main entities for hanging oil lanterns:

- `data/entities/props/physics/lantern_small.xml` - the primary small lantern, spawning in most biomes (`coalmine`, `excavationsite`, `snowcastle`, `vault`, etc.). Uses the newer physics system (`PhysicsBody2Component` + `PhysicsJoint2Component`).
- `data/entities/props/physics_lantern_small.xml` - an alternative small lantern (spawning in `snowcave`, `sandcave`, `meat`, `tower`, `lake_statue`, `temple_altar_secret`). Uses the older physics system (`PhysicsBodyComponent` + `PhysicsJointComponent`) via `<Base file="data/entities/base_item_physics.xml">`.
- `data/entities/props/physics_lantern.xml` - the large lantern (spawning in `liquidcave`, `town`). Also based on `base_item_physics.xml` (`PhysicsBodyComponent` + `PhysicsJointComponent`).

## Duplicate Torch Entities

In vanilla Noita, chain torches have two separate files with different paths, and different biomes spawn different variants. Previously, the lighting patch ([patch_lighting.lua](../../pick_up_your_lantern/files/scripts/patch_lighting.lua)) only added a fog of war hole to the variants under `physics/`, so, for instance, ghostly torches in the Coal Pits did not pierce the fog of war. Now both variants are patched.

| Variant under `physics/` | Duplicate in `props/` | Where duplicate spawns |
| --- | --- | --- |
| `physics/chain_torch.xml` | `physics_chain_torch.xml` | `mountain_center`, `endgame_end` |
| `physics/chain_torch_blue.xml` | `physics_chain_torch_blue.xml` | Not spawned by vanilla biomes |
| `physics/chain_torch_ghostly.xml` | `physics_chain_torch_ghostly.xml` | 24 biomes, including `excavationsite` (Coal Pits), `desert`, `rainforest`, `vault`, `snowcastle`, `tower`, `the_end` |

The duplicates are an older version without `<Base file="data/entities/base_chain_torch.xml">`: the physics body and scripts are defined directly within the file, while `LightComponent` and `TorchComponent` have `enabled_in_world,enabled_in_hand` tags. The light, just as in the `physics/` variants, resides in a nested `Entity`, so the patch applies identically to both.
