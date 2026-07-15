extends CanvasLayer
## Live read-out of what the player's state machine believes is happening.
##
## Feel is subjective, but "the jump got eaten" is usually a testable claim. When
## something reads wrong, this shows whether the buffer caught the press, whether
## coyote was live, and which state actually ran — which is the difference between
## tuning a number and guessing at one.
##
## Visuals only, so it lives in _process. No gameplay logic here, ever.

@export var player: Player
## Toggled with the debug_toggle action (F3). A dev tool, not a combat verb, so it
## does not spend from the GDD's ~10 verb budget.
@export var start_visible: bool = true

@onready var _label: Label = $Panel/Margin/Label


func _ready() -> void:
	visible = start_visible


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"debug_toggle"):
		visible = not visible
	if not visible or player == null:
		return

	var buffer: InputBuffer = player.get_buffer()
	var tick: int = player.get_tick()
	var lines: PackedStringArray = [
		"state      %s" % player.get_state_name(),
		"tick       %d" % tick,
		"vel        %6.1f, %6.1f" % [player.velocity.x, player.velocity.y],
		"on_floor   %s" % _mark(player.is_on_floor()),
		"coyote     %s" % _mark(player.has_coyote()),
		"i-frames   %s" % _mark(player.invulnerable),
		"buf jump   %s" % _buffered(buffer, &"jump", tick),
		"buf roll   %s" % _buffered(buffer, &"roll", tick),
		"",
		"F3 toggles this",
	]
	_label.text = "\n".join(lines)


func _mark(value: bool) -> String:
	return "YES" if value else "-"


## Shows how stale a buffered press is, in ticks, against the live window.
func _buffered(buffer: InputBuffer, action: StringName, tick: int) -> String:
	var age: int = buffer.ticks_since(action, tick)
	if age < 0:
		return "-"
	var window: int = player.ms_to_ticks(player.input_buffer_ms)
	if age > window:
		return "expired"
	return "%d/%d ticks" % [age, window]
