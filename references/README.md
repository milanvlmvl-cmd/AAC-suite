# References

Reference material for building the AAC-suite addon and pipeline. Nothing here is our own code.

| Path | What |
|---|---|
| `aaclassic-addon-api.lua` | ArcheAge Classic addon API reference (globals, `UI_EVENTS`, `ADDON_API` functions), as supplied by the user. |
| `example-addons/PlayerDB/` | PlayerDB addon (players, houses, regrades, inventory, for-sale, demo OCR). Writes `.dat` files that PlayerDBSync uploads. Ships its own, **newer** `api.lua` (adds e.g. `GetMemoryUsage`, `Nametag:*`, `Team:MakeTeamOwner`, `Unit:RememberEventUnitId`, `Voice:*`) plus `API_DOCUMENTATION.md`. |
| `example-addons/RaidsDB/` | RaidsDB addon (raid loot recording). Its `ignore.dat` is written externally by PlayerDBSync. |
| `example-addons/ChatLogs/` | ChatLogs addon. |
| `example-addons/CombatLogPro/` | Combat log addon (skill, buff and role data tables). |

## External sources

| Source | Notes |
|---|---|
| https://github.com/Madpeterz/PlayerDBSync | Sync app that uploads PlayerDB/RaidsDB `.dat` files unmodified. |
| https://aa-classic.com/api/game/tod | Prints the current in-game time of day. |
| https://aa-classic.com/timers | Event timers. In winter, the "world bosses" and "daily events" headers run 1 hour behind; game-time events are correct. |
