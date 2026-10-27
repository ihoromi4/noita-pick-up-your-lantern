# Natural Fear: Creatures Avoid Lantern Light

[← Back to R&D Index](../rnd.md)

Research on the light avoidance part of the [Natural Fear](../versions/version-0.3.md#natural-fear-mode) mode: creatures that lanterns do not attract keep out of lantern light. The attraction part (Hiisi and insects) is described in [Fire Enemies](fire-enemies.md#attraction-to-lanterns).

- [Requirements](#requirements)
- [Vanilla Burning and AI States](#vanilla-burning-and-ai-states)
  - [AI States](#ai-states)
  - [Burning](#burning)
  - [AI Fields Writable from Lua](#ai-fields-writable-from-lua)
- [Approach](#approach)
- [Design](#design)
- [Constants](#constants)
- [In-Game Findings](#in-game-findings)
- [Current Status and Next Steps](#current-status-and-next-steps)
- [Open Questions](#open-questions)
- [Implementation](#implementation)

## Requirements

- With `Natural Fear` on, every enemy that lanterns do not attract fears lantern light: zombies, slime creatures such as Limanuljaska (`slimeshooter.xml`, herd `slimes`), and other monsters.
- Lanterns in the world (hanging, thrown or lying, vanilla hanging lanterns too) and the lantern in the player's hands scare them. Light spell projectiles and the belt lantern do not.
- Fear beats hunting: a hunting enemy stays out of the light too, so ranged enemies attack from the edge of the darkness, and melee enemies do not come to a player with a lantern in hand.
- Once the light is gone, the enemies go back to their usual behaviour.

## Vanilla Burning and AI States

Burning enemies change their behaviour and run around. The user asked whether this mechanism can serve the fear of light.

### AI States

`AnimalAIComponent.ai_state` by index. Source: the AI debug display of GKBRKN (workshop 1975079109, `files/gkbrkn/gui/update.lua`). The table matches our logs: 1 for idle walking, 18 before the camera comes close (`JobDefault` idles until then), 21 for going home.

| `ai_state` | Name | `ai_state` | Name |
| --- | --- | --- | --- |
| 1 | RandomMove | 12 | EscapingPrey |
| 2 | Wandering | 13 | AttackingMelee |
| 3 | Eating | 14 | AttackingMeleeDash |
| 4 | RaisingHead | 15 | AttackingRanged |
| 5 | PreparingJump | 16 | AttackingRangedMulti |
| 6 | MoveNearTarget | 17 | Escaping |
| 7 | Peeing | 18 | JobDefault |
| 8 | Defecating | 19 | JobGoto |
| 9 | Alert | 20 | JobHelpOtherEntity |
| 10 | Landing | 21 | GoNearHome |
| 11 | TakingFireDamage | | |

The game binary (`noita.exe`, `strings`) holds the path finding logics behind the states: `PathFindingLogic_Burning`, `_Escaping`, `_EscapingPrey`, `_Goto`, `_MoveNearTarget`, `_RandomMove`, `_Charmed`, `_Default`, `_None`.

### Burning

- `data/entities/misc/effect_on_fire.xml` is a child entity with `GameEffectComponent effect="ON_FIRE"` (100 frames), fire and smoke particles and sound. It has no AI logic.
- `DamageModelComponent` keeps the fire state: `is_on_fire`, `mIsOnFire`, `mFireFramesLeft`, `mFireDurationFrames`, `fire_probability_of_ignition`, `fire_damage_amount`.
- The reaction is hard-coded: `AnimalAIComponent` listens to `Message_DamageReceived`, and fire damage puts the AI into state 11 (`TakingFireDamage`) with `PathFindingLogic_Burning`. The `preferred_job` documentation says so: "We always do this job, unless interrupted (i.e. by taking fire damage)".
- So the burning panic is triggered only by fire damage, not by a component or a tag. The chosen approach deals a tiny fire damage on purpose (see [Approach](#approach)).

### AI Fields Writable from Lua

- `ai_state` and `ai_state_timer` ("If not 0, then we wait till this frame to pop current state from our state stack"). D2DContentPack (workshop 3559987358) tried to set them for charmed creatures (commented out in its code).
- `mGreatestThreat` and `mGreatestPrey`: the entities the AI runs from and hunts.
- `preferred_job`: vanilla uses `JobDefault`, `Escaping` (deer, sheep and elk run from threats) and `JobHelpOtherEntity`. Rabies (workshop 2483422875) changes it at runtime.
- `escape_if_damaged_probability`: the chance of a walking enemy to run when damaged.

## Approach

Three options were tried:

- **Dark home (rejected).** Like the attraction: the AI home (`mHomePosition`) moves to the nearest dark point, with a leash. In game, zombies stood still and reacted to nothing (first test, see [In-Game Findings](#in-game-findings)).
- **Escaping state set from Lua (rejected).** The light source becomes `mGreatestThreat`, and `ai_state` is set to 17 (`Escaping`) with `ai_state_timer`. In game, every scared enemy stood still in state 17 for the whole session (second test): a state written from Lua does not start its path finding logic.
- **Light burns (chosen, experiment).** Lantern light deals a tiny fire damage (`EntityInflictDamage`, `DAMAGE_FIRE`) to a fearful enemy in it, every 30 frames. The AI reacts as to burning (state 11, `TakingFireDamage`, `PathFindingLogic_Burning`) and runs around by its own path finding. Nothing in the AI is written, so nothing can freeze or needs to be restored. The idea came from the research of vanilla burning, asked for by the user.
- `preferred_job = "Escaping"` for the time of fear was not chosen: the enemy would stop attacking, like a deer, while ranged enemies should shoot from the dark.

## Design

`files/scripts/lantern_fear.lua`, every 30 frames, 5 frames after the attraction updates (`UPDATE_FRAME_OFFSET`).

- **Fearful enemies**: root entities with the `enemy` tag that the fire enemy glow has checked (`pul_fire_glow_checked`) and that lanterns never attract, whatever the options: without the `pul_fire_enemy` tag and with a herd other than `orcs` and `fly`. Bosses, a polymorphed player and charmed enemies are skipped. The glow check is required: in the second test, Liekkiö (`fireskull`) far from the camera was scared, as the glow scan (512 px around the camera) had not tagged it as a fire enemy yet. So the fear also works only near the camera.
- **Fear lights**: entities with the `lantern` tag and an enabled `LightComponent` with the `pul_light_source` tag that are their own root entity (in the world) or the held item of their root entity (in hand, `GetHeldItem`). A carried lantern that is not in hand (inventory, belt) does not scare, whatever the state of its light; the belt lantern and the light of the player have no `lantern` tag, and an extinguished lantern has no enabled light. The fear radius is the lit area, 0.6 of the current light radius (`LIT_RADIUS_FACTOR`, the same share as in [Enemy Study](enemy-study.md)): `LightComponent.radius` is the outer edge of a soft light, and the visibly lit area is smaller. It is scaled by `FEAR_RADIUS_SCALE` (0.6, tuned by feel after the sixth test), so the fear radius is 0.36 of the light radius.
- **Line of sight**: an enemy is lit only by a lantern it sees (`RaytraceSurfaces` from its hitbox centre, stopping `SIGHT_MARGIN` 10 px before the lantern, as in the attraction). Light does not pass through walls.
- **Scorch**: a fearful enemy whose hitbox centre is in a fear light, every 30 frames:
  - takes `LIGHT_BURN_DAMAGE` (0.000001) of fire damage with no responsible entity, no ragdoll effect and no impulse, which starts the burning panic. The damage adds up: 0.001 killed weak zombies (0.2) in a few minutes in the third test;
  - is pushed away from the light that lights it the most (`FEAR_PUSH_SPEED` 60 added to `CharacterDataComponent.mVelocity`; walking enemies only along X). The burning panic alone ran in place and drifted out of the light slowly, which the player could not explain;
  - shows the look of fear while it is scorched: `files/entities/lantern_fear_effect.xml`, the sprite particles of the Confusion status effect (`data/particles/shine_confusion.xml`, as in vanilla `effect_confusion.xml`) without its `GameEffectComponent effect="CONFUSION"`. It is a child entity (`pul_lantern_fear_effect` tag) attached once the enemy is scorched (the enemy gets the `pul_lantern_scared` tag) and killed once it is out of the light, flies into a rage, is charmed, or the option is off. Scared enemies are evaluated even outside the light to lose the look. Smoke particles on every scorch were used before and removed at the user's request.
- Fear beats hunting: the damage interrupts any job, as burning does.
- **Rage** (Markov process, the idea of the user): on every update, an enemy in the light flies into a rage with `RAGE_ENTER_CHANCE` (5%, about 10 seconds in the light on average) instead of being scorched, and an enraged enemy calms down with `RAGE_LEAVE_CHANCE` (10%, about 5 seconds).
  - The target is the root entity of the light: the lantern in the world, or the player who holds the lantern. It is kept in a `VariableStorageComponent` named `pul_lantern_rage_target` (`value_int`), and the enemy gets the `pul_lantern_enraged` tag.
  - On every update, the target is set again as `mGreatestPrey` (Goki's Things sets the player this way), as the AI may pick other prey on its own. An enraged enemy is not scorched.
  - The rage has the look of the Berserk status effect: `files/entities/lantern_rage_effect.xml` is based on `data/entities/particles/berserk.xml` (Berserk sprite particles inside the hitbox and a dim blue light), as vanilla `effect_berserk.xml` is, but without its `GameEffectComponent effect="BERSERK"`, so the enemy does not attack everyone around. It is added as a child entity (`pul_lantern_rage_effect` tag) and killed when the rage passes. Red sparks were used before and replaced at the user's request.
  - The rage ends by chance, when the target is gone (a broken lantern, a dead player), when the enemy is charmed, or when the option is off. A lantern target stops being the prey; a player target stays, as the enemy would hunt them anyway.
  - Enraged enemies are evaluated even outside the light, so they calm down in time.
  - The rage turns fear into a risk: lanterns in the world, vanilla hanging lanterns too, can be broken by enemies, and the darkness spreads.
- Enemies immune to fire (`fire="0"` damage multiplier: ghosts, robots and others) take no damage and do not react.
- The shared helpers (lured groups, excluded enemies, settings, hitbox centre) are in `files/scripts/enemy_ai_home.lua`, a module shared with the attraction (see [Fire Enemies](fire-enemies.md#implementation)).

## Constants

| Constant | Value | Meaning |
| --- | --- | --- |
| `LIT_RADIUS_FACTOR` | 0.6 | Share of the light radius that looks lit |
| `FEAR_RADIUS_SCALE` | 0.6 | Scale of the lit area that scares (fear radius 0.36 of the light radius) |
| `SIGHT_MARGIN` | 10 px | The line of sight stops this far before the lantern |
| `LIGHT_BURN_DAMAGE` | 0.000001 | Fire damage per update (1 is 25 HP) |
| `FEAR_PUSH_SPEED` | 60 | Speed added away from the light per update |
| `RAGE_ENTER_CHANCE` | 0.05 | Chance per update of an enemy in the light to fly into a rage |
| `RAGE_LEAVE_CHANCE` | 0.1 | Chance per update of an enraged enemy to calm down |
| `UPDATE_INTERVAL_FRAMES` | 30 | Burn interval |
| `UPDATE_FRAME_OFFSET` | 5 | Frame offset from the attraction updates |

## In-Game Findings

Eighth step, 2026-10-27: the user asked for a look of the scared enemies. Vanilla has no Scared status: no such game effect in the engine (`noita.exe` has ON_FIRE, BERSERK, CHARM, CONFUSION, WEAKNESS and others), and the `scared.png` status icon belongs to the Weakened status (`effect_weaken.xml`: resistances and protective perks off, shown in the HUD only). The `mScared` field belongs to `AdvancedFishAIComponent` (fish flee predators). The user chose the particles of Confusion.

Seventh test, 2026-10-27, with the rage and `FEAR_RADIUS_SCALE` 0.6: works well overall. The user asked to remove the smoke of the scorch and the red sparks of the rage, and to give the rage a look like the Berserk status effect.

Sixth test, 2026-10-27, with the smaller radius and the line of sight: the user found it better, even fun to play. Next request: a Markov chain of decisions, so that enemies now and then fly into a rage and attack the lantern they fear (see Rage in [Design](#design)).

Fifth test, 2026-10-27, with only lanterns in the world or in hand: enemies were still scared all the time. In the log, 1251 of 1440 samples were lit by lanterns in the world, 159 by the lantern in the player's hand. Two causes:

- **The radius was too large**: one lantern (488) lit enemies over x 533 to 865. Fixed with a factor of 0.6 (`LIT_RADIUS_FACTOR`).
- **Light passed through walls**: `zombie_weak` 510 was lit by 12 different lanterns at heights from 262 to 580, vanilla hanging lanterns of nearby caves. Fixed with the line of sight check.

Fourth test, 2026-10-27, scorch version (0.000001 damage, push, smoke):

- **The tiny damage works**: 5352 samples of lit enemies, all in state 11 (`TakingFireDamage`); `hp` stays at its start value up to the 4th digit (e.g. `zombie_weak` 0.1996). Unlit enemies are mostly back in other states (18, 0), a few still in 11 shortly after the light.
- **Enemies kept running near the player** even without a lantern in hand. The user: enemies must not fear the light of the player itself or the belt lantern. Both have no `lantern` tag, so the cause is not proven; a carried lantern in the inventory is the most likely suspect. Fixed by counting a carried lantern only while it is held (see [Design](#design)). The diagnostics now print which lantern lights an enemy and its carrier (`world` or the carrier name). **[Needs verification]**.

Third test, 2026-10-27, light burn version with 0.001 damage. The user: enemies do leave the light, but:

- **They run in place and drift out of the light slowly**, which looks odd, and the player cannot tell why. Hence the push away from the light and the smoke.
- **They seem scared all the time, even far from light.** In the log, every sample of a fearful enemy was lit and in state 11 (`TakingFireDamage`, 3264 of 3264): vanilla hanging lanterns light many spawn places. Most likely the low health made it worse (next point): an enemy near death behaves as a fleeing one. **[Needs verification]** with the tiny damage; the diagnostics now also print enemies up to 2 light radii away, to see them calm down.
- **They lost health ("-1").** The damage adds up: `zombie_weak` went from `hp` 0.199 to 0 in about 200 scorches, `longleg` from 0.109 to 0, `fungus` from 2.56 to 0. Fixed with a 1000 times smaller damage.

Second test, 2026-10-27, Escaping state version (`[pul_fear]` lines in `logger.txt`): all 49 scared enemies (`zombie_weak`, `longleg`, `slimeshooter_weak`, `acidshooter_weak`) stood at the same pixel for the whole session, from frame 65 to 7985, in state 17 with the lantern as `mGreatestThreat`. The state set from Lua holds, but the escape never starts. Most were scared by vanilla hanging lanterns right after spawning and were still idle (`JobDefault`, 18) before that. Two `fireskull` were scared too (see the glow check in [Design](#design)).

First test, 2026-10-27, dark home version: zombies stood still and reacted to nothing. No errors in the log, no diagnostics. Most likely the same freeze in state 21 (`GoNearHome`) as walking Hiisi had with a far home (see [Fire Enemies](fire-enemies.md#in-game-findings)), made worse by hunting: the hunting AI tries to reach the player while the leash holds it at the dark home.

## Current Status and Next Steps

Work state at the end of 2026-10-27: the user found the scorch, the rage and their looks to work well enough.

- **Ready to commit**: the whole light avoidance (`lantern_fear.lua`, the fear and rage looks, `enemy_ai_home.lua`, the attraction refactoring, `FIRE_GLOW_CHECKED_TAG`, texts, docs). The temporary diagnostics (`[pul_fear]` lines in `logger.txt`) are removed; to debug again, print the enemy position, the lantern that lights it, the rage tag, `ai_state`, `mGreatestPrey` and `hp` every 60 frames.
- Enemies without an `AnimalAIComponent` are left alone: the panic and the rage are its reactions.
- Commit message: `feat: make Natural Fear creatures fear lantern light`.

Next steps:

1. Tune `FEAR_RADIUS_SCALE`, `FEAR_PUSH_SPEED`, `RAGE_ENTER_CHANCE` and `RAGE_LEAVE_CHANCE` by feel. The rage lasts about 5 seconds on average (median 3.3 s), and an enemy that spends 1 to 2 seconds in the light flies into a rage with a chance of about 10 to 19%.

## Open Questions

- 0.000001 of fire damage is enough to start the `TakingFireDamage` state (fourth test).
- **[Needs verification]** How long state 11 lasts after the last scorch.
- Enraged enemies attack and break lanterns set as `mGreatestPrey` (the user saw several lanterns broken). **[Needs verification]** whether ranged enemies shoot at them too.
- **[Needs verification]** Where `PathFindingLogic_Burning` leads: away from the damage, to water, or at random.
- **[Needs verification]** Whether the damage makes the enemy hostile to the player or plays a hurt sound and blood, and whether that looks odd.
- **[Needs verification]** Whether enemies around vanilla hanging lanterns panic right after spawning, and whether that makes levels too easy.

## Implementation

| File | Role |
| --- | --- |
| `files/scripts/lantern_fear.lua` | Fear lights, fearful enemies, scorch, rage. `UpdateLanternFear()` is called from `OnWorldPreUpdate` |
| `files/entities/lantern_fear_effect.xml` | Look of fear: Confusion particles without the Confusion effect |
| `files/entities/lantern_rage_effect.xml` | Look of the rage: Berserk particles without the Berserk effect |
| `files/scripts/enemy_ai_home.lua` | Helpers shared with the attraction: lured groups, excluded enemies, settings, hitbox centre |
| `files/scripts/utils.lua` | `FIRE_GLOW_CHECKED_TAG`, shared with the fire enemy glow |
| `settings.lua`, `files/translations.csv` | The `natural_fear` description mentions the fear |
