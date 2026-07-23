class_name TutorialBoss
extends CharacterBody2D
## The guided intro's capstone: a scripted, heavily-telegraphed, near-unlosable
## set-piece — the Foreman of the Lost Crews. It teaches "bosses are READABLE"
## with the kit you just learned: read the long wind-up, ROLL the strike or PARRY
## it for a riposte, punish the recovery. Deliberately slow, low-damage and
## forgiving — and if it does kill you, the director just revives you.
##
## NOT a data-driven Enemy: a self-contained FSM reusing the combat primitives
## (Hurtbox to take hits, Hitbox to deal them, BodyJuice for the telegraph tint),
## the same proven path as the training dummy — so parry→riposte, hitstop and
## death all work without touching the enemy roster.

signal died

enum State { INTRO, IDLE, APPROACH, TELEGRAPH, STRIKE, RECOVER, STAGGER, DEAD }

## Boss state → overseer-sheet animation, so the wind-up and strike are real
## motion (BodyJuice adds the yellow/red telegraph tint on top).
const _ANIM: Dictionary[State, StringName] = {
	State.INTRO: &"idle", State.IDLE: &"idle", State.APPROACH: &"chase",
	State.TELEGRAPH: &"telegraph", State.STRIKE: &"attack",
	State.RECOVER: &"recover", State.STAGGER: &"stagger", State.DEAD: &"dead",
}

@export_group("Timing (ms)")
@export var intro_ms: int = 900
@export var idle_ms: int = 450
## Long and obvious on purpose — this is a teaching boss, not a wall.
@export var telegraph_ms: int = 720
@export var strike_ms: int = 140
@export var recover_ms: int = 560
## The riposte window a parry opens.
@export var stagger_ms: int = 950

@export_group("Combat")
@export var max_health: float = 120.0
## A sting, not an execution — you should have to try to die here.
@export var attack_damage: float = 8.0
@export var move_speed: float = 68.0
@export var attack_range: float = 158.0

@export_group("Readability")
@export var colour_idle: Color = Color(0.55, 0.55, 0.6)
@export var colour_telegraph: Color = Color(0.95, 0.78, 0.25)
@export var colour_strike: Color = Color(0.92, 0.26, 0.26)
@export var colour_stagger: Color = Color(0.35, 0.65, 1.0)

var health: float = 0.0
var _state: State = State.INTRO
var _elapsed: int = 0
var _player: Node2D = null
var _hitbox_offset: float = 70.0

@onready var _juice: BodyJuice = $VisualRoot
@onready var _sprite: AnimatedSprite2D = $VisualRoot/Sprite
@onready var _hitbox: Hitbox = $Hitbox
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _health_bar: HealthBar = $HealthBar


func _ready() -> void:
	health = max_health
	_hitbox_offset = absf(_hitbox.position.x)
	_hitbox.deactivate()
	_hitbox.damage = attack_damage
	_hitbox.parryable = true
	_hitbox.parried.connect(_on_parried)
	_hurtbox.hurt.connect(_on_hurt)
	_health_bar.set_ratio(1.0)
	# Snap the strike and let the wind-up read; the baked base speed is tuned for
	# slow prop flickers, not a fight.
	if _sprite != null and _sprite.sprite_frames != null:
		for anim: StringName in [&"telegraph", &"attack", &"chase"]:
			if _sprite.sprite_frames.has_animation(anim):
				_sprite.sprite_frames.set_animation_speed(anim,
					{&"telegraph": 6.0, &"attack": 14.0, &"chase": 7.0}[anim])
	_enter(State.INTRO)


func _physics_process(delta: float) -> void:
	if Hitstop.is_frozen():
		return
	_elapsed += 1
	_resolve_player()
	_face_player()
	velocity.x = 0.0
	if _state == State.APPROACH and _player != null:
		velocity.x = signf(_player.global_position.x - global_position.x) * move_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y + 1800.0 * delta
	move_and_slide()
	_tick_state()


func _tick_state() -> void:
	match _state:
		State.INTRO:
			if _elapsed >= Ticks.from_ms(intro_ms):
				_enter(State.APPROACH)
		State.IDLE:
			if _elapsed >= Ticks.from_ms(idle_ms):
				_enter(State.APPROACH)
		State.APPROACH:
			if _player != null and absf(_player.global_position.x - global_position.x) <= attack_range:
				_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			if _elapsed >= Ticks.from_ms(telegraph_ms):
				_enter(State.STRIKE)
		State.STRIKE:
			if _elapsed >= Ticks.from_ms(strike_ms):
				_enter(State.RECOVER)
		State.RECOVER:
			if _elapsed >= Ticks.from_ms(recover_ms):
				_enter(State.IDLE)
		State.STAGGER:
			if _elapsed >= Ticks.from_ms(stagger_ms):
				_enter(State.IDLE)
		State.DEAD:
			pass


func _enter(next: State) -> void:
	_state = next
	_elapsed = 0
	# The hitbox is only ever open during the strike; a stagger cancels it.
	if next == State.STRIKE:
		_hitbox.activate()
	else:
		_hitbox.deactivate()
	_juice.set_base_colour(_colour_for(next))
	_play_anim(next)
	if next == State.INTRO:
		Events.boss_engaged.emit(self)


func _play_anim(state: State) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var anim: StringName = _ANIM.get(state, &"idle")
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


func _colour_for(state: State) -> Color:
	match state:
		State.TELEGRAPH:
			return colour_telegraph
		State.STRIKE:
			return colour_strike
		State.STAGGER:
			return colour_stagger
		_:
			return colour_idle


func _resolve_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D


func _face_player() -> void:
	if _player == null or _sprite == null:
		return
	var facing_left: bool = _player.global_position.x < global_position.x
	_sprite.flip_h = facing_left
	_hitbox.position.x = -_hitbox_offset if facing_left else _hitbox_offset


func _on_parried() -> void:
	if _state == State.DEAD:
		return
	_enter(State.STAGGER)
	_juice.punch(Vector2(0.8, 1.2))


func _on_hurt(hitbox: Hitbox) -> void:
	if _state == State.DEAD:
		return
	health = maxf(0.0, health - hitbox.damage)
	_health_bar.set_ratio(health / max_health)
	_juice.flash()
	_juice.punch(Vector2(1.2, 0.85))
	if health <= 0.0:
		_die()


func _die() -> void:
	_enter(State.DEAD)
	velocity = Vector2.ZERO
	_hitbox.deactivate()
	# Deferred: we may be inside the hurtbox's signal, mid-physics-flush.
	_hurtbox.set_deferred(&"monitoring", false)
	_health_bar.visible = false
	Events.enemy_died.emit(self)
	died.emit()


func get_state_name() -> String:
	return State.keys()[_state]
