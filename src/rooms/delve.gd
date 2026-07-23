class_name Delve
extends Node2D
## Assembles rooms into a run from a seed, and drives the walk through them.
##
## This is where procgen starts, and the contract is narrow on purpose: given the
## same seed, produce the same list of rooms, every time, on every machine. All
## randomness comes from Rng.stream(&"delve") — never randi(), never randf().
##
## The plan is computed UP FRONT as a list of room ids, not decided room by room
## as you walk. Two reasons. First, it is testable without playing: you can
## generate a hundred delves headlessly and diff them. Second, deciding lazily
## would let the player's actions (how long they took, how many enemies they
## killed) leak into the layout, which would make the same seed produce different
## levels for different players — quietly destroying the daily-seed mode.

const ROOM_DIR: String = "res://src/rooms/delve"

## First and last rooms are fixed; the middle is drawn from the current ZONE's
## pool. "entry" is deliberately gentle and "deep" is the biggest fight, so a
## run has a shape rather than being uniform noise.
const FIRST_ROOM: StringName = &"entry"
const LAST_ROOM: StringName = &"deep"
## The rest stop: a lit camp with no enemies, inserted before the deep room so
## the run breathes once before the boss. A pacing beat, not a combat room —
## it never counts toward depth economy and the mine never rains debris on it.
const CAMP_ROOM: StringName = &"camp"
## Union of every zone's room_pool, kept for tests and as the fallback if a
## zone resource fails to load. Zones narrow this per depth band.
const MIDDLE_POOL: Array[StringName] = [
	&"gap", &"climb", &"arena", &"corridor", &"cavern", &"shaft", &"gallery",
]
## Double-wide centrepiece rooms. Every run gets EXACTLY ONE, at a seeded
## depth — in the general pool they appeared one run in three, which read as
## never. Kept out of MIDDLE_POOL so a run cannot draw two. Which centrepiece
## appears follows the ZONE the big slot lands in (halls are Upper timber,
## the undercroft is the Vein's covered lane, the chasm plunges into the
## Deadlight) — so the seeded slot position also decides the room's identity.
const BIG_POOL: Array[StringName] = [&"halls", &"undercroft", &"chasm"]

## The mine's strata, shallowest first. The descent arc is FIXED (you always
## fall from timber into fire into the cold glow — that is the journey); which
## rooms fill each band stays seeded. Banding is a pure function of plan index,
## so zones cost the daily seed nothing.
const ZONE_PATHS: Array[String] = [
	"res://src/rooms/zones/upper_workings.tres",
	"res://src/rooms/zones/hot_vein.tres",
	"res://src/rooms/zones/deadlight.tres",
]

## One scene for every enemy: there are no enemy subclasses any more, only data.
const ENEMY_SCENE: String = "res://src/enemies/enemy.tscn"

## Shrine altars. A room's `S` glyph is a CANDIDATE spot; this chance decides
## per-spot (seeded) whether an altar actually stands there, so shrines are an
## event, not furniture. ~2 spots appear across a 5-room run at 5 spots / 7
## middle rooms, so 0.55 yields roughly one lit altar per delve.
const SHRINE_SCENE: String = "res://src/systems/shrine.tscn"
## Environmental hazards, spawned from room glyphs like enemies are.
const HAZARD_SCENES: Dictionary[String, String] = {
	"crumble": "res://src/systems/hazards/crumble_platform.tscn",
	"spikes": "res://src/systems/hazards/spikes.tscn",
	"anchor": "res://src/systems/timber_anchor.tscn",
}
## Debris rain: rocks per room = depth beyond the entry, plus the mine's heat
## ("heat shakes the mine loose"). The entry room never rains.
@export var debris_base_per_depth: int = 1
const SHRINE_POOL: Array[String] = [
	"res://src/systems/shrines/vein_of_greed.tres",
	"res://src/systems/shrines/blood_pact.tres",
	"res://src/systems/shrines/overseers_whisper.tres",
	"res://src/systems/shrines/misers_candle.tres",
]
@export_range(0.0, 1.0) var shrine_chance: float = 0.55
const ENEMY_STATS: Dictionary[String, String] = {
	"grunt": "res://src/enemies/data/grunt.tres",
	"brute": "res://src/enemies/data/brute.tres",
	"dart": "res://src/enemies/data/dart.tres",
	"overseer": "res://src/enemies/data/overseer.tres",
	"slinger": "res://src/enemies/data/slinger.tres",
	"gnat": "res://src/enemies/data/gnat.tres",
}

