# Lantern Throwing Mechanics and Controls Research

[← Back to R&D Index](../rnd.md)

This report documents the attempts to implement throwing a lantern exclusively with the right mouse button (RMB) while preserving vanilla physics, visual effects, and a clean user interface. None of the tested approaches solved all issues simultaneously.

## Table of Contents

- [Target Behavior](#target-behavior)
- [Issue List](#issue-list)
- [Tested Configurations](#tested-configurations)
  - [Configuration: Vanilla AbilityComponent](#configuration-vanilla-abilitycomponent)
  - [Configuration: Flask Emulation via PotionComponent](#configuration-flask-emulation-via-potioncomponent)
  - [Configuration: Scripted Throw via PhysicsApplyForce](#configuration-scripted-throw-via-physicsapplyforce)
  - [Configuration: Dynamic Toggling of throw_as_item](#configuration-dynamic-toggling-of-throw_as_item)
- [Summary Results Table](#summary-results-table)
- [Technical Conclusions](#technical-conclusions)
- [Hypotheses for Further Testing](#hypotheses-for-further-testing)
- [Hanging the Lantern on LMB](#hanging-the-lantern-on-lmb)

## Target Behavior

1. **Throw exclusively on RMB**: A simple right-click (or throw key) immediately throws the lantern from the hands.
2. **Ignore LMB**: The left mouse button must never throw the lantern, preventing accidental throws during gameplay.
3. **Exact match with the aiming line**: While the lantern is selected in the inventory, the game continuously renders a white dotted trajectory prediction line (`PhysicsThrowableComponent`). When thrown, the lantern must follow this exact curve.
4. **Preserve light after throw**: The thrown lantern must continue emitting light, playing flame animation, and clearing fog of war.
5. **Clean inventory**: The lantern icon in the inventory slot and its tooltip must not display extraneous numbers (`0`) or material names (`sand`).

## Issue List

Five interrelated technical issues with the Noita engine were identified during implementation:

1. **Shared LMB and RMB binding in `AbilityComponent`**: The `throw_as_item="1"` flag enables throwing the item with both RMB and LMB. Disabling the flag (`throw_as_item="0"`) blocks both buttons at once — there is no standard way to keep only RMB.
2. **Forced material rendering in the UI for flasks**: In the vanilla game, only flasks (`PotionComponent`) are not thrown via LMB. However, `PotionComponent` only functions in tandem with `MaterialInventoryComponent`, which forces the UI to display the material count (`0`) or its name in the item description.
3. **Light extinguished due to shared component tags**: Illumination components (`LightComponent`, `SpriteAnimatorComponent`, `fog_of_war_hole` sprite) simultaneously have two tags: `enabled_in_world,enabled_in_hand`. During a manual scripted throw, calling `EntitySetComponentsWithTagEnabled(id, "enabled_in_hand", false)` disables them alongside the in-hand sprite, extinguishing the thrown lantern.
4. **Custom impulse mismatch with vanilla ballistics**: A manual throw using `PhysicsApplyForce` in Lua does not reproduce the engine's internal formula for `PhysicsThrowableComponent`. Even with manual tuning of `THROW_MAX_FORCE`, the physical flight trajectory does not align with the white dotted aiming line.
5. **One-frame delay between C++ input and Lua**: The player handling system (`PlatformShooterPlayerSystem`) executes earlier in the frame than scripts (`LuaSystem`). Consequently, an attempt to enable `throw_as_item="1"` from a script on an RMB click arrives late and breaks the controls.

## Tested Configurations

### Configuration: Vanilla AbilityComponent

The base configuration of a physical item that can be held and thrown.

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

- **What works**: Flawless flight strictly along the dotted prediction line, correct lighting after throw, clean icon in inventory.
- **Problem**: LMB throws the lantern just like RMB.

### Configuration: Flask Emulation via PotionComponent

In the vanilla game, the character does not throw an empty flask on LMB (LMB sprays materials, while RMB throws). Three iterations with `PotionComponent` were evaluated:

```xml
<PotionComponent
    _tags="enabled_in_hand,enabled_in_world"
></PotionComponent>

<MaterialInventoryComponent
    _tags="enabled_in_world,enabled_in_hand,enabled_in_inventory"
    drop_as_item="0"
    max_capacity="1"
>
    <count_per_material_type>
        <Material material="sand" count="1" />
    </count_per_material_type>
</MaterialInventoryComponent>
```

1. **Iteration with an empty `MaterialInventoryComponent` (capacity 0)**:
   - *Result*: LMB no longer throws the lantern; RMB throws normally along the dotted line.
   - *Problem*: In the quick inventory, the number `0` is rendered over every lantern icon.
2. **Iteration without `MaterialInventoryComponent` (`PotionComponent` only)**:
   - *Result*: The number `0` in the inventory disappears.
   - *Problem*: Without a material inventory, the engine ignores `PotionComponent`, and LMB throws the lantern again.
3. **Iteration with 1 unit of material (`sand`, `max_capacity="1"`)**:
   - *Result*: LMB does not throw; the number `0` on the icon disappears (since the flask is 100% "full").
   - *Problem*: The item name and tooltip in the inventory indicate that sand is inside the lantern (`Lantern (sand)`).

### Configuration: Scripted Throw via PhysicsApplyForce

Completely disabling the vanilla throw (`throw_as_item="0"`) and implementing a custom throw in `lantern_in_hand.lua` on RMB press.

```lua
EntityRemoveFromParent(lantern_id)
EntitySetTransform(lantern_id, spawn_x, spawn_y, 0.0, 1.0, 1.0)

EntitySetComponentsWithTagEnabled(lantern_id, "enabled_in_world", true)
EntitySetComponentsWithTagEnabled(lantern_id, "enabled_in_hand", false)

PhysicsApplyForce(lantern_id, fx, fy)
PhysicsApplyTorque(lantern_id, torque)
```

- **What works**: LMB is completely blocked, simple RMB click throws the item, inventory UI is clean.
- **Problem 1 (Loss of light)**: Calling `EntitySetComponentsWithTagEnabled(lantern_id, "enabled_in_hand", false)` disabled `LightComponent`, `SpriteAnimatorComponent`, and the fog-of-war lighting sprite because they carry `enabled_in_hand` alongside `enabled_in_world`. The thrown lantern ceased emitting light.
- **Problem 2 (Trajectory mismatch)**: The base impulse (`THROW_FORCE = 120`) proved too weak — the lantern dropped almost at the player's feet. Attempts to manually tune `THROW_MAX_FORCE` failed: the physical trajectory from a single-frame `PhysicsApplyForce` still does not follow the dotted prediction curve rendered by the game.

### Configuration: Dynamic Toggling of throw_as_item

An attempt to use the engine's built-in physics throw by enabling `throw_as_item="1"` via Lua only when RMB is pressed (keeping `throw_as_item="0"` otherwise).

```lua
local is_throw_down = ComponentGetValue2(controls_comp, "mButtonDownThrow") or
    ComponentGetValue2(controls_comp, "mButtonDownRightClick")

if is_throw_down then
    ComponentSetValue2(ability_comp, "throw_as_item", true)
else
    ComponentSetValue2(ability_comp, "throw_as_item", false)
end
```

- **What works**: When a throw is successfully initiated, the engine correctly switches component tags (light remains on) and throws the lantern accurately along the dotted curve.
- **Problem**: Because the C++ player input system executes earlier in the frame than Lua scripts, the engine still sees `throw_as_item = false` at the exact moment of the RMB click. A simple click on RMB stops throwing the item; instead, throwing only triggers on a bizarre sequence of inputs: `RMB -> LMB -> RMB`.

## Summary Results Table

| Criterion | Vanilla (`throw_as_item="1"`) | `PotionComponent` + Inventory | Scripted (`PhysicsApplyForce`) | Dynamic `throw_as_item` |
| :--- | :---: | :---: | :---: | :---: |
| Block throw on LMB | ❌ Throws on LMB | ✅ | ✅ | ✅ |
| Throw on simple RMB click | ✅ | ✅ | ✅ | ❌ Only `RMB->LMB->RMB` |
| Flight along dotted line | ✅ | ✅ | ❌ Trajectory mismatch | ✅ |
| Light preserved after throw | ✅ | ✅ | ❌ Extinguishes (tag conflict) | ✅ |
| Clean inventory UI | ✅ | ❌ Label `0` or `sand` | ✅ | ✅ |

## Technical Conclusions

1. **Closed nature of vanilla throwing**: Only the C++ inventory engine mechanism knows how to throw an item precisely along the `PhysicsThrowableComponent` line and properly toggle component tags when transitioning from hands into the world.
2. **`PotionComponent` limitations**: It is the only native component that cleanly separates LMB (action) and RMB (throw), but its hard dependency on `MaterialInventoryComponent` inevitably clutters the inventory UI.
3. **Frame execution order issue**: Any attempts to dynamically manipulate `AbilityComponent` or `ControlsComponent` properties directly on the click frame run into the fact that `PlatformShooterPlayerSystem` executes before `LuaSystem`.

## Hypotheses for Further Testing

### The click_to_use Flag in AbilityComponent

In the `AbilityComponent` schema, besides `throw_as_item`, there is a separate boolean field `click_to_use` (default `1`). In the vanilla item `data/entities/items/books/book_all_spells.xml`, developers explicitly disable both parameters: `throw_as_item="0"` and `click_to_use="0"`.

- **What to test**: Set the combination `throw_as_item="1"` and `click_to_use="0"`.
- **Expectation**: If `click_to_use="0"` disables reaction to LMB (`mButtonDownFire`) while `throw_as_item="1"` keeps the standard RMB throw (`mButtonDownThrow`) active, this would solve the issue at the XML level without any scripts.

### Dummy Nameless Material for PotionComponent

The configuration with `PotionComponent` + `MaterialInventoryComponent` (`max_capacity="1"`, 1 unit of material) satisfied all control and physics requirements and removed the `0` from the slot icon. The only downside was the `(sand)` material suffix in the inventory item name.

- **What to test**:
  1. Register an invisible dummy technical material (e.g., `lantern_dummy`) in `materials.xml` with an empty `ui_name=""`, and fill `MaterialInventoryComponent` with 1 unit at `max_capacity="1"`.
  2. Set `dont_spray_static_materials="1"` or `spray_velocity_coeff="0"` in `PotionComponent` so that clicking LMB does not spray this material unit from the lantern.
- **Expectation**: An empty material `ui_name` will remove the parenthesized text from the lantern's name while retaining native throwing exclusively on RMB.

### Input Interception in the Global Hook OnWorldPreUpdate

Dynamic toggling of `throw_as_item` in `lantern_in_hand.lua` failed because component scripts (`LuaSystem`) execute **after** `PlatformShooterPlayerSystem` in the frame. Conversely, the global callback `OnWorldPreUpdate()` in `init.lua` is invoked at the very beginning of the frame **before** all entity systems.

- **What to test**:
  - **Option A**: Keep `throw_as_item="1"` in XML, check in `OnWorldPreUpdate()` if the player is holding a lantern (`Inventory2Component.mActiveItem`), and forcibly reset `mButtonDownFire = false` in `ControlsComponent` before the C++ system processes the LMB click.
  - **Option B**: Manage the `throw_as_item` flag directly inside `OnWorldPreUpdate()` based on the state of `mButtonDownThrow`.
- **Expectation**: Elimination of the 1-frame lag between button press and C++ engine response.
- **Status**: **[Disproven by testing]** Option A does not stop the vanilla throw: resetting `mButtonDownFire` in `OnWorldPreUpdate()` still results in the lantern being thrown on LMB. The click itself remains visible in `mButtonFrameFire`. See [Hanging the Lantern on LMB](#hanging-the-lantern-on-lmb).

### Velocity Vector Conversion via GameVecToPhysicsVec for Scripted Throw

In vanilla scripts (e.g., `data/scripts/items/potion_glass_break.lua`), the engine function `GameVecToPhysicsVec(vx, vy)` is used before passing a velocity vector to Box2D, and `PhysicsBodyComponent` has a built-in `initial_velocity` field.

- **What to test**: For a custom throw, set initial velocity via `ComponentSetValue2(phys_comp, "initial_velocity", p_vx, p_vy)` or `GameVecToPhysicsVec` before enabling `PhysicsBodyComponent`; perform disabling of `enabled_in_hand` strictly **before** enabling `enabled_in_world` with explicit re-activation of `LightComponent` and `SpriteAnimatorComponent`.
- **Expectation**: Preservation of light after throw and closer adherence of the initial velocity vector to the Box2D physics scale.

## Hanging the Lantern on LMB

Instead of blocking LMB (version 0.3), the left button is given its own action: hang the lantern under the ceiling above the player as if it had just spawned. RMB retains the vanilla throw along the dotted line.

### Behavior

- Ceiling anchor is searched for strictly above the player: `RaytraceSurfaces(x, y, x, y - 16)` (`HANG_MAX_DISTANCE`).
- Ceiling found — the lantern disappears from the hands and hangs below the ceiling: mounted on a joint, swaying, detachable by kicking, and falling when the ceiling is destroyed (`lantern_anchor.lua`).
- No ceiling found — the lantern remains in hand (the vanilla throw cannot be stopped, so the lantern is returned to hand on the frame following the throw).
- Clicking while the inventory is open (`InventoryGuiComponent.mActive`) is ignored; dropping a lantern by dragging from inventory works as before.
- After hanging, the wand from the lowest quick inventory slot is equipped; if there are no wands, the item from the lowest slot is equipped.

### Implementation

`UpdateLanternHang()` in `files/scripts/lantern_hang.lua` is called from `OnWorldPreUpdate()`:

1. **[Confirmed by testing]** A click is detected via `mButtonFrameFire`: a 1-frame lag is permitted, and the last processed frame is cached so each click triggers only once. The vanilla throw only starts after the throw animation completes, allowing the hanging logic to run first so there is nothing left to throw.
2. A new joint cannot be created on an already-thrown body (`mRefreshed`, see [ceiling-anchors-and-kicking.md](ceiling-anchors-and-kicking.md)). Therefore, hanging is done via substitution:
   - `EntityLoad` of the same XML file (`EntityGetFilename`, or by `ItemComponent.ui_sprite` after world streaming) 4 px below the raycast hit point;
   - Copying all `VariableStorageComponent` instances by `name` (tier, modifier, fuel, extinguish state, liquid state, base description, and base illumination) and `DamageModelComponent.hp`;
   - `EnsureLanternTraits` (tier is already present, so no re-roll occurs), followed by `ExtinguishLantern` or an immediate `ApplyLanternIllumination`, because the copied `lantern_illumination_scale` does not match the XML values of the fresh components;
   - `EntityKill` of the held lantern; components with `script_death` are removed beforehand to avoid spilling burning oil.
3. **[Confirmed by testing]** After `EntityKill`, hands remain empty and nothing is selected in inventory. The next item is selected via `mActiveItem = item` and `mActualActiveItem = 0`: resetting `mActualActiveItem` forces the engine to re-equip `mActiveItem` (matching vanilla `perk_list.lua`).

When there is no ceiling, a vanilla LMB throw occurs and is handled by a fallback path:

1. A `LuaComponent` with `script_throw_item` (as in vanilla `safe_haven.xml`) calls `throw_item()` in `files/scripts/lantern_throw.lua`.
2. A throw is identified as originating from LMB if `mButtonFrameFire > mButtonFrameThrow` and the click occurred no more than 60 frames ago. If the inventory is open, the throw is left untouched.
3. The lantern ID is stored in the player's `VariableStorageComponent` named `pul_return_lantern_id`. On the next frame, `UpdateLanternHang()` returns the lantern via `GamePickUpInventoryItem` and equips it in hand without interfering with the engine mid-throw.
4. **[Confirmed by testing]** The throw animation and sound cannot be removed: the vanilla throw plays out in full.
5. **[Confirmed by testing]** After the throw, the engine automatically equips the first wand. If `mActualActiveItem = 0` is reset upon returning the lantern, the engine equips the lantern without unequipping the wand: the wand remains visible at the player's feet and does not rotate with the cursor. Therefore, only `mActiveItem` is modified when returning the lantern, allowing the engine to perform a standard switch from wand to lantern. Resetting `mActualActiveItem` is reserved exclusively for hanging, where the held lantern has been destroyed.

### In-Game Test Results

**[Confirmed by testing]**

- The lantern hangs under the ceiling and looks native. Kicking and falling when the ceiling is destroyed are handled by the same `lantern_anchor.lua` used for world-spawned lanterns.
- After hanging, the wand from the first quick inventory slot is equipped.
- Without a ceiling, the lantern returns to hand after LMB, and the wand does not get stuck at the player's feet; the throw animation and sound remain.
- RMB throws the lantern along the dotted line as before.
- Dropping a lantern by dragging it out of the open inventory leaves it in the world.
- An RMB throw within 60 frames of an LMB click is not mistakenly returned to hand.
