class_name GhostRecorder
extends Node
## Records the ranked daily attempt as a position tape: room index, position
## and facing, sampled every few ticks. Written to disk when the run ends,
## replacing yesterday's tape — there is exactly one ghost, and it is today's
## ranked run.
##
## A tape, not an input log, on purpose: it is tiny, cannot desync, and stays
## valid across game updates. Input-resimulation ghosts (the GDD's determinism
## dream) can replace this later without changing what the player sees.

const TAPE_PATH: String = "user://daily_ghost.dat"
## Physics ticks between samples: 3 at the locked 60 Hz = 20 samples/second.
const SAMPLE_STRIDE: int = 3

var _rooms: PackedInt32Array = []
var _positions: PackedVector2Array = []
var _facings: PackedInt32Array = []
var _tick: int = 0
var _room_index: int = 0
var _recording: bool = false
var _player: Player = null


func _ready() -> void:
	Events.run_started.connect(_on_run_started)
	Events.room_entered.connect(func(index: int, _id: String) -> void: _room_index = index)
	Events.run_extracted.connect(func(_amount: int) -> void: _finish())
	Events.run_lost.connect(func(_amount: int) -> void: _finish())


func _on_run_started(_seed_value: int) -> void:
	_recording = GameState.run_mode == &"daily" and GameState.run_ranked
	_rooms.clear()
	_positions.clear()
	_facings.clear()
	_tick = 0
	_room_index = 0


func _physics_process(_delta: float) -> void:
	if not _recording or Hitstop.is_frozen():
		return
	_tick += 1
	if _tick % SAMPLE_STRIDE != 0:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	_rooms.append(_room_index)
	_positions.append(_player.global_position)
	_facings.append(_player.facing)


func _finish() -> void:
	if not _recording:
		return
	_recording = false
	var file: FileAccess = FileAccess.open(TAPE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_var({
		"seed": GameState.run_seed,
		"date": GameState.today_string(),
		"stride": SAMPLE_STRIDE,
		"rooms": _rooms,
		"positions": _positions,
		"facings": _facings,
	})
