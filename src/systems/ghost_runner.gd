class_name GhostRunner
extends Node2D
## The translucent echo of today's ranked daily, racing you through practice
## runs of the same seed. It runs on its own clock: wherever the ranked run
## was at this moment, that is where the ghost is — ahead of you, behind you,
## or in another room entirely (it only renders in the room you share).
##
## Pure playback of the GhostRecorder's tape. No collision, no interaction,
## no gameplay: a memory with a lantern.

const TAPE_PATH: String = "user://daily_ghost.dat"

var _rooms: PackedInt32Array = []
var _positions: PackedVector2Array = []
var _facings: PackedInt32Array = []
var _stride: int = 3
var _tick: int = 0
var _room_index: int = 0
var _active: bool = false

var _body: ColorRect = null


func _ready() -> void:
	z_index = 15
	_body = ColorRect.new()
	_body.size = Vector2(28, 56)
	_body.position = Vector2(-14, -56)
	_body.color = Color(0.6, 0.82, 1.0, 0.3)
	add_child(_body)
	visible = false
	Events.run_started.connect(_on_run_started)
	Events.room_entered.connect(func(index: int, _id: String) -> void: _room_index = index)


## The ghost only rises for PRACTICE runs of the seed it was recorded on: the
## ranked attempt itself is unaccompanied — one shot, alone in the dark.
func _on_run_started(seed_value: int) -> void:
	_active = false
	visible = false
	_tick = 0
	_room_index = 0
	if GameState.run_mode != &"daily" or GameState.run_ranked:
		return
	if not FileAccess.file_exists(TAPE_PATH):
		return
	var file: FileAccess = FileAccess.open(TAPE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = file.get_var()
	if not (data is Dictionary):
		return
	var tape: Dictionary = data
	if int(tape.get("seed", -1)) != seed_value:
		return
	_rooms = tape.get("rooms", PackedInt32Array())
	_positions = tape.get("positions", PackedVector2Array())
	_facings = tape.get("facings", PackedInt32Array())
	_stride = maxi(1, int(tape.get("stride", 3)))
	_active = not _positions.is_empty()


func _physics_process(_delta: float) -> void:
	if not _active or Hitstop.is_frozen():
		return
	_tick += 1
	var index: int = _tick / _stride
	if index >= _positions.size():
		# The tape ran out: the ranked run ended here. The ghost fades rather
		# than standing forever at its own grave.
		_active = false
		visible = false
		return
	if _rooms[index] != _room_index:
		visible = false
		return
	visible = true
	# Interpolate between samples so 20 Hz reads as motion, not teleports.
	var t: float = float(_tick % _stride) / float(_stride)
	var target: Vector2 = _positions[index]
	if index + 1 < _positions.size() and _rooms[index + 1] == _room_index:
		target = _positions[index].lerp(_positions[index + 1], t)
	global_position = target
	_body.scale.x = float(_facings[index])
