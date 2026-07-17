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
## Silent run history, one JSON record per line, newest last. No UI reads it
## yet — it exists so the M8 leaderboards and daily mode have a past to rank;
## records not written now are gone forever. Wiped by New Game with the rest.
const HISTORY_PATH: String = "user://run_history.jsonl"
const HISTORY_CAP: int = 200

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

## Shrine bargains accepted THIS run (GDD 2026-07-17). Rest-of-run, stacking,
## cleared with the rest of run state. The player's stat functions and the haul
## multiplier fold these in, same pattern as buffs.
var active_modifiers: Array[ShrineData] = []
## Kills this run, for the run-history record. Career total is total_kills.
var run_kills: int = 0


func apply_modifier(shrine: ShrineData) -> void:
	if shrine == null:
		return
	active_modifiers.append(shrine)
	Events.shrine_accepted.emit(shrine)


## Product of one named multiplier across every accepted bargain. 1.0 with none.
func modifier_product(field: StringName) -> float:
	var product: float = 1.0
	for shrine: ShrineData in active_modifiers:
		product *= shrine.get(field)
	return product


## Extra spawn-promotion chance from curse bargains. The delve adds this to its
## depth scaling, so "harder foes" rides the existing variation system.
func modifier_promote_bonus() -> float:
	var bonus: float = 0.0
	for shrine: ShrineData in active_modifiers:
		bonus += shrine.promote_bonus
	return bonus


## Spend carried (at-risk) ore — the Miser's Candle style of price. Announced so
## the HUD count moves.
func spend_carried(amount: int) -> bool:
	if amount <= 0:
		return true
	if carried_haul < amount:
		return false
	carried_haul -= amount
	Events.haul_changed.emit(carried_haul)
	return true

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


## The haul multiplier at the current depth. Deeper = more, so greed pays —
## and greedier still with an ore bargain accepted.
func depth_haul_multiplier() -> float:
	return (1.0 + float(depth) * depth_haul_bonus) * modifier_product(&"ore_mult")


func _ready() -> void:
	load_game()
	# Kills are the one stat no run-end method sees, so they are counted here.
	# Persisted by the next save (run end or vendor purchase) — a mid-run quit
	# loses them, same as it loses the run, which is the roguelite contract.
	Events.enemy_died.connect(func(_enemy: Node2D) -> void: total_kills += 1; run_kills += 1)


func begin_run(seed_value: int, plan: Array[StringName]) -> void:
	run_seed = seed_value
	run_plan = plan
	depth = 0
	carried_haul = 0
	active_modifiers.clear()
	run_kills = 0
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
	_log_run(&"extracted", extracted)
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
	_log_run(&"died", lost)
	save_game()
	Events.run_lost.emit(lost)


func _record_run_end() -> void:
	total_runs += 1
	deepest_room = maxi(deepest_room, depth + 1)


## Append this run to the history file, trimming the oldest past the cap.
func _log_run(outcome: StringName, amount: int) -> void:
	var record: Dictionary = {
		"at": Time.get_datetime_string_from_system(),
		"seed": run_seed,
		"outcome": String(outcome),
		"amount": amount,
		"room": depth + 1,
		"kills": run_kills,
	}
	var lines: PackedStringArray = []
	if FileAccess.file_exists(HISTORY_PATH):
		var reader: FileAccess = FileAccess.open(HISTORY_PATH, FileAccess.READ)
		if reader != null:
			while not reader.eof_reached():
				var line: String = reader.get_line()
				if not line.is_empty():
					lines.append(line)
	lines.append(JSON.stringify(record))
	while lines.size() > HISTORY_CAP:
		lines.remove_at(0)
	var writer: FileAccess = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if writer == null:
		return
	for line: String in lines:
		writer.store_line(line)


func end_run() -> void:
	run_active = false
	run_plan = []
	depth = 0
	carried_haul = 0
	active_modifiers.clear()


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
	active_modifiers.clear()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(HISTORY_PATH)
