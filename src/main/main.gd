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
const DELVE_SCENE: String = "res://src/rooms/delve_run.tscn"
## The onboarding entry point: the backstory crawl, which itself chains into the
## mechanics tutorial. Fresh players start here; the tutorial's finale sets
## intro_seen, so this whole arc only fires once.
const INTRO_SCENE: String = "res://src/rooms/intro_sequence.tscn"

@onready var _play: Button = $Menu/Play
@onready var _daily: Button = $Menu/Daily
@onready var _records_button: Button = $Menu/Records
@onready var _records: Control = $RecordsScreen
@onready var _new_game: Button = $Menu/NewGame
@onready var _settings_button: Button = $Menu/Settings
@onready var _settings: Control = $SettingsMenu
@onready var _menu: VBoxContainer = $Menu
@onready var _quit: Button = $Menu/Quit
@onready var _controls: Label = $Controls
@onready var _stats: Label = $Stats
@onready var _flavor: Label = $Flavor

const VERSION: String = "v0.6"
@onready var _confirm: PanelContainer = $Confirm
@onready var _confirm_yes: Button = $Confirm/Margin/Rows/Buttons/Yes
@onready var _confirm_cancel: Button = $Confirm/Margin/Rows/Buttons/Cancel

var _order: Array[Control] = []
var _nav: MenuNav = MenuNav.new()


func _ready() -> void:
	Cursor.menu()
	# The title has its own calmer, fuller bed now. The autoload survives the
	# change into the hub, where it crossfades to the hub track.
	Music.play(&"title")
	_confirm.visible = false
	_play.pressed.connect(_on_play)
	_new_game.pressed.connect(_on_new_game)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_settings_button.pressed.connect(_on_settings)
	_settings.closed.connect(_on_settings_closed)
	_daily.pressed.connect(_on_daily)
	_records_button.pressed.connect(_on_records)
	_records.closed.connect(_on_records_closed)
	# Uppercase, spec voice (round-6 tokens). DESCEND is a fresh drop; CONTINUE
	# when there is a save worth continuing — the distinction tells the player
	# their progress is still here.
	var has_save: bool = GameState.banked_haul > 0 or not GameState.upgrade_levels.is_empty()
	_play.text = "CONTINUE" if has_save else "DESCEND"
	_daily.text = "DAILY DELVE"
	# One ranked shot per day; after that the same seed is open practice.
	if not GameState.daily_available():
		_daily.text = "DAILY DELVE  (PRACTICE)"
	_records_button.text = "RECORDS"
	_new_game.text = "NEW GAME"
	_settings_button.text = "OPTIONS"
	_quit.text = "QUIT"
	_confirm_yes.pressed.connect(_on_wipe_confirmed)
	_confirm_cancel.pressed.connect(_on_confirm_cancel)
	# Wire the two confirm buttons to each other explicitly. Without this, LEFT
	# from Cancel ran Godot's geometric focus search and could jump to a background
	# Menu button instead of Wipe, leaving Wipe reachable only by mouse.
	_confirm_yes.focus_neighbor_right = _confirm_cancel.get_path()
	_confirm_yes.focus_neighbor_left = _confirm_cancel.get_path()
	_confirm_cancel.focus_neighbor_left = _confirm_yes.get_path()
	_confirm_cancel.focus_neighbor_right = _confirm_yes.get_path()
	_refresh_controls_line()
	_refresh_stats_line()
	_refresh_flavor()
	# The verbs line follows whichever device is driving.
	Keybinds.input_device_changed.connect(_refresh_controls_line)
	_play.grab_focus()
	_order = [_play, _daily, _records_button, _new_game, _settings_button, _quit]
	MenuNav.disable_builtin_nav(_order)


## Only the main menu column — Records, Settings and the wipe Confirm each hide
## it and own their own focused control while they are up.
func _process(delta: float) -> void:
	if _menu.visible:
		_nav.poll(delta, _order)


