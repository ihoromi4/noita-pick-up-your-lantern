--- Chains of lanterns for Pick Up Your Lantern mod, for each lantern type with `chain` in LANTERN_TYPES.
--- A temple lantern spawned by a biome hangs far below the ceiling, a chain torch on a short chain of 4 links. The
--- vanilla fixtures build physics chains, which get no bodies once the lantern is a mod item, so a chain is a rigid
--- rope of hanging_rope.lua made of the vanilla chain link sprites:
--- - the lantern is held at the length of its chain by its top, so it swings on it;
--- - picked up, kicked or flung far, the lantern comes off the chain, which keeps hanging from the ceiling;
--- - a projectile that hits a link breaks the chain there: the upper part keeps hanging, the lower one falls off
---   with the lantern, lies on the floor and disappears after a while;
--- - once the ceiling at the anchor is destroyed, the whole chain falls.
--- A chain entity at the ceiling anchor keeps the link count, and the lantern keeps the anchor position, so a lantern
--- on its chain is put back on it after a save and reload. A lantern hung with the left mouse button hangs right
--- under the ceiling on its joint, without a chain.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/hanging_rope.lua")

local LANTERN_TAG = "lantern"
local PROJECTILE_TAG = "projectile"
local ENTITIES_PATH = "mods/" .. MOD_ID .. "/files/entities/"
local ANCHOR_SCRIPT = "mods/" .. MOD_ID .. "/files/scripts/lantern_anchor.lua"
-- Set once the lantern has been seen in the world, so only a freshly spawned lantern gets a chain.
local CHECKED_STORAGE = "lantern_chain_checked"
-- Set while the lantern hangs on its chain; shared with lantern_chain_kick.lua.
local ON_CHAIN_STORAGE = "lantern_on_chain"
-- Set by lantern_chain_kick.lua when the lantern is kicked off its chain.
local UNHOOK_STORAGE = "lantern_chain_unhook"
local ANCHOR_X_STORAGE = "lantern_chain_anchor_x"
local ANCHOR_Y_STORAGE = "lantern_chain_anchor_y"

-- Length of a link, in pixels: the height of the vanilla link sprite (torch_hang_chain.png).
local LINK_LENGTH = 6
-- A lantern with the ceiling this close above its top hangs on its joint, without a chain, unless its chain has
-- a fixed number of links.
local JOINT_CEILING_DISTANCE = 6
-- How far above the anchor the ceiling is searched for, to tell when it is destroyed, and how often.
local ANCHOR_CEILING_CHECK_DISTANCE = 4
local ANCHOR_CHECK_INTERVAL_FRAMES = 20
-- A lantern in the world is held at the length of its chain, and comes off only when flung this much farther in
-- a frame.
local WORLD_BREAK_STRETCH = 2
-- A chain is taut, and laid straight, while its lantern is this close to the full chain length.
local TAUT_SLACK = 0.5
-- A lantern on a chain that has not been loaded for this long falls.
local MISSING_CHAIN_FRAMES = 3 * 60
-- A projectile path closer than this to a link hits it.
local HIT_DISTANCE = 2
-- Search radius for projectiles around the middle of a chain, on top of half its length.
local HIT_SEARCH_MARGIN = 16
local BREAK_SPARK_COUNT = 6
-- A piece that fell off a chain lies on the floor for 10 seconds.
local LOOSE_PIECE_FRAMES = 10 * 60

---A kind of chain: its rope kind and the entity at its ceiling anchor. Kinds share the link tag, so each one keeps
---the links of the others when it syncs its chains.
---@class ChainKind : RopeKind
---@field anchor_entity_path string Chain entity spawned at the ceiling anchor.

---Plain chain of the temple lantern.
---@type ChainKind
local PLAIN_CHAIN_KIND = {
    segment_length = LINK_LENGTH,
    segment_entity_path = ENTITIES_PATH .. "lantern_chain_link.xml",
    anchor_tag = "pul_chain",
    segment_tag = "pul_chain_link",
    segment_count_storage = "chain_link_count",
    rigid = true,
    anchor_entity_path = ENTITIES_PATH .. "lantern_chain.xml",
}

