class_name FloatingText
extends Node2D
## A short piece of world-space text that rises, pops and fades. The generic
## sibling of DamageNumber: same motion, but it says WORDS ("+3 ore", "Haste!")
## instead of a damage figure.
##
## Exists because pickups had zero feedback — you collected ore on contact, often
## standing on top of an enemy mid-fight, and never saw what you got. Feedback at
## the pickup's world position ties the reward to the thing you grabbed.
##
## DamageNumber deliberately stays its own class: combat and tests depend on its
## spawn(host, at, amount, is_riposte) signature, and combat tuning (riposte
## sizing) should not be entangled with pickup styling.
##
## Frees itself. Nothing owns these.

@export var rise: float = 74.0
@export var lifetime: float = 0.95
@export var drift: float = 22.0

var _elapsed: float = 0.0
var _drift_x: float = 0.0


static func spawn(parent: Node, at: Vector2, text: String, color: Color, font_size: int = 28) -> void:
	var scene: PackedScene = load("res://src/ui/floating_text.tscn") as PackedScene
	var toast: FloatingText = scene.instantiate() as FloatingText
	parent.add_child(toast)
	toast.global_position = at
	toast.setup(text, color, font_size)


func _ready() -> void:
	# Above tiles and bodies, same as DamageNumber — a toast drawn behind the
	# enemy you are fighting is indistinguishable from no toast at all.
	z_index = 100


func setup(text: String, color: Color, font_size: int) -> void:
	# @onready has not run if setup is called right after instantiate.
	var label: Label = get_node("Label")
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", font_size)
	# Dark outline so it reads against pale tiles and hit flashes.
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override(&"outline_size", 8)
	_drift_x = randf_range(-drift, drift)


## Visual only, and deliberately unseeded: never touches gameplay.
func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = _elapsed / lifetime
	if t >= 1.0:
		queue_free()
		return
	position.y -= rise * delta * (1.0 - t * 0.5)
	position.x += _drift_x * delta
	# Pop in, hold, fade only at the end — fading from frame one makes ghosts.
	modulate.a = 1.0 if t < 0.66 else 1.0 - (t - 0.66) / 0.34
	var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - t * 6.0)
	scale = Vector2(pop, pop)
