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

# --- Daily Delve (M8) ---
# One seed per calendar day, same on every machine, ONE ranked attempt
# (Dustin's rules, 2026-07-18): the first daily run of the day is THE run —
# the attempt is spent at run START, so quitting out cannot refund a bad
# opening. Replays of the seed are practice. Dailies play at heat 0 and on the
# bare pickaxe (session weapons wait for free runs), and never touch the heat
# streak: every player faces the same mine.
## What the next begin_run is: &"free" or &"daily". Consumed by begin_run.
var pending_mode: StringName = &"free"
## The live run's mode.
var run_mode: StringName = &"free"
## Whether the live run is the day's ranked daily attempt.
var run_ranked: bool = false
## Date (YYYY-MM-DD) whose ranked daily attempt has been spent. Persisted.
var daily_played: String = ""


func today_string() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [now["year"], now["month"], now["day"]]


func daily_available() -> bool:
	return daily_played != today_string()

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

# --- Mine heat (persistent, reset by DEATH) ---
# Dustin's call (2026-07-17): every extraction you survive makes the mine
# angrier — enemies tougher, harder spawn mixes, but richer ore. Death cools it
# to zero along with everything else death costs. This is the answer to
# "permanent upgrades let me roflstomp": the mine levels up alongside you, and
# the streak itself becomes a thing you are afraid to lose.
## Consecutive extractions since the last death. Saved with the meta save.
var mine_heat: int = 0

# Per-heat scaling knobs. Same tuning discipline as depth_haul_bonus above.
var heat_health_per: float = 0.12
var heat_damage_per: float = 0.10
var heat_ore_per: float = 0.08
var heat_promote_per: float = 0.05
## Scaling stops compounding past this streak, so a long streak stays hard
## rather than becoming arithmetically unwinnable.
var heat_cap: int = 8


func heat_level() -> int:
	# The daily is a level playing field: the same seed must be the same mine
	# for everyone, whatever their streak. One choke point covers all heat
	# scaling — enemies, promotions, ore, debris all route through here.
	if run_mode == &"daily":
		return 0
	return mini(mine_heat, heat_cap)


func heat_health_multiplier() -> float:
	return 1.0 + heat_health_per * float(heat_level())


func heat_damage_multiplier() -> float:
	return 1.0 + heat_damage_per * float(heat_level())


## Extra spawn-promotion chance from the streak; stacks with curse bargains.
func heat_promote_bonus() -> float:
	return heat_promote_per * float(heat_level())


# --- Meta stats (persistent) ---
# The career record: the game remembering you played it. Shown on the title
# screen. Updated INSIDE extract()/lose_run() rather than via Events listeners,
# because those methods save_game() before their signals fire — a listener would
# always be one save behind.
## Runs finished, by either exit: extraction or death.
var total_runs: int = 0
## Unix time of the last death, for the title screen's "days since last
## collapse" flavor counter. 0 = never died.
var last_collapse_unix: int = 0
## Deepest room ever reached, 1-based ("room 3"). 0 = never delved.
var deepest_room: int = 0
## Most haul banked in a single extract.
var best_haul: int = 0
## Enemies killed, ever. Counted here (not per-run) via enemy_died.
var total_kills: int = 0
## Whether the player has finished (or skipped) the guided intro, "The First
## Descent." First-run-gated: false on a fresh save routes the first DESCEND into
## the tutorial instead of the hub. Wiped by New Game like everything else.
var intro_seen: bool = false
## Whether the player has been shown the hub the first time. Gates the one-time
## surface tour: on the first hub arrival the building prompts explain the whole
## loop (trade / smith / go deeper), then revert to terse the moment you descend.
var hub_toured: bool = false

## How much richer each room deeper is. Room 0 (entry) pays 1x; each step down
## adds this. At the default 0.35 the deep room pays ~2.4x, which is the whole
## mechanical reason to push your luck rather than extract early. Tune to taste.
var depth_haul_bonus: float = 0.35


