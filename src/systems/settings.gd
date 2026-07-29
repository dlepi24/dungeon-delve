extends Node
## Device and display preferences. Autoloaded as `Settings`.
##
## Modeled on Keybinds: capture, apply on boot, persist on change. Lives in its
## own user://settings.cfg rather than GameState's save.cfg ON PURPOSE — the
## save is wipeable via reset_save() ("New game" on the title), and your volume
## or window mode is not progress to be wiped.

const SAVE_PATH: String = "user://settings.cfg"

## Fires whenever ui_scale changes, for the UI trees that stay alive across a
## whole scene (the HUD) rather than being freshly opened — everything else
## just reads Settings.ui_scale directly when it opens.
signal ui_scale_changed(scale: float)

## 0..1 linear scales. Master rides the whole mix (the Master bus); music and
## sfx scale on top of their tuned bed levels.
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
## Borderless fullscreen (the project default) vs a plain window.
var fullscreen: bool = true
## The "10-foot UI" accessibility knob: a 4K TV is the same relative on-screen
## size as a 1080p monitor, just viewed from three times the distance, so
## legible-on-a-monitor text still reads small from a couch. 1.0 is the design
## size; 2.0 doubles the HUD and every menu. Applied per-Control (UiScaler),
## NOT via Window.content_scale_factor — that scales the whole rendered scene,
## camera and all, which is how a floor hazard once vanished off screen at
## higher settings. This never touches gameplay rendering, only chosen UI trees.
var ui_scale: float = 1.0
## Accessibility: camera screen-shake. Off kills all trauma-driven camera kick
## (hits, parries, damage taken) for motion-sensitive players.
var screen_shake: bool = true

## The name shown on the online daily board (Leaderboard autoload). Lives in
## settings.cfg, not the save: "New Game" wipes a career, not an identity.
## Empty until first needed — Leaderboard mints a MINER-#### then.
var daily_handle: String = ""
## The pause overlay's background blur (over the dim). Off = dim only, which is
## also the cheap fallback on weak hardware.
var pause_blur: bool = true


func _ready() -> void:
	_load()
	apply()


## Push the loaded/current prefs onto the systems that enact them.
func apply() -> void:
	_apply_master()
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"SFX", sfx_volume)
	_apply_window()
	_apply_ui_scale()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_master()
	_save()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus(&"Music", music_volume)
	_save()


## One slider now scales a whole bus, not a per-player trim: the SFX slider hits
## the SFX bus, and UI + Ambience route through it, so all non-music sound follows
## the one fader. Cleaner than the old per-voice dB, and it means new sound
## sources need no volume plumbing — they just pick the right bus.
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus(&"SFX", sfx_volume)
	_save()


## A named bus's volume from a linear 0..1 slider. Named lookup, never a raw
## index — same discipline as the collision layers. A missing bus is a no-op, so
## a headless run without the layout does not crash.
func _apply_bus(bus: StringName, value: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, -80.0 if value <= 0.001 else linear_to_db(value))


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	_save()


func set_ui_scale(value: float) -> void:
	ui_scale = clampf(value, 0.75, 2.0)
	_apply_ui_scale()
	_save()


func set_daily_handle(value: String) -> void:
	daily_handle = sanitize_handle(value)
	_save()


## Handle rules, mirrored by the leaderboard worker: it has to survive URLs,
## JSON, and other people's screens. Letters, digits, _ and -, max 12.
func sanitize_handle(value: String) -> String:
	const ALLOWED: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
	var out: String = ""
	for ch: String in value.strip_edges():
		if ALLOWED.contains(ch):
			out += ch
		if out.length() >= 12:
			break
	return out


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_save()


func set_pause_blur(on: bool) -> void:
	pause_blur = on
	_save()


## Master bus in dB. A linear 0..1 slider maps through linear_to_db so it feels
## right (a fader, not a light switch); 0 hard-mutes.
func _apply_master() -> void:
	var db: float = -80.0 if master_volume <= 0.001 else linear_to_db(master_volume)
	AudioServer.set_bus_volume_db(0, db)


## Headless-guarded like every DisplayServer call: the check gate and the test
## scenes load all autoloads with no window to set a mode on.
func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Nothing to push onto the engine here — UiScaler.apply() is called by each
## UI tree itself (on open, and on this signal for the ones that stay alive
## across a whole scene). This just tells them a new value is live.
func _apply_ui_scale() -> void:
	ui_scale_changed.emit(ui_scale)


func _save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("accessibility", "screen_shake", screen_shake)
	config.set_value("accessibility", "pause_blur", pause_blur)
	config.set_value("daily", "handle", daily_handle)
	config.save(SAVE_PATH)


func _load() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", true))
	ui_scale = clampf(float(config.get_value("display", "ui_scale", 1.0)), 0.75, 2.0)
	screen_shake = bool(config.get_value("accessibility", "screen_shake", true))
	pause_blur = bool(config.get_value("accessibility", "pause_blur", true))
	# Re-sanitized on load: the cfg is hand-editable.
	daily_handle = sanitize_handle(str(config.get_value("daily", "handle", "")))
