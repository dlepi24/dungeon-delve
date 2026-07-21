extends Node
## Player key rebinding, saved to disk. Autoloaded as `Keybinds`.
##
## Pulled forward from M7 because Dustin found J/K awkward, and "the defaults are
## locked in the GDD" is not a reason to make someone play with bindings that
## fight their hands. The GDD table is now the DEFAULT, not the only option — see
## the decision log.
##
## Only rebinds the FIRST keyboard event of an action, leaving mouse and gamepad
## bindings alone. That is deliberate: attack is on both LMB and J, and someone
## rebinding J has no reason to lose LMB. It also means the gamepad layout stays
## exactly as the GDD specifies while the keyboard is free.
##
## Overrides live in user:// so they survive an update, and the defaults are
## captured at startup BEFORE any override is applied — otherwise "reset to
## default" would reset to whatever was last saved.

const SAVE_PATH: String = "user://keybinds.cfg"

## Rebindable actions, in the order a settings screen should list them. Movement
## is deliberately included: WASD is not universal.
const REBINDABLE: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"jump", &"roll", &"attack", &"parry",
	&"skill_1", &"skill_2", &"interact",
]

## Human labels. The action names are code, not UI.
const LABELS: Dictionary[StringName, String] = {
	&"move_left": "Move left",
	&"move_right": "Move right",
	&"move_up": "Aim up / ladders",
	&"move_down": "Crouch / drop",
	&"jump": "Jump",
	&"roll": "Dodge roll",
	&"attack": "Attack",
	&"parry": "Parry",
	&"skill_1": "Swap weapon",
	&"skill_2": "Timber hook",
	&"interact": "Interact",
}

## The GDD's layout, captured before anything overrides it.
var _defaults: Dictionary[StringName, InputEventKey] = {}

# --- Input device awareness ---
# The game watches which device spoke last and every on-screen hint follows:
# keyboard letters normally, pad glyphs while a controller is driving, flipped
# back the instant the keyboard is touched. Godot does not do this for you —
# it only names the pad; the flavour split is ours.

## Fired when the active device (or pad flavour) changes, so one-shot labels
## (the title's controls line) can rebuild. Per-frame labels just poll.
signal input_device_changed

## True while the last meaningful input came from a gamepad.
var using_gamepad: bool = false
## &"xbox" or &"playstation", from the connected pad's reported name. Xbox is
## the fallback because its lettered buttons are the generic convention.
var pad_flavor: StringName = &"xbox"

## Xbox speaks in letters (that IS its official glyph text); Sony pads get
## their shapes — the geometric characters render in the default font, where
## circled letters (Ⓐ) would risk tofu boxes. Real drawn button icons are an
## M9 asset job (labels would need to become RichTextLabels).
const _XBOX_BUTTONS: Dictionary[int, String] = {
	0: "A", 1: "B", 2: "X", 3: "Y", 4: "View", 6: "Menu",
	9: "LB", 10: "RB", 11: "↑", 12: "↓", 13: "←", 14: "→",
}
const _PS_BUTTONS: Dictionary[int, String] = {
	0: "✕", 1: "○", 2: "□", 3: "△", 4: "Share", 6: "Options",
	9: "L1", 10: "R1", 11: "↑", 12: "↓", 13: "←", 14: "→",
}


func _ready() -> void:
	# Menus pause the tree; device detection must keep running under them or
	# hints freeze on whichever device opened the menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_defaults()
	load_overrides()


## Passive listener: never consumes anything, just notices who is talking.
## Stick drift is filtered by the 0.5 threshold; mouse MOTION deliberately does
## not flip back (brushing the mouse mid-pad-session is incidental).
func _input(event: InputEvent) -> void:
	var from_pad: bool
	if event is InputEventJoypadButton:
		from_pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) < 0.5:
			return
		from_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		from_pad = false
	else:
		return
	if from_pad == using_gamepad:
		return
	using_gamepad = from_pad
	if from_pad:
		_detect_flavor(event.device)
	input_device_changed.emit()


