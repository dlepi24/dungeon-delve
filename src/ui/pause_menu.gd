extends CanvasLayer
## The pause menu: Resume, Settings, Quit to title. Nothing else — the seed
## replay and new-run dev affordances moved into the settings screen's run
## section, so pausing reads like a product, not a debug panel.
##
## Everything here runs with process_mode = ALWAYS, since the tree is paused
## while it is open; a paused node cannot un-pause itself.
##
## Instanced in every playable scene (delve AND hub) — pause is a promise the
## whole game makes, not a delve feature. It found this out the hard way:
## round 2 shipped with ESC only working underground.

@onready var _panel: PanelContainer = $Panel
@onready var _resume: Button = $Panel/Margin/Rows/Resume
@onready var _settings_button: Button = $Panel/Margin/Rows/Settings
@onready var _quit_title: Button = $Panel/Margin/Rows/QuitTitle
@onready var _status: Label = $Panel/Margin/Rows/Status
@onready var _settings: Control = $SettingsMenu


func _ready() -> void:
	# The tree is paused when this is up, so it must keep processing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_settings.visible = false
	_settings.closed.connect(_on_settings_closed)
	_settings.run_action_taken.connect(_on_settings_run_action)
	_settings_button.pressed.connect(_on_settings)
	_resume.pressed.connect(_close)
	_quit_title.pressed.connect(_on_quit_to_title)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	if visible:
		_close()
	else:
		_open()


func _on_settings() -> void:
	_panel.visible = false
	_settings.open()


func _on_settings_closed() -> void:
	_settings.visible = false
	_panel.visible = true


## The settings run section restarted or abandoned the run: the pause state is
## already torn down by the settings menu, we just need to stop being visible.
func _on_settings_run_action() -> void:
	visible = false


func _open() -> void:
	Cursor.menu()
	_panel.visible = true
	_settings.visible = false
	_status.text = "room %d of %d" % [GameState.depth + 1, maxi(1, GameState.run_plan.size())] \
		if GameState.run_active else "the surface"
	visible = true
	get_tree().paused = true


func _close() -> void:
	visible = false
	get_tree().paused = false
	Cursor.gameplay()


## Souls-style exit: back to the title, and the full app quit lives there. Same
## forfeit rules as abandoning to the hub — quitting mid-run is walking away.
func _on_quit_to_title() -> void:
	GameState.end_run()
	_close()
	get_tree().change_scene_to_file.call_deferred("res://src/main/main.tscn")
