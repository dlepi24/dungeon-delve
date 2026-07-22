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

@onready var _dim: ColorRect = $Dim
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
	# A controller dying mid-fight should freeze the game, not the player's
	# corpse. Skipped if something else already paused (a result screen, the
	# door choice) — stacking pause states helps nobody.
	Input.joy_connection_changed.connect(_on_joy_connection)


func _on_joy_connection(_device: int, connected: bool) -> void:
	if connected or visible or get_tree().paused:
		return
	_open()


## Start (pause) toggles; the gamepad B button (ui_cancel) also backs out of an
## open pause. On keyboard ESC matches the pause action first, so the ui_cancel
## branch is gamepad-only in practice.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if visible:
			_close()
		else:
			_open()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


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
	# No blur shader in the build yet, so PAUSE BLUR controls the dim weight:
	# on = the spec's heavy rgba(13,11,9,0.72) stand-in, off = a lighter dim.
	_dim.color = Color(0.051, 0.043, 0.035, 0.72 if Settings.pause_blur else 0.5)
	_panel.visible = true
	_settings.visible = false
	# Live run readout (spec stats strip): depth, haul at risk, ore multiplier.
	if GameState.run_active:
		var rooms: int = maxi(1, GameState.run_plan.size())
		_status.text = "DEPTH %d/%d          HAUL %d          MULT ×%.2f" % [
			GameState.depth + 1, rooms, GameState.carried_haul,
			GameState.depth_haul_multiplier(),
		]
	else:
		_status.text = "THE SURFACE"
	visible = true
	get_tree().paused = true
	# Gamepad/keyboard navigation needs a starting point — with the cursor
	# hidden, an unfocused menu is an unusable menu.
	_resume.grab_focus()


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
