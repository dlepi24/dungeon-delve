class_name FollowCamera
extends Camera2D
## Screenshake, plus following the player.
##
## Rooms are 1920x640 and the viewport is 1920x1080, so horizontally the room
## already fits — this exists mainly to keep the room framed vertically and to
## carry the shake. The follow is deliberately STIFF (high lerp): the M1 gate was
## judged with a static camera, and a laggy camera changes how movement reads.
## If it ever needs to be loose, that is a feel change and it is Dustin's call.

@export var target: Player
## 1.0 = snap. Lower values lag behind, which muddies the feel that was signed off.
@export_range(0.05, 1.0) var follow_stiffness: float = 1.0

@export_group("View")
## How close the camera sits. 1.0 is the old static framing; higher shows less
## of the room at once, so the camera SCROLLS and the world reads bigger —
## Dustin's "feel like an actual world" call. His dial.
## Bumped from 1.45 (2026-07-22): the wider zoom left the player small in a lot
## of dead space. Tighter reads more intimate and Dead-Cells-like. Feel knob —
## higher = closer but you see less of the room ahead, which matters for
## telegraph reads, so tune against the combat, not just the framing.
@export var zoom_level: float = 1.7

## Bounds of the current room, set by the Delve per room (variable-width rooms
## report their own size). The camera clamps inside; an axis where the view is
## bigger than the room centres instead.
var _room_size: Vector2 = Vector2(1920, 640)
## Momentary extra zoom on a parry or riposte — the camera leans IN on the
## moment of mastery, then eases back. Visual only.
var _zoom_punch: float = 0.0


func punch_zoom(amount: float = 0.05) -> void:
	_zoom_punch = maxf(_zoom_punch, amount)


func set_room_bounds(size: Vector2) -> void:
	if size.x > 0.0 and size.y > 0.0:
		_room_size = size


func _clamp_to_room(goal: Vector2) -> Vector2:
	var half: Vector2 = get_viewport_rect().size * 0.5 / zoom_level
	if _room_size.x <= half.x * 2.0:
		goal.x = _room_size.x * 0.5
	else:
		goal.x = clampf(goal.x, half.x, _room_size.x - half.x)
	if _room_size.y <= half.y * 2.0:
		goal.y = _room_size.y * 0.5
	else:
		goal.y = clampf(goal.y, half.y, _room_size.y - half.y)
	return goal

@export_group("Shake")
@export_range(0.0, 1.0) var trauma_hit: float = 0.35
@export_range(0.0, 1.0) var trauma_parry: float = 0.6
@export_range(0.0, 1.0) var trauma_hurt: float = 0.45
@export var max_offset: Vector2 = Vector2(18, 12)
@export var max_roll_degrees: float = 1.5
@export var decay: float = 2.4

var _trauma: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	zoom = Vector2(zoom_level, zoom_level)
	Events.hit_landed.connect(_on_hit_landed)
	Events.parry_succeeded.connect(_on_parry_succeeded)
	Events.player_hurt.connect(_on_player_hurt)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Player


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _on_hit_landed(_damage: float, was_riposte: bool) -> void:
	add_trauma(trauma_parry if was_riposte else trauma_hit)
	if was_riposte:
		punch_zoom(0.05)


func _on_parry_succeeded() -> void:
	add_trauma(trauma_parry)
	punch_zoom(0.06)


func _on_player_hurt(_damage: float) -> void:
	add_trauma(trauma_hurt)


func _process(delta: float) -> void:
	_zoom_punch = move_toward(_zoom_punch, 0.0, 0.25 * delta)
	zoom = Vector2.ONE * zoom_level * (1.0 + _zoom_punch)

	if target != null:
		var goal: Vector2 = _clamp_to_room(Vector2(target.global_position.x, target.global_position.y - 200.0))
		global_position = global_position.lerp(goal, minf(1.0, follow_stiffness))

	if _trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = 0.0
		return
	_trauma = maxf(_trauma - decay * delta, 0.0)
	# Trauma SQUARED: small hits barely register, big ones kick. Linear reads mushy.
	var shake: float = _trauma * _trauma
	offset = Vector2(
		max_offset.x * shake * _rng.randf_range(-1.0, 1.0),
		max_offset.y * shake * _rng.randf_range(-1.0, 1.0),
	)
	rotation = deg_to_rad(max_roll_degrees) * shake * _rng.randf_range(-1.0, 1.0)