## What an authored marker may become instead (seeded draw): each kind's
## alternates share its weight class, so a room's difficulty budget holds while
## the ANSWER it demands varies — a slinger post makes you approach, a gnat
## makes the high ground contested. The FALLBACK table; zones carry their own
## lean (the Deadlight trades toward slingers and gnats, so its fights feel
## like its fiction: ranged things glowing in the dark).
const SIDEWAYS: Dictionary[String, Array] = {
	"grunt": ["dart", "slinger"],
	"dart": ["grunt", "gnat"],
}
## What the camp's guaranteed heart restores. The one in-run heal that is a
## PLACE rather than a drop: the rest stop before the deep is worth reaching.
@export var camp_heart_heal: int = 2

## Total rooms in a delve, including entry and deep.
@export var room_count: int = 5
## Chance a given depth's shaft SPLITS into a choice of two rooms. Occasional
## by design — a fork every floor made forking mundane; a rare one is an event.
@export_range(0.0, 1.0) var branch_chance: float = 0.3
## Start a run on its own at _ready. True so the scene is playable by itself.
## M5's hub will set this false, choose the seed, and call start() explicitly —
## and anything calling start() must turn this off, or the delve starts twice and
## the first room is entered twice.
@export var auto_start: bool = true
## The run's camera, told each room's size so it can clamp its scroll. Optional
## — headless tests run the Delve with no camera at all.
@export var camera: FollowCamera

## What each room id sounds like from the tunnel above it. Shown on the door
## choice — a hint, not a name, so the choice is informed but not spoiled.
const HINTS: Dictionary[StringName, String] = {
	&"entry": "the mine mouth",
	&"camp": "lantern light, and quiet",
	&"gap": "a broken floor",
	&"climb": "a long climb",
	&"arena": "an open fighting floor",
	&"corridor": "a low gallery",
	&"cavern": "gaping dark",
	&"shaft": "rising timbers",
	&"gallery": "a two-storey drop",
	&"halls": "a long dark hall",
	&"undercroft": "a covered lane, wind above",
	&"chasm": "a plunging chasm",
	&"deep": "the deep vein",
}

var _plan: Array[StringName] = []
## Per-depth candidate rooms from the seed: [ [entry], [a,b], [a,b], ..., [deep] ].
## The player's door choice at each descent picks which candidate _plan takes.
var _options: Array[Array] = []
var _index: int = -1
var _room: Room = null
var _player: Player = null
## Loaded ZoneData resources, shallowest first. Lazy — headless tests build
## Delves by the hundred and most never need the zone scenes.
var _zones: Array[ZoneData] = []
## Which zone band the run is currently in, so _advance only announces a zone
## when the band actually CHANGES. -1 = not started.
var _zone_band: int = -1
## The guided tutorial locks the whole plan to the Upper Workings: a first
## descent stays shallow, and the scripted set-piece must not inherit the
## Deadlight's grade. -1 = band normally by depth.
var _fixed_band: int = -1


func zones() -> Array[ZoneData]:
	if _zones.is_empty():
		for path: String in ZONE_PATHS:
			var zone: ZoneData = load(path) as ZoneData
			if zone != null:
				_zones.append(zone)
	return _zones


## Which zone band a plan index falls in. Pure arithmetic — no RNG, no state —
## so the daily seed pays nothing for zones and tests can call it freely.
##
## The entry is always the Upper Workings; the camp and the deep are always
## the Deadlight (the rest stop is IN the cold — its hanging lanterns against
## the spore-light is the point); the combat middles spread evenly across all
## three strata. A naive thirds-of-the-plan split banded every middle 0 or 1,
## which quietly deleted the Deadlight's combat rooms AND the chasm (its
## centrepiece) from every run — the kind of variety loss nobody errors on.
func band_for_index(index: int, plan_size: int) -> int:
	if _fixed_band >= 0:
		return _fixed_band
	var last: int = ZONE_PATHS.size() - 1
	if index <= 0 or plan_size <= 1:
		return 0
	# The tail: deep, and the camp above it when the plan carries one.
	var tail: int = 2 if plan_size >= 6 else 1
	if index >= plan_size - tail:
		return last
	var middles: int = plan_size - 1 - tail
	if middles <= 0:
		return last
	return clampi((index - 1) * ZONE_PATHS.size() / middles, 0, last)


