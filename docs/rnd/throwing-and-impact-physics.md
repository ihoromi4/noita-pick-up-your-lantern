# Throwing and Impact Physics

[← Back to R&D Index](../rnd.md)

- **[Confirmed]** To prevent a thrown lantern from phasing through walls or jittering inside terrain, `gridworld_box2d="1"`, `is_bullet="1"`, and `hax_fix_going_through_ground="1"` must be enabled in `PhysicsBodyComponent`.
- **[Confirmed]** Reducing `speed_threshold` in `PhysicsBodyCollisionDamageComponent` from the vanilla `120.0` to `80.0` (and `hp="0.5"` instead of `0.9` for the large lantern) ensures reliable shattering and explosion of the lantern when thrown by the player.
- **[Confirmed]** `CameraBoundComponent` (`distance="1000"`) freezes a lantern once the camera is farther away: the save keeps only its file and position (in `world/area_*.bin`, not with the chunk entities in `world/entities_*.bin`), and the lantern is spawned again from the file with its storages lost. A chain torch spawned again built a second chain next to the saved one. The component is removed from all lanterns, see [Lantern Entities](../dev/lantern-entities.md#physics-system).
