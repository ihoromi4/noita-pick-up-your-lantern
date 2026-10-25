# Fog of War Line-of-Sight and Shaders

[← Back to R&D Index](../rnd.md)

Investigation of the Fog of War and Lighting systems in Noita, along with an analysis of the feasibility of implementing Line-of-Sight fog clearance via shaders.

## Vanilla Fog of War and Lighting System

In Noita, map clearance and environmental lighting function as two distinct yet interconnected systems operating at the engine level and during final post-processing.

### Fog of War Grid

1. **Discrete World Grid**:
   - Map revelation state is stored in a low-resolution world grid, where each cell corresponds to approximately $32 \times 32$ world pixels (`FOG_PIXEL_SIZE = 32.0` in the `post_final.vert` shader).
   - Values range from $0$ (fully revealed) to $255$ (complete fog).
   - Fog state is saved into the world save data (`save00/world/`). For reading and writing at the C++ and Lua levels, several functions exist:
     - `GameGetFogOfWar(pos_x, pos_y)`
     - `GameGetFogOfWarBilinear(pos_x, pos_y)`
     - `GameSetFogOfWar(pos_x, pos_y, fog_of_war)`
2. **Clearance Components**:
   - `FogOfWarRadiusComponent`: processed by `FogOfWarRadiusSystem`. Has a `radius` field ($256$ by default, as noted in `component_documentation.txt`: *"256 is the default player has"*). As the entity moves, a circular area with a radius of $256$ pixels is permanently cleared in the world grid.
   - `FogOfWarRemoverComponent`: a component with a `radius` field ($140$ by default), used by projectiles or entities for localized fog removal.
   - `MagicXRayComponent`: a projectile component for the All-Seeing Eye spell (`X_RAY`, `data/entities/projectiles/deck/xray.xml`) with fields `radius="512"` and `steps_per_frame="8"`, which gradually clears the fog grid around the cast position.
   - `REMOVE_FOG_OF_WAR`: a systemic game effect (the All-Seeing Eye perk) that sets the internal flag `mFogOfWarOpenEverywhere` and disables fog entirely.
3. **Fog Texture (`tex_fog`)**:
   - The fog grid is rendered into the `tex_fog` texture ($64 \times 64$ in size relative to the current camera viewport).
   - The red channel (`.r`) stores the fog of war factor, while the green channel (`.g`) stores the underground dust amount (`dust_amount`).
4. **Temporary Fog Holes (`SpriteComponent`)**:
   - The `fog_of_war_hole="1"` attribute on `SpriteComponent` instructs the engine to render the sprite texture's alpha channel into the `tex_lights.a` buffer.
   - This allows dynamically "punching a hole" in the fog in the shader without modifying the permanent world grid:
     `fog_of_war_amount = fog_value.r * (1.0 - light_tex_sample.a);`

### Lighting Around the Player

1. **Point Light Source (`LightComponent`)**:
   - In the player entity file `data/entities/player_base.xml`, the component is defined as follows:

     ```xml
     <LightComponent
       r="255"
       g="255"
       b="255"
       radius="350"
       fade_out_time="5.0"
     ></LightComponent>
     ```

   - The player's light radius is $350$ pixels. The light is rendered into the `tex_lights.rgb` texture.
2. **Interaction in the Final Shader (`post_final.frag`)**:
   - Light is modulated by the fog of war:

     ```glsl
     lights *= fog_of_war;
     ```

   - If an area is still shrouded in fog (`fog_of_war == 0`), light cannot penetrate through it.
   - Lighting is applied to the foreground:

     ```glsl
     color_fg.rgb *= lights;
     ```

   - If fog is cleared but no light source is nearby, pixels remain dark due to the absence of light.

## Line-of-Sight Clearance via Shaders

Currently, fog clearance is purely circular: it ignores material geometry and reveals space through thick solid walls into adjacent caverns.

### 2D Screen-Space Raymarching Principle

To achieve a realistic Field of View / Line-of-Sight (similar to *Darkwood* or *Teleglitch*), per-pixel raymarching in screen space can be employed:

