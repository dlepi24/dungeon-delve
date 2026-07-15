class_name InputBuffer
extends RefCounted
## Remembers recent presses so an input fired slightly too early still counts.
##
## Without this, pressing jump 30 ms before you land simply does nothing, and the
## game feels like it ignored you. The GDD feel spec calls for a 100 ms window.
##
## Presses are stamped with the physics tick they happened on, never wall-clock
## time — see the note in player.gd about determinism.

var _watched: PackedStringArray
var _pressed_tick: Dictionary[StringName, int] = {}


func _init(actions: PackedStringArray) -> void:
	_watched = actions


## Call once per physics tick, before states run.
func poll(tick: int) -> void:
	for action: String in _watched:
		if Input.is_action_just_pressed(action):
			press(StringName(action), tick)


## Record a press directly, as though it arrived on `tick`.
##
## poll() routes through here, and it is also the seam the feel tests drive.
## They cannot use Input.action_press(): a synthetic press does not line up with
## is_action_just_pressed() the way real hardware does — _physics_process misses
## it on the tick it was injected and it surfaces around the release instead.
## Real input is unaffected. Driving this directly tests our windows and
## consume semantics rather than Godot's input plumbing.
func press(action: StringName, tick: int) -> void:
	_pressed_tick[action] = tick


func is_buffered(action: StringName, tick: int, window_ticks: int) -> bool:
	if not _pressed_tick.has(action):
		return false
	return tick - _pressed_tick[action] <= window_ticks


## Spend the press so it cannot fire twice.
func consume(action: StringName) -> void:
	_pressed_tick.erase(action)


## Ticks since the action was pressed, or -1 if never. Debug overlay only.
func ticks_since(action: StringName, tick: int) -> int:
	if not _pressed_tick.has(action):
		return -1
	return tick - _pressed_tick[action]
