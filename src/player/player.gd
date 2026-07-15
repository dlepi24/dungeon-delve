class_name Player
extends CharacterBody2D
## Gray-box player: move, jump, roll. Combat verbs land after the M1 feel gate.
##
## DETERMINISM: every timing window here is counted in physics ticks, never in
## wall-clock milliseconds. The GDD requires identical output from identical
## inputs so daily seeds and ghost replays work, and Time.get_ticks_msec() drifts
## with framerate. The @export knobs are still in milliseconds, because that is
## how the feel spec is written and how it is easiest to reason about — the
## conversion to ticks happens here, in ms_to_ticks().
##
## TUNING: derived values (gravity, tick windows) are recomputed every physics
## frame rather than cached in _ready. That costs a few multiplies and means
## editing an export in the inspector changes the feel instantly, mid-play,
## without a restart. That live loop is the entire point of the workflow.

## Actions that queue instead of being dropped. Movement is not buffered — you
## hold a direction, you do not fire it.
const BUFFERED_ACTIONS: PackedStringArray = ["jump", "roll", "attack", "parry"]

@export_group("Run")
## Top horizontal speed, px/s.
@export var max_run_speed: float = 340.0
## Acceleration toward top speed on the ground, px/s². Higher = twitchier start.
@export var ground_acceleration: float = 2600.0
## Deceleration on the ground with no input, px/s². Higher = less ice-skating.
@export var ground_friction: float = 3200.0
## Air control authority, px/s².
@export var air_acceleration: float = 1900.0
## Drag in the air with no input, px/s². Keep low or the air feels sticky.
@export var air_friction: float = 500.0

@export_group("Jump")
## Peak height of a full-hold jump, px. Gravity is derived from this and the two
## timings below, so you tune the shape of the arc you want rather than guessing
## at a gravity constant.
@export var jump_height: float = 104.0
## Seconds from leaving the ground to the top of a full-hold jump.
@export var jump_time_to_peak: float = 0.36
## Seconds from the peak back down to ground height. Setting this lower than
## time_to_peak gives the classic snappy platformer arc: floaty up, quick down.
@export var jump_time_to_fall: float = 0.28
## Fraction of upward velocity kept when you release jump early. Lower = more
## height variation between a tap and a hold.
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.45
## Terminal velocity, px/s.
@export var max_fall_speed: float = 1000.0

@export_group("Feel")
## GDD feel spec: 100 ms. Presses fire when they become legal instead of dropping.
@export var input_buffer_ms: int = 100
## GDD feel spec: 80 ms. Jump stays legal briefly after walking off a ledge.
@export var coyote_ms: int = 80

@export_group("Roll")
## GDD feel spec: ~350 ms total.
@export var roll_duration_ms: int = 350
## GDD feel spec: i-frames cover roughly the middle 200 ms, i.e. 75..275 of 350.
@export var roll_iframe_start_ms: int = 75
@export var roll_iframe_duration_ms: int = 200
## Roll speed, px/s.
@export var roll_speed: float = 480.0
## OPEN DESIGN QUESTION — Dustin's call, not mine. The GDD says roll is "always
## available", which read literally includes mid-air, but air-rolling changes
## platforming substantially and the GDD never actually says so. Defaulting to
## off. Flip it, feel both, and whichever wins goes in the GDD decision log.
@export var allow_air_roll: bool = false

@export_group("Attack")
## Wind-up before the hitbox opens. This is the "weight" the GDD asks for: raise
## it and attacks commit harder, lower it and they get twitchy.
@export var attack_startup_ms: int = 90
## How long the hitbox stays open.
@export var attack_active_ms: int = 80
## Tail you are locked into after the hitbox closes. This is the punish window.
@export var attack_recovery_ms: int = 180
## When cancel-into-roll becomes legal, measured from the start of the attack.
## The GDD calls where this window sits a PRIMARY TUNING KNOB. Default 170 ms is
## exactly when the hitbox closes: swing, connect, bail. Push it later and
## attacking gets genuinely committal; pull it earlier and you can cancel out of
## your own active frames, which usually feels cheap.
@export var attack_cancel_start_ms: int = 170
@export var attack_damage: float = 12.0
## Fraction of run speed you keep while swinging. Low values plant your feet.
@export_range(0.0, 1.0) var attack_move_control: float = 0.15
## Hitbox position relative to the player, mirrored by facing.
@export var attack_hitbox_offset: Vector2 = Vector2(34, -28)

@export_group("Parry")
## GDD feel spec: 120 ms. The greedy window.
@export var parry_active_ms: int = 120
## GDD feel spec: ~300 ms. Whiff this and you are punishable — roll deliberately
## does NOT cancel it, or the whiff would carry no risk and parry would stop
## being a decision.
@export var parry_whiff_recovery_ms: int = 300
## How long the riposte stays open after a successful parry.
@export var riposte_window_ms: int = 700
## Damage multiplier on a riposte attack. Set to 1.0 to feel a stagger-only
## parry with no damage reward.
@export var riposte_damage_multiplier: float = 3.0

@export_group("Hitstun")
@export var hitstun_ms: int = 250
@export var hitstun_knockback: float = 220.0
@export var hitstun_pop: float = 120.0

