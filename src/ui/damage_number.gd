class_name DamageNumber
extends Node2D
## A number that floats off a hit and fades.
##
## Readability, not decoration: the difference between a 12 and a 36 riposte is
## invisible without it, so you cannot tell whether the parry payoff is landing
## or whether a poise chip registered. You are tuning those values — you need to
## see them.
##
## Frees itself. Nothing owns these.

@export var rise: float = 46.0
@export var lifetime: float = 0.7
@export var drift: float = 18.0

var _elapsed: float = 0.0
var _drift_x: float = 0.0

@onready var _label: Label = $Label


static func spawn(parent: Node, at: Vector2, amount: float, is_riposte: bool) -> void:
	var scene: PackedScene = load("res://src/ui/damage_number.tscn") as PackedScene
	var number: DamageNumber = scene.instantiate() as DamageNumber
	parent.add_child(number)
	number.global_position = at
	number.setup(amount, is_riposte)


func setup(amount: float, is_riposte: bool) -> void:
	# @onready has not run if setup is called right after instantiate.
	var label: Label = get_node("Label")
	label.text = str(roundi(amount))
	if is_riposte:
		label.text += "!"
		label.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.3))
		label.add_theme_font_size_override(&"font_size", 30)
	else:
		label.add_theme_color_override(&"font_color", Color(1, 1, 1))
		label.add_theme_font_size_override(&"font_size", 20)
	# Scatter sideways so a flurry of hits does not stack into one unreadable blob.
	_drift_x = randf_range(-drift, drift)


## Visual only, and deliberately unseeded: these never touch gameplay.
func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = _elapsed / lifetime
	if t >= 1.0:
		queue_free()
		return
	position.y -= rise * delta * (1.0 - t * 0.5)
	position.x += _drift_x * delta
	modulate.a = 1.0 - t * t