## The ZoneData governing a plan index. Null only if the zone resources are
## missing, in which case everything falls back to the flat pools.
func zone_for_index(index: int, plan_size: int) -> ZoneData:
	var all_zones: Array[ZoneData] = zones()
	if all_zones.is_empty():
		return null
	return all_zones[clampi(band_for_index(index, plan_size), 0, all_zones.size() - 1)]


## The middle-room pool a given plan index draws from: the zone's pool, or the
## flat fallback. Public so the delve test's stream-alignment replica can
## mirror the draw pattern exactly.
func middle_pool_at(index: int, plan_size: int) -> Array[StringName]:
	var zone: ZoneData = zone_for_index(index, plan_size)
	if zone == null or zone.room_pool.is_empty():
		return MIDDLE_POOL
	var pool: Array[StringName] = []
	for id: String in zone.room_pool:
		pool.append(StringName(id))
	return pool


## The centrepiece pool for a given plan index — the zone's, or the flat one.
func big_pool_at(index: int, plan_size: int) -> Array[StringName]:
	var zone: ZoneData = zone_for_index(index, plan_size)
	if zone == null or zone.big_pool.is_empty():
		return BIG_POOL
	var pool: Array[StringName] = []
	for id: String in zone.big_pool:
		pool.append(StringName(id))
	return pool


## Total plan length for a requested combat-room count: the camp adds one when
## the run is long enough to deserve a rest (a 3-room delve has no room for
## pacing beats).
func plan_size_for(count: int) -> int:
	return count + 1 if count >= 4 else count


## Pure function of the seed: no scene loading, no side effects, so tests can
## generate delves by the hundred and compare them. Each middle depth gets TWO
## distinct candidates (one redraw, not a loop — a variable number of draws
## would make the sequence depend on what came before); the player chooses at
## the exit, which multiplies run shapes without new content.
##
## The plan descends through the zone bands: each depth draws from ITS zone's
## pool, the one big room comes from the zone its seeded slot lands in, and the
## camp sits just above the deep room — the breath before the bottom.
func options_for_seed(seed_value: int, count: int) -> Array[Array]:
	Rng.set_seed(seed_value)
	var generator: RandomNumberGenerator = Rng.stream(&"delve")

	var plan_size: int = plan_size_for(count)
	var options: Array[Array] = [[FIRST_ROOM]]
	var middles: int = maxi(0, count - 2)
	# One middle depth per run is the big-room centrepiece, seeded like all else.
	var big_slot: int = generator.randi_range(0, maxi(0, middles - 1))
	var previous: StringName = FIRST_ROOM
	for i: int in middles:
		var depth_index: int = i + 1
		if i == big_slot:
			# The centrepiece never branches: the run's one guaranteed big room
			# should not be dodgeable behind the other door. Its identity follows
			# the zone the slot landed in.
			var bigs: Array[StringName] = big_pool_at(depth_index, plan_size)
			var big: StringName = bigs[generator.randi_range(0, bigs.size() - 1)]
			options.append([big])
			previous = big
			continue
		# One redraw against repeats, one against a duplicate pair, then the
		# branch roll. Single redraws, never loops — see the original note.
		var pool: Array[StringName] = middle_pool_at(depth_index, plan_size)
		var a: StringName = pool[generator.randi_range(0, pool.size() - 1)]
		if a == previous and pool.size() > 1:
			a = pool[generator.randi_range(0, pool.size() - 1)]
		var b: StringName = pool[generator.randi_range(0, pool.size() - 1)]
		if b == a and pool.size() > 1:
			b = pool[generator.randi_range(0, pool.size() - 1)]
		var branches: bool = generator.randf() < branch_chance
		options.append([a, b] if branches and b != a else [a])
		previous = a
	if plan_size > count:
		options.append([CAMP_ROOM])
	if count >= 2:
		options.append([LAST_ROOM])
	return options


## The default path: the first candidate at every depth. What the run plan
## holds until a door choice overrides a level.
func plan_for_seed(seed_value: int, count: int) -> Array[StringName]:
	var plan: Array[StringName] = []
	for opts: Array in options_for_seed(seed_value, count):
		plan.append(opts[0])
	return plan


func get_plan() -> Array[StringName]:
	return _plan


func current_index() -> int:
	return _index


