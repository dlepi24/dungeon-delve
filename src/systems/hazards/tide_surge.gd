class_name TideSurge
extends Hitbox
## THE HOLLOW BELOW's signature hazard (2026-07-23 decision log): the water
## table rises and falls on a schedule, spanning the whole room — the inverse
## of the upper mine's ceiling debris. Instead of danger falling on you from
## above, it rises to meet you from below.
##
## A Hitbox like Spikes: NOT parryable (you cannot parry a flood, and a
## parried hitbox deactivates — a one-parry permanent tide defusal would be
## silly), but roll i-frames cross it clean, same as every other floor
## hazard. No new art: a translucent ColorRect standing in for the water,
## same discipline as the debris warning column.

@export var surge_damage: float = 8.0
## Ticks the water telegraphs (rising, translucent) before it slams.
@export var warning_ticks: int = 100
## Ticks the surge stays active (deals contact damage) once it hits.
@export var active_ticks: int = 40
## Ticks the water stays low (safe) between surges.
@export var trough_ticks: int = 160

@export var width: float = 640.0
@export var surge_height: float = 90.0
## Ticks before the cycle starts counting at all — fully invisible, fully
## harmless. Sized past the zone-title card's 3.45s hold (fade_in + hold +
## fade_out in zone_title.gd), which runs with the room already live
## underneath it. Without this, a fresh Hollow Below room's tide had already
## telegraphed AND surged once before the card even cleared — "spawning into
## a level and having water instantly hitting me", Dustin's exact report
## after playing it. The room is live the moment the card starts, but the
## PLAYER'S ATTENTION isn't; the hazard now waits for both.
@export var entry_grace_ticks: int = 240

var _tick: int = 0
var _visual: ColorRect = null


func _ready() -> void:
	super()
	parryable = false
	poise_damage = 0.0
	damage = surge_damage
	# Spawned from code, not a hand-written .tscn — spikes.tscn sets these on
	# the node header instead, but the "never raw layer numbers in code" rule
	# means a code-built hazard reaches for the named constants.
	collision_layer = CollisionLayers.ENEMY_ATTACK
	collision_mask = CollisionLayers.PLAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(width, surge_height)
	shape.shape = rect
	shape.position = Vector2(0, -surge_height * 0.5)
	add_child(shape)
	_visual = ColorRect.new()
	_visual.size = Vector2(width, surge_height)
	_visual.position = Vector2(-width * 0.5, -surge_height)
	_visual.color = Color(0.28, 0.78, 0.72, 0.0)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	deactivate()


func _physics_process(_delta: float) -> void:
	if Hitstop.is_frozen():
		return
	_tick += 1
	if _tick <= entry_grace_ticks:
		_visual.color.a = 0.0
		if is_active():
			deactivate()
		return
	var cycle: int = warning_ticks + active_ticks + trough_ticks
	# Offset by the grace period so the FIRST real cycle after it starts clean
	# at phase 0 (full warning), not wherever _tick happens to already be.
	var phase: int = (_tick - entry_grace_ticks) % cycle
	if phase < warning_ticks:
		var t: float = float(phase) / float(maxi(1, warning_ticks))
		_visual.color.a = lerpf(0.0, 0.5, t)
		if is_active():
			deactivate()
	elif phase < warning_ticks + active_ticks:
		_visual.color.a = 0.72
		if not is_active():
			activate()
	else:
		_visual.color.a = 0.0
		if is_active():
			deactivate()
