class_name RoomSkirt
extends Node2D
## The rock under the floor. The touch camera may look PAST the room's bottom
## bound (FollowCamera's overscan — the lever that lifts the character out of
## the thumb band), and without this that space is void: the world reads as a
## floating island with a hole under it. This draws a rock face fading to
## black below the room, and a thin margin past the side walls for the
## horizontal overscan. Visual only; created by FollowCamera on touch, never
## exists on desktop.

## How far below the room bottom the rock reaches before going fully black.
## Comfortably past the camera's touch_overscan_bottom.
const DEPTH: float = 460.0
## Sideways reach past the room walls (covers touch_overscan_x plus shake).
const SIDE: float = 220.0
## Matches the baked tileset's dark rock, then sinks to the void colour.
const ROCK: Color = Color(0.135, 0.11, 0.088, 1.0)
const VOID: Color = Color(0.015, 0.012, 0.01, 1.0)
const STRIPS: int = 12

var _room_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	z_index = -10


func set_room(size: Vector2) -> void:
	if size == _room_size:
		return
	_room_size = size
	queue_redraw()


func _draw() -> void:
	if _room_size == Vector2.ZERO:
		return
	var width: float = _room_size.x + SIDE * 2.0
	# Side margins: solid rock beside the walls, floor level upward a little,
	# so horizontal overscan at a room edge meets stone rather than void.
	draw_rect(Rect2(-SIDE, -SIDE, SIDE, _room_size.y + SIDE), ROCK)
	draw_rect(Rect2(_room_size.x, -SIDE, SIDE, _room_size.y + SIDE), ROCK)
	# Below the floor: strips easing rock into void, a cheap baked gradient.
	var strip_h: float = DEPTH / float(STRIPS)
	for i: int in STRIPS:
		var t: float = float(i) / float(STRIPS - 1)
		var col: Color = ROCK.lerp(VOID, ease(t, 0.7))
		draw_rect(Rect2(-SIDE, _room_size.y + strip_h * float(i), width, strip_h + 1.0), col)