1. **Passing Light Source / Player Coordinates**:
   - In a Lua script (e.g. a per-frame hook or `OnWorldPreUpdate`), the player's screen coordinates $UV \in [0, 1]$ are computed from `EntityGetTransform` and `GameGetCameraPos`.
   - Coordinates are passed to the post-processing shader via the official Noita API function:

     ```lua
     ---Sets post processing shader uniform parameter.
     ---@param name string Parameter name.
     ---@param x number X value.
     ---@param y number Y value.
     ---@param z number Z value.
     ---@param w number W value.
     local function UpdateShaderPlayerPos(name, x, y, z, w)
         GameSetPostFxParameter(name, x, y, z, w)
     end
     ```

2. **Raymarching in `post_final.frag`**:
   - For each screen pixel, a ray vector is constructed from `player_screen_pos` to `tex_coord`:

     ```glsl
     vec2 ray_dir = tex_coord - player_screen_pos;
     float dist = length(ray_dir);
     ```

   - If the fragment lies beyond the maximum visibility radius, raymarching is skipped (early exit to save GPU cycles).
   - A fixed number of steps (e.g. $16$–$32$ samples) is taken along the segment:

     ```glsl
     float visibility = 1.0;
     const int STEPS = 24;
     for (int i = 1; i <= STEPS; ++i) {
         float t = float(i) / float(STEPS);
         vec2 sample_uv = player_screen_pos + ray_dir * t;
         vec4 fg_sample = texture2D(tex_fg, sample_uv);
         if (fg_sample.a > 0.1) {
             visibility = 0.0;
             break;
         }
     }
     ```

   - The resulting `visibility` coefficient is multiplied with `lights` and `fog_of_war`.

## Technical Challenges and Limitations

1. **GPU Performance**:
   - `post_final.frag` executes for every pixel on the screen. Adding $24$ texture samples per fragment creates substantial pressure on GPU memory bandwidth.
   - *Optimization approaches*:
     - Restricting sample steps outside the player's light radius.
     - Dithered raymarching: using fewer steps ($8$–$12$) with random offsets sampled from `tex_noise` to soften shadow edges.
2. **Foreground Texture Contents (`tex_fg`)**:
   - The `tex_fg` texture contains not only static walls, but also the player sprite itself, particles, gold drops, enemies, and liquids.
   - Without sample filtering:
     - The player's cape or body silhouette will block rays and cast a shadow across the entire opposite side (requires an initial radial `offset` from the player's center).
     - Liquids (water, blood) can be misinterpreted as solid walls. This can be partly addressed using the liquid mask stored in the alpha channel of `tex_glow_unfiltered.a` (`liquid_mask = step(SHADING_LIQUID_BITS_ALPHA, extra_data.a)`).
3. **Screen-Space Limitations**:
   - The shader operates exclusively on data within the camera viewport. If an obstacle or light source extends beyond the screen edges, screen-space rays cannot account for them properly.
4. **Divergence Between Dynamic Vision and World Grid**:
   - The shader only modifies the screen rendering for the current frame.
   - Unless `FogOfWarRadiusComponent` is zeroed out, the Noita engine will continue clearing fog through walls in the global world grid. To achieve full consistency, setting `FogOfWarRadiusComponent.radius = 0` is required, fully delegating control to the shader or a dedicated manager.

## CPU-Side Alternative (Lua Raytracing)

The Noita API provides pixel-level physical grid raytracing functions:

- `RaytraceSurfaces(x1, y1, x2, y2)` — stops at solid pixels, ignoring liquids and gases.
- `GameSetFogOfWar(x, y, value)` — writes values directly into the fog of war grid.

However, casting dozens of rays in 360 degrees every frame in Lua causes severe FPS drops due to Lua-to-C++ call overhead. This method is only practical for turn-based or infrequent updates (e.g. scanning once every 30–60 frames).

## Relevant Game Files

- `data/shaders/post_final.vert` — post-processing vertex shader, calculates `tex_coord_fogofwar`.
- `data/shaders/post_final.frag` — post-processing fragment shader, blends `tex_fg`, `tex_lights`, and `tex_fog`.
- `data/entities/player_base.xml` — base player XML, `LightComponent` configuration.
- `data/entities/misc/fogofwar_radius.xml` — reference spell entity with `FogOfWarRadiusComponent`.
- `tools_modding/component_documentation.txt` — engine documentation for `FogOfWarRadiusComponent`, `FogOfWarRemoverComponent`, `LightComponent`, and `SpriteComponent.fog_of_war_hole`.
