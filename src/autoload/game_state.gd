extends Node
## Owner of state that outlives any single scene. Autoloaded as `GameState`.
##
## Two lifetimes live here, and keeping them distinct is the whole point:
## - RUN state: seed, plan, depth, carried haul. Wiped when a run ends, and
##   carried haul is LOST if the run ends in death — that is the greed pillar.
## - META state: banked haul, permanent upgrades. Persists across runs, saved to
##   disk. This is what "the hub grows even when runs fail" means.
##
## The meta/run split maps exactly onto the extraction decision (GDD, locked
## 2026-07-15): haul you carry is at risk until you extract it up to the surface,
## at which point it becomes banked and yours.

const SAVE_PATH: String = "user://save.cfg"

# --- Run state (volatile) ---
## The seed this run was generated from. Shareable: same value, same delve.
var run_seed: int = 0
var run_plan: Array[StringName] = []
## How many rooms deep we currently are, 0-based.
var depth: int = 0
var run_active: bool = false
## Haul gathered THIS run, not yet safe. Banked on extract, lost on death.
var carried_haul: int = 0

## Seed the hub picked for the next descent. -1 = none set (use the daily seed).
## Not persisted: a pending run does not survive a quit.
var pending_seed: int = -1

# --- Meta state (persistent) ---
## Haul you have successfully extracted. The vendor currency.
var banked_haul: int = 0
## Permanent upgrade levels bought at the hub, by id. Stacks across runs.
var upgrade_levels: Dictionary[StringName, int] = {}

## How much richer each room deeper is. Room 0 (entry) pays 1x; each step down
## adds this. At the default 0.35 the deep room pays ~2.4x, which is the whole
## mechanical reason to push your luck rather than extract early. Tune to taste.
var depth_haul_bonus: float = 0.35


## The haul multiplier at the current depth. Deeper = more, so greed pays.
func depth_haul_multiplier() -> float:
	return 1.0 + float(depth) * depth_haul_bonus


func _ready() -> void:
	load_game()


func begin_run(seed_value: int, plan: Array[StringName]) -> void:
	run_seed = seed_value
	run_plan = plan
	depth = 0
	carried_haul = 0
	run_active = true
	Events.run_started.emit(seed_value)


## Add to the at-risk pile. Announced so the HUD can react without polling.
func add_haul(amount: int) -> void:
	if amount <= 0:
		return
	carried_haul += amount
	Events.haul_changed.emit(carried_haul)


## Reached the surface alive. Carried haul becomes banked and yours.
func extract() -> void:
	banked_haul += carried_haul
	var extracted: int = carried_haul
	carried_haul = 0
	run_active = false
	save_game()
	Events.run_extracted.emit(extracted)


## Died in the mine. Everything carried is lost — only banked survives.
func lose_run() -> void:
	var lost: int = carried_haul
	carried_haul = 0
	run_active = false
	save_game()
	Events.run_lost.emit(lost)


func end_run() -> void:
	run_active = false
	run_plan = []
	depth = 0
	carried_haul = 0


# --- Upgrades ---

func upgrade_level(id: StringName) -> int:
	return upgrade_levels.get(id, 0)


func can_afford(cost: int) -> bool:
	return banked_haul >= cost


## Spend banked haul to raise an upgrade a level. Returns whether it happened, so
## the vendor UI does not have to re-check affordability itself.
func buy_upgrade(id: StringName, cost: int) -> bool:
	if not can_afford(cost):
		return false
	banked_haul -= cost
	upgrade_levels[id] = upgrade_level(id) + 1
	save_game()
	Events.upgrade_purchased.emit(id, upgrade_levels[id])
	return true


## A human-shareable form of the seed. M8's daily mode needs this to round-trip
## through Rng.seed_from_text().
func seed_text() -> String:
	return str(run_seed)


# --- Persistence ---
# Only META state is saved. A run in progress is deliberately not resumable: the
# whole tension is that a run is a single sitting you can lose.

func save_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("meta", "banked_haul", banked_haul)
	for id: StringName in upgrade_levels:
		config.set_value("upgrades", String(id), upgrade_levels[id])
	config.save(SAVE_PATH)


func load_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	banked_haul = int(config.get_value("meta", "banked_haul", 0))
	upgrade_levels.clear()
	if config.has_section("upgrades"):
		for key: String in config.get_section_keys("upgrades"):
			upgrade_levels[StringName(key)] = int(config.get_value("upgrades", key))


## Wipe the save. Dev affordance for testing the loop from zero.
func reset_save() -> void:
	banked_haul = 0
	upgrade_levels.clear()
	carried_haul = 0
	DirAccess.remove_absolute(SAVE_PATH)
