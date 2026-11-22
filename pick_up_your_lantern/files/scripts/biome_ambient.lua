--- Biome ambient lighting controller for Pick Up Your Lantern mod.
--- Passes biome-specific diffused air light parameters to the post_final shader
--- so open caverns in snowy biomes remain readable as silhouettes without
--- lighting up the inside of solid terrain.

---@diagnostic disable: undefined-global

local FADE_FRAMES = 60

---Offsets from the camera center used to sample the visible viewport.
local SAMPLE_OFFSETS = {
    { x = 0, y = 0, },
    { x = 0, y = -90, },
    { x = 0, y = 90, },
    { x = -160, y = 0, },
    { x = 160, y = 0, },
}

---Diffused air ambient definitions keyed by BiomeMapGetName() return value.
---@type table<string, {r: number, g: number, b: number, strength: number}>
local BIOME_AMBIENTS = {
    ["$biome_snowcave"] = {
        r = 0.032,
        g = 0.060,
        b = 0.100,
        strength = 1.0,
    },
}

local current_r = 0.0
local current_g = 0.0
local current_b = 0.0
local current_strength = 0.0
local last_update_frame = nil

---Moves a value toward a target by at most max_delta.
---@param value number Current value.
---@param target number Target value.
---@param max_delta number Maximum step size.
---@return number
local function MoveToward(value, target, max_delta)
    if value < target then
        return math.min(target, value + max_delta)
    end
    if value > target then
        return math.max(target, value - max_delta)
    end

    return target
end

---Samples the biomes visible in the camera viewport and computes target ambient values.
---@return number r, number g, number b, number strength
local function SampleViewportAmbient()
    local cam_x, cam_y = GameGetCameraPos()
    if cam_x == nil or cam_y == nil then
        return 0.0, 0.0, 0.0, 0.0
    end

    local sum_r = 0.0
    local sum_g = 0.0
    local sum_b = 0.0
    local sum_strength = 0.0
    local matched = 0

    for _, offset in ipairs(SAMPLE_OFFSETS) do
        local biome_name = BiomeMapGetName(cam_x + offset.x, cam_y + offset.y)
        local ambient = BIOME_AMBIENTS[biome_name]
        if ambient ~= nil then
            sum_r = sum_r + ambient.r
            sum_g = sum_g + ambient.g
            sum_b = sum_b + ambient.b
            sum_strength = sum_strength + ambient.strength
            matched = matched + 1
        end
    end

    if matched == 0 then
        return current_r, current_g, current_b, 0.0
    end

    return sum_r / matched, sum_g / matched, sum_b / matched, sum_strength / #SAMPLE_OFFSETS
end

---Updates biome diffused air ambient parameters every frame and sends them to post_final.frag.
---@param player_entity number? Entity currently controlled by the player, nil when dead.
---@return nil
function UpdateBiomeAmbient(player_entity)
    local frame = GameGetFrameNum()
    local frames = last_update_frame ~= nil and math.max(0, frame - last_update_frame) or 1
    last_update_frame = frame

    local target_r, target_g, target_b, target_strength = 0.0, 0.0, 0.0, 0.0
    if player_entity ~= nil then
        target_r, target_g, target_b, target_strength = SampleViewportAmbient()
    end

    local step = frames / FADE_FRAMES
    if target_strength > 0.0 then
        if current_strength <= 0.001 then
            current_r = target_r
            current_g = target_g
            current_b = target_b
        else
            current_r = MoveToward(current_r, target_r, step)
            current_g = MoveToward(current_g, target_g, step)
            current_b = MoveToward(current_b, target_b, step)
        end
    end
    current_strength = MoveToward(current_strength, target_strength, step)

    GameSetPostFxParameter("pul_biome_ambient", current_r, current_g, current_b, current_strength)
end