## The verbs, from the LIVE keybinds and the live input device — a static hint
## goes stale the moment a key is rebound or a controller wakes up. Lesson from
## M2: a build that does not state its verbs gets judged on the verbs you
## happened to guess.
func _refresh_controls_line() -> void:
	if Keybinds.using_gamepad:
		_controls.text = "Stick move   %s jump   %s roll   %s attack   %s parry   %s pause" % [
			Keybinds.hint_for(&"jump"), Keybinds.hint_for(&"roll"),
			Keybinds.hint_for(&"attack"), Keybinds.hint_for(&"parry"),
			Keybinds.hint_for(&"pause"),
		]
		return
	_controls.text = "%s%s move   %s jump   %s roll   %s / LMB attack   %s / RMB parry   ESC pause" % [
		Keybinds.label_for(&"move_left"), Keybinds.label_for(&"move_right"),
		Keybinds.label_for(&"jump"), Keybinds.label_for(&"roll"),
		Keybinds.label_for(&"attack"), Keybinds.label_for(&"parry"),
	]


## The career record — the game remembering you played it. Silent until the
## first run ends, so a brand-new player is not greeted with a wall of zeroes.
func _refresh_stats_line() -> void:
	if GameState.total_runs <= 0:
		_stats.text = ""
		return
	_stats.text = "runs %d   ·   deepest room %d   ·   best extract %d ore   ·   kills %d" % [
		GameState.total_runs, GameState.deepest_room, GameState.best_haul, GameState.total_kills,
	]


## Bottom-right flavor: a deadpan "shift" number and a real days-since-death
## counter (cheap joke, real data). Uppercase, faint, per the tokens.
func _refresh_flavor() -> void:
	if _flavor == null:
		return
	var shift: int = GameState.total_runs + 1
	var tail: String
	if GameState.last_collapse_unix <= 0:
		tail = "NO COLLAPSE ON RECORD"
	else:
		var days: int = int((Time.get_unix_time_from_system() - float(GameState.last_collapse_unix)) / 86400.0)
		tail = "%d DAYS SINCE LAST COLLAPSE" % days
	_flavor.text = "SHIFT %d  —  %s   ·   %s" % [shift, tail, VERSION]


## Gamepad B (or ESC) backs out of the wipe confirm. The settings menu handles
## its own back-navigation.
func _unhandled_input(event: InputEvent) -> void:
	if _confirm.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_confirm()


## Opening the wipe confirm hides the menu behind it — same as the Records and
## Settings panels. Beyond looking cleaner, it removes the six menu buttons as
## competing focus targets, so directional nav stays inside the two confirm
## buttons. Focus starts on Cancel: the safe choice for a destructive dialog.
func _on_new_game() -> void:
	_menu.visible = false
	_confirm.visible = true
	_confirm_cancel.grab_focus()


func _on_confirm_cancel() -> void:
	_close_confirm()


func _close_confirm() -> void:
	_confirm.visible = false
	_menu.visible = true
	_play.grab_focus()


func _on_play() -> void:
	get_tree().change_scene_to_file.call_deferred(_first_destination())


## A fresh player (intro not yet seen) gets the story crawl, then the guided
## mechanics tutorial, before ever reaching the hub; everyone else goes straight
## to the surface. The crawl hands off to the tutorial on its own.
func _first_destination() -> String:
	return HUB_SCENE if GameState.intro_seen else INTRO_SCENE


## Straight down the mine on today's shared seed — no hub stop, no heat, no
## carried loadout: the ceremony is that everyone faces the same mine.
func _on_daily() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	GameState.pending_seed = Rng.daily_seed(now["year"], now["month"], now["day"])
	GameState.pending_mode = &"daily"
	get_tree().change_scene_to_file.call_deferred(DELVE_SCENE)


func _on_records() -> void:
	_menu.visible = false
	_records.open()


func _on_records_closed() -> void:
	_records.visible = false
	_menu.visible = true
	_records_button.grab_focus()


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
	_refresh_stats_line()
	_confirm.visible = false
	# A wiped save has intro_seen = false again, so New Game replays the intro.
	get_tree().change_scene_to_file.call_deferred(_first_destination())
