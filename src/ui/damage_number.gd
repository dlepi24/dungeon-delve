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

@export var rise: float = 74.0
@export var lifetime: float = 0.95
@export var drift: float = 22.0
## Size on a normal hit and on a riposte. The gap between them IS the readout:
## the riposte number should be obviously bigger, not just a different figure.
@export var font_size: int = 34
@export var riposte_font_size: int = 54

var _elapsed: float = 0.0
var _drift_x: float = 0.0

@onready var _label: Label = $Label


static func spawn(parent: Node, at: Vector2, amount: float, is_riposte: bool) -> void:
	var scene: PackedScene = load("res://src/ui/damage_number.tscn") as PackedScene
	var number: DamageNumber = scene.instantiate() as DamageNumber
	parent.add_child(number)
	number.global_position = at
	number.setup(amount, is_riposte)


func _ready() -> void:
	# Above the tiles and the bodies. Without this a number can be drawn behind
	# whatever it was spawned next to, which is indistinguishable from it never
	# having appeared at all — the first version was 20 px of white text for 0.7 s
	# during a hitstop and a screenshake, and Dustin could not tell whether it was
	# firing.
	z_index = 100


func setup(amount: float, is_riposte: bool) -> void:
	# @onready has not run if setup is called right after instantiate.
	var label: Label = get_node("Label")
	label.text = str(roundi(amount))
	# A dark outline, so the number reads against a pale tile or a bright flash.
	# Plain white text on gray-box is nearly invisible at speed.
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override(&"outline_size", 8)
	if is_riposte:
		label.text += "!"
		label.add_theme_color_override(&"font_color", Color(1.0, 0.82, 0.2))
		label.add_theme_font_size_override(&"font_size", riposte_font_size)
	else:
		label.add_theme_color_override(&"font_color", Color(1, 1, 1))
		label.add_theme_font_size_override(&"font_size", font_size)
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
	# Pop in, then fade only at the end — fading from the first frame is what made
	# these ghosts. Full opacity for the first two thirds.
	modulate.a = 1.0 if t < 0.66 else 1.0 - (t - 0.66) / 0.34
	var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - t * 6.0)
	scale = Vector2(pop, pop)
