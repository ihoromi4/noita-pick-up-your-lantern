# Sprite Geometry and Positioning

[← Back to R&D Index](../rnd.md)

- **[Confirmed]** The lantern spawn marker on biome maps (`spawn_lamp`, color `0xffffff00`) is placed in the first air pixel (`dy = 0`) immediately below solid ceiling pixels (`dy = -1, -2, -3`).
- **[Confirmed]** The sprites `lantern_small.png` and `lantern.png` have a size of `9x13` pixels, but different vertical fill:
  - In `lantern_small.png`, rows `y = 0..2` are fully transparent; at `y = 3` there is 1 eyelet pixel (`x = 4`), at `y = 4` is a cap 5 pixels wide (`x = 2..6`), and at `y = 5..10` is the main body.
  - In `lantern.png`, only row `y = 0` is transparent; at `y = 1` is the cap top 3 pixels wide (`x = 3..5`), and at `y = 2` is the cap rim 7 pixels wide (`x = 1..7`).
- **[Confirmed]** According to `component_documentation.txt`, if `centered="1"` is enabled in `PhysicsImageShapeComponent`, the engine automatically sets `offset_x = 4.5`, `offset_y = 6.5` and **overwrites (ignores)** any manually defined `offset_x` and `offset_y`.
- **[Confirmed]** With `centered="1"` (`offset_y = 6.5`), the top pixels of the small lantern (`y = 3..5`) end up at world coordinates `y - 3.5 .. y - 1.5`, physically embedded into the ceiling. This caused three issues:
  - The lantern appeared pulled 2–3 pixels higher into the ceiling than intended;
  - On wooden beams (e.g., at the entrance to the Mines), ceiling pixels modified the embedded lantern body upon spawn, causing it to fall immediately;
  - The lantern could not be knocked down with a kick because its top was wedged inside solid ceiling pixels.
- **[Confirmed]** Setting `centered="0"`, `offset_x="4.5"`, `offset_y="3.5"` in `PhysicsImageShapeComponent` and `offset_y="3.5"` in the world flame `SpriteComponent` positions the small lantern directly beneath the ceiling without clipping into it.
- **[Needs verification]** The large lantern (`physics_lantern.xml`) currently also sets `offset_y="3.5"` and `pos_y="1"`, but since in `lantern.png` the opaque cap pixels start at `y = 1` (2 pixels higher than in `lantern_small.png`), its position and flame height must be visually and physically verified in the `liquidcave` and `town` biomes.
