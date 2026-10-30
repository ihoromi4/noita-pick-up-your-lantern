# Native Physics Chain for Chain Torches

[← Back to R&D Index](../rnd.md)

Whether a pickable chain torch can hang on a real Box2D chain built the way the vanilla duplicates build theirs, instead of the Lua chain of `lantern_chain.lua`.

## Contents

- [Why](#why)
- [Vanilla Precedent](#vanilla-precedent)
- [Experiment](#experiment)
- [Results](#results)
- [Decision](#decision)

## Why

The chain torches hang on a Lua rope ([Hanging Ropes](../dev/lantern-entities.md#hanging-ropes)), and every step of fitting the torch body to it needed a workaround:

- Holding the torch body from Lua (`HoldBodyOnHangingRope()`) turned its heavy bowl upside down; the cause was not found.
- So the torch is pinned by its own `nail_to_wall` joint in the air at the end of the chain, which needs the torch to be spawned again at that point.
- Taking the torch off the chain then relies on `PhysicsRemoveJoints()`, which sometimes misses the joint, so the torch keeps hanging after the chain is shot through.

The chain and the torch live in two physics systems, and Lua stitches them together. A chain made of Box2D bodies would swing, break and drop the torch by itself.

## Vanilla Precedent

The vanilla duplicates `data/entities/props/physics_chain_torch*.xml` already hang on such a chain, and they use the physics family the item system works with:

- The head is a `PhysicsBodyComponent` with `uid="1"`, its shape a `PhysicsImageShapeComponent` with `body_id="1"`.
- `data/scripts/props/physics_chain_torch.lua` runs once and adds 3 links as bodies of the same entity with `PhysicsAddBodyImage()`, joins them to each other and to the head with `PhysicsAddJoint()`, and joins the top link to the world (body `-1`).
- `data/scripts/props/physics_chain_torch_damaged.lua` (`script_physics_body_modified`) kills the whole torch when any of its bodies is damaged.

The chains that failed before were `PhysicsBody2Component` chains built at runtime (see [Tube Lamp Cable](../dev/lantern-entities.md#tube-lamp-cable)). `PhysicsAddBodyImage()` and `PhysicsAddJoint()` belong to the other family and were not tried.

## Experiment

A pickable chain torch without its `nail_to_wall` joint, with `uid="1"` on its body, built 4 links of 6 px above the top of its bail with `PhysicsAddBodyImage()` and joined them to each other, to the head and to the world with `PhysicsAddJoint()`. It was spawned by the debug spawner at `623, -167`, 24 px under the free ceiling point `623, -191` of `hall.png`. The experiment files were removed afterwards.

## Results

- **[Confirmed]** The links are created on the pickable torch, and it hangs on them.
- **[Confirmed]** Shooting a link does not break the chain. The torch falls only when the shot hits the top of its bail.
- **[Needs verification]** The likely cause: the links are made of `metal_chain_nohit`, as in vanilla, and projectiles pass through `*_nohit` materials.
- Not checked, as the experiment stopped here: what happens to the links on pickup, after saving and loading, and when the torch is thrown.

## Decision

Chain torches stay on the Lua chain of `lantern_chain.lua`, the same one the temple lantern hangs on, which the player can shoot through and which the user found to work well. A native chain would need its own way to break links (a material that projectiles hit, which the player would also bump into, or the Lua hit test of `lantern_chain.lua` on top of it), and its link bodies would outlive the torch in ways not yet known.

What made the Lua chain hard to tune for the torches was not the chain but the workarounds around the torch body, which are dropped:

- The torch is held from Lua like the temple lantern. `HoldBodyOnHangingRope()` now takes the centre of mass from the Box2D body (`PhysicsBodyIDGetWorldCenter()`), not from a configured offset, which is the suspected cause of the torch turning upside down.
- A torch spawned by a biome has no `nail_to_wall` joint, so nothing has to be removed or spawned again: it drops to the end of its chain. Only a torch hung with the left mouse button gets the joint, from its own file `files/entities/chain_torch*_hung.xml`.