func current_room() -> Room:
	return _room


func start(seed_value: int) -> void:
	_fixed_band = -1
	_zone_band = -1
	_options = options_for_seed(seed_value, room_count)
	_plan = []
	for opts: Array in _options:
		_plan.append(opts[0])
	_index = -1
	GameState.begin_run(seed_value, _plan)
	# A restart must be a clean slate, or you carry your last run's health and
	# riposte into the new one and the comparison is worthless.
	var player: Player = _get_player()
	if player != null:
		player.reset_for_new_run()
	_advance()


## Start a FIXED, curated plan rather than one drawn from a seed — the guided
## tutorial's path. Still seeds the Rng streams and sets up run state through
## begin_run, so every reused system (rooms, enemies, shrines) behaves exactly
## as in a real delve; only the sequence is authored instead of rolled. The
## caller (TutorialDirector) sets pending_mode = &"tutorial" first, so this never
## touches the daily/ranked path.
func start_plan(plan: Array[StringName], seed_value: int = 0) -> void:
	# The guided first descent stays in the Upper Workings — see _fixed_band.
	_fixed_band = 0
	_zone_band = -1
	_options = []
	for id: StringName in plan:
		_options.append([id])
	_plan = plan.duplicate()
	_index = -1
	GameState.begin_run(seed_value, _plan)
	var player: Player = _get_player()
	if player != null:
		player.reset_for_new_run()
	_advance()


## Lazy — see the note in enemy.gd. Resolving in _ready found nothing, because
## the Delve sits above the Player in delve_run.tscn and its _ready runs first.
func _get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	return _player


## Fired once per room, when its last living enemy falls.
var _room_cleared: bool = false


func _ready() -> void:
	Events.run_restart_requested.connect(start)
	Events.enemy_died.connect(_on_enemy_died)
	if auto_start and _plan.is_empty():
		# DEFERRED, not called directly. Starting inside _ready runs before the
		# Player's own _ready, so its @onready nodes are still null and placing it
		# in the first room crashes on a state machine that does not exist yet.
		# Deferring waits until every node in the scene is ready.
		_start_today.call_deferred()


## Begin a run. Uses the seed the hub picked if there is one, otherwise today's
## daily seed so the scene is still playable on its own.
func _start_today() -> void:
	if GameState.pending_seed >= 0:
		var chosen: int = GameState.pending_seed
		GameState.pending_seed = -1
		start(chosen)
		return
	var today: Dictionary = Time.get_datetime_dict_from_system()
	start(Rng.daily_seed(today["year"], today["month"], today["day"]))


## What lies below the current room: 1 candidate (no real choice) or 2 (the
## coordinator shows the doors). Empty at the bottom.
func next_options() -> Array:
	var next: int = _index + 1
	if next >= _options.size():
		return []
	return _options[next]


## Go one room deeper, through the chosen door. Public because the run
## coordinator calls it when the player chooses to descend at an exit — the
## Delve no longer decides that itself, since "descend or extract" is a
## run-loop decision, not an assembly one.
##
## _plan and GameState.run_plan are the same array object, so writing the
## choice here updates everything that displays the plan.
func descend(choice: int = 0) -> void:
	var next: int = _index + 1
	if next < _options.size():
		var opts: Array = _options[next]
		_plan[next] = opts[clampi(choice, 0, opts.size() - 1)]
	_advance()


func _advance() -> void:
	_index += 1
	if _index >= _plan.size():
		# Cleared the whole mine. The coordinator treats this as a forced extract.
		Events.delve_completed.emit()
		return
	# Depth is run state and the Delve is the thing that knows it. This write used
	# to live in the dev HUD, which meant deleting a HUD could silently break the
	# depth-pays-more economy. The camp is a pause, not a descent: it never
	# counts, so the deep room pays the same whether or not a rest sat above it.
	GameState.depth = _combat_depth(_index)
	_load_room(_plan[_index])
	# Announce the zone BEFORE the room, so the atmosphere/music regrade is
	# already in flight when listeners react to the room itself.
	var band: int = band_for_index(_index, _plan.size())
	if band != _zone_band:
		_zone_band = band
		var zone: ZoneData = zone_for_index(_index, _plan.size())
		if zone != null:
			Events.zone_entered.emit(zone)
	Events.room_entered.emit(_index, String(_plan[_index]))


