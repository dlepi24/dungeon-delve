extends Node
## Device and display preferences. Autoloaded as `Settings`.
##
## Modeled on Keybinds: capture, apply on boot, persist on change. Lives in its
## own user://settings.cfg rather than GameState's save.cfg ON PURPOSE — the
## save is wipeable via reset_save() ("New game" on the title), and your volume
## or window mode is not progress to be wiped.
##
## Owns exactly two things: music volume and window mode. Key rebinding stays in
## Keybinds; duplicating it here would give two sources of truth.

const SAVE_PATH: String = "user://settings.cfg"

## 0..1 linear scale on top of the tuned music bed level (Music.volume_db).
var music_volume: float = 1.0
## Borderless fullscreen (the project default) vs a plain window.
var fullscreen: bool = true
## Accessibility: camera screen-shake. Off kills all trauma-driven camera kick
## (hits, parries, damage taken) for motion-sensitive players.
var screen_shake: bool = true


func _ready() -> void:
	_load()
	apply()


## Push the loaded/current prefs onto the systems that enact them.
func apply() -> void:
	Music.set_user_volume(music_volume)
	_apply_window()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	Music.set_user_volume(music_volume)
	_save()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	_save()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_save()


## Headless-guarded like every DisplayServer call: the check gate and the test
## scenes load all autoloads with no window to set a mode on.
func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("accessibility", "screen_shake", screen_shake)
	config.save(SAVE_PATH)


func _load() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	music_volume = clampf(float(config.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", true))
	screen_shake = bool(config.get_value("accessibility", "screen_shake", true))
