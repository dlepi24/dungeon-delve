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
## How much of a committed enemy's poise this hit chips. Separate from damage so
## a fast poke can hurt without staggering: that gap between "it hurts" and "it
## interrupts" is exactly what makes heavy attacks worth respecting.
@export var poise_damage: float = 10.0

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
## Degrees the arc sweeps through as it fades. This is animation without a sprite:
## a rectangle that appears reads as a rectangle appearing, but one that rotates
## through an arc reads as a swing. Set 0 for a straight thrust.
@export var visual_sweep_degrees: float = 84.0

## Set by the attacker when this swing is cashing in a parry. Travels with the
## hitbox because the defender cannot know why it was hit, and M2's hitstop wants
## to hit harder on a riposte than on a normal connect.
var is_riposte: bool = false

## The attacker's weapon SOUND CLASS (&"pick"/&"blade"/&"blunt"), set by the
## player from the equipped weapon. Travels with the hitbox for the same reason
## is_riposte does — the defender emits hit_landed but only the attacker knows
## what swung, so the Sfx layer can stack the right impact over the material.
var impact_profile: StringName = &"pick"

## Whether a parry answers this hit. Attacks and projectiles: yes, always —
## that is the pillar. Environmental hazards (spikes): no; you cannot deflect
## the floor, and a parried spike would deactivate forever. Roll i-frames
## still work on everything.
@export var parryable: bool = true

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
	# Draw before decaying: a long frame would otherwise drive alpha to zero
	# before the arc is ever seen. Same trap as BodyJuice.
	visual.visible = _visual_alpha > 0.01
	visual.modulate.a = _visual_alpha
	if visual is Control and visual_sweep_degrees > 0.0:
		var control: Control = visual as Control
		# Pivot on the hitbox centre, not the rect's corner, or it swings around
		# its own top-left and reads as a wobble.
		control.pivot_offset = control.size * 0.5
		# Sweep from leading edge to trailing as the arc fades.
		control.rotation = deg_to_rad(visual_sweep_degrees * (_visual_alpha - 0.5))
	_visual_alpha = move_toward(_visual_alpha, 0.0, visual_fade * delta)


## Open the box. Anything already overlapping is hit immediately.
func activate() -> void:
	_already_hit.clear()
	_active = true
	_visual_alpha = 1.0
	for area: Area2D in get_overlapping_areas():
		_try_hit(area)


## Reopen WITHOUT the overlap sweep. For a reflected projectile: its previous
## victim is still standing inside the box when the parry lands, and the sweep
## in activate() would hit them again synchronously — mid-parry that means
## parry -> reflect -> sweep -> parry again, an unbounded recursion that
## freezes the game. New targets still fire area_entered on their own.
func reopen() -> void:
	_already_hit.clear()
	_active = true
	_visual_alpha = 1.0


func deactivate() -> void:
	_active = false


func is_active() -> bool:
	return _active


## How many targets this activation has connected with. The pogo state polls
## it to know the strike landed without wiring another signal.
func hit_count() -> int:
	return _already_hit.size()


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
