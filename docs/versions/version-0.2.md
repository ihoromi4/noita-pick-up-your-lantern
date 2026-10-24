# Version 0.2 - Passive Carrying and Atmosphere

Tracking document for features, implementation progress, and known issues for **Version 0.2**. Functional requirements are defined in [requirements.md](../requirements.md) and milestone planning in [roadmap.md](../roadmap.md). Previous milestone progress is tracked in [version-0.1.1.md](version-0.1.1.md).

## Summary

Your lantern now stays with you even when your hands are busy: it hangs on your belt and softly lights the way while you fight with wands or drink from flasks. Every lantern you find is a little different. Each type has its own light, color and durability, lanterns from deeper places tend to be better, and some are rare oddities that flicker restlessly or slowly run out of oil and die. Diving into oil makes your lantern blaze wider, while a swim in water leaves it dim until you find oil again, and the item description always tells you what kind of lantern you are carrying. The darkness also plays fairer now: All-Seeing Eye, Sunseed and Sunstone reveal the world again, every chain torch lights its surroundings, and your limited vision is restored after polymorph, with a separate setting for how far you see while polymorphed.

## Belt Attachment and Passive Illumination

- [x] Automatically display the first available lantern from `Quick Inventory` on the character's belt/waist when hands are holding wands, flasks, or items (reference: "Extra Backpack", Steam ID: `3807317449`).
- [x] Emit moderate passive ambient light from the belt (dimmer than active hand holding, but brighter than unlit player vision).
- [x] `Belt lantern light` option in Mod Settings to scale the belt light relative to the lantern in hand (0-100%, 50% by default).
- [x] Hide the belt lantern (sprite and light) whenever any lantern is the active held item, even if other lanterns remain in the inventory.
- [x] Synchronize belt lantern movement with player locomotion.

## Lantern Properties and Dynamic States

- [x] Distinct properties per lantern: light radius, fog of war hole size, light color, and durability differ between lantern types and are declared in the lantern XML files. Details: [Lantern Properties and Progression](../dev/lantern-properties-and-progression.md).
- [x] Lantern quality tiers rolled on spawn, with better tiers becoming more likely in deeper biomes; tier is described by an atmospheric sentence in the item description. Details: [Lantern Properties and Progression](../dev/lantern-properties-and-progression.md).
- [x] Rare lantern modifiers rolled independently of the tier, each described by a sentence in the item description: Flickering (20% wider but unstable light) and Short-lived (leaks a drop of oil every 5 seconds, fades over its limited burn time and goes out).
- [x] `Lantern progression` option in Mod Settings to turn tiers and modifiers off (enabled by default).
- [x] Oil-soaked state: diving into oil with a lantern in hand makes its light and fog of war hole 30% wider until it is submerged in water. The state is described by a sentence in the item description. Details: [Lantern Properties and Progression](../dev/lantern-properties-and-progression.md).
- [x] Wet state: diving under water with a lantern in hand makes its light and fog of war hole 20% narrower until it is submerged in oil. The state is described by a sentence in the item description.

## Known Issues and Next Steps

- [x] Flame sprite desync: the flame was flipped away from the glass container after throwing a held lantern while facing left. Details: [Holding and Belt](../dev/holding-and-belt.md).
- [x] Limited vision lost after polymorph: vision stayed almost vanilla after returning to normal form until mod settings were changed. Details: [Vision and Lighting](../dev/vision-and-lighting.md).
- [x] Separate `Polymorphed vision` option in Mod Settings for the polymorphed form (`Same as player` by default). Details: [Vision and Lighting](../dev/vision-and-lighting.md).
- [x] Chain torches in some biomes (e.g., ghostly torches in Coal Pits) did not dispel fog of war: these biomes spawn duplicate torch files from `data/entities/props/` that the mod did not patch. Details: [Lantern Entities](../dev/lantern-entities.md).
- [x] All-Seeing Eye spell (`X_RAY`) did not work: the limited vision darkened the revealed area again. It now reveals a slowly expanding circle around the cast point at vanilla brightness. Once the circle covers the screen, the revealed lighting fades back to the previous level over 10 seconds. A repeated cast takes over the size and lighting of the active circle and brightens it back up, so rapid casting does not make the screen flicker. Details: [Vision and Lighting](../dev/vision-and-lighting.md).
- [x] All-Seeing Eye perk (`REMOVE_FOG_OF_WAR`) did not work for the same reason: it now reveals the whole level as in vanilla. Holding Sunseed or Sunstone has the same effect.
