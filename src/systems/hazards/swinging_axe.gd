class_name SwingingAxe
extends Hitbox
## A bladed pendulum — a mine trap the guided intro hangs over a SOLID-floor path
## to teach the roll. Touching the blade stings (unparryable, like spikes: you
## cannot deflect a trap); a dodge roll's i-frames carry you straight through,
## which IS the lesson — on firm ground, not a pit you fall into and get hit by
## every time.
##
## Swing and damage run in _physics_process so the trap is deterministic (daily
## seeds / ghosts depend on it). The node sits at the PIVOT (a ceiling mount);
## the blade hangs `arm_length` below and sweeps back and forth.

@export var arm_length: float = 205.0
@export var max_angle_deg: float = 58.0
## Ticks for a full back-and-forth. Slow enough to read and time.
@export var period_ticks: int = 165
## How often contact re-hurts; a roll's i-frames span a pulse gap cleanly.
@export var pulse_ticks: int = 12
@export var hit_damage: float = 12.0
@export var blade_radius: float = 24.0

const CHAIN: Color = Color(0.24, 0.25, 0.28)
const IRON: Color = Color(0.66, 0.68, 0.72)
const IRON_DARK: Color = Color(0.32, 0.33, 0.37)
const EDGE: Color = Color(0.9, 0.92, 0.96)

var _tick: int = 0
var _angle: float = 0.0
var _blade: CollisionShape2D = null
## Positional audio, so the trap can be heard sweeping before you round the
## corner into it — the whoosh IS part of the telegraph. On the SFX bus.
var _whoosh: AudioStreamPlayer2D = null
var _thunk: AudioStreamPlayer2D = null
## Sign of the arm angle last tick, to catch the pass through dead-centre (the
## blade's fastest point) exactly once per swing.
var _prev_sign: int = 0
## Whether the blade was in contact last pulse, so the heavy chunk fires once
## when it first catches you rather than every re-hurt pulse.
var _was_hitting: bool = false


func _ready() -> void:
	super()
	parryable = false
	damage = hit_damage
	poise_damage = 0.0
	_blade = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = blade_radius
	_blade.shape = circle
	add_child(_blade)
	_whoosh = _make_player(preload("res://assets/audio/axe_whoosh.wav"), -6.0)
	_thunk = _make_player(preload("res://assets/audio/axe_hit.wav"), 0.0)
	_swing_to(0.0)
	activate()


func _make_player(stream: AudioStream, trim_db: float) -> AudioStreamPlayer2D:
	var p: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = &"SFX"
	p.volume_db = trim_db
	p.max_distance = 900.0
	add_child(p)
	return p


func _physics_process(_delta: float) -> void:
	if Hitstop.is_frozen():
		return
	_tick += 1
	_swing_to(deg_to_rad(max_angle_deg) * sin(TAU * float(_tick) / float(period_ticks)))
	# Whoosh on the pass through centre — where the blade is fastest and the whoosh
	# reads. Follow the blade so the sound comes from the swinging iron.
	var sign_now: int = int(signf(_angle))
	if sign_now != 0 and sign_now != _prev_sign and _prev_sign != 0:
		_whoosh.position = _blade.position
		_whoosh.play()
	if sign_now != 0:
		_prev_sign = sign_now
	if _tick % pulse_ticks == 0:
		activate()
		# One heavy chunk when it first bites, not one per re-hurt pulse.
		var hitting: bool = hit_count() > 0
		if hitting and not _was_hitting:
			_thunk.position = _blade.position
			_thunk.play()
		_was_hitting = hitting
	queue_redraw()


func _swing_to(angle: float) -> void:
	_angle = angle
	if _blade != null:
		_blade.position = Vector2(0.0, arm_length).rotated(angle)


func _draw() -> void:
	var tip: Vector2 = Vector2(0.0, arm_length).rotated(_angle)
	draw_line(Vector2.ZERO, tip, CHAIN, 5.0)
	# An iron wrecking-blade: dark rim, iron core, a bright honed edge.
	draw_circle(tip, blade_radius, IRON_DARK)
	draw_circle(tip, blade_radius * 0.72, IRON)
	draw_arc(tip, blade_radius, 0.0, TAU, 22, EDGE, 2.0)
