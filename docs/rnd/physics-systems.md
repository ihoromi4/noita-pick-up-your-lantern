# Two Physics Systems of Noita

[← Back to R&D Index](../rnd.md)

- **[Confirmed]** Noita's inventory item system (`ItemComponent`, `AbilityComponent` with `throw_as_item="1"`, `PhysicsThrowableComponent`, `ProjectileComponent`, `VelocityComponent`) is compatible **only with the legacy `PhysicsBodyComponent`** and does not work with `PhysicsBody2Component`.
- **[Confirmed]** If `PhysicsBody2Component` is left on the item:
  - Picking up the lantern into inventory takes only the flame sprite, while the glass bulb (`PhysicsImageShapeComponent`) remains hanging on the ceiling as an empty lamp fixture.
  - If `base_item_physics.xml` (`PhysicsBodyComponent`) is attached to an entity with `PhysicsBody2Component` at the same time, two physical objects of the same lantern are spawned in the world (one falls to the floor, the other hangs on the joint).
- **[Confirmed]** Instead of dynamically modifying XML via Lua (`ModTextFileGetContent` / `ModTextFileSetContent`), it is much cleaner and more reliable to completely override [these three XML files](vanilla-lantern-types.md) in the mod's `data/entities/props/` directory, directly inlining the components of `base_item_physics.xml` into them.
