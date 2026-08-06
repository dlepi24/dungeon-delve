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
## 2026-07-22: 1.45 -> 1.7 -> 1.85 across two passes; the art-director review
## asked for another ~10% in. Tighter reads intimate and Dead-Cells-like. Feel
## knob — higher = closer but you see less of the room ahead, which matters for
## telegraph reads, so tune against the combat, not just the framing. (Bounds-
## clamped, so tall rooms like the Chasm still frame their full height.)
@export var zoom_level: float = 1.85

@export_group("Touch framing")
## Everything in this group applies ONLY while touch controls are live — the
## desktop framing above passed the M1 gate and is never altered by these.
## The phone problem (Dustin, 2026-08-01): thumbs and buttons own the bottom
## band of the screen, and the desktop framing parks the character exactly
## there. These lift the character into clean glass.
## Slightly wider than desktop: telegraph reads need more room on a small
## screen, and the extra view height gives the anchor below space to work.
@export var touch_zoom_level: float = 1.55
## Where the character sits on screen, as a fraction of view height from the
## top. 0.5 = centre; lower = higher on screen, clear of the thumb band.
@export_range(0.2, 0.8) var touch_player_anchor: float = 0.45
## How far past the room's bottom edge the view may look, px. This is THE
## lever that makes the anchor possible on a room floor — without it the
## bottom clamp pins the character low no matter what. Below-floor shows dark
## mine void; if that reads wrong on device, it gets a cosmetic rock skirt.
@export var touch_overscan_bottom: float = 220.0
## Same idea sideways, so room entries don't pin you under the stick thumb.
@export var touch_overscan_x: float = 60.0

## Bounds of the current room, set by the Delve per room (variable-width rooms
## report their own size). The camera clamps inside; an axis where the view is
## bigger than the room centres instead.
var _room_size: Vector2 = Vector2(1920, 640)
## Momentary extra zoom on a parry or riposte — the camera leans IN on the
## moment of mastery, then eases back. Visual only.
var _zoom_punch: float = 0.0


func punch_zoom(amount: float = 0.05) -> void:
	_zoom_punch = maxf(_zoom_punch, amount)


## Under-floor rock fill for the touch overscan; null on desktop.
var _skirt: RoomSkirt = null


func set_room_bounds(size: Vector2) -> void:
	if size.x > 0.0 and size.y > 0.0:
		_room_size = size
		if _skirt != null:
			_skirt.set_room(_room_size)


func _clamp_to_room(goal: Vector2) -> Vector2:
	var on_touch: bool = TouchControls.is_touch_active()
	var half: Vector2 = get_viewport_rect().size * 0.5 / _active_zoom()
	var over_x: float = touch_overscan_x if on_touch else 0.0
	var over_b: float = touch_overscan_bottom if on_touch else 0.0
	if _room_size.x <= half.x * 2.0:
		goal.x = _room_size.x * 0.5
	else:
		goal.x = clampf(goal.x, half.x - over_x, _room_size.x - half.x + over_x)
	var max_y: float = _room_size.y - half.y + over_b
	if max_y <= half.y:
		# Room shorter than the view. Desktop centres it; touch pins the room's
		# FLOOR a fixed height above the view bottom instead, so the character
		# still rides above the thumb band in short rooms and the hub.
		goal.y = max_y if on_touch else _room_size.y * 0.5
	else:
		goal.y = clampf(goal.y, half.y, max_y)
	return goal


func _active_zoom() -> float:
	return touch_zoom_level if TouchControls.is_touch_active() else zoom_level

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
	# The touch camera looks below the room floor (overscan); give that space
	# rock instead of void. Deferred: adding a sibling during _ready is illegal.
	if TouchControls.is_touch_active():
		_skirt = RoomSkirt.new()
		_skirt.set_room(_room_size)
		get_parent().add_child.call_deferred(_skirt)


func add_trauma(amount: float) -> void:
	# Accessibility: honoured here so every trauma source (hits, parries, damage
	# taken, heavy enemy attacks) is silenced by the one toggle.
	if not Settings.screen_shake:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _on_hit_landed(_damage: float, was_riposte: bool, _impact: StringName, _material: StringName) -> void:
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
	zoom = Vector2.ONE * _active_zoom() * (1.0 + _zoom_punch)

	if target != null:
		# Desktop: the M1-gate framing (character low, room above). Touch: aim
		# the camera so the character sits at the anchor fraction instead.
		var goal_y: float = target.global_position.y - 200.0
		if TouchControls.is_touch_active():
			var view_h: float = get_viewport_rect().size.y / _active_zoom()
			goal_y = target.global_position.y + (0.5 - touch_player_anchor) * view_h
		var goal: Vector2 = _clamp_to_room(Vector2(target.global_position.x, goal_y))
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