## +1 right, -1 left. Combat will read this for attack direction.
var facing: int = 1
## Driven by the roll's i-frame window. Nothing can hurt us yet; the overlay
## draws it so the window can be tuned before enemies exist to test it against.
var invulnerable: bool = false

## Direction the last hit came from, +1 if it pushed us right. Hitstun reads it.
var last_hit_direction: int = 1

var _tick: int = 0
## Deliberately far in the past so we do not start the game holding a coyote jump.
var _last_grounded_tick: int = -10000
var _riposte_until_tick: int = -10000
var _buffer: InputBuffer

var _jump_velocity: float = 0.0
var _jump_gravity: float = 0.0
var _fall_gravity: float = 0.0

@onready var _state_machine: PlayerStateMachine = $StateMachine
@onready var attack_hitbox: Hitbox = $AttackHitbox
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	_buffer = InputBuffer.new(BUFFERED_ACTIONS)
	_state_machine.setup(self)
	attack_hitbox.deactivate()
	hurtbox.hurt.connect(_on_hurt)


func _physics_process(delta: float) -> void:
	_tick += 1
	_recalculate_derived()
	_buffer.poll(_tick)

	if is_on_floor():
		_last_grounded_tick = _tick

	attack_hitbox.position = Vector2(attack_hitbox_offset.x * float(facing), attack_hitbox_offset.y)

	_state_machine.physics_update(delta)
	move_and_slide()


## The hurtbox reports; the active state decides what a hit means. i-frames are
## checked here because they apply regardless of state.
func _on_hurt(hitbox: Hitbox) -> void:
	if invulnerable:
		return
	last_hit_direction = 1 if hitbox.global_position.x < global_position.x else -1
	_state_machine.handle_hit(hitbox)


## Godot's y axis points down: a negative velocity is upward, gravity is positive.
## Standard kinematics for "reach this height in this time": v = 2h/t, g = 2h/t².
func _recalculate_derived() -> void:
	_jump_velocity = -2.0 * jump_height / maxf(jump_time_to_peak, 0.001)
	_jump_gravity = 2.0 * jump_height / pow(maxf(jump_time_to_peak, 0.001), 2.0)
	_fall_gravity = 2.0 * jump_height / pow(maxf(jump_time_to_fall, 0.001), 2.0)


func ms_to_ticks(ms: int) -> int:
	return Ticks.from_ms(ms)


## Called on a successful parry. The payoff is a window, not an instant effect,
## so cashing it in is still a decision you can fumble.
func open_riposte() -> void:
	_riposte_until_tick = _tick + ms_to_ticks(riposte_window_ms)


func is_riposte_open() -> bool:
	return _tick <= _riposte_until_tick


func consume_riposte() -> void:
	_riposte_until_tick = -10000


func riposte_ticks_left() -> int:
	return maxi(0, _riposte_until_tick - _tick)


func get_input_direction() -> float:
	return Input.get_axis(&"move_left", &"move_right")


func update_facing(direction: float) -> void:
	if direction > 0.0:
		facing = 1
	elif direction < 0.0:
		facing = -1


## Rising uses jump_gravity, falling uses fall_gravity. The asymmetry is most of
## why a jump reads as snappy rather than floaty.
func apply_gravity(delta: float) -> void:
	var g: float = _jump_gravity if velocity.y < 0.0 else _fall_gravity
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func apply_horizontal(delta: float, direction: float) -> void:
	var accel: float = ground_acceleration if is_on_floor() else air_acceleration
	var friction: float = ground_friction if is_on_floor() else air_friction
	if is_zero_approx(direction):
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		velocity.x = move_toward(velocity.x, direction * max_run_speed, accel * delta)


## True while a jump is still legal after walking off a ledge.
func has_coyote() -> bool:
	return not is_on_floor() and _tick - _last_grounded_tick <= ms_to_ticks(coyote_ms)


## Fires a jump if one is buffered and legal, and reports whether it did.
func try_consume_jump() -> bool:
	if not _buffer.is_buffered(&"jump", _tick, ms_to_ticks(input_buffer_ms)):
		return false
	if not is_on_floor() and not has_coyote():
		return false
	_buffer.consume(&"jump")
	# Spend the coyote window too, or it would fund a second jump mid-air.
	_last_grounded_tick = -10000
	velocity.y = _jump_velocity
	return true


func try_jump_cut() -> void:
	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


## Roll is a pillar: safe, never punished, no stamina, no cooldown. If it is
## legal at all it is legal now. The only gate is the air-roll design question.
func try_consume_roll() -> bool:
	if not _buffer.is_buffered(&"roll", _tick, ms_to_ticks(input_buffer_ms)):
		return false
	if not is_on_floor() and not allow_air_roll:
		return false
	_buffer.consume(&"roll")
	return true


func try_consume_attack() -> bool:
	if not _buffer.is_buffered(&"attack", _tick, ms_to_ticks(input_buffer_ms)):
		return false
	_buffer.consume(&"attack")
	return true


func try_consume_parry() -> bool:
	if not _buffer.is_buffered(&"parry", _tick, ms_to_ticks(input_buffer_ms)):
		return false
	_buffer.consume(&"parry")
	return true


## Read-only accessors for the debug overlay.
func get_tick() -> int:
	return _tick


func get_state_name() -> StringName:
	return _state_machine.get_current_name()


func get_buffer() -> InputBuffer:
	return _buffer
