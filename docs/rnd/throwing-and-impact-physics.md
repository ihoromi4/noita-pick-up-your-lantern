# Throwing and Impact Physics

[← Back to R&D Index](../rnd.md)

- **[Confirmed]** To prevent a thrown lantern from phasing through walls or jittering inside terrain, `gridworld_box2d="1"`, `is_bullet="1"`, and `hax_fix_going_through_ground="1"` must be enabled in `PhysicsBodyComponent`.
- **[Confirmed]** Reducing `speed_threshold` in `PhysicsBodyCollisionDamageComponent` from the vanilla `120.0` to `80.0` (and `hp="0.5"` instead of `0.9` for the large lantern) ensures reliable shattering and explosion of the lantern when thrown by the player.
- **[Needs verification]** The effect of `CameraBoundComponent` on lanterns after the player picks them up and throws them onto the floor (whether they despawn when the player moves away beyond `distance="1000"` and whether `CameraBoundComponent` should be removed).
