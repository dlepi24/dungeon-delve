class_name KeyHint
extends Control
## A single "press <key>: <label>" line — the uniform KeyChip plus a label — for
## menus and full-screen panels (the result screen, etc.), so their prompts read
## exactly like the world prompts. Centres its content and follows the device
## (keyboard letter ↔ pad glyph). Set it once with set_hint().

const FONT: FontFile = preload("res://assets/fonts/Rajdhani-Medium.ttf")
const GAP: float = 10.0
const COLOUR: Color = Color(0.94, 0.9, 0.82, 1.0)

@export var action: StringName = &"interact"
@export var label: String = ""
@export var font_size: int = 20
@export var chip_font_size: int = 17


func _ready() -> void:
	custom_minimum_size.y = 34.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Keybinds.input_device_changed.connect(func() -> void: queue_redraw())


func set_hint(new_action: StringName, new_label: String) -> void:
	action = new_action
	label = new_label
	queue_redraw()


func _draw() -> void:
	var glyph: String = Keybinds.hint_for(action)
	var chip: Vector2 = KeyChip.chip_size(glyph, chip_font_size)
	var label_w: float = FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var total: float = chip.x + GAP + label_w
	var left: float = (size.x - total) * 0.5
	KeyChip.draw_chip(self, glyph, chip_font_size, Vector2(left, (size.y - chip.y) * 0.5))
	var baseline: float = (size.y - (FONT.get_ascent(font_size) + FONT.get_descent(font_size))) * 0.5 + FONT.get_ascent(font_size)
	draw_string(FONT, Vector2(left + chip.x + GAP, baseline), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOUR)