## How many combat rooms precede this index — the economy's idea of depth,
## which skips rest stops.
func _combat_depth(index: int) -> int:
	var depth: int = 0
	for j: int in index:
		if _plan[j] != CAMP_ROOM:
			depth += 1
	return depth


## The zone the run is currently standing in, for anything outside the Delve
## (the coordinator's descend prompt, the HUD) that wants to name it.
func current_zone() -> ZoneData:
	if _index < 0 or _plan.is_empty():
		return null
	return zone_for_index(_index, _plan.size())


## The zone one room deeper, or null at the bottom. The descend prompt names it
## when it differs from the current one — crossing a stratum should be felt at
## the door, not discovered after it.
func next_zone() -> ZoneData:
	var next: int = _index + 1
	if next >= _plan.size() or _plan.is_empty():
		return null
	return zone_for_index(next, _plan.size())


## True once the player is standing at the current room's exit, so the coordinator
## can offer the extract/descend choice.
func player_at_exit() -> bool:
	return _room != null and _room.is_player_in_exit_zone()


func _load_room(id: StringName) -> void:
	if _room != null:
		_room.queue_free()
		_room = null

	var packed: PackedScene = load("%s/%s.tscn" % [ROOM_DIR, id]) as PackedScene
	if packed == null:
		push_error("Delve: no room scene for id '%s'" % id)
		return
	_room = packed.instantiate() as Room
	add_child(_room)
	_room_cleared = false
	if camera != null:
		camera.set_room_bounds(_room.room_size)

	# The zone colours the rock itself (tile layers only — enemies keep their
	# greyscale telegraph-tint contract; the CanvasModulate handles the rest).
	var zone: ZoneData = zone_for_index(_index, _plan.size())
	if zone != null:
		_room.apply_zone_tint(zone.world_tint)

	_spawn_enemies(_room)
	_spawn_debris(_room)
	# The very first run of a save gets its verbs taught in the world — UNLESS
	# this is the guided intro, which teaches them itself (and superseded these
	# signs per the 2026-07-22 GDD decision). Kept as a backstop for any real
	# first delve that somehow skipped the intro.
	if id == FIRST_ROOM and GameState.total_runs == 0 and GameState.run_mode != &"tutorial":
		_room.add_child(TeachingSigns.new())
	var player: Player = _get_player()
	if player != null:
		player.teleport_to(_room.entry_position())
	else:
		push_error("Delve: no player in the 'player' group — the run cannot place you.")


## Enemies are built from the room's markers, so a room never hard-codes which
## enemy it holds — swapping the roster is a data change.
func _spawn_enemies(room: Room) -> void:
	var rng: RandomNumberGenerator = Rng.stream(&"spawns")
	for point: Dictionary in room.spawn_points():
		if point["kind"] == "shrine":
			_maybe_place_shrine(room, point["position"], rng)
			continue
		if point["kind"] == "hearth":
			# The camp's fire: pure warmth against the zone's cold grade.
			var fire: Node2D = SetDressing.make_campfire()
			fire.position = point["position"]
			room.add_child(fire)
			continue
		if point["kind"] == "heart":
			# The camp's guaranteed heal — authored, not dropped, so it takes no
			# draw from the seeded stream and every runner finds the same rest.
			var heart: Pickup = (load("res://src/systems/pickup.tscn") as PackedScene).instantiate() as Pickup
			heart.kind = Pickup.Kind.HEAL
			heart.amount = camp_heart_heal
			heart.global_position = point["position"] + Vector2(0, -8)
			room.add_child(heart)
			continue
		if HAZARD_SCENES.has(point["kind"]):
			var hazard: Node2D = (load(HAZARD_SCENES[point["kind"]]) as PackedScene).instantiate() as Node2D
			hazard.global_position = point["position"]
			room.add_child(hazard)
			continue
		var kind: String = _vary_kind(point["kind"], rng)
		if not ENEMY_STATS.has(kind):
			push_error("Delve: unknown enemy kind '%s'" % kind)
			continue
		var packed: PackedScene = load(ENEMY_SCENE) as PackedScene
		var enemy: Enemy = packed.instantiate() as Enemy
		enemy.stats = load(ENEMY_STATS[kind]) as EnemyStats
		enemy.global_position = point["position"]
		room.add_child(enemy)


