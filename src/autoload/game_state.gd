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
	# UTC on purpose (2026-07-28): the daily is one shared day worldwide — the
	# seed, the ranked-attempt gate, and the leaderboard row all key off this
	# same string, so they must all roll over at the same instant everywhere.
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
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

# --- The Keystone System (2026-07-23 decision log) ---
## Build-path identity: &"powderhand" / &"ironback" / &"tunnel_rat", or &"" if
## none picked yet. Nothing is ever locked by this — every UpgradeData stays
## buyable to its baseline `max_level` regardless. Matching the active
## keystone just lets ITS stat(s) keep going past baseline
## (UpgradeData.effective_max_level). Dustin's call: "no lock, just a bias."
var active_keystone: StringName = &""
## Baseline every UpgradeData ships with — kept here too (not just read off
## the resource) because respec cost needs to know how many levels on ANY
## upgrade are "extended" without needing to hold UpgradeData references
## itself; GameState only ever sees plain levels.
const KEYSTONE_BASELINE_LEVEL: int = 5
var respec_base_cost: int = 80
var respec_cost_per_level: int = 60
## THE STARTING CLASS LAYER (2026-07-23): what picking a keystone grants
## instantly, so the choice DOES something the moment you make it instead of
## only widening a ceiling you still have to grind into. All three total 4
## free levels — Ironback just splits its 4 across the two stats it governs
## instead of stacking them on one, matching its already-bigger structural
## ceiling (10 extra levels available across two stats vs. 5 for the others).
## Kept here, not on UpgradeData, for the same reason KEYSTONE_BASELINE_LEVEL
## is: this file's own bookkeeping stays free of UpgradeData references.
const KEYSTONE_BONUS_LEVELS: Dictionary[StringName, Dictionary] = {
	&"powderhand": {&"damage": 4},
	&"ironback": {&"armor": 2, &"max_health": 2},
	&"tunnel_rat": {&"mobility": 4},
}
## Which keystones have ALREADY had their bonus granted, ever, on this save.
## Without this, a player could respec away and back (often free/cheap early,
## see respec_cost()) to farm the bonus repeatedly — the bonus is meant to be
## a one-time head start, not a lever.
var keystones_unlocked: Dictionary[StringName, bool] = {}
## Per-path colour, read by WeaponSprite for a subtle idle tint and the swing
## smear (src/player/weapon_sprite.gd) — NOT the player body. The player is
## explicitly never base-tinted (CLAUDE.md, and the GDD's own zone guard-
## rails: "the player's lamp stays warm in every zone... enemy sprites are
## never tinted by zones"); the weapon is the identity marker instead. Lives
## here rather than in vendor_panel.gd's KEYSTONE_LABELS because two
## different systems (the vendor UI and WeaponSprite) both need to read it,
## and GameState is the one place both already depend on.
const KEYSTONE_COLOURS: Dictionary[StringName, Color] = {
	&"powderhand": Color(1.0, 0.45, 0.15, 1.0),
	&"ironback": Color(0.58, 0.64, 0.72, 1.0),
	&"tunnel_rat": Color(0.68, 0.5, 0.88, 1.0),
}


## Levels bought past baseline, across every upgrade — only ever nonzero on
## the stat(s) belonging to whichever keystone was active when they were
## bought, since nothing else can cross baseline in the first place. This is
## what respec_cost() scales against: the more invested in your current
## build, the pricier it is to walk away from it.
func extended_levels_bought() -> int:
	var total: int = 0
	for level: int in upgrade_levels.values():
		total += maxi(0, level - KEYSTONE_BASELINE_LEVEL)
	return total


