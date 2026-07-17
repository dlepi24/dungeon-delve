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
	&"skill_1": "Weapon slot 1",
	&"skill_2": "Weapon slot 2",
	&"interact": "Interact",
}

## The GDD's layout, captured before anything overrides it.
var _defaults: Dictionary[StringName, InputEventKey] = {}


func _ready() -> void:
	_capture_defaults()
	load_overrides()


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


## What to show on a settings row.
##
## Bindings are stored as PHYSICAL keycodes so the layout follows the keys' places
## rather than their letters — WASD stays a square on AZERTY. But the LABEL must
## show what is printed on the player's actual key, which needs the display server
## to map physical to logical. Headless has no keyboard to ask, and calling it
## there logs an error every time, so fall back to the physical name.
func label_for(action: StringName) -> String:
	var key: InputEventKey = _first_key(action)
	if key == null:
		return "—"
	# There is no FEATURE_KEYBOARD to ask for; the headless driver simply has no
	# keyboard, and calling the mapping there logs an error per row.
	if DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(key.physical_keycode)
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode))


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