## Schedule this room's ceiling debris from the seeded hazards stream. Depth
## and heat scale the count, so the same seed rains differently at different
## heat — deliberate, the same as heat's spawn promotions: heat IS difficulty.
func _spawn_debris(room: Room) -> void:
	# The camp is the one roof in the mine that holds: a rest stop that rains
	# rocks on you is not a rest stop.
	if _index >= 0 and _index < _plan.size() and _plan[_index] == CAMP_ROOM:
		return
	var count: int = maxi(0, GameState.depth - 1) * debris_base_per_depth + GameState.heat_level()
	if count <= 0:
		return
	var rng: RandomNumberGenerator = Rng.stream(&"hazards")
	var size: Vector2 = room.room_size if room.room_size != Vector2.ZERO else Vector2(1920, 640)
	var rain: DebrisRain = DebrisRain.new()
	rain.room_height = size.y
	for i: int in count:
		rain.events.append({
			"tick": rng.randi_range(240, 2600),
			"x": rng.randf_range(80.0, size.x - 80.0),
		})
	room.add_child(rain)


## The clear check: when a death leaves no living enemy standing in the current
## room, the room is CLEARED — once. Corpses linger in the group briefly, so
## the living are counted, not the members.
func _on_enemy_died(_enemy: Node2D) -> void:
	if _room == null or _room_cleared:
		return
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var other: Enemy = node as Enemy
		if other != null and not other.is_dead() and _room.is_ancestor_of(other):
			return
	_room_cleared = true
	Events.room_cleared.emit()


## Seeded twice per spot: once for whether the altar is lit, once for which
## bargain it offers. Both draws ALWAYS happen so the stream stays aligned
## whether or not the altar appears.
func _maybe_place_shrine(room: Room, at: Vector2, rng: RandomNumberGenerator) -> void:
	var lit: bool = rng.randf() < shrine_chance
	var pick: int = rng.randi_range(0, SHRINE_POOL.size() - 1)
	if not lit:
		return
	var shrine: Shrine = (load(SHRINE_SCENE) as PackedScene).instantiate() as Shrine
	shrine.data = load(SHRINE_POOL[pick]) as ShrineData
	shrine.global_position = at
	room.add_child(shrine)


## Seeded, depth-scaled variation on the authored spawns, so the same layout
## does not always hold the same fight. The ASCII marker is the room designer's
## SUGGESTION of weight class; which grunt-tier or dart-tier thing actually
## stands there varies per seed, and deeper rooms promote harder.
##
## Draws come from the seeded &"spawns" stream, never randf(): two players on
## one daily seed must meet the same monsters. The entry room (depth 0) and the
## Overseer are never varied — the gentle first room and the boss are promises,
## not suggestions.
func _vary_kind(kind: String, rng: RandomNumberGenerator) -> String:
	if kind == "overseer" or _index <= 0:
		return kind
	# Sideways variety: an authored post may hold any same-weight alternate —
	# the CURRENT ZONE's alternates, so the Deadlight's posts lean toward
	# slingers and gnats while the Upper Workings stay classic. Both draws
	# ALWAYS happen so the stream stays aligned across rooms, and the zone only
	# changes what a draw MEANS, never how many draws occur.
	var zone: ZoneData = zone_for_index(_index, _plan.size())
	var swap_chance: float = zone.swap_chance if zone != null else 0.45
	var swap: bool = rng.randf() < swap_chance
	var pick: int = rng.randi_range(0, 255)
	if swap:
		var alts: Array = _sideways_for(kind, zone)
		if not alts.is_empty():
			kind = alts[pick % alts.size()]
	# Depth promotion: the mine grows meaner as it pays better — meaner still
	# under a curse bargain (Overseer's Whisper), a hot extract streak, or the
	# Hot Vein's heavier garrison (its promote_bonus).
	var promote: float = 0.08 * float(GameState.depth) \
		+ GameState.modifier_promote_bonus() + GameState.heat_promote_bonus() \
		+ (zone.promote_bonus if zone != null else 0.0)
	if kind != "brute" and rng.randf() < promote:
		kind = "brute"
	return kind


## The swap table for a marker kind: the zone's, or the flat fallback.
func _sideways_for(kind: String, zone: ZoneData) -> Array:
	if zone != null:
		if kind == "grunt" and not zone.grunt_swaps.is_empty():
			return Array(zone.grunt_swaps)
		if kind == "dart" and not zone.dart_swaps.is_empty():
			return Array(zone.dart_swaps)
	return SIDEWAYS.get(kind, [])

