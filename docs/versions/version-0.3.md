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

## Fire Enemies Lighting Rework

- [ ] Make fire-related enemies glow noticeably brighter than other enemies so they stand out in darkness.
- [ ] Cover vanilla fire enemies: Fire Mage (Stendari), Fire Spirit (Liekkiö), Hell Spitter (Helvetin sylkijä), Hell Gazer (Helvetinkatse), Hellfire Mage (Eldari), perhaps some others.
- [ ] Implement a procedural patch that automatically detects similar fire-related enemies added by other mods and applies the same lighting enhancements.

## Natural Fear Mode

- [ ] Mod settings toggle where wild beast and animal enemy categories (`herd_id`) actively avoid lantern light and maintain distance from the player.