---Chain of a chain torch, with the vanilla ceiling mount sprite on its top link.
---@type ChainKind
local MOUNTED_CHAIN_KIND = {
    segment_length = LINK_LENGTH,
    segment_entity_path = ENTITIES_PATH .. "lantern_chain_link.xml",
    top_segment_entity_path = ENTITIES_PATH .. "lantern_chain_mount.xml",
    anchor_tag = "pul_mounted_chain",
    segment_tag = "pul_chain_link",
    segment_count_storage = "chain_link_count",
    rigid = true,
    anchor_entity_path = ENTITIES_PATH .. "lantern_mounted_chain.xml",
}

---@type ChainKind[]
local CHAIN_KINDS = { PLAIN_CHAIN_KIND, MOUNTED_CHAIN_KIND, }

---A chain hanging from the ceiling, or a loose piece of one.
---@class LanternChain : HangingRope
---@field lantern_id number|nil Lantern hanging on the chain.
---@field config LanternChainConfig|nil Chain config of the lantern type hanging on the chain.
---@field age_frames number|nil Frames since a loose piece fell off.

---Chains simulated this session, by chain kind and chain entity ID.
---@type table<ChainKind, table<number, LanternChain>>
local chains = {}
for _, kind in ipairs(CHAIN_KINDS) do
    chains[kind] = {}
end

---Chains that hold a lantern, by lantern entity ID.
---@type table<number, LanternChain>
local lantern_chains = {}

---Pieces that fell off a chain; not saved.
---@type LanternChain[]
local loose_pieces = {}

---Frames a lantern on a chain has waited for its chain to load, by lantern entity ID.
---@type table<number, number>
local missing_frames = {}

---Returns the chain config of a lantern type, if it hangs on a chain.
---@param lantern_id number Lantern entity ID.
---@return LanternChainConfig|nil
local function GetChainConfig(lantern_id)
    local _, lantern_type = GetLanternType(lantern_id)
    return lantern_type.chain
end

---Returns the kind of chain a lantern type hangs on.
---@param config LanternChainConfig
---@return ChainKind
local function GetChainKind(config)
    return config.has_ceiling_link and MOUNTED_CHAIN_KIND or PLAIN_CHAIN_KIND
end

---Hangs a lantern on a chain: links them both ways and marks the lantern.
---@param chain LanternChain
---@param lantern_id number Lantern entity ID.
---@param config LanternChainConfig Chain config of the lantern type.
---@return nil
local function HookLantern(chain, lantern_id, config)
    chain.lantern_id = lantern_id
    chain.config = config
    lantern_chains[lantern_id] = chain
    missing_frames[lantern_id] = nil
    local anchor = chain.points[1]
    SetStorageFloat(lantern_id, ON_CHAIN_STORAGE, 1)
    SetStorageFloat(lantern_id, ANCHOR_X_STORAGE, anchor.x)
    SetStorageFloat(lantern_id, ANCHOR_Y_STORAGE, anchor.y)
end

---Takes a lantern off its chain; the chain keeps hanging.
---@param chain LanternChain
---@return nil
local function UnhookLantern(chain)
    local lantern_id = chain.lantern_id
    if lantern_id == nil then
        return
    end

    chain.lantern_id = nil
    chain.config = nil
    lantern_chains[lantern_id] = nil
    if EntityGetIsAlive(lantern_id) then
        SetStorageFloat(lantern_id, ON_CHAIN_STORAGE, 0)
        SetStorageFloat(lantern_id, UNHOOK_STORAGE, 0)
    end
end

---Forgets the lantern of a chain whose rope was dropped, e.g. when its anchor streamed out. The lantern stays
---marked as hanging on it and is put back once the chain is loaded again.
---@param rope HangingRope
---@return nil
local function OnChainDropped(rope)
    ---@cast rope LanternChain
    if rope.lantern_id ~= nil then
        lantern_chains[rope.lantern_id] = nil
    end
end

