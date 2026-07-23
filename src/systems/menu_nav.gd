class_name MenuNav
extends RefCounted
## Vertical menu navigation: wraps top<->bottom, and holding ui_up/ui_down keeps
## moving after a short delay. Godot's built-in focus search does neither — it
## has no wrap, and a gamepad hold never echoes the way a physical keyboard key
## does (only OS-level key-repeat generates the echo events focus nav relies
## on), so a controller hold was dead in every menu. Same poll-every-frame shape
## as HoldInteract, just driving focus instead of a hold-to-commit prompt.
##
## Callers own an ordered Array[Control] for their menu (rebuilding it whenever
## the visible set changes — a shop restocking, run tools showing) and must
## call disable_builtin_nav on it once built. Without that, the engine's own
## single-step move on the initial press races this class's move on the same
## frame and the first press skips two items instead of one.

const REPEAT_DELAY: float = 0.4
const REPEAT_RATE: float = 0.12

var _held_dir: int = 0
var _timer: float = 0.0


## Points every control's up/down neighbor at itself, turning Godot's built-in
## focus search into a no-op so this class is the only thing moving focus.
static func disable_builtin_nav(controls: Array[Control]) -> void:
	for control: Control in controls:
		var self_path: NodePath = control.get_path()
		control.focus_neighbor_top = self_path
		control.focus_neighbor_bottom = self_path


## Poll once per frame while the menu is the live input surface. Moves focus
## within `controls`, wrapping past either end, firing on the initial press
## and then repeating at REPEAT_RATE once held past REPEAT_DELAY.
func poll(delta: float, controls: Array[Control]) -> void:
	if controls.is_empty():
		return
	var dir: int = 0
	if Input.is_action_pressed(&"ui_down"):
		dir = 1
	elif Input.is_action_pressed(&"ui_up"):
		dir = -1

	if dir == 0:
		_held_dir = 0
		_timer = 0.0
		return

	var fire: bool = false
	if dir != _held_dir:
		# New direction (including the initial press from idle): move now and
		# start the longer initial delay before repeat kicks in.
		_held_dir = dir
		_timer = REPEAT_DELAY
		fire = true
	else:
		_timer -= delta
		if _timer <= 0.0:
			_timer = REPEAT_RATE
			fire = true

	if not fire:
		return

	var current: Control = controls[0].get_viewport().gui_get_focus_owner()
	var idx: int = controls.find(current)
	if idx == -1:
		idx = 0
	controls[wrapi(idx + dir, 0, controls.size())].grab_focus()