## Free to pick a keystone the first time (nothing to walk away from yet).
## After that, scales with how much you've invested past baseline — cheap to
## try early, expensive to fully hop between builds repeatedly. Not a hard
## wall: a wealthy enough player can still cycle through every keystone
## eventually, but the friction is the point, not a hard lock (see the
## "no lock, just a bias" decision — this is where that philosophy's own
## risk, drifting back toward "eventually max everything", gets pushed back on).
func respec_cost() -> int:
	# Free with nothing at stake — whether that's because no keystone has
	# ever been picked, or one is active but nothing past-baseline has been
	# bought on it yet. "Cheap to try early" means free stays free until
	# there is an actual sunk investment to walk away from, not just once.
	if active_keystone == &"" or extended_levels_bought() == 0:
		return 0
	return respec_base_cost + respec_cost_per_level * extended_levels_bought()


## Switch the active keystone, spending banked haul at respec_cost(). Returns
## whether it happened. Levels already bought are never lost or refunded —
## you just cannot buy FURTHER past-baseline levels on your old keystone's
## stat(s) until you switch back.
func respec_keystone(new_keystone: StringName) -> bool:
	if new_keystone == &"" or new_keystone == active_keystone:
		return false
	var cost: int = respec_cost()
	if not can_afford(cost):
		return false
	active_keystone = new_keystone
	_grant_keystone_bonus(new_keystone)
	if cost > 0:
		spend_banked(cost)
	else:
		save_game()
	return true


## The one-time instant bonus, first activation only. `maxi`, not `+=` — a
## player who already bought baseline levels into the stat before picking
## this keystone gets topped up to the bonus floor, not double-dipped past
## it. Every bonus lands under KEYSTONE_BASELINE_LEVEL, so this never itself
## raises respec_cost() (extended_levels_bought() only counts past baseline).
func _grant_keystone_bonus(keystone: StringName) -> void:
	if keystones_unlocked.get(keystone, false):
		return
	keystones_unlocked[keystone] = true
	for id: StringName in KEYSTONE_BONUS_LEVELS.get(keystone, {}):
		var bonus: int = KEYSTONE_BONUS_LEVELS[keystone][id]
		upgrade_levels[id] = maxi(upgrade_level(id), bonus)

# --- Mine heat (persistent, reset by DEATH) ---
# Dustin's call (2026-07-17): every extraction you survive makes the mine
# angrier — enemies tougher, harder spawn mixes, but richer ore. Death cools it
# to zero along with everything else death costs. This is the answer to
# "permanent upgrades let me roflstomp": the mine levels up alongside you, and
# the streak itself becomes a thing you are afraid to lose.
##
## UNCAPPED as of 2026-07-23 (decision log — "PAST THE FIFTH ROOM"): heat used
## to stop compounding at heat_vein_threshold. It no longer does. Honing at the
## blacksmith is deliberately uncapped and resets on death exactly like heat
## does — two greed streaks meant to race each other — but only heat had a
## ceiling, which is the actual reason a fully-honed weapon started
## one-shotting everything. Removing the ceiling puts the race back on. What
## used to be the cap is now a CONTENT gate (THE VEIN's elites start appearing
## past it) rather than a scaling one.
## Consecutive extractions since the last death. Saved with the meta save.
var mine_heat: int = 0

# Per-heat scaling knobs. Same tuning discipline as depth_haul_bonus above.
var heat_health_per: float = 0.12
var heat_damage_per: float = 0.10
var heat_ore_per: float = 0.08
var heat_promote_per: float = 0.05
## Heat past this streak is THE VEIN: elites (see EliteModifierData) start
## rolling on spawns. This used to be the scaling ceiling; it is now a content
## threshold instead — see the uncap note above.
var heat_vein_threshold: int = 8
## THE THRESHOLD (2026-07-23): the gate into the Hollow Below is a COMBINATION
## unlock, not either alone — beating Varok at least once (a permanent flag,
## the skill check) PLUS holding at least this much live heat (a streak you
## have to be currently carrying, the greed check). See threshold_open().
## Was 12 — Dustin's call after playing it: "that took too long, other
## people would've gotten bored." Lower than heat_vein_threshold (8) now,
## so a fast player can reach the Threshold before The Vein's elites start
## appearing in the ordinary mine — accepted, not fixed; re-tune together
## later if that ordering reads wrong once played more.
var heat_threshold_gate: int = 6