## The haul multiplier at the current depth. Deeper = more, so greed pays —
## greedier still with an ore bargain accepted, and a hot mine pays for its
## danger too (heat raises risk AND reward, per the not-punishing rule).
func depth_haul_multiplier() -> float:
	return (1.0 + float(depth) * depth_haul_bonus) * modifier_product(&"ore_mult") \
		* (1.0 + heat_ore_per * float(heat_level()))


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
	run_mode = pending_mode
	pending_mode = &"free"
	run_ranked = false
	if run_mode == &"daily" and daily_available():
		# The ranked attempt is spent NOW, not at the end — abandoning a bad
		# start must not refund the one shot.
		run_ranked = true
		daily_played = today_string()
		save_game()
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
	Events.banked_changed.emit(banked_haul)
	var extracted: int = carried_haul
	carried_haul = 0
	run_active = false
	_record_run_end()
	best_haul = maxi(best_haul, extracted)
	if run_mode != &"daily":
		mine_heat += 1
	_log_run(&"extracted", extracted)
	save_game()
	Events.run_extracted.emit(extracted)


## Died in the mine. Everything carried is lost — only banked survives.
## The depth still counts: you reached it, dying there does not unreach it.
func lose_run() -> void:
	var lost: int = carried_haul
	carried_haul = 0
	run_active = false
	if run_mode != &"daily":
		# A daily death costs the daily, not the career: the streak and the
		# session weapons belong to free play and were never brought along.
		clear_session_loadout()
		mine_heat = 0
	last_collapse_unix = int(Time.get_unix_time_from_system())
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
		"mode": String(run_mode),
		"ranked": run_ranked,
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
	run_mode = &"free"
	run_ranked = false
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
	Events.banked_changed.emit(banked_haul)
	save_game()
	return true


## Spend banked haul to raise an upgrade a level. Returns whether it happened, so
## the vendor UI does not have to re-check affordability itself.
func buy_upgrade(id: StringName, cost: int) -> bool:
	if not can_afford(cost):
		return false
	banked_haul -= cost
	upgrade_levels[id] = upgrade_level(id) + 1
	Events.banked_changed.emit(banked_haul)
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
	config.set_value("meta", "mine_heat", mine_heat)
	config.set_value("meta", "daily_played", daily_played)
	config.set_value("stats", "total_runs", total_runs)
	config.set_value("stats", "last_collapse_unix", last_collapse_unix)
	config.set_value("stats", "deepest_room", deepest_room)
	config.set_value("stats", "best_haul", best_haul)
	config.set_value("stats", "total_kills", total_kills)
	config.set_value("meta", "intro_seen", intro_seen)
	config.set_value("meta", "hub_toured", hub_toured)
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
	mine_heat = int(config.get_value("meta", "mine_heat", 0))
	daily_played = str(config.get_value("meta", "daily_played", ""))
	total_runs = int(config.get_value("stats", "total_runs", 0))
	last_collapse_unix = int(config.get_value("stats", "last_collapse_unix", 0))
	deepest_room = int(config.get_value("stats", "deepest_room", 0))
	best_haul = int(config.get_value("stats", "best_haul", 0))
	total_kills = int(config.get_value("stats", "total_kills", 0))
	intro_seen = bool(config.get_value("meta", "intro_seen", false))
	hub_toured = bool(config.get_value("meta", "hub_toured", false))


## Wipe the save. "New game" on the title, and the tests' clean slate.
func reset_save() -> void:
	banked_haul = 0
	upgrade_levels.clear()
	carried_haul = 0
	clear_session_loadout()
	total_runs = 0
	last_collapse_unix = 0
	deepest_room = 0
	best_haul = 0
	total_kills = 0
	mine_heat = 0
	daily_played = ""
	intro_seen = false
	hub_toured = false
	active_modifiers.clear()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(HISTORY_PATH)
