# Version 0.4

Tracking document for features, implementation progress, and known issues for **Version 0.4**. Functional requirements are defined in [requirements.md](../requirements.md) and milestone planning in [roadmap.md](../roadmap.md). Previous milestone progress is tracked in [version-0.3.md](version-0.3.md).

## Temple Lantern Modifiers

- [ ] Magic liquid modifier for the temple lantern (`physics/temple_lantern.xml`): with a small chance, a temple lantern is filled with a magic liquid instead of plasma.
- [ ] A lantern with this modifier gives no light.
- [ ] When it breaks, it spills one of the magic liquids instead of `plasma_fading`:
  - Concentrated Mana (`magic_liquid_mana_regeneration`);
  - Flummoxium (`material_confusion`);
  - Unstable Teleportatium (`magic_liquid_unstable_teleportation`).
