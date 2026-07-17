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

# --- Session state (survives runs, not the app) ---
# Locked 2026-07-17: coming out of the mine ALIVE banks your weapon loadout the
# same way it banks your haul — extract, walk around the hub, descend again,
# still armed. Death loses it with everything else. Deliberately NOT saved to
# disk: "as long as you don't die or quit" is the rule, so an app quit is a
# surrender too. That keeps found weapons an in-session treasure rather than
# permanent inventory (permanent weapons are a vendor/blacksmith matter).
var session_weapons: Array[WeaponData] = []
var session_active_slot: int = 0


## The player reports every loadout change here, so whatever scene rebuilds the
## player next can re-arm it without the two ever talking directly.
func store_loadout(weapons: Array[WeaponData], active: int) -> void:
	session_weapons = weapons.duplicate()
	session_active_slot = active


func clear_session_loadout() -> void:
	session_weapons.clear()
	session_active_slot = 0


# --- Meta state (persistent) ---
## Haul you have successfully extracted. The vendor currency.
var banked_haul: int = 0
## Permanent upgrade levels bought at the hub, by id. Stacks across runs.
var upgrade_levels: Dictionary[StringName, int] = {}

# --- Meta stats (persistent) ---
# The career record: the game remembering you played it. Shown on the title
# screen. Updated INSIDE extract()/lose_run() rather than via Events listeners,
# because those methods save_game() before their signals fire — a listener would
# always be one save behind.
## Runs finished, by either exit: extraction or death.
var total_runs: int = 0
## Deepest room ever reached, 1-based ("room 3"). 0 = never delved.
var deepest_room: int = 0
## Most haul banked in a single extract.
var best_haul: int = 0
## Enemies killed, ever. Counted here (not per-run) via enemy_died.
var total_kills: int = 0

## How much richer each room deeper is. Room 0 (entry) pays 1x; each step down
## adds this. At the default 0.35 the deep room pays ~2.4x, which is the whole
## mechanical reason to push your luck rather than extract early. Tune to taste.
var depth_haul_bonus: float = 0.35


## The haul multiplier at the current depth. Deeper = more, so greed pays.
func depth_haul_multiplier() -> float:
	return 1.0 + float(depth) * depth_haul_bonus


func _ready() -> void:
	load_game()
	# Kills are the one stat no run-end method sees, so they are counted here.
	# Persisted by the next save (run end or vendor purchase) — a mid-run quit
	# loses them, same as it loses the run, which is the roguelite contract.
	Events.enemy_died.connect(func(_enemy: Node2D) -> void: total_kills += 1)


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
	_record_run_end()
	best_haul = maxi(best_haul, extracted)
	save_game()
	Events.run_extracted.emit(extracted)


## Died in the mine. Everything carried is lost — only banked survives.
## The depth still counts: you reached it, dying there does not unreach it.
func lose_run() -> void:
	var lost: int = carried_haul
	carried_haul = 0
	run_active = false
	clear_session_loadout()
	_record_run_end()
	save_game()
	Events.run_lost.emit(lost)


func _record_run_end() -> void:
	total_runs += 1
	deepest_room = maxi(deepest_room, depth + 1)


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


## Spend banked haul on something that is not an upgrade (the blacksmith's
## weapons). Returns whether it happened.
func spend_banked(amount: int) -> bool:
	if not can_afford(amount):
		return false
	banked_haul -= amount
	save_game()
	return true


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
	config.set_value("stats", "total_runs", total_runs)
	config.set_value("stats", "deepest_room", deepest_room)
	config.set_value("stats", "best_haul", best_haul)
	config.set_value("stats", "total_kills", total_kills)
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
	total_runs = int(config.get_value("stats", "total_runs", 0))
	deepest_room = int(config.get_value("stats", "deepest_room", 0))
	best_haul = int(config.get_value("stats", "best_haul", 0))
	total_kills = int(config.get_value("stats", "total_kills", 0))


## Wipe the save. "New game" on the title, and the tests' clean slate.
func reset_save() -> void:
	banked_haul = 0
	upgrade_levels.clear()
	carried_haul = 0
	clear_session_loadout()
	total_runs = 0
	deepest_room = 0
	best_haul = 0
	total_kills = 0
	DirAccess.remove_absolute(SAVE_PATH)
