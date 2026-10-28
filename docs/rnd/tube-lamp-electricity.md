# Tube Lamp and Electricity

[← Back to R&D Index](../rnd.md)

A fluorescent tube lamp cannot shine without power. Unlike oil lanterns, a pickable tube lamp shines only while it is wired to the ceiling or hit by electricity, so taking it down mostly costs the player a light source.

## Contents

- [Design](#design)
- [Implementation Stages](#implementation-stages)
- [Engine Building Blocks](#engine-building-blocks)
- [Open Questions](#open-questions)

## Design

- **Power.** A hanging lamp is powered by its cable and shines. Once it leaves the ceiling (picked up, kicked down, or the ceiling is destroyed), it goes dark.
- **Electricity.** A dark lamp lights up for a short time when electricity hits it, in the world or in hand, and takes no damage from it. Its capacity is small, about 1.5 seconds: vanilla electric sources hit periodically (the damaged tube lamp every 60 frames, electric traps for 100 frames), so a lamp in a pulsing current flickers on and off.
- **Cable while carrying.** When the player takes a lamp off the ceiling, a cable of separate segments runs from the ceiling to the lamp. A segment is paid out from the ceiling each time the cable gets too short, up to a random limit; past the limit the cable breaks with a burst of sparks, and the lamp goes dark.
- **Dangling cable.** The ceiling part of a broken cable stays hanging, with the segments paid out before the break, so it sometimes reaches the floor and sometimes does not. A lamp kicked down leaves a cable of random length. 2 seconds after the break, so the player is not shocked right away, its end starts sparking (`electricity_weak.xml`), about once a second. The cable is live for 3 minutes.
- **In hand.** The lamp is held like a sword point down: the unlit tube hangs from the hand by its end, at 70% size, with no wire stubs, and swings like a lantern. The left mouse button throws it as usual: a lamp that needs a power cable is not hung back.
- **Breaking.** A broken tube bursts like the vanilla propane tank (`physics_propane_tank.xml`, the blue gas cylinder of the Hiisi Base), scaled down: radius 24 instead of 60, damage 3 instead of 13, the same blast sprite, blue smoke and sound, no freezing vapour. It no longer bursts with electric sparks.

## Implementation Stages

1. Sword-like sprite in hand, no left-button hanging, propane-like burst. Done.
2. Power state: the lamp shines only while it hangs, scaled to zero light and fog of war hole otherwise. Done.
3. Lighting up from electricity, with a small capacity.
4. Dangling cable of random length after a kick, sparking for 3 minutes. Implemented, see [Lantern Entities](../dev/lantern-entities.md#tube-lamp-cable).
5. Cable of segments while carrying, breaking into a dangling cable. Implemented, see [Lantern Entities](../dev/lantern-entities.md#tube-lamp-cable).

## Engine Building Blocks

- **[Confirmed]** A runtime physics chain spawned by the mod got no bodies, see [Lantern Entities](../dev/lantern-entities.md#tube-lamp-cable); both cables are Lua ropes instead. Vanilla builds chains of physics segments at runtime: `data/scripts/props/temple_lantern.lua` and `hanging_wire_spawner.lua` add `PhysicsImageShapeComponent` and `PhysicsJoint2Component` (`REVOLUTE_JOINT_ATTACH_TO_NEARBY_SURFACE` for the ceiling) with `EntityAddComponent2`, then call `PhysicsBody2InitFromComponents` once. Wire segment: `data/props_breakable_gfx/wire_vertical_10_00.png`, material `metal_wire_nohit` (the player passes through it).
- **[Confirmed]** `data/entities/misc/electricity_weak.xml` is a short electric discharge (`ElectricityComponent energy="50"`). The vanilla damaged tube lamp spawns it every 60 frames (`physics_tube_lamp_electricity_pulse.lua`).
- **[Confirmed]** `ElectricityReceiverComponent` (`radius`, `active_time_frames`) calls `electricity_receiver_switched(on)` of `script_electricity_receiver_switched` when electricity reaches the entity; vanilla traps and the drill laser are powered this way.
- **[Confirmed]** Lantern light consumers (fire enemy attraction, Natural Fear, enemy study, belt) read the current `LightComponent` radius, so a radius of 0 turns a lamp off for all of them. The fog of war hole is scaled separately.
- **[Needs verification]** A physics chain cannot grow after `PhysicsBody2InitFromComponents`.
- **[Needs verification]** `ElectricityReceiverComponent` works on an item in hand, not only in the world.

## Open Questions

- What happens to the cable while the player carries a lamp across a save and reload, or far enough to unload the ceiling chunk.
- A dead cable stays hanging without sparks after 3 minutes; to be confirmed in play.
- The Lua rope stops at surfaces but is not pushed by explosions or creatures.