func _detect_flavor(device: int) -> void:
	var pad_name: String = Input.get_joy_name(device).to_lower()
	var sony: bool = false
	for marker: String in ["ps5", "ps4", "ps3", "dualsense", "dualshock", "sony", "playstation"]:
		if marker in pad_name:
			sony = true
			break
	pad_flavor = &"playstation" if sony else &"xbox"


## Device-aware hint for on-screen prompts: the keyboard key normally, the pad
## glyph while a gamepad is driving. Stick-only actions (movement) say "Stick".
func hint_for(action: StringName) -> String:
	if not using_gamepad:
		return label_for(action)
	var table: Dictionary[int, String] = _PS_BUTTONS if pad_flavor == &"playstation" else _XBOX_BUTTONS
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return table.get((event as InputEventJoypadButton).button_index, "Pad")
		if event is InputEventJoypadMotion:
			return "Stick"
	return label_for(action)


func _capture_defaults() -> void:
	for action: StringName in REBINDABLE:
		if not InputMap.has_action(action):
			continue
		var key: InputEventKey = _first_key(action)
		if key != null:
			_defaults[action] = key.duplicate() as InputEventKey


func _first_key(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event as InputEventKey
	return null


## Labels are asked for EVERY FRAME (the HUD's swap hint, world prompts), so
## they are cached — the display-server lookup is not per-frame cheap, and on
## platforms where it is unsupported it LOGS AN ERROR PER CALL, which on the
## web export meant an error-spam firehose in the browser console.
var _label_cache: Dictionary[StringName, String] = {}


## What to show on a settings row.
##
## Bindings are stored as PHYSICAL keycodes so the layout follows the keys' places
## rather than their letters — WASD stays a square on AZERTY. But the LABEL must
## show what is printed on the player's actual key, which needs the display server
## to map physical to logical. Headless has no keyboard to ask, and the WEB
## display server does not support the mapping at all — both log an error every
## call, so both fall back to the physical name.
func label_for(action: StringName) -> String:
	if _label_cache.has(action):
		return _label_cache[action]
	var key: InputEventKey = _first_key(action)
	if key == null:
		return "—"
	var label: String
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		label = OS.get_keycode_string(key.physical_keycode)
	else:
		label = OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode))
	_label_cache[action] = label
	return label


## Replace the keyboard binding for an action. Mouse and gamepad events survive.
func rebind(action: StringName, key: InputEventKey) -> void:
	if not InputMap.has_action(action):
		return
	var existing: InputEventKey = _first_key(action)
	if existing != null:
		InputMap.action_erase_event(action, existing)
	var fresh: InputEventKey = InputEventKey.new()
	fresh.device = -1
	fresh.physical_keycode = key.physical_keycode
	InputMap.action_add_event(action, fresh)
	_label_cache.erase(action)
	save_overrides()


## Any other action already using this key. A settings screen should warn rather
## than silently leave two verbs on one key.
func conflict_for(action: StringName, key: InputEventKey) -> StringName:
	for other: StringName in REBINDABLE:
		if other == action:
			continue
		var existing: InputEventKey = _first_key(other)
		if existing != null and existing.physical_keycode == key.physical_keycode:
			return other
	return &""


func reset_to_defaults() -> void:
	for action: StringName in _defaults:
		var existing: InputEventKey = _first_key(action)
		if existing != null:
			InputMap.action_erase_event(action, existing)
		InputMap.action_add_event(action, _defaults[action].duplicate())
	_label_cache.clear()
	save_overrides()


func save_overrides() -> void:
	var config: ConfigFile = ConfigFile.new()
	for action: StringName in REBINDABLE:
		var key: InputEventKey = _first_key(action)
		if key != null:
			config.set_value("keys", String(action), key.physical_keycode)
	config.save(SAVE_PATH)


func load_overrides() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for action: StringName in REBINDABLE:
		if not config.has_section_key("keys", String(action)):
			continue
		var code: int = int(config.get_value("keys", String(action)))
		var key: InputEventKey = InputEventKey.new()
		key.device = -1
		key.physical_keycode = code as Key
		var existing: InputEventKey = _first_key(action)
		if existing != null:
			InputMap.action_erase_event(action, existing)
		InputMap.action_add_event(action, key)