---Turns points and links of a chain into a loose piece that falls.
---@param kind ChainKind
---@param points RopePoint[]
---@param segment_ids number[]
---@return nil
local function DropLoosePiece(kind, points, segment_ids)
    if #segment_ids == 0 then
        return
    end

    table.insert(loose_pieces, {
        kind = kind,
        anchor_id = nil,
        points = points,
        segment_ids = segment_ids,
        lantern_id = nil,
        age_frames = 0,
    })
end

---Removes a chain from the ceiling: its anchor entity is killed and its links fall as a loose piece.
---@param chain LanternChain
---@return nil
local function DropWholeChain(chain)
    UnhookLantern(chain)
    chains[chain.kind][chain.anchor_id] = nil
    EntityKill(chain.anchor_id)
    DropLoosePiece(chain.kind, chain.points, chain.segment_ids)
end

---Breaks a chain at one link: the link is gone, the part above it keeps hanging, and the part below falls off
---together with the lantern.
---@param chain LanternChain
---@param link_index number Index of the broken link, from the ceiling.
---@return nil
local function BreakChain(chain, link_index)
    UnhookLantern(chain)

    local a, b = chain.points[link_index], chain.points[link_index + 1]
    GameCreateCosmeticParticle("spark", (a.x + b.x) / 2, (a.y + b.y) / 2, BREAK_SPARK_COUNT, 0, 0)
    EntityKill(chain.segment_ids[link_index])

    local lower_points, lower_segment_ids = {}, {}
    for index = link_index + 1, #chain.points do
        table.insert(lower_points, chain.points[index])
    end
    for index = link_index + 1, #chain.segment_ids do
        table.insert(lower_segment_ids, chain.segment_ids[index])
    end
    DropLoosePiece(chain.kind, lower_points, lower_segment_ids)

    if link_index == 1 then
        chains[chain.kind][chain.anchor_id] = nil
        EntityKill(chain.anchor_id)
        return
    end

    for index = #chain.points, link_index + 1, -1 do
        table.remove(chain.points, index)
    end
    for index = #chain.segment_ids, link_index, -1 do
        table.remove(chain.segment_ids, index)
    end
    SetStorageFloat(chain.anchor_id, chain.kind.segment_count_storage, #chain.segment_ids)
end

---Removes the joints of a lantern that hangs on a chain, and its anchor script, which would detach it from
---a ceiling it does not touch.
---@param lantern_id number Lantern entity ID.
---@return nil
local function RemoveCeilingJoint(lantern_id)
    local x, y = EntityGetTransform(lantern_id)
    for _, joint_comp in ipairs(EntityGetComponentIncludingDisabled(lantern_id, "PhysicsJointComponent") or {}) do
        EntityRemoveComponent(lantern_id, joint_comp)
    end
    PhysicsRemoveJoints(x - 3, y - 3, x + 3, y + 3)

    for _, lua_comp in ipairs(EntityGetComponentIncludingDisabled(lantern_id, "LuaComponent") or {}) do
        if ComponentGetValue2(lua_comp, "script_source_file") == ANCHOR_SCRIPT then
            EntityRemoveComponent(lantern_id, lua_comp)
        end
    end
end

---Moves a lantern straight down or up to another height, its physics body too, at rest.
---@param lantern_id number Lantern entity ID.
---@param y number New world Y coordinate of the lantern origin.
---@return nil
local function MoveLanternTo(lantern_id, y)
    local x, old_y, rotation = EntityGetTransform(lantern_id)
    for _, body_id in ipairs(PhysicsBodyIDGetFromEntity(lantern_id) or {}) do
        local body_x, body_y, angle = PhysicsBodyIDGetTransform(body_id)
        if body_x ~= nil then
            local game_x, game_y = PhysicsPosToGamePos(body_x, body_y)
            body_x, body_y = GamePosToPhysicsPos(game_x, game_y + y - old_y)
            PhysicsBodyIDSetTransform(body_id, body_x, body_y, angle, 0, 0, 0)
        end
    end
    EntitySetTransform(lantern_id, x, y, rotation)
end

---Gives a freshly spawned lantern its chain. A chain with a fixed number of links hangs from the ceiling right
---above, and the lantern is moved to its end, as a vanilla chain torch hangs. Otherwise the chain reaches up to the
---ceiling, as the vanilla temple_lantern.lua builds it, and a lantern right under the ceiling, hung with the left
---mouse button, keeps its joint. Without a ceiling the lantern falls.
---@param lantern_id number Lantern entity ID.
---@param config LanternChainConfig Chain config of the lantern type.
---@return nil
local function CreateChain(lantern_id, config)
    local x, y = EntityGetTransform(lantern_id)
    local link_count = config.link_count
    if link_count == nil and RaytraceSurfaces(x, y, x, y - JOINT_CEILING_DISTANCE) then
        return
    end

    local found, _, hit_y = RaytracePlatforms(x, y, x, y - config.ceiling_search_distance)
    if not found then
        return
    end

    local anchor_y = math.floor(hit_y) + 1
    if link_count == nil then
        local distance = y - anchor_y
        if distance <= LINK_LENGTH then
            return
        end
        link_count = math.floor(distance / LINK_LENGTH)
    end

    local kind = GetChainKind(config)
    local anchor_id = SpawnHangingRopeAnchor(kind.anchor_entity_path, kind, x, anchor_y, link_count)
    if anchor_id == nil then
        return
    end

    RemoveCeilingJoint(lantern_id)
    local end_y = anchor_y + link_count * LINK_LENGTH
    if config.link_count ~= nil then
        MoveLanternTo(lantern_id, end_y)
    end
    local chain = CreateHangingRope(kind, anchor_id, x, anchor_y, x, end_y, link_count)
    ---@cast chain LanternChain
    chains[kind][anchor_id] = chain
    HookLantern(chain, lantern_id, config)
end

---Puts a lantern loaded from a save back on its chain, once the chain is loaded. A lantern whose chain does not
---show up in time falls.
---@param lantern_id number Lantern entity ID.
---@param config LanternChainConfig Chain config of the lantern type.
---@return nil
local function RehookLantern(lantern_id, config)
    local kind = GetChainKind(config)
    local anchor_x = GetStorageFloat(lantern_id, ANCHOR_X_STORAGE)
    local anchor_y = GetStorageFloat(lantern_id, ANCHOR_Y_STORAGE)
    for _, anchor_id in ipairs(EntityGetInRadiusWithTag(anchor_x, anchor_y, 2, kind.anchor_tag) or {}) do
        local chain = chains[kind][anchor_id]
        if chain ~= nil and chain.lantern_id == nil then
            HookLantern(chain, lantern_id, config)
            return
        end
    end

    local frames = (missing_frames[lantern_id] or 0) + 1
    missing_frames[lantern_id] = frames
    if frames > MISSING_CHAIN_FRAMES then
        missing_frames[lantern_id] = nil
        SetStorageFloat(lantern_id, ON_CHAIN_STORAGE, 0)
    end
end

---Watches lanterns that hang on chains: a freshly spawned one gets its chain, a lantern loaded from a save is put
---back on its chain, and a lantern picked up comes off it.
---@return nil
local function UpdateChainLanterns()
    for _, lantern_id in ipairs(EntityGetWithTag(LANTERN_TAG) or {}) do
        local config = GetChainConfig(lantern_id)
        if config ~= nil then
            local chain = lantern_chains[lantern_id]
            if EntityGetRootEntity(lantern_id) ~= lantern_id then
                if chain ~= nil then
                    UnhookLantern(chain)
                else
                    SetStorageFloat(lantern_id, ON_CHAIN_STORAGE, 0)
                end
                SetStorageFloat(lantern_id, CHECKED_STORAGE, 1)
            elseif GetStorageFloat(lantern_id, CHECKED_STORAGE) <= 0 then
                SetStorageFloat(lantern_id, CHECKED_STORAGE, 1)
                CreateChain(lantern_id, config)
            elseif chain == nil and GetStorageFloat(lantern_id, ON_CHAIN_STORAGE) > 0 then
                RehookLantern(lantern_id, config)
            end
        end
    end
end

---Holds a lantern at the length of its chain by its top, and takes it off when it is kicked or flung far.
---@param chain LanternChain
---@return boolean is_taut Whether the lantern pulls the chain taut.
local function UpdateChainedLantern(chain)
    local lantern_id = chain.lantern_id --[[@as number]]
    local config = chain.config --[[@as LanternChainConfig]]
    if not EntityGetIsAlive(lantern_id) or GetStorageFloat(lantern_id, UNHOOK_STORAGE) > 0 then
        UnhookLantern(chain)
        return false
    end

    local x, y, rotation = EntityGetTransform(lantern_id)
    local anchor = chain.points[1]
    local dx, dy = x - anchor.x, y - anchor.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local length = #chain.segment_ids * LINK_LENGTH
    if distance > length * WORLD_BREAK_STRETCH then
        UnhookLantern(chain)
        return false
    elseif distance > length then
        local center_x, center_y = OffsetToWorld(x, y, rotation, 0, config.center_offset_y)
        HoldBodyOnHangingRope(lantern_id, x, y, center_x, center_y, dx / distance, dy / distance, distance - length,
            config.mass_over_inertia)
        x, y = anchor.x + dx / distance * length, anchor.y + dy / distance * length
    end

    local last = chain.points[#chain.points]
    last.x, last.y = x, y
    return distance >= length - TAUT_SLACK
end

---Returns the distance between two line segments.
---@param ax number First segment start, X.
---@param ay number First segment start, Y.
---@param bx number First segment end, X.
---@param by number First segment end, Y.
---@param cx number Second segment start, X.
---@param cy number Second segment start, Y.
---@param dx number Second segment end, X.
---@param dy number Second segment end, Y.
---@return number
local function SegmentDistance(ax, ay, bx, by, cx, cy, dx, dy)
    ---Distance from a point to a segment.
    ---@return number
    local function PointToSegment(px, py, sx, sy, ex, ey)
        local vx, vy = ex - sx, ey - sy
        local length_sq = vx * vx + vy * vy
        local t = 0
        if length_sq > 0 then
            t = math.max(0, math.min(1, ((px - sx) * vx + (py - sy) * vy) / length_sq))
        end
        local qx, qy = sx + vx * t - px, sy + vy * t - py
        return math.sqrt(qx * qx + qy * qy)
    end

    -- Proper crossing: the endpoints of each segment lie on different sides of the other.
    local function Side(px, py, sx, sy, ex, ey)
        return (ex - sx) * (py - sy) - (ey - sy) * (px - sx)
    end
    local d1, d2 = Side(ax, ay, cx, cy, dx, dy), Side(bx, by, cx, cy, dx, dy)
    local d3, d4 = Side(cx, cy, ax, ay, bx, by), Side(dx, dy, ax, ay, bx, by)
    if d1 * d2 < 0 and d3 * d4 < 0 then
        return 0
    end

    return math.min(
        PointToSegment(ax, ay, cx, cy, dx, dy),
        PointToSegment(bx, by, cx, cy, dx, dy),
        PointToSegment(cx, cy, ax, ay, bx, by),
        PointToSegment(dx, dy, ax, ay, bx, by)
    )
end

---Breaks a chain where a projectile hits one of its links, checked along the path of the projectile in the last
---frame so that fast projectiles do not pass through. Projectiles that pass through the world are ignored; a
---projectile that hits a link stops there, as on a physics body, and dies with its usual death effects.
---@param chain LanternChain
---@return nil
local function CheckProjectileHits(chain)
    local points = chain.points
    local first, last = points[1], points[#points]
    local center_x, center_y = (first.x + last.x) / 2, (first.y + last.y) / 2
    local radius = #chain.segment_ids * LINK_LENGTH / 2 + HIT_SEARCH_MARGIN
    for _, projectile_id in ipairs(EntityGetInRadiusWithTag(center_x, center_y, radius, PROJECTILE_TAG) or {}) do
        local projectile_comp = EntityGetFirstComponent(projectile_id, "ProjectileComponent")
        if projectile_comp ~= nil and ComponentGetValue2(projectile_comp, "collide_with_world")
            and not ComponentGetValue2(projectile_comp, "penetrate_world") then
            local x, y = EntityGetTransform(projectile_id)
            local prev_x, prev_y = x, y
            local velocity_comp = EntityGetFirstComponent(projectile_id, "VelocityComponent")
            if velocity_comp ~= nil then
                local vel_x, vel_y = ComponentGetValue2(velocity_comp, "mVelocity")
                prev_x, prev_y = x - vel_x / 60, y - vel_y / 60
            end

            local hit_index, hit_distance = nil, HIT_DISTANCE
            for index = 1, #chain.segment_ids do
                local a, b = points[index], points[index + 1]
                local distance = SegmentDistance(prev_x, prev_y, x, y, a.x, a.y, b.x, b.y)
                if distance < hit_distance then
                    hit_index, hit_distance = index, distance
                end
            end
            if hit_index ~= nil then
                local a, b = points[hit_index], points[hit_index + 1]
                EntitySetTransform(projectile_id, (a.x + b.x) / 2, (a.y + b.y) / 2)
                EntityKill(projectile_id)
                BreakChain(chain, hit_index)
                return
            end
        end
    end
end

---Updates the chains of one kind hanging from the ceiling.
---@param kind_chains table<number, LanternChain> Chains of the kind by chain entity ID.
---@return nil
local function UpdateChains(kind_chains)
    local check_anchors = GameGetFrameNum() % ANCHOR_CHECK_INTERVAL_FRAMES == 0
    ---@type table<number, boolean>
    local taut = {}
    for anchor_id, chain in pairs(kind_chains) do
        local anchor = chain.points[1]
        if check_anchors
            and not RaytraceSurfaces(anchor.x, anchor.y, anchor.x, anchor.y - ANCHOR_CEILING_CHECK_DISTANCE) then
            DropWholeChain(chain)
        else
            if chain.lantern_id ~= nil then
                taut[anchor_id] = UpdateChainedLantern(chain)
            end
            CheckProjectileHits(chain)
        end
    end

    for anchor_id, chain in pairs(kind_chains) do
        -- A projectile may have broken a taut chain since, which then hangs free.
        if taut[anchor_id] and chain.lantern_id ~= nil then
            StraightenHangingRope(chain)
        else
            SimulateHangingRope(chain, chain.lantern_id ~= nil)
        end
        RenderHangingRope(chain)
    end
end

---Lets the loose pieces fall, and removes them after a while.
---@return nil
local function UpdateLoosePieces()
    for index = #loose_pieces, 1, -1 do
        local piece = loose_pieces[index]
        piece.age_frames = piece.age_frames + 1
        if piece.age_frames > LOOSE_PIECE_FRAMES then
            RemoveHangingRopeSprites(piece)
            table.remove(loose_pieces, index)
        else
            SimulateHangingRope(piece, false)
            RenderHangingRope(piece)
        end
    end
end

---Matches the chains of each kind to the loaded chain entities. The links of the other kinds and of loose pieces
---are kept, as all kinds share the link tag.
---@return nil
local function SyncChains()
    for _, kind in ipairs(CHAIN_KINDS) do
        ---@type HangingRope[]
        local other_ropes = {}
        for _, piece in ipairs(loose_pieces) do
            table.insert(other_ropes, piece)
        end
        for other_kind, kind_chains in pairs(chains) do
            if other_kind ~= kind then
                for _, chain in pairs(kind_chains) do
                    table.insert(other_ropes, chain)
                end
            end
        end
        SyncHangingRopes(kind, chains[kind], OnChainDropped, other_ropes)
    end
end

---Updates lantern chains. Runs every frame in OnWorldPostUpdate, after physics, so a chain follows its lantern in
---the same frame before rendering.
---@return nil
function UpdateLanternChains()
    SyncChains()
    UpdateChainLanterns()
    for _, kind in ipairs(CHAIN_KINDS) do
        UpdateChains(chains[kind])
    end
    UpdateLoosePieces()
end
