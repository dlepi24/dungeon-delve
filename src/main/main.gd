extends Control
## The title screen. First thing a player sees; the game no longer boots you
## straight into the hub mid-scene, because products start with a front door.
##
## Kept deliberately dumb: buttons route to scenes, and the one destructive
## action (New Game wipes the save) hides behind an explicit confirm. Scene
## flow is title -> hub -> delve -> hub; the title is only revisited on boot.
##
## Headless-safe by construction: tools/check.gd instantiates this scene
## without adding it to the tree, so _ready never runs there — and everything
## display-touching goes through the already-guarded Cursor helper anyway.

const HUB_SCENE: String = "res://src/hub/hub.tscn"

@onready var _play: Button = $Menu/Play
@onready var _new_game: Button = $Menu/NewGame
@onready var _settings_button: Button = $Menu/Settings
@onready var _settings: Control = $SettingsMenu
@onready var _menu: VBoxContainer = $Menu
@onready var _quit: Button = $Menu/Quit
@onready var _controls: Label = $Controls
@onready var _confirm: PanelContainer = $Confirm
@onready var _confirm_yes: Button = $Confirm/Margin/Rows/Buttons/Yes
@onready var _confirm_cancel: Button = $Confirm/Margin/Rows/Buttons/Cancel


func _ready() -> void:
	Cursor.menu()
	# Menu ambience. The autoload survives the change into the hub, so the track
	# carries through without restarting.
	Music.play(&"hub")
	_confirm.visible = false
	_play.pressed.connect(_on_play)
	_new_game.pressed.connect(func() -> void: _confirm.visible = true; _confirm_cancel.grab_focus())
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_settings_button.pressed.connect(_on_settings)
	_settings.closed.connect(_on_settings_closed)
	_confirm_yes.pressed.connect(_on_wipe_confirmed)
	_confirm_cancel.pressed.connect(func() -> void: _confirm.visible = false; _play.grab_focus())
	# "Continue" when there is a save worth continuing; the distinction tells the
	# player their progress is still here.
	if GameState.banked_haul > 0 or not GameState.upgrade_levels.is_empty():
		_play.text = "Continue"
	_refresh_controls_line()
	_play.grab_focus()


## The verbs, from the LIVE keybinds — a static hint goes stale the moment a key
## is rebound. Lesson from M2: a build that does not state its verbs gets judged
## on the verbs you happened to guess.
func _refresh_controls_line() -> void:
	_controls.text = "%s%s move   %s jump   %s roll   %s / LMB attack   %s / RMB parry   ESC pause" % [
		Keybinds.label_for(&"move_left"), Keybinds.label_for(&"move_right"),
		Keybinds.label_for(&"jump"), Keybinds.label_for(&"roll"),
		Keybinds.label_for(&"attack"), Keybinds.label_for(&"parry"),
	]


func _on_play() -> void:
	get_tree().change_scene_to_file.call_deferred(HUB_SCENE)


func _on_settings() -> void:
	_menu.visible = false
	_settings.open()


func _on_settings_closed() -> void:
	_settings.visible = false
	_menu.visible = true
	# Rebinding may have happened in there; the verbs line must not lie.
	_refresh_controls_line()
	_play.grab_focus()


func _on_wipe_confirmed() -> void:
	GameState.reset_save()
	_confirm.visible = false
	get_tree().change_scene_to_file.call_deferred(HUB_SCENE)
