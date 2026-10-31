# Extended Light Fixtures

[← Back to R&D Index](../rnd.md)

Results of the version 0.3 item "Extended Light Fixture Support" ([version-0.3.md](../versions/version-0.3.md#extended-light-fixture-support)): making the mining lamp, the tube lamp, the temple lantern and the chain torches pickable like lanterns. All of them are pickable and checked in game. How they are built now is described in [Lantern Entities](../dev/lantern-entities.md); this page keeps what was learned on the way and why the final design was chosen.

## Contents

- [Results](#results)
- [Entities and Physics](#entities-and-physics)
- [Chains and Cables](#chains-and-cables)
- [Fire and Light of Chain Torches](#fire-and-light-of-chain-torches)
- [Saving and Streaming](#saving-and-streaming)
- [Conclusions](#conclusions)
- [Open Issues](#open-issues)
- [Later Ideas](#later-ideas)

## Results

| Fixture | Files | Result |
| --- | --- | --- |
| Mining lamp | `physics_mining_lamp.xml` | Hangs on its joint like a lantern. |
| Tube lamp | `physics_tubelamp.xml` | Shines only while powered by a cable that follows the lamp, snaps and keeps sparking. The only lamp of the Hiisi Base, so it also closes the "Hiisi Base fixtures" part of the item. See [Tube Lamp and Electricity](tube-lamp-electricity.md). |
| Temple lantern | `physics/temple_lantern.xml` | Hangs on a Lua chain up to the ceiling, up to 200 px above, swings on it; projectiles break the chain. |
| Chain torches | `physics/chain_torch*.xml`, `physics_chain_torch*.xml` | Hang on a short Lua chain of 4 links, burn with an open fire in hand and on the belt, go out in liquids and light again from fire. |

All fixtures share the lantern features: quality tiers and modifiers, the belt, throwing, hanging with the left mouse button (except the tube lamp, which needs its cable) and kicking down.

## Entities and Physics

- **[Confirmed]** The item system works only with `PhysicsBodyComponent`, not with `PhysicsBody2Component`. Fixtures built on `PhysicsBody2Component` in vanilla (temple lantern, tube lamp, chain torches) are full overrides with one `PhysicsBodyComponent` body. See [Physics System](../dev/lantern-entities.md#physics-system).
- **[Confirmed]** A body material with `platform_type="1"` makes the player bump into the fixture and stand on it. The vanilla mining lamp is made of `wood_prop`, so its override uses `wood_prop_noplayerhit`. Check `data/materials.xml` before choosing a body material.
- **[Confirmed]** The mining lamp keeps its vanilla origin in the centre, 6 px below its joint, so it declares its own ceiling check distance (`lantern_ceiling_check_distance`) for `lantern_anchor.lua`.
- **[Confirmed]** The light of the chain torches, their `TorchComponent` and particles sit in a nested `Entity` in vanilla. The illumination, belt and modifier code reads the components of the lantern entity itself, so they had to move to the root.
- **[Confirmed]** Each chain torch exists in two files that different biomes spawn: `physics/chain_torch*.xml` and the older duplicates `physics_chain_torch*.xml`. Both paths are overridden; a duplicate only includes the `physics/` variant of its colour with `<Base>`. See [Duplicate Torch Entities](../dev/lantern-entities.md#duplicate-torch-entities).
- **[Confirmed]** Chain torches are unbreakable in vanilla (no `DamageModelComponent`). With the durability of a glass lantern (`hp="0.5"`, `speed_threshold="85"`) they broke from a fall. With `hp="1.0"`, `speed_threshold="120"` and `damage_multiplier="0.002"` they survive falls and throws and still break from projectiles and explosions.

## Chains and Cables

- **[Confirmed]** A `PhysicsBody2Component` chain built at runtime by the mod gets no physics bodies, whether `PhysicsBody2InitFromComponents` is called right after `EntityLoad` or from the entity's own script. This held for the first tube lamp cable and for the vanilla temple lantern spawned by the mod, which fell right away. All chains and cables are verlet ropes simulated in Lua instead (`hanging_rope.lua`), one sprite entity per segment.
- **[Confirmed]** A native Box2D chain built with `PhysicsAddBodyImage` and `PhysicsAddJoint`, as the vanilla duplicate torches do, holds a torch, but its links cannot be shot through. Rejected, see [Native Physics Chain for Chain Torches](native-chain-torch.md).
- **[Confirmed]** Pinning a torch with a joint in the air at the end of its chain, or spawning it again to get a joint, was hard to tune. One model for all chained fixtures works better: the Lua chain holds the lantern by its top from Lua (`HoldBodyOnHangingRope()`), and a biome-spawned torch has no joint at all.
- **[Confirmed]** The hold needs the centre of mass of the Box2D body itself; with a centre guessed from the sprite a torch turned upside down.
- **[Confirmed]** A rigid chain keeps its links at their length only if it alternates the direction of its constraint passes. With both ends held, the simulation gathers its remaining error in the last link, which stands at an angle, so a taut chain is laid straight from the anchor to the lantern instead of being simulated.
- **[Confirmed]** A projectile is checked against the links along its path in the last frame, so fast projectiles do not pass through. Killed at the hit link, it dies with its usual effect, as on a physics body.
- Many torches on chains cost time every frame. Chains without a lantern that stand still skip simulation and rendering until something moves them, link sprites of no known chain are swept only right after chains load and once a second, and chain states of lanterns are cached.

## Fire and Light of Chain Torches

- **[Confirmed]** The vanilla `TorchComponent` also goes out in solid materials, and the item system lights it again when the torch is picked up. It is replaced by `chain_torch_fire.lua`: a torch goes out only when its coals are in a liquid, and lights again from fire.
- **[Confirmed]** In hand the engine turns and mirrors particle emitters with the aim of the player, so the fire in hand and on the belt is made from Lua at the coals of the swinging sprite (`EmitOpenFire()`).
- **[Confirmed]** `GameCreateParticle` with `just_visual` makes particles that fall and still set the player alight. Visual fire is made of cosmetic particles that rise on a negative gravity; only a share of the fire in hand (10%) is real fire cells, and none on the belt.
- The light of the blue and ghostly torches is tinted to the colour of their sparks instead of the warm vanilla colour.

## Saving and Streaming

- **[Confirmed]** `CameraBoundComponent`, kept from the vanilla files, froze a lantern once the camera was farther than its `distance` (1000 px): the engine killed it and kept only its file and position, then spawned it again from the file. The save showed it: the frozen lanterns were in `world/area_*.bin` as a file path and a position, while the chain anchors were saved with their storages in `world/entities_*.bin`. The respawned lantern lost all storages (quality tier, modifiers, `lantern_chain_checked`), so a torch built a second chain next to its old one. The component is removed from all lanterns; they are now saved with their chunk, as potions and wands are.
- **[Confirmed]** `EntityGetFilename()` of a lantern depends on how it got into the world: a frozen and respawned lantern lost its filename, and `GetLanternType()` fell back to the inventory icon. Code that needs a specific file of a type must not reuse the filename of the entity: hanging with the left mouse button always loads the first file of the type (`chain_torch*_hung.xml` for torches, with the ceiling joint).
- **[Confirmed]** An anchor entity at the ceiling that keeps the segment count rebuilds a rope after a reload or when a chunk streams in; the lantern keeps the anchor position and is put back on its chain. Loose pieces of broken chains are not saved.

## Conclusions

- Rebuild a vanilla fixture as a full override on `PhysicsBodyComponent`; anything built from `PhysicsBody2Component` at runtime by the mod is not reliable.
- Keep everything a lantern needs on its root entity, and keep its state in storages that are saved with the entity. Do not let the engine respawn a lantern from its file: no `CameraBoundComponent`.
- Simulate chains and cables in Lua and hold the lantern on them from Lua: one model for all chained fixtures, with saving through anchor entities.
- Replace vanilla behaviour that does not fit an item (`TorchComponent`, emitters in hand) with Lua rather than tune around it.
- Test rare fixtures with a temporary debug spawner in the mountain hall, see [Spawning Fixtures for In-Game Tests](test-spawning.md), and check both a save and reload and walking far away and back.

## Open Issues

- Quality tier and modifier descriptions are written for oil lanterns (flame, wick, oil) and read oddly on a tube lamp and on chain torches; per-type descriptions are an idea for later.
- A tube lamp knocked off keeps its lit-looking physics image after it loses power, until it is picked up and thrown again.
- Which lamp a cable holds is not saved: after a reload the lamp falls off and goes dark, the cable stays.
- Not checked one by one: that the tube lamp cable works as before after its rope moved to `hanging_rope.lua` (it passed a run against a stubbed API).
- Explosions do not break lantern chains, as the Lua chain has no bodies; the lantern itself usually breaks or is flung off.
- Lighting up a dark tube lamp from electricity, with a small capacity between hits (stage 3 in [Tube Lamp and Electricity](tube-lamp-electricity.md#implementation-stages)), is not done.

## Later Ideas

- Version 0.4 plans a magic liquid modifier for the temple lantern: a rare dark lantern that spills Concentrated Mana, Flummoxium or Unstable Teleportatium when it breaks. See [version-0.4.md](../versions/version-0.4.md#temple-lantern-modifiers).
