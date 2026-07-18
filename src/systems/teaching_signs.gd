class_name TeachingSigns
extends Node2D
## Verb signs planted along the entry room's floor, shown on the FIRST run of a
## save only. The mine teaches you to walk before anything tries to kill you —
## the alternative was learning the verbs from the title screen or not at all
## (the M2 lesson: a build that does not state its verbs gets judged on the
## verbs you happened to guess).
##
## Added by the Delve when it loads the entry room and GameState.total_runs is
## zero. Text pulls live hints, so a rebind or a controller pickup mid-read
## updates the signs.

## Sign x-positions and their templates, in walk order. %s slots are filled
## from live keybind hints at build time.
var _built: Array[Label] = []


func _ready() -> void:
	_build()
	Keybinds.input_device_changed.connect(_refresh)


func _refresh() -> void:
	for label: Label in _built:
		label.queue_free()
	_built.clear()
	_build()


func _build() -> void:
	if Keybinds.using_gamepad:
		_sign(250, "Stick to move   ·   %s to jump" % Keybinds.hint_for(&"jump"))
	else:
		_sign(250, "%s%s to move   ·   %s to jump" % [
			Keybinds.label_for(&"move_left"), Keybinds.label_for(&"move_right"), Keybinds.label_for(&"jump"),
		])
	_sign(660, "%s to roll — nothing can touch you mid-roll" % Keybinds.hint_for(&"roll"))
	_sign(1060, "%s to swing   ·   %s to parry as a blow lands" % [
		Keybinds.hint_for(&"attack"), Keybinds.hint_for(&"parry"),
	])
	_sign(1500, "ore you carry is only yours once you EXTRACT")


func _sign(x: float, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = Vector2(x - 220, 440)
	label.size = Vector2(440, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_color", Color(0.75, 0.68, 0.55, 0.9))
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override(&"outline_size", 6)
	add_child(label)
	_built.append(label)
