# Settings

All options of the mod are in **Options → Mod Settings → Pick Up Your Lantern**. Options marked "new game" take effect only after you start a new game. The others apply immediately.

## Contents

- [Preset](#preset)
- [Lighting](#lighting)
- [Gameplay](#gameplay)
- [Enemy Study](#enemy-study)

## Preset

The first option sets all other options at once, except the options marked "not affected by presets". Pick the one that matches how dark you want the game to be:

| Option | Light Touch | Atmospheric | Survival | Pitch Black |
|---|---|---|---|---|
| Illuminate the Darkness | on | on | on | on |
| Illuminated Area Size | Standard (100%) | Standard (100%) | Standard (100%) | Standard (100%) |
| Belt Lantern Light | Moderate (50%) | Moderate (50%) | Faint (25%) | Faint (25%) |
| Player Vision | Vanilla (100%) | Dark (50%) | Minimal (10%) | Pitch Black (0%) |
| Polymorphed Vision | Same as player | Same as player | Same as player | Same as player |
| Show Lanterns on Item Radar | off | off | off | off |
| Lantern Progression | off | on | on | on |

- Light Touch keeps the game close to vanilla: you can carry lanterns, but you see as usual and all lanterns are ordinary.
- If you change any option by hand, the preset shows `Custom`. If your options match a preset again, its name comes back.
- Left click picks the next preset, right click goes back to Light Touch.
- Default: Light Touch.
- Applies: immediately. New-game options of the preset, such as Lantern Progression, apply when you start a new game.

## Lighting

### Illuminate the Darkness

Lanterns and other light sources clear the fog of war around them, both in the world and in your hand.

- Default: on.
- Applies: new game.

### Illuminated Area Size

How far the light of lanterns and other light sources reaches, and how much fog of war they clear.

- Values: Standard (100%), Expanded (200%), Huge (300%), Massive (500%).
- Default: Standard (100%).
- Applies: immediately for lanterns; other light sources after restarting the game.

### Belt Lantern Light

How bright the lantern on your belt is, compared with holding it in hand. See [Lantern on Your Belt](lanterns.md#lantern-on-your-belt).

- Values: Off (0%), Faint (25%), Moderate (50%), Bright (75%), Full (100%).
- Default: Moderate (50%).
- Applies: immediately.

### Player Vision

How far you see in dark biomes without a lantern. See [Limited Vision](vision-and-darkness.md#limited-vision).

- Values: Vanilla (100%), Dim (75%), Dark (50%), Very Dark (25%), Minimal (10%), Pitch Black (0%).
- Default: Vanilla (100%).
- Applies: immediately.

### Polymorphed Vision

How far you see while polymorphed into another creature. See [Polymorph](vision-and-darkness.md#polymorph).

- Values: Same as player, then the same presets as Player Vision.
- Default: Same as player.
- Applies: immediately.

## Gameplay

### Show Lanterns on Item Radar

Lets the Item Radar perk point to nearby lanterns. Off by default, so the radar keeps pointing to items you actually look for.

- Default: off.
- Applies: immediately.

### Lantern Progression

Lanterns spawn with a quality from dim to masterwork, and rarely with modifiers. See [Lantern Quality and States](lantern-quality-and-states.md). When off, all lanterns are ordinary.

- Default: off (Light Touch preset). On in all other presets.
- Applies: new game.

### Lanterns Attract Fire Enemies

Fire creatures, such as Stendari and Liekkiö, that see a lit lantern in the world gather around it, like moths to a flame. Spellbound by the light, they notice you only up close and wake up when hurt. Lanterns in your hands, inventory or on your belt do not attract them.

- Default: on.
- Applies: immediately.
- Not affected by presets.

### Natural Fear

Creatures react to lantern light by their nature. Hiisi and insects that see a lit lantern in the world gather around it, the same way fire creatures do. Spellbound by the light, they notice you only up close and wake up when hurt. Other creatures, such as zombies and Limanuljaska, fear lantern light, even of the lantern in your hands, and keep to the dark.

- Default: off.
- Applies: immediately.
- Not affected by presets.

## Enemy Study

Watch enemies in lantern light to deal more damage to them. See [Studying Enemies](lanterns.md#studying-enemies). Presets do not change the options in this category.

### Enemy Study

Turns studying enemies on or off. When it is off, enemies you studied earlier take normal damage.

- Default: off.
- Applies: immediately.
- Not affected by presets.

### Studied Enemy Damage Bonus

How much more damage you deal to a fully studied enemy. A partly studied enemy gets a part of this bonus.

- Values: +10%, +25%, +50%, +100%.
- Default: +25%.
- Applies: immediately, also to enemies studied earlier.
- Not affected by presets.

### Base Study Time

How long it takes to study an enemy of a type you know nothing about. Studying enemies of a type and its relatives shortens this time, down to half a second. Bosses always take two minutes.

- Values: 3 s, 5 s, 10 s, 30 s.
- Default: 10 s.
- Applies: immediately.
- Not affected by presets.
