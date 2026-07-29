extends Control
## Art-review rig for KeyChip: draws every chip kind in all three device
## flavours on one screen, forcing Keybinds' device state so no controller is
## needed. Run via the screenshot tool to eyeball a glyph pass:
##   godot --path . res://tools/screenshot.tscn -- res://tools/glyph_preview.tscn out.png

const ACTIONS: Array[StringName] = [&"jump", &"roll", &"attack", &"parry", &"interact", &"skill_1", &"pause"]
const FS: int = 22


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.1, 0.09))
	var rows: Array[Array] = [
		["keyboard", false, &"xbox"],
		["xbox pad", true, &"xbox"],
		["playstation pad", true, &"playstation"],
	]
	var y: float = 80.0
	for row: Array in rows:
		Keybinds.using_gamepad = row[1]
		Keybinds.pad_flavor = row[2]
		draw_string(KeyChip.FONT, Vector2(60, y - 14), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.7))
		var x: float = 60.0
		for action: StringName in ACTIONS:
			x += KeyChip.draw_action(self, action, FS, Vector2(x, y)) + 26.0
		# A charging hold chip and the four D-pad arrows, to proof those paths.
		x += KeyChip.draw_action(self, &"interact", FS, Vector2(x, y), 0.6) + 26.0
		y += 110.0
	Keybinds.using_gamepad = false
