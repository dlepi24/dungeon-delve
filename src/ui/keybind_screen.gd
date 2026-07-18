extends PanelContainer
## The rebinding rows inside the pause menu.
##
## Click a row, press a key, done. Escape cancels rather than binding Escape —
## binding your pause key to a combat verb is a trap you cannot escape from,
## literally.
##
## Rows are built in code from Keybinds.REBINDABLE, so adding a rebindable action
## means editing that list and nothing here.

signal closed

var _listening_for: StringName = &""
var _rows: Dictionary[StringName, Button] = {}

@onready var _list: VBoxContainer = $Margin/Rows/List
@onready var _hint: Label = $Margin/Rows/Hint
@onready var _reset: Button = $Margin/Rows/Buttons/Reset
@onready var _back: Button = $Margin/Rows/Buttons/Back


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_rows()
	_reset.pressed.connect(_on_reset)
	_back.pressed.connect(func() -> void: closed.emit())


func _build_rows() -> void:
	for action: StringName in Keybinds.REBINDABLE:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)

		var label: Label = Label.new()
		label.text = Keybinds.LABELS.get(action, String(action))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(150, 0)
		button.pressed.connect(_listen.bind(action))
		row.add_child(button)

		_rows[action] = button
		_list.add_child(row)
	_refresh()


func _refresh() -> void:
	for action: StringName in _rows:
		_rows[action].text = Keybinds.label_for(action)


## Give gamepad/keyboard navigation a starting point when the screen opens.
func focus_first() -> void:
	for action: StringName in Keybinds.REBINDABLE:
		if _rows.has(action):
			_rows[action].grab_focus()
			return


func _listen(action: StringName) -> void:
	_listening_for = action
	_rows[action].text = "press a key…"
	_hint.text = "Press a key for \"%s\", or ESC to cancel." % Keybinds.LABELS.get(action, String(action))


func _on_reset() -> void:
	Keybinds.reset_to_defaults()
	_listening_for = &""
	_refresh()
	_hint.text = "Reset to the GDD defaults."


func _input(event: InputEvent) -> void:
	if _listening_for == &"":
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()

	# ESC cancels. Binding a combat verb to the pause key would leave you unable
	# to open the menu that would let you unbind it.
	if key.physical_keycode == KEY_ESCAPE:
		_listening_for = &""
		_refresh()
		_hint.text = "Cancelled."
		return

	var clash: StringName = Keybinds.conflict_for(_listening_for, key)
	if clash != &"":
		_hint.text = "That key is already \"%s\". Pick another." % Keybinds.LABELS.get(clash, String(clash))
		_rows[_listening_for].text = Keybinds.label_for(_listening_for)
		_listening_for = &""
		return

	Keybinds.rebind(_listening_for, key)
	_listening_for = &""
	_refresh()
	_hint.text = "Saved."
