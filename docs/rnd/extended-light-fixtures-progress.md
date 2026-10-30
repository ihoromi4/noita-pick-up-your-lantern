# Extended Light Fixture Support: Progress

[← Back to R&D Index](../rnd.md)

Where the work on the version 0.3 item "Extended Light Fixture Support" ([version-0.3.md](../versions/version-0.3.md#extended-light-fixture-support)) stopped, and what is left. The work happens on the `feat/extended-light-fixtures` branch.

## Contents

- [Done](#done)
- [Remaining Fixtures](#remaining-fixtures)
- [Test Spawner State](#test-spawner-state)
- [Open Issues](#open-issues)
- [Later Ideas](#later-ideas)
- [Before Merging](#before-merging)

## Done

Each pickable fixture is a full override in `pick_up_your_lantern/data/entities/props/`, registered in `LANTERN_TYPES` of `files/scripts/lantern_properties_config.lua`. See [Lantern Entities](../dev/lantern-entities.md).

- **Mining lamp** (`physics_mining_lamp.xml`): pickable, checked in game. Keeps the vanilla origin in the centre, so it declares its own ceiling check distance (`lantern_ceiling_check_distance`). Made of `wood_prop_noplayerhit`, as the vanilla `wood_prop` blocks the player.
- **Tube lamp** (`physics_tubelamp.xml`): pickable, checked in game. It is the only lamp of the Hiisi Base, which closes the "Hiisi Base fixtures" part of the item. Design and engine findings: [Tube Lamp and Electricity](tube-lamp-electricity.md).
  - Shines only while powered by its cable; in hand, on the belt and in the inventory it shows a lit or dark sprite and icon.
  - Held like a sword point down; thrown with both mouse buttons; bursts like a small propane tank.
  - A cable of 5 px segments, simulated in Lua as a verlet rope, follows a lamp taken down and snaps past a random length; a lamp knocked off dangles by one end of the tube on a short cable, swings and blinks.
  - A torn cable keeps hanging and, from 2 s after the break for 3 min, sparks from its end and shocks creatures within 20 px.
- **Temple lantern** (`physics/temple_lantern.xml`): pickable, checked in game. See [Temple Lantern Chain](../dev/lantern-entities.md#temple-lantern-chain).
  - Hangs on a Lua chain of vanilla link sprites (`torch_hang_chain.png`, 6 px) from the ceiling up to 200 px above, swings on it; a taut chain is laid straight (`StraightenHangingRope()`), otherwise its last link bends.
  - Comes off when picked up, kicked (`temple_lantern_kick.lua`) or flung; the chain keeps hanging. A lantern on its chain is put back on it after a reload.
  - A projectile that passes within 2 px of a link breaks it and dies there with its usual effect (checked in game); the lower part falls off with the lantern.
  - Hung with the left mouse button, it hangs right under the ceiling without a chain.
  - Light 50% wider than vanilla (radius 192) and brighter (`r="80" g="100" b="255"`). Breaks with the vanilla explosion and spills `plasma_fading`.
- **Shared rope** (`files/scripts/hanging_rope.lua`): the verlet rope of the tube lamp cable, moved out for the temple lantern chain. A `RopeKind` sets the segment length, sprite and tags; a rigid kind keeps links at their length and alternates the direction of its constraint passes. See [Hanging Ropes](../dev/lantern-entities.md#hanging-ropes).
- **Commits** on the branch: `61d872e` (shared rope), `b0d8abf` (temple lantern), `d7f1737` (docs), and the docs commit with this update.
- **Test spawning**: [Spawning Fixtures for In-Game Tests](test-spawning.md), with points in the mountain hall at the entrance to the Mines.

## Remaining Fixtures

| Fixture | Files | Vanilla specifics |
| --- | --- | --- |
| Chain torches | `physics/chain_torch.xml`, `chain_torch_blue.xml`, `chain_torch_ghostly.xml` and their duplicates `physics_chain_torch.xml`, `physics_chain_torch_blue.xml`, `physics_chain_torch_ghostly.xml` | The `physics/` variants use `base_chain_torch.xml` (`PhysicsBody2Component`, 4 chain links and an 11×13 `torch_hang_unlit.png` head); the duplicates use the older `PhysicsBodyComponent` with a chain from `physics_chain_torch.lua`. The light (radius 96), `TorchComponent` and torch particles are in a nested child `Entity`. The ghostly torch spawns in 37 biomes. |

Decisions already made for them:

- Full parity with lanterns: pick up, hold, belt, throw, hang with the left mouse button, kick down, break.
- All quality tiers and modifiers apply.
- Chain torches keep `TorchComponent` and ignite things in the world and in hand, as in vanilla.

Vanilla geometry of the `physics/` variants (`data/entities/base_chain_torch.xml`):

- The entity origin is at the top of the chain, right under the ceiling: biomes spawn it at the marker (`coalmine`) or with small offsets (`crypt`: `offset_y = 10`, `spawn_lamp` at `x + 4, y - 8`).
- Body 0 is `torch_hang_chain_ceiling.png` (3×6) at `y = 0`, attached to the ceiling with `REVOLUTE_JOINT_ATTACH_TO_NEARBY_SURFACE` at `(2, 0)`; bodies 1–3 are `torch_hang_chain.png` links at `y = 6, 12, 18`; body 4 is the `torch_hang_unlit.png` head (11×13) at `(-3.5, 24)`. Joints at `x = 2`, every 6 px.
- The duplicates (`physics_chain_torch*.xml`) have their origin in the middle of the head (`centered="1"`); `physics_chain_torch.lua` adds 3 links and attaches the top about 32 px above the origin.

Suggested approach, reusing the temple lantern:

- Give the torch type `hangs_on_chain` in `LANTERN_TYPES` and let `temple_lantern_chain.lua` serve it too (rename it to a general chain script). A torch needs a fixed chain of 4 links (the top one with the ceiling sprite) instead of a chain to a ceiling up to 200 px away, so the chain length becomes a per-type setting, as well as the link sprite of the top link.
- Override both file sets: the `physics/` variants with their origin at the top of the head, spawned 24 px below the marker by the chain script, and the duplicates with their own origin; check where each spawns in [test spawning](test-spawning.md).
- The light, `TorchComponent` and particles of the chain torches have to move from the nested `Entity` to the root: the illumination, belt and modifier code read the components of the lantern entity itself.
- Before writing a body material, check its `platform_type` in `data/materials.xml`: `1` makes the player bump into the fixture.
- A runtime `PhysicsBody2Component` chain spawned by the mod gets no bodies (see [Lantern Entities](../dev/lantern-entities.md#tube-lamp-cable)), so the vanilla chain cannot be kept.

## Test Spawner State

`files/scripts/debug_spawn_fixtures.lua` (uncommitted, see [Spawning Fixtures for In-Game Tests](test-spawning.md)) currently spawns, in this order:

- 2 mining lamps and 4 tube lamps at the hall ceiling points;
- 2 temple lanterns at `928, -45` and `780, -165`;
- the 6 vanilla chain torches, still not pickable, under the sloped cave ceiling: `physics/chain_torch.xml` at `836, -167`, `physics/chain_torch_blue.xml` at `864, -160`, `physics/chain_torch_ghostly.xml` at `896, -128`, and the duplicates `physics_chain_torch.xml` at `812, -140`, `physics_chain_torch_blue.xml` at `880, -112`, `physics_chain_torch_ghostly.xml` at `912, -80` (32 px below the ceiling).

Each fixture is spawned once per run under a flag named by its index in the list: after inserting or reordering entries, start a new game.

## Open Issues

- Quality tier and modifier descriptions are written for oil lanterns (flame, wick, oil) and read oddly on a tube lamp; per-type descriptions are an idea for later.
- A tube lamp knocked off keeps its lit-looking physics image after it loses power, until it is picked up and thrown again.
- Which lamp a cable holds is not saved: after a reload the lamp falls off and goes dark, the cable stays.
- Not checked one by one after the temple lantern: that the tube lamp cable works as before after moving its rope to `hanging_rope.lua` (it passed a run against a stubbed API).
- The vanilla temple lantern spawned by the debug spawner fell right away, most likely because its runtime physics chain gets no bodies when the mod spawns it (as with the first cable). Not checked further: the override replaces the vanilla chain.
- Explosions do not break a temple lantern chain, as the Lua chain has no bodies; the lantern itself usually breaks or is flung off.
- Lighting up a dark tube lamp from electricity, with a small capacity between hits (stage 3 in [Tube Lamp and Electricity](tube-lamp-electricity.md#implementation-stages)), is not done.

## Later Ideas

- Version 0.4 plans a magic liquid modifier for the temple lantern: a rare dark lantern that spills Concentrated Mana, Flummoxium or Unstable Teleportatium when it breaks. See [version-0.4.md](../versions/version-0.4.md#temple-lantern-modifiers).

## Before Merging

- Remove the temporary test spawner: `files/scripts/debug_spawn_fixtures.lua` and its two lines in `init.lua` (`dofile_once` and `UpdateDebugFixtureSpawns()`). They are kept uncommitted on purpose.
- Check off the remaining items in [version-0.3.md](../versions/version-0.3.md#extended-light-fixture-support).
