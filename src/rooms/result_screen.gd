extends CanvasLayer
## The end-of-run screen: YOU DIED or EXTRACTED, with what it cost or earned.
##
## This exists because a death with no feedback reads as a bug — Dustin lost
## carried haul and could not tell it had happened, because nothing said so. The
## screen makes the stakes legible: you SEE the haul you lost, or the haul you
## banked, before the hub.
##
## Pauses the tree so the dead delve stops simulating underneath it, and runs
## with process_mode ALWAYS so it can still take the dismiss input.

signal dismissed

@onready var _title: Label = $Panel/Margin/Rows/Title
@onready var _detail: Label = $Panel/Margin/Rows/Detail
@onready var _hint: Label = $Panel/Margin/Rows/Hint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## outcome: "died", "extracted", or "cleared". amount: haul lost or banked.
func show_result(outcome: StringName, amount: int) -> void:
	match outcome:
		&"died":
			_title.text = "YOU DIED"
			_title.add_theme_color_override(&"font_color", Color(0.9, 0.25, 0.22))
			_detail.text = "The mine keeps your %d haul." % amount
		&"extracted":
			_title.text = "EXTRACTED"
			_title.add_theme_color_override(&"font_color", Color(0.4, 0.9, 0.55))
			_detail.text = "Banked %d haul." % amount
		&"cleared":
			_title.text = "MINE CLEARED"
			_title.add_theme_color_override(&"font_color", Color(1.0, 0.82, 0.3))
			_detail.text = "You reached the bottom and out with %d haul." % amount
	_hint.text = "[F] Return to the surface"
	visible = true
	get_tree().paused = true
	Cursor.menu()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"jump"):
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		dismissed.emit()
