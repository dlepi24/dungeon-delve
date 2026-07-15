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

const ENEMY_SCENES: Dictionary[String, String] = {
	"grunt": "res://src/enemies/enemy.tscn",
	"brute": "res://src/enemies/enemy.tscn",
	"dart": "res://src/enemies/dart_enemy.tscn",
}
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
	_advance()


## Lazy — see the note in enemy.gd. Resolving in _ready found nothing, because
## the Delve sits above the Player in delve_run.tscn and its _ready runs first.
func _get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	return _player


func _ready() -> void:
	if auto_start and _plan.is_empty():
		# DEFERRED, not called directly. Starting inside _ready runs before the
		# Player's own _ready, so its @onready nodes are still null and placing it
		# in the first room crashes on a state machine that does not exist yet.
		# Deferring waits until every node in the scene is ready.
		_start_today.call_deferred()


## Run directly rather than from a hub: pick today's seed so the scene is
## playable on its own. M5 gives this a real entry point.
func _start_today() -> void:
	var today: Dictionary = Time.get_datetime_dict_from_system()
	start(Rng.daily_seed(today["year"], today["month"], today["day"]))


func _advance() -> void:
	_index += 1
	if _index >= _plan.size():
		Events.delve_completed.emit()
		return
	_load_room(_plan[_index])
	Events.room_entered.emit(_index, String(_plan[_index]))


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
	_room.exit_reached.connect(_on_exit_reached)

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
		if not ENEMY_SCENES.has(kind):
			push_error("Delve: unknown enemy kind '%s'" % kind)
			continue
		var packed: PackedScene = load(ENEMY_SCENES[kind]) as PackedScene
		var enemy: Enemy = packed.instantiate() as Enemy
		enemy.stats = load(ENEMY_STATS[kind]) as EnemyStats
		enemy.global_position = point["position"]
		room.add_child(enemy)


func _on_exit_reached() -> void:
	_advance()
