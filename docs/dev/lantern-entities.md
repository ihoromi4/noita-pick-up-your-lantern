# Lantern Entities

Which vanilla entities the mod turns into pickable items, how they are rebuilt for the item system, and how they hang from the ceiling.

## Contents

- [Pickable Lanterns](#pickable-lanterns)
- [Physics System](#physics-system)
- [Ceiling Anchors](#ceiling-anchors)
- [Sprite Geometry](#sprite-geometry)
- [Other Light Sources](#other-light-sources)
- [Hanging Ropes](#hanging-ropes)
- [Tube Lamp Cable](#tube-lamp-cable)
- [Temple Lantern Chain](#temple-lantern-chain)
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
| `physics/temple_lantern.xml` | Temple Lantern | Holy Mountains (`temple_altar*`), `boss_arena`, `boss_arena_top`, secret chambers (`excavationsite_cube_chamber`, `snowcave_secret_chamber`, `snowcastle_hourglass_chamber`) |

Each entity carries the `lantern` tag, an `ItemComponent` that puts it into the Quick Inventory, and an `AbilityComponent` for throwing. Their light and durability are described in [Lantern Properties and Progression](lantern-properties-and-progression.md).

## Physics System

Noita has two physics component families, and the item system works only with the older one:

- `ItemComponent`, `AbilityComponent` with `throw_as_item="1"`, `PhysicsThrowableComponent`, `ProjectileComponent` and `VelocityComponent` work with `PhysicsBodyComponent` only, not with `PhysicsBody2Component`.
- With `PhysicsBody2Component` left on the entity, picking the lantern up takes only the flame sprite; the glass body stays on the ceiling.
- Adding `base_item_physics.xml` to an entity that has `PhysicsBody2Component` creates two physics bodies for one lantern: one falls, the other keeps hanging.

So `physics/lantern_small.xml` and `physics/temple_lantern.xml`, which use `PhysicsBody2Component` in vanilla, are rewritten to use `PhysicsBodyComponent` and `PhysicsJointComponent`. The tube lamp, a tube and two wires on `PhysicsBody2Component` in vanilla, becomes one `PhysicsBodyComponent` body. The mining lamp already uses the older family in vanilla. All files are full overrides with the `base_item_physics.xml` components expanded inline, not runtime XML edits.

The body material must not have `platform_type="1"` in `data/materials.xml`, otherwise the player bumps into the lantern and stands on it. `glass_box2d` has `platform_type="0"`, and the `*_nohit` materials inherit none from `aluminium`. The vanilla mining lamp is made of `wood_prop` (`platform_type="1"`), so its override uses the twin `wood_prop_noplayerhit`.

Lanterns have no `CameraBoundComponent`, unlike their vanilla files. With it, a lantern farther than its `distance` from the camera is frozen: the engine kills it and keeps only its file and position, then spawns it again from the file when the camera comes back. The respawned lantern loses its storages (quality tier, modifiers, `lantern_chain_checked`), so a chained lantern would build a second chain next to its old one. Without the component a lantern is saved with its chunk, as potions and wands are.

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
- **Power.** The tube lamp has `needs_power` in `LANTERN_TYPES`: it shines only while it hangs or is attached to its cable. `CutLanternPower()` (`lantern_traits.lua`) cuts the power for good and sets the `lantern_power_lost` storage; `UpdateTubeLampCables()` in `tube_lamp_cable.lua` calls it when the cable snaps, or when the lamp leaves the ceiling without a cable. `GetLanternPowerFactor()` then turns the light radius and the fog of war hole to 0 in hand, in the world, on the belt and in the modifier script, so attraction, fear and enemy study ignore the lamp as well. The belt counts a lamp without power as unlit.
- The physics image cannot change on an existing body, so `CutLanternPower()` switches `PhysicsImageShapeComponent.image_file` to `unpowered_image_file` (`tube_lamp_unlit.png`), and the engine uses it for the next body, created when the lamp is thrown or dropped. A lamp kicked down keeps the lit-looking image until it is picked up and thrown again. `CutLanternPower()` also switches the lit in-hand sprite `tube_lamp_in_hand.xml` to the unlit `tube_lamp_in_hand_out.xml`, which the belt copies, and the lit inventory icon `ui_tube_lamp.png` to `unpowered_ui_sprite` (`ui_tube_lamp_unlit.png`). `GetLanternType()` recognises the type by either icon.
- **Cable.** See [Tube Lamp Cable](#tube-lamp-cable).
- `temple_lantern_01.png` (temple lantern) is 9×11 pixels: a transparent row at `y = 0`, the roof at `y = 1..2`, the glass at `y = 3..8`, a drop at `y = 9`. `centered="0"`, `offset_x="4.5"`, `offset_y="0.5"` put the origin at the top in the middle, where the vanilla chain is attached; `hang_offset_y = 1` hangs it right under the ceiling, like a small lantern. The in-hand sprite is the physics image (`temple_lantern_in_hand.xml`), the dark one has dimmed glass (`temple_lantern_out.png`).
- The temple lantern shines blue like the vanilla one, but wider (radius 192 instead of 128) and brighter: `LightComponent` has no intensity, so red and green are raised from 30 to 80 and 100 while blue stays at 255. It keeps the vanilla plasma glow and spark particles, explosion and `plasma_fading` spill. The spill comes from a death script (`temple_lantern_death.lua`), not from a `MaterialInventoryComponent`, which would also spill when the held lantern is replaced by a hung one. `ExtinguishLantern()` removes particle emitters together with the light.
- **Chain.** See [Temple Lantern Chain](#temple-lantern-chain).
- The tube lamp spins in flight: `min_torque="4"`, `max_torque="10"` on `PhysicsThrowableComponent`, as on the vanilla broken wand.

## Other Light Sources

Besides the lanterns, `patch_lighting.lua` adds a fog of war hole to light sources that are not pickable, so they also dispel fog of war under limited vision:

- chain torches: `chain_torch`, `chain_torch_blue`, `chain_torch_ghostly` and their duplicates;
- torch stands: `physics_torch_stand.xml`, `physics_torch_stand_blue.xml`;
- `physics_barrel_burning.xml`.

The hole is scaled by `Illuminated area size` when the game starts. It is added only when `Illuminate the darkness` is on.

## Hanging Ropes

`files/scripts/hanging_rope.lua` holds the rope shared by the tube lamp cable and the temple lantern chain:

- A rope is a chain of verlet points simulated in Lua: gravity, damping, segments pulled back to their length, and points stopped at surfaces with `RaytraceSurfaces`. Each segment is a sprite entity, placed at its upper point and turned along the segment every frame.
- A `RopeKind` sets the segment length and sprite, the tags of the anchor and segment entities, and the anchor storage with the segment count. A slack rope (the cable) only pulls stretched segments back and stretches its sprites to the segment length; a rigid one (the chain) keeps every segment at its length and its sprites unscaled, and alternates the direction of its constraint passes.
- An anchor entity at the ceiling keeps the segment count, so after a save and reload, or when a chunk streams in, each anchor gets its rope again, hanging straight down. Segment sprites of no known rope are removed.
- `HoldBodyOnHangingRope()` holds a physics body at the length of its rope by the attachment point, see [Tube Lamp Cable](#tube-lamp-cable).

## Tube Lamp Cable

`files/scripts/tube_lamp_cable.lua` (`UpdateTubeLampCables()`, every frame in `OnWorldPostUpdate`) gives a tube lamp its power cable:

- While a lamp hangs (`IsLanternHanging()`: a root entity with a `PhysicsJointComponent`), its position, the upper end of its wires right under the ceiling, is kept in the `lantern_cable_anchor_x/y` storages as the cable anchor, and `lantern_cable_hanging` is set. The flag tells the moment the lamp leaves the ceiling apart from a powered lamp found off the ceiling without a cable, e.g. after a reload, which only loses its power.
- A cable is a slack [hanging rope](#hanging-ropes), so a hanging cable lies on the floor. Each segment (5 px, the vanilla `wire_vertical_5_00.png`) is a `tube_lamp_cable_segment.xml` sprite entity (tag `pul_cable_segment`).
- A cable entity (`files/entities/tube_lamp_cable.xml`, tag `pul_cable`) marks the anchor and keeps the `cable_segment_count` and `cable_age_frames` storages. Ropes live in Lua, so after a save and reload, or when a chunk streams in, each cable entity gets a rope again, hanging straight down, and segment sprites of no known rope are removed.
- When a lamp leaves the ceiling, its cable stays attached and keeps it powered. The lamp joint is removed, so the lamp does not count as hanging once it is back in the world. Several cables can hold lamps at once.
- A lamp the player picks up gets a cable of 8 to 32 segments (40 to 160 px). It runs from the anchor to the lamp, or to the player while the lamp is in the inventory but not in hand. A segment is paid out from the ceiling whenever the lamp is farther from the anchor than the cable length.
- A lamp knocked off by a shot or a kick dangles on a cable of 2 to 6 segments (10 to 30 px), as if the cable held on to its mounts, and its light blinks (`blinking_freq="0.9"`, as the vanilla damaged tube lamp). Picked up later, it gets the length of a picked-up lamp.
- The player snaps the cable by carrying the lamp 10% farther than the full cable. A lamp in the world is held at the length of its cable by one end of the tube, the upper end of a vanilla wire (5 px left or right of the origin, picked at random), so it swings on the cable and hangs vertically. It snaps the cable only when flung twice as far as the full cable in a single frame.
- `HoldLampOnCable()` moves the physics body so that the attachment point is back on the circle around the anchor, and takes away the speed of the point away from the anchor as an impulse at the point would (`PhysicsBodyIDGetTransform`, `PhysicsBodyIDSetTransform`). The tube is taken as a thin rod of 19 px around its middle, so the impulse needs only the ratio of mass to moment of inertia, `12 / length^2`, not the mass itself. The impulse also changes the spin, which turns the lamp. The sign of the Box2D angle relative to the game is taken from `GameVecToPhysicsVec(0, 1)`.
- The cable snaps with cosmetic electric sparks (`GameCreateCosmeticParticle`, harmless), the lamp loses its power, and the cable keeps hanging from the ceiling with its paid-out segments.
- A lamp whose ceiling was destroyed gets no cable and loses its power: no ceiling is found within 8 px above the anchor. Which lamp a cable holds is not saved, so after a reload the lamp falls off and loses its power.
- A torn cable sparks from its end: `data/entities/misc/electricity_weak.xml` every 60 frames, from 2 seconds after it snapped for 3 minutes. Then it keeps hanging without sparks.
- Each spark induces current around the end: creatures (`enemy`, `player_unit`) within 20 px with no wall in between (`RaytraceSurfaces`) get the vanilla electrocution effect (`effect_electricity.xml`, 40 frames), 0.08 electric damage (`$damage_tube_lamp_cable`) and an arc of cosmetic sparks from the cable.
- Only one carried cable exists at a time.

> [!NOTE]
> The cable was first a `PhysicsBody2Component` chain built at runtime like the vanilla temple lantern chain. Spawned by the mod, it got no physics bodies, whether `PhysicsBody2InitFromComponents` was called from a world callback right after `EntityLoad` or from the cable's own `LuaComponent`. Every vanilla chain built this way also declares a root shape (`is_root="1"`) in its XML, except the hanging wire, which kills its entity after initialization. A physics chain also could not grow while carried, so both cables are Lua ropes now.

## Temple Lantern Chain

The vanilla temple lantern builds a physics chain up to the ceiling at runtime (`data/scripts/props/temple_lantern.lua`) out of `PhysicsBody2Component` shapes, which the item system cannot use (see [Physics System](#physics-system)). `files/scripts/temple_lantern_chain.lua` (`UpdateTempleLanternChains()`, every frame in `OnWorldPostUpdate`) hangs it on a rigid [hanging rope](#hanging-ropes) instead, for every type with `hangs_on_chain` in `LANTERN_TYPES`:

- **Look.** Each link is a `temple_lantern_chain_link.xml` sprite entity (tag `pul_chain_link`) with the vanilla link sprite `torch_hang_chain.png` (3×6 px), 6 px long and never stretched.
- **Spawn.** A lantern seen in the world for the first time (no `lantern_chain_checked` storage) searches for the ceiling up to 200 px above its top with `RaytracePlatforms`, as the vanilla script does. It gets a chain of `floor(distance / 6)` links, as many as the vanilla script builds. Its ceiling joint and anchor script are removed. With the ceiling within 6 px, the lantern keeps its joint; without a ceiling it falls.
- **Hanging.** The lantern is held at the length of its chain by its top with `HoldBodyOnHangingRope()`, taken as a 9×11 box, so it swings on the chain. While it pulls the chain taut, the links are laid on the straight line from the anchor to the lantern (`StraightenHangingRope()`) instead of being simulated: with both ends held, the step-by-step simulation gathers its remaining error in the last link, which then stands at an angle.
- **Coming off.** The lantern comes off its chain when it is picked up, kicked (`temple_lantern_kick.lua` sets `lantern_chain_unhook`) or flung twice as far as the chain in a frame. The chain keeps hanging.
- **Projectiles.** A projectile that collides with the world (`collide_with_world`, not `penetrate_world`) and passes within 2 px of a link in the last frame (its path is taken from `VelocityComponent.mVelocity`) breaks the closest link: the projectile is moved there and killed, and dies with its usual effect (**[Confirmed]**), the part above keeps hanging, the part below falls off with the lantern as a loose piece, lies on the floor and disappears after 10 seconds. A chain without a lantern breaks the same way.
- **Ceiling destroyed.** The anchor checks the ceiling 4 px above it every 20 frames. Without it the whole chain falls as a loose piece.
- **Saving.** A chain entity at the anchor (`temple_lantern_chain.xml`, tag `pul_chain`) keeps the link count in `chain_link_count`. The lantern keeps `lantern_on_chain` and the anchor position (`lantern_chain_anchor_x/y`), and is put back on the chain at that anchor after a reload. A lantern whose chain does not load within 3 seconds falls. Loose pieces are not saved.
- A lantern hung with the left mouse button copies the state of the held one, `lantern_chain_checked` included, so it hangs on its joint right under the ceiling, without a chain.

## Duplicate Torch Entities

Each chain torch exists in two files with different paths, and different biomes spawn different files:

| `physics/` variant | Duplicate in `props/` | Where the duplicate spawns |
| --- | --- | --- |
| `physics/chain_torch.xml` | `physics_chain_torch.xml` | `mountain_center`, `endgame_end` |
| `physics/chain_torch_blue.xml` | `physics_chain_torch_blue.xml` | No vanilla biome |
| `physics/chain_torch_ghostly.xml` | `physics_chain_torch_ghostly.xml` | 24 biomes, including `excavationsite` (Coal Pits), `desert`, `rainforest`, `vault`, `snowcastle`, `tower`, `the_end` |

The duplicates are an older version without `<Base file="data/entities/base_chain_torch.xml">`: the physics body and scripts are declared inline, and `LightComponent` and `TorchComponent` are tagged `enabled_in_world,enabled_in_hand`. The light still sits in a nested `Entity`, as in the `physics/` variants, so the same patch applies to both. Patch both paths whenever you patch a chain torch.
