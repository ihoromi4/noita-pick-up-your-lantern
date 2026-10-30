# Extended Light Fixture Support: Progress

[← Back to R&D Index](../rnd.md)

Where the work on the version 0.3 item "Extended Light Fixture Support" ([version-0.3.md](../versions/version-0.3.md#extended-light-fixture-support)) stopped, and what is left. The work happens on the `feat/extended-light-fixtures` branch.

## Contents

- [Done](#done)
- [Remaining Fixtures](#remaining-fixtures)
- [Open Issues](#open-issues)
- [Before Merging](#before-merging)

## Done

Each pickable fixture is a full override in `pick_up_your_lantern/data/entities/props/`, registered in `LANTERN_TYPES` of `files/scripts/lantern_properties_config.lua`. See [Lantern Entities](../dev/lantern-entities.md).

- **Mining lamp** (`physics_mining_lamp.xml`): pickable, checked in game. Keeps the vanilla origin in the centre, so it declares its own ceiling check distance (`lantern_ceiling_check_distance`). Made of `wood_prop_noplayerhit`, as the vanilla `wood_prop` blocks the player.
- **Tube lamp** (`physics_tubelamp.xml`): pickable, checked in game. It is the only lamp of the Hiisi Base, which closes the "Hiisi Base fixtures" part of the item. Design and engine findings: [Tube Lamp and Electricity](tube-lamp-electricity.md).
  - Shines only while powered by its cable; in hand, on the belt and in the inventory it shows a lit or dark sprite and icon.
  - Held like a sword point down; thrown with both mouse buttons; bursts like a small propane tank.
  - A cable of 5 px segments, simulated in Lua as a verlet rope, follows a lamp taken down and snaps past a random length; a lamp knocked off dangles by one end of the tube on a short cable, swings and blinks.
  - A torn cable keeps hanging and, from 2 s after the break for 3 min, sparks from its end and shocks creatures within 20 px.
- **Temple lantern** (`physics/temple_lantern.xml`): pickable, checked in game. Hangs on a Lua chain of vanilla link sprites from the ceiling, swings on it, comes off when picked up, kicked or flung; a projectile breaks the chain at the link it hits. Its light is 50% wider and brighter than vanilla. See [Temple Lantern Chain](../dev/lantern-entities.md#temple-lantern-chain). The rope of the tube lamp cable is shared with the chain in `hanging_rope.lua`.
- **Test spawning**: [Spawning Fixtures for In-Game Tests](test-spawning.md), with points in the mountain hall at the entrance to the Mines.

## Remaining Fixtures

| Fixture | Files | Vanilla specifics |
| --- | --- | --- |
| Chain torches | `physics/chain_torch.xml`, `chain_torch_blue.xml`, `chain_torch_ghostly.xml` and their duplicates `physics_chain_torch.xml`, `physics_chain_torch_blue.xml`, `physics_chain_torch_ghostly.xml` | The `physics/` variants use `base_chain_torch.xml` (`PhysicsBody2Component`, 4 chain links and an 11×13 `torch_hang_unlit.png` head); the duplicates use the older `PhysicsBodyComponent` with a chain from `physics_chain_torch.lua`. The light (radius 96), `TorchComponent` and torch particles are in a nested child `Entity`. The ghostly torch spawns in 37 biomes. |

Decisions already made for them:

- Full parity with lanterns: pick up, hold, belt, throw, hang with the left mouse button, kick down, break.
- All quality tiers and modifiers apply.
- Chain torches keep `TorchComponent` and ignite things in the world and in hand, as in vanilla.

Notes for the next steps:

- A runtime `PhysicsBody2Component` chain spawned by the mod got no bodies (see [Lantern Entities](../dev/lantern-entities.md#tube-lamp-cable)). A visible chain for the temple lantern or the torches is better drawn as a Lua rope, like the tube lamp cable.
- The light, `TorchComponent` and particles of the chain torches have to move from the nested `Entity` to the root: the illumination, belt and modifier code read the components of the lantern entity itself.
- Before writing a body material, check its `platform_type` in `data/materials.xml`: `1` makes the player bump into the fixture.

## Open Issues

- Quality tier and modifier descriptions are written for oil lanterns (flame, wick, oil) and read oddly on a tube lamp; per-type descriptions are an idea for later.
- A tube lamp knocked off keeps its lit-looking physics image after it loses power, until it is picked up and thrown again.
- Which lamp a cable holds is not saved: after a reload the lamp falls off and goes dark, the cable stays.
- Not checked one by one after the temple lantern: whether a projectile killed on a chain link dies with its usual effect (`EntityKill` after moving it there), and that the tube lamp cable works as before after moving its rope to `hanging_rope.lua`.
- The vanilla temple lantern spawned by the debug spawner fell right away, most likely because its runtime physics chain gets no bodies when the mod spawns it (as with the first cable). Not checked further: the override replaces the vanilla chain.
- Explosions do not break a temple lantern chain, as the Lua chain has no bodies; the lantern itself usually breaks or is flung off.
- Lighting up a dark tube lamp from electricity, with a small capacity between hits (stage 3 in [Tube Lamp and Electricity](tube-lamp-electricity.md#implementation-stages)), is not done.

## Before Merging

- Remove the temporary test spawner: `files/scripts/debug_spawn_fixtures.lua` and its two lines in `init.lua` (`dofile_once` and `UpdateDebugFixtureSpawns()`). They are kept uncommitted on purpose.
- Check off the remaining items in [version-0.3.md](../versions/version-0.3.md#extended-light-fixture-support).
