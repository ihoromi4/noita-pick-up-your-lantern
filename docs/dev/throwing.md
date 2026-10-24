# Throwing

How lanterns are thrown, how they fly, and when they shatter.

## Contents

- [Throw Setup](#throw-setup)
- [Flight Physics](#flight-physics)
- [Shattering](#shattering)
- [Engine Limitations](#engine-limitations)

## Throw Setup

Lanterns use the vanilla item throw:

```xml
<AbilityComponent
    ui_name="$item_lantern"
    throw_as_item="1"
>
    <gun_config deck_capacity="0" />
</AbilityComponent>

<PhysicsThrowableComponent
    max_throw_speed="180"
    throw_force_coeff="1.5"
></PhysicsThrowableComponent>
```

Only the built-in throw flies exactly along the dotted aiming line drawn by `PhysicsThrowableComponent` and switches the lifecycle tags correctly when the lantern leaves the hand. A thrown lantern keeps its light, flame animation and fog of war hole.

After a throw, `lantern_in_world.lua` resets the mirrored transform scale. See [Flame Desync After Throw](holding-and-belt.md#flame-desync-after-throw).

## Flight Physics

`PhysicsBodyComponent` has `gridworld_box2d="1"`, `is_bullet="1"` and `hax_fix_going_through_ground="1"`. Without them a thrown lantern passes through walls or jitters inside the terrain.

`ProjectileComponent` (`damage="0"`, `never_hit_player="1"`) and `VelocityComponent` let a thrown lantern hit enemies through physics impact damage.

## Shattering

- `PhysicsBodyCollisionDamageComponent.speed_threshold` is lowered from the vanilla `120.0` to `80.0`, and the large lantern's `hp` from `0.9` to `0.5`. With these values a thrown lantern reliably shatters on a hard hit, while a soft landing leaves it intact.
- On death, `ExplodeOnDamageComponent` sets off a small explosion (radius 12 for the large lantern, 5 for the small ones). `lantern_death.lua` (large) and `lantern_small_death.lua` (small) spill 4 oil particles and 2 fire particles and spawn the vanilla shatter particles, so the spilled oil catches fire.

## Engine Limitations

With `throw_as_item="1"`, the left mouse button throws a held lantern just like the right one. The engine offers no way to keep only the right button:

- `throw_as_item="0"` disables both buttons.
- `PotionComponent` is the only native component that keeps the left button for an action and the right one for throwing. It only works together with `MaterialInventoryComponent`, which always shows a material count or name in the inventory UI.
- Component scripts run after the player input system in a frame, so switching `throw_as_item` from Lua at the moment of a click is one frame late.
- A scripted throw through `PhysicsApplyForce` does not follow the aiming line. Turning off `enabled_in_hand` components by hand also turns off the light, because the light carries both `enabled_in_world` and `enabled_in_hand`.