func heat_level() -> int:
	# The daily is a level playing field: the same seed must be the same mine
	# for everyone, whatever their streak. One choke point covers all heat
	# scaling — enemies, promotions, ore, debris all route through here.
	if run_mode == &"daily":
		return 0
	return mine_heat


func heat_health_multiplier() -> float:
	return 1.0 + heat_health_per * float(heat_level())


func heat_damage_multiplier() -> float:
	return 1.0 + heat_damage_per * float(heat_level())


## Extra spawn-promotion chance from the streak; stacks with curse bargains.
func heat_promote_bonus() -> float:
	return heat_promote_per * float(heat_level())


## Whether the current live heat streak has passed THE VEIN's threshold — the
## point past which elites start rolling on spawns. Heat 0 in daily mode reads
## as never past it, same as every other heat-gated system.
func past_vein_threshold() -> bool:
	return heat_level() > heat_vein_threshold


# --- Depth scaling (2026-07-23 decision log) ---
# The OTHER axis besides heat: enemies get tougher THIS run the deeper you go,
# independent of the cross-run streak. Long-flagged in the GDD ("depth-scaling
# enemy stats... needs Dustin's call") and never built until now. Modest on
# purpose — heat is the big lever, this is the run-local one that makes the
# deep room feel earned even at heat 0.
var depth_health_per: float = 0.05
var depth_damage_per: float = 0.04


func depth_health_multiplier() -> float:
	return 1.0 + depth_health_per * float(depth)


func depth_damage_multiplier() -> float:
	return 1.0 + depth_damage_per * float(depth)


# --- The Threshold (2026-07-23 decision log) ---
## Beating Varok, the Overseer, at least once. Permanent — the skill half of
## the gate, satisfied once and never revoked. Set from the enemy_died
## listener in _ready() below.
var overseer_defeated: bool = false


## The combination gate into the Hollow Below: the boss kill (permanent) AND
## live heat at or above the threshold (a streak you have to be currently
## carrying — the greed half). Losing your streak locks the door again until
## you rebuild it; beating Varok never has to happen twice.
func threshold_open() -> bool:
	return overseer_defeated and mine_heat >= heat_threshold_gate


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
## Highest mine_heat a run was actually played through and survived (measured
## the moment before an extraction increments the streak, i.e. the heat that
## run was scaled at). BLAZING's number for the Records screen — nearly free,
## since the tracking pattern is identical to every other stat here.
var best_heat_survived: int = 0
## Whether the player has finished (or skipped) the guided intro, "The First
## Descent." First-run-gated: false on a fresh save routes the first DESCEND into
## the tutorial instead of the hub. Wiped by New Game like everything else.
var intro_seen: bool = false
## Whether the player has been shown the hub the first time. Gates the one-time
## surface tour: on the first hub arrival the building prompts explain the whole
## loop (trade / smith / go deeper), then revert to terse the moment you descend.
var hub_toured: bool = false
## THE STARTING CLASS LAYER (2026-07-23): whether the player has extracted at
## least once, ever. Gates the vendor's keystone row — a brand-new player
## shouldn't be asked to specialize before they've felt what damage/armor/
## mobility even mean in practice. Deliberately NOT total_runs (which
## conflates extraction and death) or best_haul/mine_heat (both have false-
## negative edge cases: a 0-haul extract, or a heat streak reset by a death
## since the first extraction). Same permanent-flag shape as hub_toured
## above and overseer_defeated near the Threshold fields.
var has_extracted: bool = false

## How much richer each room deeper is. Room 0 (entry) pays 1x; each step down
## adds this. At the default 0.35 the deep room pays ~2.4x, which is the whole
## mechanical reason to push your luck rather than extract early. Tune to taste.
var depth_haul_bonus: float = 0.35


