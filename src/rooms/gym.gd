extends Node2D
## The tuning gym, now doing double duty as the player-facing TRAINING room:
## reachable from the hub, signed for the parry (the pillar nothing else
## teaches), with a way back to the surface. The dummy swings forever, so the
## 120 ms window can be read as many times as it takes.

const HUB_SCENE: String = "res://src/hub/hub.tscn"
const PAUSE_MENU: String = "res://src/ui/pause_menu.tscn"

## Stand left of this to be offered the way out.
@export var exit_x: float = 300.0

var _player: Player = null

@onready var _prompt: Label = _build_prompt()


func _ready() -> void:
	Cursor.gameplay()
	# ESC must work here like everywhere playable.
	add_child((load(PAUSE_MENU) as PackedScene).instantiate())
	_build_signs()


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	if _player.global_position.x <= exit_x:
		_prompt.text = "[%s] Return to the surface" % Keybinds.hint_for(&"interact")
	else:
		_prompt.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if _prompt.text.is_empty() or not event.is_action_pressed(&"interact"):
		return
	get_viewport().set_input_as_handled()
	get_tree().change_scene_to_file.call_deferred(HUB_SCENE)


func _build_prompt() -> Label:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var label: Label = Label.new()
	label.position = Vector2(660, 620)
	label.size = Vector2(600, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(label)
	return label


func _build_signs() -> void:
	_sign(Vector2(980, 700), "%s to parry AS THE SWING LANDS\na riposte hits for 3x" % Keybinds.hint_for(&"parry"))
	_sign(Vector2(400, 700), "%s to swing   ·   %s to roll" % [
		Keybinds.hint_for(&"attack"), Keybinds.hint_for(&"roll"),
	])
	_sign(Vector2(1500, 700), "in the air: hold DOWN + %s\nto POGO off anything below you" % Keybinds.hint_for(&"attack"))


func _sign(at: Vector2, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = at - Vector2(220, 0)
	label.size = Vector2(440, 56)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_color", Color(0.75, 0.68, 0.55, 0.9))
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override(&"outline_size", 6)
	add_child(label)
