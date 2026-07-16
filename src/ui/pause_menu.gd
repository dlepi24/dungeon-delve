extends CanvasLayer
## Pause, restart, and seed entry.
##
## Scope note: pause and menus are M7's milestone and seed entry is M8's. This is
## deliberately pulled forward as a DEV AFFORDANCE, because it makes Dustin's
## judgement better right now — being able to replay one exact delve is the only
## way to A/B a tuning change against the same rooms rather than against a
## different level. M7 replaces this with real product UI.
##
## Everything here runs with process_mode = ALWAYS, since the tree is paused
## while it is open; a paused node cannot un-pause itself.

@export var delve: Delve

@onready var _panel: PanelContainer = $Panel
@onready var _seed_field: LineEdit = $Panel/Margin/Rows/SeedRow/SeedField
@onready var _resume: Button = $Panel/Margin/Rows/Buttons/Resume
@onready var _replay: Button = $Panel/Margin/Rows/Buttons/Replay
@onready var _fresh: Button = $Panel/Margin/Rows/Buttons/Fresh
@onready var _controls: Button = $Panel/Margin/Rows/Controls
@onready var _status: Label = $Panel/Margin/Rows/Status
@onready var _keybinds: Control = $KeybindScreen


func _ready() -> void:
	# The tree is paused when this is up, so it must keep processing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_keybinds.visible = false
	_keybinds.closed.connect(_on_keybinds_closed)
	_controls.pressed.connect(_on_controls)
	_resume.pressed.connect(_close)
	_replay.pressed.connect(_on_replay)
	_fresh.pressed.connect(_on_fresh)
	_seed_field.text_submitted.connect(func(_t: String) -> void: _on_replay())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	if visible:
		_close()
	else:
		_open()


func _on_controls() -> void:
	_panel.visible = false
	_keybinds.visible = true


func _on_keybinds_closed() -> void:
	_keybinds.visible = false
	_panel.visible = true


func _open() -> void:
	_panel.visible = true
	_keybinds.visible = false
	_seed_field.text = GameState.seed_text()
	_status.text = "room %d of %d" % [GameState.depth + 1, maxi(1, GameState.run_plan.size())]
	visible = true
	get_tree().paused = true
	_seed_field.grab_focus()


func _close() -> void:
	visible = false
	get_tree().paused = false


## Replay whatever is in the field. Accepts a number or a word — Rng hashes text,
## so "cavern" is a perfectly good seed to share.
func _on_replay() -> void:
	if delve == null:
		_status.text = "no delve to restart"
		return
	var seed_value: int = Rng.seed_from_text(_seed_field.text)
	_close()
	Events.run_restart_requested.emit(seed_value)


func _on_fresh() -> void:
	if delve == null:
		return
	# A fresh seed is the one thing here that is genuinely arbitrary, so it does
	# NOT come from the seeded service — asking Rng for a random seed would make
	# the seed depend on the seed.
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.randomize()
	_close()
	Events.run_restart_requested.emit(generator.randi())
