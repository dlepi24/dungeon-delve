class_name TrainingDummy
extends CharacterBody2D
## A stationary target that swings on a loop so parry has something to read.
##
## Not an enemy: no AI, no chasing, no death. M3 builds real enemies with real
## FSMs; this exists so the M1 combat verbs can be judged against something.
##
## Deliberately a plain enum-and-counters machine rather than the player's
## node-based FSM. Five states with no shared behaviour do not earn that
## ceremony, and M3 will know far more about what enemies actually need. Copying
## the player's structure now would be guessing at the abstraction.
##
## The colour changes are not juice: the GDD requires enemies telegraph
## everything, and in gray-box a colour IS the telegraph. M2 replaces this with
## real feedback.

enum State { IDLE, TELEGRAPH, SWING, RECOVER, STAGGER }

## Dummy state → grunt-sheet animation. The sheet names the strike "attack"; the
## dummy calls it SWING. Mapping here is what makes it actually wind up and swing
## instead of only changing colour, so the parry has real motion to read.
const _ANIM: Dictionary[State, StringName] = {
	State.IDLE: &"idle",
	State.TELEGRAPH: &"telegraph",
	State.SWING: &"attack",
	State.RECOVER: &"recover",
	State.STAGGER: &"stagger",
}

@export_group("Timing")
## Long and obvious on purpose. "Telegraph everything. Readability over surprise."
## This is the number to tune when the parry window feels unfair.
@export var telegraph_ms: int = 550
@export var swing_active_ms: int = 90
@export var recover_ms: int = 450
@export var idle_ms: int = 700
## How long a parry staggers it. This is the window the riposte is cashed in.
@export var stagger_ms: int = 800

@export_group("Combat")
@export var max_health: float = 240.0
@export var attack_damage: float = 10.0

@export_group("Readability")
@export var colour_idle: Color = Color(0.62, 0.62, 0.66)
@export var colour_telegraph: Color = Color(0.95, 0.78, 0.25)
@export var colour_swing: Color = Color(0.9, 0.28, 0.28)
@export var colour_recover: Color = Color(0.45, 0.45, 0.5)
@export var colour_stagger: Color = Color(0.35, 0.65, 1.0)

var health: float = 0.0

var _state: State = State.IDLE
var _elapsed: int = 0

@onready var _juice: BodyJuice = $VisualRoot
@onready var _hitbox: Hitbox = $Hitbox
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _sprite: AnimatedSprite2D = $VisualRoot/Sprite

var _player: Node2D = null


func _ready() -> void:
	health = max_health
	_hitbox.deactivate()
	_hitbox.parried.connect(_on_parried)
	_hurtbox.hurt.connect(_on_hurt)
	# The strike should snap and the wind-up should read; the base sheet speed is
	# tuned for slow prop flickers, so give the telling animations their own pace.
	if _sprite != null and _sprite.sprite_frames != null:
		var frames: SpriteFrames = _sprite.sprite_frames
		for anim: StringName in [&"idle", &"telegraph", &"attack"]:
			if frames.has_animation(anim):
				frames.set_animation_speed(anim, {&"idle": 3.0, &"telegraph": 6.0, &"attack": 16.0}[anim])
	_enter(State.IDLE)


func _physics_process(delta: float) -> void:
	# Opt in to the freeze, like every other gameplay system. Forget this and the
	# dummy keeps swinging through a hitstop, which reads as a bug.
	if Hitstop.is_frozen():
		return

	_elapsed += 1
	_hitbox.damage = attack_damage
	_face_player()

	if not is_on_floor():
		velocity.y += 1800.0 * delta
	move_and_slide()

	match _state:
		State.IDLE:
			if _elapsed >= Ticks.from_ms(idle_ms):
				_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			if _elapsed >= Ticks.from_ms(telegraph_ms):
				_enter(State.SWING)
		State.SWING:
			if _elapsed >= Ticks.from_ms(swing_active_ms):
				_enter(State.RECOVER)
		State.RECOVER:
			if _elapsed >= Ticks.from_ms(recover_ms):
				_enter(State.IDLE)
		State.STAGGER:
			if _elapsed >= Ticks.from_ms(stagger_ms):
				_enter(State.IDLE)


func _enter(next: State) -> void:
	_state = next
	_elapsed = 0

	# The hitbox is only ever open during SWING. Everything else closes it, which
	# also means a stagger cancels an in-flight swing.
	if next == State.SWING:
		_hitbox.activate()
	else:
		_hitbox.deactivate()

	_juice.set_base_colour(_colour_for(next))
	if _sprite != null and _sprite.sprite_frames != null:
		var anim: StringName = _ANIM.get(next, &"idle")
		if _sprite.sprite_frames.has_animation(anim):
			_sprite.play(anim)


## Turn to face the player so the swing points at them (the hitbox already
## reaches both sides — this is purely so the animation reads).
func _face_player() -> void:
	if _sprite == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _player != null:
		_sprite.flip_h = _player.global_position.x < global_position.x


func _colour_for(state: State) -> Color:
	match state:
		State.TELEGRAPH:
			return colour_telegraph
		State.SWING:
			return colour_swing
		State.RECOVER:
			return colour_recover
		State.STAGGER:
			return colour_stagger
		_:
			return colour_idle


func _on_parried() -> void:
	_enter(State.STAGGER)
	_juice.punch(Vector2(0.78, 1.24))


func _on_hurt(hitbox: Hitbox) -> void:
	health = maxf(0.0, health - hitbox.damage)
	_juice.flash()
	_juice.punch(Vector2(1.24, 0.8) if hitbox.is_riposte else Vector2(1.12, 0.9))
	# A practice dummy is wood: the hollow knock is the training-hall sound.
	Events.hit_landed.emit(hitbox.damage, hitbox.is_riposte, hitbox.impact_profile, &"wood")
	# No death at M1 — a dummy you can kill is a dummy you cannot practise on.
	# M3 owns health, death and hurt states properly.
	if health <= 0.0:
		health = max_health


func get_state_name() -> String:
	return State.keys()[_state]
