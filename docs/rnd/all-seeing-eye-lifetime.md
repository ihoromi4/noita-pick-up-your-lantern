# All-Seeing Eye Projectile Lifetime

Question: Does the `lifetime` field of the All-Seeing Eye projectile include the lifetime that spell modifiers add, and how long does the projectile live?

Status: answered

Environment: build `17130612`, mod commit `0eb80aa`. Runs 1 and 2 used a sandbox mod alone. Run 3 used the sandbox mod together with the mod and temporary in-situ probes.

## Terms

- The **projectile lifetime** is the `lifetime` field of the `ProjectileComponent`. The vanilla projectile `data/entities/projectiles/deck/xray.xml` has `lifetime="1000"`.
- The **added lifetime** is `c.lifetime_add`, which spell modifiers change before the cast.
- The **reveal timer** is the number of frames that the reveal circle of the mod keeps its full strength before it starts to fade.

## Hypotheses

- H1, `lifetime` already includes the added lifetime when the mod first sees the projectile in `OnWorldPreUpdate`: confirmed.
- H2, `lifetime` counts down every frame, and `mStartingLifetime` keeps the value from the XML: confirmed. `mStartingLifetime` does not include the added lifetime.
- H3, the projectile lives for its whole lifetime, so a longer lifetime means a longer reveal in vanilla: refuted.

## Experiments

The sandbox mod spawned wands with fixed spells next to the player. A probe in `OnWorldPreUpdate` found each projectile by the file name `xray.xml`. It logged the active wand, `lifetime` and `mStartingLifetime` on the first sight, and the age of the projectile when it disappeared.

| Wand | `lifetime` on the first sight | `mStartingLifetime` | Age when gone |
| --- | --- | --- | --- |
| `X_RAY` | 999 | 1000 | 63 frames |
| `ZERO_DAMAGE`, `X_RAY` | 1279 | 1000 | 63 frames |
| `LIFETIME_DOWN`, `X_RAY` | 957 | 1000 | not logged |

- The projectile is first seen one frame after the cast, so `lifetime` is 1 lower than `1000 + c.lifetime_add`.
- Every projectile disappeared after 63 frames, whatever its lifetime. `MagicXRayComponent` most likely removes it after it has cleared the full radius: `radius="512"` divided by `steps_per_frame="8"` is 64 frames.
- A wand with `SHORTLIVED_SHOT` behaved like a wand with `X_RAY` alone. In vanilla `data/scripts/gun/gun_actions.lua`, the `SHORTLIVED_SHOT` action is inside a `--[[ ... ]]--` comment, so the spell does not exist in the game.

Run 3 checked the fix with temporary probes in `all_seeing_eye.lua`. They logged the reveal timer at the start of each circle, the frame when the fading started, and the frame when the circle ended.

| Wand | Reveal timer | Full strength | Fading |
| --- | --- | --- | --- |
| `X_RAY` | 600 | 600 frames | 600 frames |
| `ZERO_DAMAGE`, `X_RAY` | 2000 | 2000 frames | 600 frames |
| `LIFETIME_DOWN`, `X_RAY` | 390 | 390 frames | 600 frames |

## Conclusion

- In vanilla, lifetime modifiers do not change how long the All-Seeing Eye reveals the area, because the projectile is gone after about 64 frames. The link between the lifetime and the reveal timer is a new mechanic of the mod.
- The added lifetime is `lifetime + 1 - mStartingLifetime` on the first sight of the projectile.
- The reveal timer must live in the script, not in the projectile.
- Open question: the run did not test a repeated cast while a circle was still active.
