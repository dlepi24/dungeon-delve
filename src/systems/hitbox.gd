class_name Hitbox
extends Area2D
## A damage-dealing volume. Lives on PlayerAttack or EnemyAttack.
##
## The Area2D monitors continuously and hits are gated by an internal flag rather
## than by toggling `monitoring`. That is deliberate: area_entered only fires on
## a *new* overlap, so a target standing still inside the box when it opens would
## never be hit — which is precisely the training-dummy case. activate() sweeps
## the current overlaps instead.

## Emitted when a defender parried this attack, so the attacker can react
## (stagger) without anything reaching across the tree for it.
signal parried

@export var damage: float = 10.0

## Drawn while the box is live, then faded out. NOT decoration: without it an
## attack is 80 ms of invisible geometry and you are fighting on faith — you
## cannot see your own reach, so you cannot learn spacing. Real art is M9; this
## is the gray-box stand-in that makes a swing legible.
##
## Optional child named "Swing", looked up rather than exported — see the note in
## body_juice.gd about hand-written .tscn node paths silently resolving to null.
@onready var visual: CanvasItem = get_node_or_null(^"Swing")
## How fast the swing arc fades after the box closes. The lingering trail is what
## sells it as a slash rather than a blinking rectangle.
@export var visual_fade: float = 5.0

## Set by the attacker when this swing is cashing in a parry. Travels with the
## hitbox because the defender cannot know why it was hit, and M2's hitstop wants
## to hit harder on a riposte than on a normal connect.
var is_riposte: bool = false

var _active: bool = false
var _already_hit: Array[Hurtbox] = []
var _visual_alpha: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	if visual != null:
		visual.visible = false


## Visual only, so it lives here rather than in the physics step.
func _process(delta: float) -> void:
	if visual == null:
		return
	_visual_alpha = move_toward(_visual_alpha, 0.0, visual_fade * delta)
	visual.visible = _visual_alpha > 0.01
	visual.modulate.a = _visual_alpha


## Open the box. Anything already overlapping is hit immediately.
func activate() -> void:
	_already_hit.clear()
	_active = true
	_visual_alpha = 1.0
	for area: Area2D in get_overlapping_areas():
		_try_hit(area)


func deactivate() -> void:
	_active = false


func is_active() -> bool:
	return _active


func notify_parried() -> void:
	# Close the box first: a parried attack must not also land.
	deactivate()
	parried.emit()


func _on_area_entered(area: Area2D) -> void:
	if _active:
		_try_hit(area)


## One hit per target per activation, or a lingering box would grind them down.
func _try_hit(area: Area2D) -> void:
	var hurtbox: Hurtbox = area as Hurtbox
	if hurtbox == null or _already_hit.has(hurtbox):
		return
	_already_hit.append(hurtbox)
	hurtbox.take_hit(self)
