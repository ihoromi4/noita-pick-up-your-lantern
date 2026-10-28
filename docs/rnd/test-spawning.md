# Spawning Fixtures for In-Game Tests

[← Back to R&D Index](../rnd.md)

Many light fixtures spawn only in a few biomes, often far from the start (for example, the mining lamp: `hills`, `winter`, `mountain_tree`, `lake`). To test a new pickable fixture quickly, the mod can spawn it at known ceiling points in the mountain hall, the entrance to the Mines, which every run passes in the first minute.

## Contents

- [Debug Spawner](#debug-spawner)
- [Spawn Rules](#spawn-rules)
- [Finding a Biome in the World](#finding-a-biome-in-the-world)
- [Finding Ceiling Points in a Pixel Scene](#finding-ceiling-points-in-a-pixel-scene)
- [Ceiling Points in the Mountain Hall](#ceiling-points-in-the-mountain-hall)

## Debug Spawner

`pick_up_your_lantern/files/scripts/debug_spawn_fixtures.lua` holds a `DEBUG_FIXTURES` list of `{ file, x, y }` entries. `init.lua` loads it and calls `UpdateDebugFixtureSpawns()` from `OnWorldPreUpdate`. Each spawn prints `[pick_up_your_lantern] DEBUG: spawned <file> at <x>, <y>` to the log.

> [!IMPORTANT]
> The spawner is a temporary test tool. Remove the script and its two lines in `init.lua` before merging a feature branch.

## Spawn Rules

- **[Confirmed]** Spawn a fixture only when the player is close (300 px) and the area is loaded, checked with `DoesWorldExistAt(x - 16, y - 16, x + 16, y + 16)`. Mining lamps spawned this way appear on the ceiling and work as usual.
- **[Needs verification]** A fixture spawned with `EntityLoad` into an area that is not loaded yet may get its `nail_to_wall` joint created with no ceiling to hold on to, and fall.
- **[Confirmed]** Spawn each fixture once per run: a `GlobalsSetValue("pul_debug_fixture_<index>", "1")` flag survives saving and reloading, and a new game starts without it.
- **[Confirmed]** Use the same offset from the spawn marker as the vanilla biome scripts do for that fixture (`spawn_lamp(x, y)` in `data/scripts/biomes/*.lua`). The offset differs between biomes and fixtures, for example:
  - the mining lamp is spawned at `y + 6` in `hills`, `winter` and `mountain_tree`, but at `x - 4, y` in `lake`;
  - lanterns in `coalmine` are spawned at `x, y`;
  - tube lamps in `snowcastle` are spawned at `x + 5, y` or `x, y`.
- Test both offsets when a fixture has several: the marker itself is the first air pixel under the ceiling, so a fixture spawned right at it may have its top inside the ceiling (see [Sprite Geometry and Positioning](sprite-geometry.md)).

## Finding a Biome in the World

The biome layout is `data/biome_impl/biome_map.png` (70×48 pixels); each pixel is a 512×512 px chunk of the world. The colors are listed in `data/biome/_biomes_all.xml`, which also sets `biome_offset_y="14"`.

- World X of a map pixel: `(px - 35) * 512`, where 35 is half of the map width.
- World Y of a map pixel: `(py - 14) * 512`.

For example, `mountain_hall` (color `ff204060`) is at world `x = 512, y = -512`. Its biome script `data/scripts/biomes/mountain/mountain_hall.lua` loads `hall.png` at the chunk origin and `hall_b.png` one chunk below (`x, y + 512`).

## Finding Ceiling Points in a Pixel Scene

A pixel scene PNG is a material map: each color is the `wang_color` of a material in `data/materials.xml`.

- `ff000042` is `air`.
- **[Needs verification]** Opaque white `ffffff` and transparent pixels are not scene materials: they keep what the biome generates, usually rock.

A good test point is an air pixel with solid pixels right above it (also 2 px to each side) and at least 24 px of air below it (also 3 px to each side), so the fixture hangs freely. A Python sketch, to be run with `python3 -I` from `noita/data/biome_impl/mountain/`:

```python
from PIL import Image

AIR = (0, 0, 66)

def FindCeilingPoints(path, origin_x, origin_y):
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    pixels = image.load()

    def IsAir(x, y):
        return 0 <= y < height and pixels[x, y] == AIR + (255,)

    for x in range(4, width - 4, 2):
        for y in range(1, height - 30):
            if (IsAir(x, y) and all(not IsAir(x + dx, y - 1) for dx in (-2, 0, 2))
                    and all(IsAir(x + dx, y + k) for k in range(24) for dx in (-3, 0, 3))):
                print(origin_x + x, origin_y + y)

FindCeilingPoints("hall.png", 512, -512)
FindCeilingPoints("hall_b.png", 512, 0)
```

## Ceiling Points in the Mountain Hall

Spawn markers (first air pixel under the ceiling) found this way, in world coordinates, and the space below them:

| Marker x, y | Air below | Pixel scene |
| --- | --- | --- |
| 542, -148 | 54 px | `hall.png` |
| 822, -167 | 86 px | `hall.png` |
| 850, -167 | 114 px | `hall.png` |
| 806, 24 | 41 px | `hall_b.png` |
| 828, 25 | 46 px | `hall_b.png` |
| 938, 56 | 28 px | `hall_b.png` |

**[Confirmed]** Mining lamps spawned at these markers (five at `y + 6`, one right at the marker) appear in the hall and work.
