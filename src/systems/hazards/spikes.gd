class_name Spikes
extends Hitbox
## A bed of spikes on a pit floor. The GAP rooms promised "falling in is
## survivable" — still true, but the mine now charges for the mistake.
##
## A Hitbox that never sleeps: it re-activates on a pulse so standing in it
## keeps hurting, and it is NOT parryable (you cannot deflect the floor, and a
## parried hitbox deactivates — a one-parry permanent spike defusal would be
## silly). Roll i-frames cross it clean, which keeps the roll pillar: the
## skilled way out of a spiked pit costs nothing.

## Damage per pulse. Deliberately a sting, not an execution.
@export var pulse_damage: float = 10.0
## Ticks between re-activations (how often standing in it hurts again).
@export var pulse_ticks: int = 40

@export var width: float = 96.0
@export var tooth_height: float = 14.0
@export var colour: Color = Color(0.55, 0.4, 0.38)

var _tick: int = 0


func _ready() -> void:
	super()
	parryable = false
	damage = pulse_damage
	poise_damage = 0.0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(width, tooth_height)
	shape.shape = rect
	shape.position = Vector2(0, -tooth_height * 0.5)
	add_child(shape)
	activate()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if Hitstop.is_frozen():
		return
	_tick += 1
	if _tick % pulse_ticks == 0:
		activate()


func _draw() -> void:
	var teeth: int = maxi(1, int(width / 12.0))
	var step: float = width / float(teeth)
	for i: int in teeth:
		var x0: float = -width * 0.5 + float(i) * step
		draw_colored_polygon(PackedVector2Array([
			Vector2(x0, 0), Vector2(x0 + step, 0), Vector2(x0 + step * 0.5, -tooth_height),
		]), colour)
