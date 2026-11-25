# Version 0.4.0

Tracking document for completed work in **Version 0.4.0**. All releases are listed in [Versions](README.md). Previous milestone progress is tracked in [version-0.3.2.md](version-0.3.2.md).

## Completed Work

### Snowy Biome Diffused Air Light

- Added faint bluish diffused ambient light to open air in Snowy Depths (`$biome_snowcave`) and Hiisi Base (`$biome_snowcastle`) when limited vision is active. Solid terrain stays dark inside, while distant walls and enemies appear as soft, dark silhouettes smeared with morphological erosion-dilation in `post_final.frag`. The glow fades smoothly across biome borders and does not affect areas lit by lanterns or the All-Seeing Eye. Details: [Vision and Darkness](../guides/vision-and-darkness.md#snowy-biomes) and [Vision and Lighting](../dev/vision-and-lighting.md#snowy-biome-diffused-air-light).

### Wet Lantern Drying and Liquid State Filtering

- Held wet oil lanterns now dry and lose the wet state with a puff of steam when the player catches fire, submerges in a hot liquid (`liquid_fire`, `lava`, or molten materials), or stands in a hot biome (any biome with the `HOT` modifier, plus Desert, Pyramid, and Lava Lake).
- Limited liquid states (`oil-soaked`, `wet`) and drying to oil lanterns (`Lantern`, `Small Lantern`, and `Mining Lamp`), excluding tube lamps, temple lanterns, and chain torches. Magical lanterns (`Temple Lantern`) and powered hermetic lamps (`Tube Lamp`) remain fully lit underwater, while closed oil lanterns stay lit and only dim with the `wet` state. Details: [Lantern Quality and States](../guides/lantern-quality-and-states.md#oil-and-water) and [Lantern Properties and Progression](../dev/lantern-properties-and-progression.md#liquid-states).

### Chain Torch Submersion Timer and Sounds

- Added a 1-second submersion timer for open-fire lanterns (chain torches) in water and other liquids. While submerged, a torch hisses with a looping sound and emits real `fire` cells so the engine runs the native reaction for each liquid (such as turning water into `steam`, turning slime into `cloud_slime`, or igniting oil and alcohol). Leaving the liquid stops the hissing and resets the timer, while `lava` and `liquid_fire` never douse a torch and relight a doused one. Dousing and relighting play vanilla extinguish and ignite sounds. Details: [Lanterns](../guides/lanterns.md#chain-torches) and [Lantern Entities](../dev/lantern-entities.md#chain-torches).

### Visibility API and Enemy Study Migration

- Moved the **Enemy Study** mechanic, its settings, markers, and documentation to the **In Game Wiki** mod. Exported `files/scripts/visibility_api.lua` (`IsPointVisible`, `IsEntityVisible`, `GetLitAreas`) calibrated at `0.35` of the light radius, covering lanterns in the world, in hand, on the player's belt (at its reduced `belt_light_scale` radius), and projectiles with the Light spell modifier. Details: [Creatures and Light](../dev/creatures-and-light.md#visibility-api).

### Natural Fear Creature Filtering

- Excluded robots and fire-immune creatures from Natural Fear reactions so they neither fear lantern light nor gather around lanterns (fire-related robots such as flamethrower robots remain lured when fire enemy attraction is enabled).
- Included the `healer` herd in Natural Fear attraction so organic support Hiisi (`scavenger_heal`, `scavenger_invis`, `scavenger_shield`) and cowards (`coward`) gather around lanterns while healer drones (`healerdrone_physics`) and Hiisi machines (`tank`, `turret`) are filtered out as robots. Details: [Lanterns](../guides/lanterns.md#scaring-creatures) and [Creatures and Light](../dev/creatures-and-light.md#natural-fear).
