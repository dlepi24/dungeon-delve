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

## First and last rooms are fixed; the middle is drawn from this pool. "entry" is
## deliberately gentle and "deep" is the biggest fight, so a run has a shape
## rather than being uniform noise.
const FIRST_ROOM: StringName = &"entry"
const LAST_ROOM: StringName = &"deep"
const MIDDLE_POOL: Array[StringName] = [&"gap", &"climb", &"arena", &"corridor"]

## One scene for every enemy: there are no enemy subclasses any more, only data.
const ENEMY_SCENE: String = "res://src/enemies/enemy.tscn"
const ENEMY_STATS: Dictionary[String, String] = {
	"grunt": "res://src/enemies/data/grunt.tres",
	"brute": "res://src/enemies/data/brute.tres",
	"dart": "res://src/enemies/data/dart.tres",
}

## Total rooms in a delve, including entry and deep.
@export var room_count: int = 5
## Start a run on its own at _ready. True so the scene is playable by itself.
## M5's hub will set this false, choose the seed, and call start() explicitly —
## and anything calling start() must turn this off, or the delve starts twice and
## the first room is entered twice.
@export var auto_start: bool = true

var _plan: Array[StringName] = []
var _index: int = -1
var _room: Room = null
var _player: Player = null


## Pure function of the seed: no scene loading, no side effects, so tests can
## generate delves by the hundred and compare them.
##
## Avoids repeating the previous room where it can, because two identical rooms
## back to back reads as a bug even when it is legitimately random.
func plan_for_seed(seed_value: int, count: int) -> Array[StringName]:
	Rng.set_seed(seed_value)
	var generator: RandomNumberGenerator = Rng.stream(&"delve")

	var plan: Array[StringName] = [FIRST_ROOM]
	var middles: int = maxi(0, count - 2)
	var previous: StringName = FIRST_ROOM
	for i: int in middles:
		var choice: StringName = MIDDLE_POOL[generator.randi_range(0, MIDDLE_POOL.size() - 1)]
		if choice == previous and MIDDLE_POOL.size() > 1:
			# One re-draw, not a loop: a while-loop here could spin forever on a
			# pool of one, and burning a variable number of draws would make the
			# sequence depend on what came before.
			choice = MIDDLE_POOL[generator.randi_range(0, MIDDLE_POOL.size() - 1)]
		plan.append(choice)
		previous = choice
	if count >= 2:
		plan.append(LAST_ROOM)
	return plan


func get_plan() -> Array[StringName]:
	return _plan


func current_index() -> int:
	return _index


func current_room() -> Room:
	return _room


func start(seed_value: int) -> void:
	_plan = plan_for_seed(seed_value, room_count)
	_index = -1
	GameState.begin_run(seed_value, _plan)
	# A restart must be a clean slate, or you carry your last run's health and
	# riposte into the new one and the comparison is worthless.
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


func _ready() -> void:
	Events.run_restart_requested.connect(start)
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


## Go one room deeper. Public because the run coordinator calls it when the player
## chooses to descend at an exit — the Delve no longer decides that itself, since
## "descend or extract" is a run-loop decision, not an assembly one.
func descend() -> void:
	_advance()


func _advance() -> void:
	_index += 1
	if _index >= _plan.size():
		# Cleared the whole mine. The coordinator treats this as a forced extract.
		Events.delve_completed.emit()
		return
	# Depth is run state and the Delve is the thing that knows it. This write used
	# to live in the dev HUD, which meant deleting a HUD could silently break the
	# depth-pays-more economy.
	GameState.depth = _index
	_load_room(_plan[_index])
	Events.room_entered.emit(_index, String(_plan[_index]))


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

	_spawn_enemies(_room)
	var player: Player = _get_player()
	if player != null:
		player.teleport_to(_room.entry_position())
	else:
		push_error("Delve: no player in the 'player' group — the run cannot place you.")


## Enemies are built from the room's markers, so a room never hard-codes which
## enemy it holds — swapping the roster is a data change.
func _spawn_enemies(room: Room) -> void:
	for point: Dictionary in room.spawn_points():
		var kind: String = point["kind"]
		if not ENEMY_STATS.has(kind):
			push_error("Delve: unknown enemy kind '%s'" % kind)
			continue
		var packed: PackedScene = load(ENEMY_SCENE) as PackedScene
		var enemy: Enemy = packed.instantiate() as Enemy
		enemy.stats = load(ENEMY_STATS[kind]) as EnemyStats
		enemy.global_position = point["position"]
		room.add_child(enemy)

