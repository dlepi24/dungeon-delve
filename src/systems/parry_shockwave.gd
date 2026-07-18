class_name ParryShockwave
extends Node2D
## The parry's crown: an expanding ring of light at the moment of the deflect.
##
## The parry is the design pillar and the most skilled input in the game, but
## visually it was a white flash you could mistake for taking a hit. A
## shockwave is unmistakable — it announces MASTERY, radiating from the exact
## point where the read happened. Self-freeing, draw-call only, no assets.

@export var lifetime: float = 0.28
@export var start_radius: float = 14.0
@export var end_radius: float = 120.0
@export var colour: Color = Color(1.0, 0.92, 0.6)

var _elapsed: float = 0.0


static func burst(parent: Node, at: Vector2) -> void:
	var wave: ParryShockwave = ParryShockwave.new()
	parent.add_child(wave)
	wave.global_position = at
	wave.z_index = 90


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_elapsed / lifetime, 0.0, 1.0)
	# Ease out: the ring leaps then settles, like a struck bell.
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var radius: float = lerpf(start_radius, end_radius, eased)
	var faded: Color = Color(colour, 1.0 - t)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, faded, 7.0 * (1.0 - t) + 1.0)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 48, Color(1, 1, 1, (1.0 - t) * 0.5), 3.0)
