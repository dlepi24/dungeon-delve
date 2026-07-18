extends CanvasLayer
## The fork under the fork: descending offers TWO shafts, each with a hint of
## what lies behind it ("sounds of fighting", "a broken floor"). Reuses the
## menu grammar the pad already knows — navigate, A commits, B backs out to
## the exit ledge with nothing spent.
##
## Pauses the tree while open: reading a door hint mid-brute-swing is not a
## choice, it is a trap.

signal chosen(index: int)
signal cancelled

@onready var _left: Button = $Panel/Margin/Rows/Doors/Left
@onready var _right: Button = $Panel/Margin/Rows/Doors/Right


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_left.pressed.connect(func() -> void: _pick(0))
	_right.pressed.connect(func() -> void: _pick(1))


func offer(hint_a: String, hint_b: String) -> void:
	_left.text = "Left shaft\n%s" % hint_a
	_right.text = "Right shaft\n%s" % hint_b
	visible = true
	get_tree().paused = true
	Cursor.menu()
	_left.grab_focus()


func _pick(index: int) -> void:
	_close()
	chosen.emit(index)


func _close() -> void:
	visible = false
	get_tree().paused = false
	Cursor.gameplay()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_close()
		cancelled.emit()
