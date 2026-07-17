extends Control
## The settings screen: music volume, window mode, and the key rebinder.
## Reachable from the title menu and from pause.
##
## Thin by design — every row just calls into the autoload that owns the state
## (Settings for volume/window, Keybinds via the embedded KeybindScreen), so
## opening this from two places cannot produce two divergent behaviours.

signal closed
## A run-section action (replay seed / abandon) tore the pause state down and is
## changing scenes — whoever hosts this menu should stop being visible.
signal run_action_taken

@onready var _panel: PanelContainer = $Panel
@onready var _volume: HSlider = $Panel/Margin/Rows/VolumeRow/Slider
@onready var _volume_value: Label = $Panel/Margin/Rows/VolumeRow/Value
@onready var _fullscreen: CheckButton = $Panel/Margin/Rows/FullscreenRow/Toggle
@onready var _controls: Button = $Panel/Margin/Rows/Controls
@onready var _back: Button = $Panel/Margin/Rows/Back
@onready var _keybinds: Control = $KeybindScreen
@onready var _run_sep: HSeparator = $Panel/Margin/Rows/RunSep
@onready var _seed_row: HBoxContainer = $Panel/Margin/Rows/SeedRow
@onready var _seed_field: LineEdit = $Panel/Margin/Rows/SeedRow/SeedField
@onready var _run_buttons: HBoxContainer = $Panel/Margin/Rows/RunButtons
@onready var _replay: Button = $Panel/Margin/Rows/RunButtons/Replay
@onready var _fresh: Button = $Panel/Margin/Rows/RunButtons/Fresh


func _ready() -> void:
	# Usable while the tree is paused (opened from the pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_keybinds.visible = false
	_keybinds.closed.connect(_on_keybinds_closed)
	_controls.pressed.connect(_on_controls)
	_back.pressed.connect(func() -> void: closed.emit())
	_volume.value_changed.connect(_on_volume_changed)
	_fullscreen.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	_replay.pressed.connect(_on_replay)
	_fresh.pressed.connect(_on_fresh)
	_seed_field.text_submitted.connect(func(_t: String) -> void: _on_replay())


## Sync the widgets from live state every time the menu opens — it can be
## changed elsewhere (another session, a hand-edited cfg) and stale widgets
## would then LIE, then clobber.
func open() -> void:
	visible = true
	_panel.visible = true
	_keybinds.visible = false
	_volume.set_value_no_signal(Settings.music_volume * 100.0)
	_volume_value.text = "%d%%" % roundi(Settings.music_volume * 100.0)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	# The run tools only exist mid-run; from the title or hub they are noise.
	var in_run: bool = GameState.run_active
	_run_sep.visible = in_run
	_seed_row.visible = in_run
	_run_buttons.visible = in_run
	if in_run:
		_seed_field.text = GameState.seed_text()


func _on_volume_changed(value: float) -> void:
	Settings.set_music_volume(value / 100.0)
	_volume_value.text = "%d%%" % roundi(value)


func _on_controls() -> void:
	_panel.visible = false
	_keybinds.visible = true


func _on_keybinds_closed() -> void:
	_keybinds.visible = false
	_panel.visible = true


## Replay whatever is in the field. Accepts a number or a word — Rng hashes
## text, so "cavern" is a perfectly good seed to share. The Delve listens on the
## Events bus, so no direct reference is needed.
func _on_replay() -> void:
	if not GameState.run_active:
		return
	var seed_value: int = Rng.seed_from_text(_seed_field.text)
	_close_for_run_action()
	Events.run_restart_requested.emit(seed_value)


func _on_fresh() -> void:
	# Abandon this run and go back to the hub. Abandoning is NOT extracting: you
	# forfeit the carried haul, same as walking away from the mine.
	GameState.end_run()
	_close_for_run_action()
	get_tree().change_scene_to_file.call_deferred("res://src/hub/hub.tscn")


## Run actions leave menu-land entirely: unpause, restore the gameplay cursor,
## and tell the host (pause menu) to stand down.
func _close_for_run_action() -> void:
	visible = false
	get_tree().paused = false
	Cursor.gameplay()
	run_action_taken.emit()