## Set by the Delve on every room load — the current zone's ore_bonus (0.0
## for zones that don't set one, i.e. the three surface zones). Same pattern
## as `depth`: GameState holds run state, Delve is the thing that knows which
## zone a room belongs to. Added for the Hollow Below (2026-07-23): a shorter
## run than the ordinary mine (4 rooms, not 5) was quietly paying LESS total
## haul than a normal run despite costing far more to reach — this is the
## zone-level premium that fixes that, on top of depth and heat unchanged.
var zone_ore_bonus: float = 0.0


## The haul multiplier at the current depth. Deeper = more, so greed pays —
## greedier still with an ore bargain accepted, a hot mine pays for its
## danger too (heat raises risk AND reward, per the not-punishing rule), and
## a zone that charges more to reach (the Hollow Below) pays a premium too.
func depth_haul_multiplier() -> float:
	return (1.0 + float(depth) * depth_haul_bonus) * modifier_product(&"ore_mult") \
		* (1.0 + heat_ore_per * float(heat_level())) * (1.0 + zone_ore_bonus)


func _ready() -> void:
	load_game()
	# Kills are the one stat no run-end method sees, so they are counted here.
	# Persisted by the next save (run end or vendor purchase) — a mid-run quit
	# loses them, same as it loses the run, which is the roguelite contract.
	Events.enemy_died.connect(func(enemy: Node2D) -> void:
		total_kills += 1
		run_kills += 1
		# THE THRESHOLD's skill check: whatever boss just fell counts as beating
		# Varok. There is exactly one is_boss enemy today; if a second boss ever
		# ships this widens to check identity, not just the flag.
		var fallen: Enemy = enemy as Enemy
		if fallen != null and fallen.stats != null and fallen.stats.is_boss and not overseer_defeated:
			overseer_defeated = true
			save_game()
	)


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
	has_extracted = true
	best_haul = maxi(best_haul, extracted)
	if run_mode != &"daily":
		# Record the streak this run was just PLAYED AT, before it climbs — that
		# is the heat "survived", not the new number the next run will face.
		best_heat_survived = maxi(best_heat_survived, mine_heat)
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
		# UTC to match today_string(): the records screen finds "today's daily"
		# by prefix-matching this against the UTC day.
		"at": Time.get_datetime_string_from_system(true),
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
	zone_ore_bonus = 0.0
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
	config.set_value("stats", "best_heat_survived", best_heat_survived)
	config.set_value("meta", "intro_seen", intro_seen)
	config.set_value("meta", "hub_toured", hub_toured)
	config.set_value("meta", "has_extracted", has_extracted)
	config.set_value("meta", "overseer_defeated", overseer_defeated)
	config.set_value("meta", "active_keystone", String(active_keystone))
	var unlocked_list: PackedStringArray = []
	for keystone: StringName in keystones_unlocked:
		if keystones_unlocked[keystone]:
			unlocked_list.append(String(keystone))
	config.set_value("meta", "keystones_unlocked", unlocked_list)
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
	best_heat_survived = int(config.get_value("stats", "best_heat_survived", 0))
	intro_seen = bool(config.get_value("meta", "intro_seen", false))
	hub_toured = bool(config.get_value("meta", "hub_toured", false))
	has_extracted = bool(config.get_value("meta", "has_extracted", false))
	overseer_defeated = bool(config.get_value("meta", "overseer_defeated", false))
	active_keystone = StringName(config.get_value("meta", "active_keystone", ""))
	keystones_unlocked.clear()
	for keystone: String in config.get_value("meta", "keystones_unlocked", PackedStringArray()):
		keystones_unlocked[StringName(keystone)] = true


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
	best_heat_survived = 0
	mine_heat = 0
	daily_played = ""
	intro_seen = false
	hub_toured = false
	has_extracted = false
	overseer_defeated = false
	active_keystone = &""
	keystones_unlocked.clear()
	active_modifiers.clear()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(HISTORY_PATH)
