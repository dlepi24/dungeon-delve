extends Node
## Owner of state that outlives any single scene. Autoloaded as `GameState`.
##
## Two lifetimes will live here, and keeping them distinct matters:
## - Run state: seed, depth, current haul. Wiped on death or extraction.
## - Meta state: hub upgrades, unlocks, records. Persists across runs (M5+).
##
## The seeded RNG service the GDD requires for daily seeds and ghost replays
## belongs here too. Every gameplay random draw must route through one seeded
## source, or the same seed stops producing the same delve.
##
## Deliberately empty at M0. Populated as M1 and M5 define what actually persists.
