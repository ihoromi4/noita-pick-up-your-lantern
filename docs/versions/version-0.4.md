# Version 0.4

Tracking document for features, implementation progress, and known issues for **Version 0.4**. Functional requirements are defined in [requirements.md](../requirements.md) and milestone planning in [roadmap.md](../roadmap.md). Previous milestone progress is tracked in [version-0.3.1.md](version-0.3.1.md).

## Cleanup

- [ ] Remove the temporary leaked component cleanup that was added in version 0.3.1. In version 0.3, every lit lantern with a modifier got a new empty `LuaComponent` on each illumination update. The cleanup removes these components from lanterns in saves made with version 0.3. To remove it, delete `files/scripts/leaked_component_cleanup.lua` and the two lines that load and call it in `init.lua`.

## Temple Lantern Modifiers

- [ ] Magic liquid modifier for the temple lantern (`physics/temple_lantern.xml`): with a small chance, a temple lantern is filled with a magic liquid instead of plasma.
- [ ] A lantern with this modifier gives no light.
- [ ] When it breaks, it spills one of the magic liquids instead of `plasma_fading`:
  - Concentrated Mana (`magic_liquid_mana_regeneration`);
  - Flummoxium (`material_confusion`);
  - Unstable Teleportatium (`magic_liquid_unstable_teleportation`).

## Visual Polish and UI

- [ ] Custom UI icons redesign: create dedicated pixel-art icons visually matching physical lantern props (`ui_lantern.png`, `ui_lantern_small.png`) with clear illumination.

## Open-Flame Variants

- [ ] Implement open-flame torches and braziers that actively ignite flammable materials, gases, and enemies on contact while held.
- [ ] Immediate extinguishing upon liquid contact (without a delay).

## Rogue Mode

- [ ] A Mod Settings toggle that makes the player invisible to enemies while they stay far from light.
- [ ] Investigate whether the player's visibility can be set per enemy type (e.g., zombies see in the dark, Hiisi do not).
