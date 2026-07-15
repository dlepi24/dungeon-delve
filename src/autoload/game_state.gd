extends Node
## Owner of state that outlives any single scene. Autoloaded as `GameState`.
##
## Two lifetimes live here, and keeping them distinct matters:
## - Run state: seed, plan, depth, current haul. Wiped when a run ends.
## - Meta state: hub upgrades, unlocks, records. Persists across runs (M5+).
##
## Run state is populated; meta state is still a stub, because the GDD has not
## ruled on what persists (open question 3) or on what death costs (open
## question 2). Guessing at those now would be inventing design.

## The seed this run was generated from. Shareable: the same value reproduces the
## same delve on any machine.
var run_seed: int = 0
## The room ids this run will visit, decided up front from the seed.
var run_plan: Array[StringName] = []
## How many rooms deep we currently are, 0-based.
var depth: int = 0
var run_active: bool = false


func begin_run(seed_value: int, plan: Array[StringName]) -> void:
	run_seed = seed_value
	run_plan = plan
	depth = 0
	run_active = true
	Events.run_started.emit(seed_value)


func end_run() -> void:
	run_active = false
	run_plan = []
	depth = 0


## A human-shareable form of the seed. M8's daily mode and any "seed of the day"
## chat needs this to round-trip through Rng.seed_from_text().
func seed_text() -> String:
	return str(run_seed)
