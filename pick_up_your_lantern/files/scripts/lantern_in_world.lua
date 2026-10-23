--- World transform guard for lanterns: resets mirrored scale inherited from the player's hand.
-- While held, the engine mirrors the item via transform scale (e.g. scale_y = -1 when facing left).
-- After a throw or drop the physics body only drives position and rotation, so the mirrored scale
-- persists and flips the flame SpriteComponent away from the physics-rendered container.
-- Runs once per return to the world: the component disables itself after the check and is
-- re-enabled by the engine through the `enabled_in_world` tag on the next throw or drop.

local entity_id = GetUpdatedEntityID()
local x, y, rotation, scale_x, scale_y = EntityGetTransform(entity_id)

if scale_x ~= 1 or scale_y ~= 1 then
    EntitySetTransform(entity_id, x, y, rotation, 1, 1)
end

EntitySetComponentIsEnabled(entity_id, GetUpdatedComponentID(), false)
