# Version 0.3 - Variety and World Interactions

Tracking document for features, implementation progress, and known issues for **Version 0.3**. Functional requirements are defined in [requirements.md](../requirements.md) and milestone planning in [roadmap.md](../roadmap.md). Previous milestone progress is tracked in [version-0.2.md](version-0.2.md).

## Visual Polish and UI

- [ ] Custom UI icons redesign: create dedicated pixel-art icons visually matching physical lantern props (`ui_lantern.png`, `ui_lantern_small.png`) with clear illumination.

## Extended Light Fixture Support

- [ ] Support hanging chain torches (`chain_torch.xml`, `chain_torch_blue.xml`, `chain_torch_ghostly.xml`).
- [ ] Support mining lamps (`physics_mining_lamp.xml`) and temple lanterns (`temple_lantern.xml`).
- [ ] Support fluorescent tube lamps (`physics_tubelamp.xml`) and Hiisi Base fixtures.

## Open-Flame Variants

- [ ] Implement open-flame torches and braziers that actively ignite flammable materials, gases, and enemies on contact while held.
- [ ] Immediate extinguishing upon liquid contact (without a delay).

## Strategic World Incentives

- [ ] Implement gameplay incentives for leaving light fixtures hanging in the world (e.g., safe illumination zones, stations to reignite unlit lanterns, enemy debuff zones, or fog of war landmarks).
- [ ] Counteract the tendency to treat lanterns purely as disposable weapons.
- [x] Hang a held lantern on the ceiling above the player (up to 16 px) with LMB, then take the first wand (or the first item) from the Quick Inventory in hand; without a ceiling the lantern stays in hand. RMB keeps the vanilla throw. Details: [throwing-mechanics-and-controls.md](../rnd/throwing-mechanics-and-controls.md).

## Lantern Modifiers

- [x] Cracked glass modifier: a lantern that takes damage without breaking (e.g., a fall or a projectile hit) has a 33% chance to crack. A cracked lantern has a 50% chance every 20 frames to emit 2 particles of gaseous fire (`fire`), both in the world and in hand, so it can set the player on fire. Does not appear when lantern progression is disabled. Described by a sentence in the item description.
- [x] Keep the configuration of all lantern modifiers (IDs, description keys, roll chances and behaviour parameters) in a single file.
- [x] Allow a lantern to carry several modifiers at once; the modifier configuration defines how modifiers interact with each other (e.g., which ones are incompatible, replace or combine with each other).

## Settings Presets

- [x] Add a `Preset` option as the first entry in Mod Settings that sets all other options at once: Light Touch (default, minimal changes: vanilla vision, lantern progression off), Atmospheric (Dark 50% vision), Survival (Minimal 10% vision, 25% belt light) and Pitch Black (0% vision, 25% belt light). Lantern progression is on in every preset except Light Touch.
- [x] Changing any option by hand switches the preset to `Custom`; new-game options of a preset take effect in the next run.

## Fire Enemies Lighting Rework

- [ ] Make fire-related enemies glow noticeably brighter than other enemies so they stand out in darkness.
- [ ] Cover vanilla fire enemies: Fire Mage (Stendari), Fire Spirit (Liekkiö), Hell Spitter (Helvetin sylkijä), Hell Gazer (Helvetinkatse), Hellfire Mage (Eldari), perhaps some others.
- [ ] Implement a procedural patch that automatically detects similar fire-related enemies added by other mods and applies the same lighting enhancements.

## Natural Fear Mode

- [ ] Mod settings toggle where wild beast and animal enemy categories (`herd_id`) actively avoid lantern light and maintain distance from the player.
