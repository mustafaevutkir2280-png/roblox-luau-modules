# roblox-luau-modules

Open-source, plug-and-play Luau modules for Roblox game developers.

## Modules

| Module | Description |
|--------|-------------|
| Inventory | Grid-based inventory with stacks and weight |
| DataStore | DataStoreService wrapper with auto-retry and versioning |
| Shop | In-game shop with MarketplaceService integration |
| NPC | NPC dialogue, waypoints, aggro system |
| Physics | Cart and vehicle physics helpers |

## Quick Start

```lua
local Inventory = require(game.ReplicatedStorage.Modules.Inventory)
local inv = Inventory.new(player, { maxSlots = 20, maxWeight = 100 })
inv:addItem("Sword", 1)
print(inv:getItems())
```

## Contributing

Pull requests welcome. Add your module under src/ and open a PR.

## License

MIT (c) 2026 mustafaevutkir2280-png
