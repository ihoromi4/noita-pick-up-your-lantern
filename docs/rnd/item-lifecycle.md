# Item Lifecycle in World, Inventory, and Hands

[← Back to R&D Index](../rnd.md)

- **[Confirmed]** The engine automatically toggles component states using system tags specified in the `_tags` attribute:
  - `enabled_in_world` — components are active when the lantern hangs or lies in the world, and are automatically disabled when picked up into the inventory.
  - `enabled_in_hand` — components are enabled when the lantern is selected as the active item in hands.
  - `enabled_in_inventory` — components remain active while in the inventory.
- **[Confirmed]** The `TorchComponent` in vanilla lanterns is responsible for igniting adjacent pixels and extinguishing in water. If `TorchComponent` is removed and `LightComponent` is kept with `_tags="enabled_in_world,enabled_in_hand"`, the lantern emits light in the world and in hands, but never ignites anything until it shatters.
- **[Confirmed]** Setting the `drinkable="0"` attribute in `ItemComponent` disables the ability to drink oil from the lantern's `MaterialInventoryComponent` via RMB.
