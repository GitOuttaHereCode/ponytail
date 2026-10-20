# Critter Quarry

Cozy idle farming sim for Roblox. Critters dig rocks on your land (even offline), you sell commons for coins, fill your museum, and breed stronger animals to unlock deeper layers.

## Setup in Roblox Studio

Paste each script into Studio (or sync with Rojo using `default.project.json`):

| File | Studio location | Type |
| --- | --- | --- |
| `src/shared/Config.luau` | ReplicatedStorage, named `Config` | ModuleScript |
| `src/server/Game.server.luau` | ServerScriptService | Script |
| `src/client/UI.client.luau` | StarterPlayer > StarterPlayerScripts | LocalScript |

Turn on Game Settings > Security > Enable Studio Access to API Services so saves work in Studio.

## Loop

- You start with one free Chicken digging Topsoil. Each critter digs every 30s (faster with Speed).
- Sell rocks for coins or put one of each in the museum.
- Fill the Topsoil shelf to unlock Pigs (Clay and Sandstone). Fill that shelf and breed a Pig with Strength 7+ to unlock Goats (Crystal Caves).
- Breeding two of a kind averages their stats with a small random shift and a 5% Shiny chance (+3 Luck).
- Luck gives a chance at a bonus find. It never changes the disclosed odds, which the "Show odds" panel lists.
- Rare and ultra finds are announced to the whole server. Offline digging is capped at 8 hours.

## Test

`luau tests/config.test.luau` checks that every layer sums to 100% and that rolls land on the right rocks.
