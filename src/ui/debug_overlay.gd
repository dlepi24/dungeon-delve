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
@export var dummy: TrainingDummy
## Toggled with the debug_toggle action (F3). A dev tool, not a combat verb, so it
## does not spend from the GDD's ~10 verb budget. Ships hidden: a debug panel on
## by default reads as a broken game, and M7 is the "reads like a game" pass.
@export var start_visible: bool = false

@onready var _label: Label = $Panel/Margin/Label

## Ticks to keep the PARRY banner up after one lands. Purely so a 120 ms window
## does not vanish before you can see that it worked.
const PARRY_FLASH_TICKS: int = 40

var _parry_flash: int = 0
## Current room id, from room_entered. Dev info that used to live on the
## always-visible delve HUD; the seed and full plan are F3 material, not player UI.
var _room_id: String = ""


func _ready() -> void:
	visible = start_visible
	Events.parry_succeeded.connect(_on_parry_succeeded)
	Events.room_entered.connect(func(_index: int, room_id: String) -> void: _room_id = room_id)


func _on_parry_succeeded() -> void:
	_parry_flash = PARRY_FLASH_TICKS


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"debug_toggle"):
		visible = not visible
	if not visible or player == null:
		return

	_parry_flash = maxi(0, _parry_flash - 1)

	var buffer: InputBuffer = player.get_buffer()
	var tick: int = player.get_tick()
	var lines: PackedStringArray = [
		"hp         %d / %d" % [roundi(player.health), roundi(player.max_health)],
		"state      %s" % player.get_state_name(),
		"tick       %d" % tick,
		"vel        %6.1f, %6.1f" % [player.velocity.x, player.velocity.y],
		"on_floor   %s" % _mark(player.is_on_floor()),
		"coyote     %s" % _mark(player.has_coyote()),
		"i-frames   %s" % _mark(player.invulnerable),
		"riposte    %s" % _riposte(),
		"buf jump   %s" % _buffered(buffer, &"jump", tick),
		"buf roll   %s" % _buffered(buffer, &"roll", tick),
		"buf attack %s" % _buffered(buffer, &"attack", tick),
		"buf parry  %s" % _buffered(buffer, &"parry", tick),
	]
	if dummy != null:
		lines.append("")
		lines.append("dummy      %s" % dummy.get_state_name())
		lines.append("dummy hp   %d" % roundi(dummy.health))
	if GameState.run_active:
		var plan: String = ""
		for id: StringName in GameState.run_plan:
			plan += "%s " % id
		lines.append("")
		lines.append("seed       %s" % GameState.seed_text())
		lines.append("room       %d/%d %s" % [GameState.depth + 1, GameState.run_plan.size(), _room_id])
		lines.append("plan       %s" % plan.strip_edges())
	if _parry_flash > 0:
		lines.append("")
		lines.append(">>> PARRY <<<")
	lines.append("")
	lines.append("F3 toggles this")
	_label.text = "\n".join(lines)


func _riposte() -> String:
	if not player.is_riposte_open():
		return "-"
	return "OPEN (%d ticks)" % player.riposte_ticks_left()


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
