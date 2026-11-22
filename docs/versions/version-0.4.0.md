# Version 0.4.0

Tracking document for completed work in **Version 0.4.0**. All releases are listed in [Versions](README.md). Previous milestone progress is tracked in [version-0.3.2.md](version-0.3.2.md).

## Completed Work

### Snowy Biome Diffused Air Light

- [x] Added faint bluish diffused ambient light to open air in Snowy Depths (`$biome_snowcave`) and Hiisi Base (`$biome_snowcastle`) when limited vision is active. Solid terrain stays dark inside, while distant walls and enemies appear as soft, dark silhouettes smeared with morphological erosion-dilation in `post_final.frag`. The glow fades smoothly across biome borders and does not affect areas lit by lanterns or the All-Seeing Eye. Details: [Vision and Darkness](../guides/vision-and-darkness.md#snowy-biomes) and [Vision and Lighting](../dev/vision-and-lighting.md#snowy-biome-diffused-air-light).
