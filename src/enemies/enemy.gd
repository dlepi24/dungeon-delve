class_name Enemy
extends CharacterBody2D
## Base for real enemies. Approach, telegraph, attack, recover, react, die.
##
## One state machine, parameterised by an EnemyStats resource, with a virtual
## hook for the attack itself. The roadmap says "enemy types with their own
## FSMs"; three copies of approach->telegraph->swing would have been three places
## to fix every bug, and would break the rule that new content is a resource file
## rather than a system edit. So: numbers live in `.tres`, and only genuinely
## different VERBS (a stationary swing vs a dash) subclass _attack_* below.
##
## Finds the player through the "player" group rather than a node path, so an
## enemy can be dropped into any room without knowing its layout.

enum State { IDLE, CHASE, TELEGRAPH, ATTACK, RECOVER, HURT, STAGGER, DEAD }

const GRAVITY: float = 1800.0

@export var stats: EnemyStats

var health: float = 0.0

var _state: State = State.IDLE
var _elapsed: int = 0
var _facing: int = 1
var _player: Player = null

@onready var _juice: BodyJuice = $VisualRoot
@onready var _visual: ColorRect = $VisualRoot/Visual
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _hitbox: Hitbox = $Hitbox
@onready var _hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D


func _ready() -> void:
	assert(stats != null, "Enemy has no EnemyStats resource assigned.")
	health = stats.max_health
	_apply_stats_to_body()
	_hitbox.deactivate()
	_hitbox.parried.connect(_on_parried)
	_hurtbox.hurt.connect(_on_hurt)
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_enter(State.IDLE)


## Body and box sizes come from the resource too, so a "big heavy one" is a data
## change rather than a new scene.
func _apply_stats_to_body() -> void:
	_visual.offset_left = -stats.body_size.x * 0.5
	_visual.offset_right = stats.body_size.x * 0.5
	_visual.offset_top = -stats.body_size.y
	_visual.offset_bottom = 0.0

	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = stats.body_size.x * 0.5
	capsule.height = stats.body_size.y
	_body_shape.shape = capsule
	_body_shape.position = Vector2(0, -stats.body_size.y * 0.5)

	var hurt_capsule: CapsuleShape2D = CapsuleShape2D.new()
	hurt_capsule.radius = stats.body_size.x * 0.5
	hurt_capsule.height = stats.body_size.y
	_hurtbox_shape.shape = hurt_capsule
	_hurtbox_shape.position = Vector2(0, -stats.body_size.y * 0.5)

	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = stats.hitbox_size
	_hitbox_shape.shape = rect


func _physics_process(delta: float) -> void:
	# Opt in to the freeze like everything else, or this keeps swinging through
	# a hitstop and reads as a bug.
	if Hitstop.is_frozen():
		return

	_elapsed += 1
	_hitbox.damage = stats.damage

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	_hitbox.position = Vector2(stats.hitbox_offset.x * float(_facing), stats.hitbox_offset.y)

	match _state:
		State.IDLE:
			_decelerate(delta)
			_face_player()
			if _player_distance() <= stats.aggro_range and _elapsed >= Ticks.from_ms(stats.idle_ms):
				_enter(State.CHASE)
		State.CHASE:
			_chase(delta)
			if _player_distance() <= stats.attack_range:
				_enter(State.TELEGRAPH)
			elif _player_distance() > stats.aggro_range:
				_enter(State.IDLE)
		State.TELEGRAPH:
			_decelerate(delta)
			_face_player()
			if _elapsed >= Ticks.from_ms(stats.telegraph_ms):
				_enter(State.ATTACK)
		State.ATTACK:
			_attack_physics(delta)
			if _elapsed >= Ticks.from_ms(stats.swing_active_ms):
				_enter(State.RECOVER)
		State.RECOVER:
			_decelerate(delta)
			if _elapsed >= Ticks.from_ms(stats.recover_ms):
				_enter(State.IDLE)
		State.HURT:
			_decelerate(delta)
			if _elapsed >= Ticks.from_ms(stats.hurt_ms):
				_enter(State.IDLE)
		State.STAGGER:
			_decelerate(delta)
			if _elapsed >= Ticks.from_ms(stats.stagger_ms):
				_enter(State.IDLE)
		State.DEAD:
			_decelerate(delta)

	move_and_slide()


func _enter(next: State) -> void:
	var previous: State = _state
	_state = next
	_elapsed = 0

	# The hitbox is open during ATTACK and nowhere else, so a stagger or a death
	# cancels an in-flight swing for free.
	if next == State.ATTACK:
		_attack_start()
	elif previous == State.ATTACK:
		_attack_end()
		_hitbox.deactivate()

	if next == State.DEAD:
		_on_death()

	_juice.set_base_colour(_colour_for(next))


func _colour_for(state: State) -> Color:
	match state:
		State.TELEGRAPH:
			return stats.colour_telegraph
		State.ATTACK:
			return stats.colour_attack
		State.RECOVER:
			return stats.colour_recover
		State.STAGGER:
			return stats.colour_stagger
		State.DEAD:
			return Color(0.2, 0.2, 0.22)
		_:
			return stats.colour_idle


# --- Virtual hooks. Subclasses override these; everything else is data. ---

## Called once when the attack becomes live.
func _attack_start() -> void:
	_hitbox.activate()


## Called every tick while the attack is live.
func _attack_physics(delta: float) -> void:
	_decelerate(delta)


## Called once when the attack ends.
func _attack_end() -> void:
	pass


# --- Shared movement ---

func _decelerate(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, stats.acceleration * delta)


func _chase(delta: float) -> void:
	_face_player()
	velocity.x = move_toward(velocity.x, float(_facing) * stats.move_speed, stats.acceleration * delta)


func _face_player() -> void:
	if _player == null:
		return
	_facing = 1 if _player.global_position.x > global_position.x else -1


func _player_distance() -> float:
	if _player == null:
		return INF
	return absf(_player.global_position.x - global_position.x)


func get_facing() -> int:
	return _facing


func get_player() -> Player:
	return _player


func get_state_name() -> String:
	return State.keys()[_state]


func is_dead() -> bool:
	return _state == State.DEAD


# --- Reactions ---

func _on_parried() -> void:
	if _state == State.DEAD:
		return
	_enter(State.STAGGER)
	_juice.punch(Vector2(0.78, 1.24))


func _on_hurt(hitbox: Hitbox) -> void:
	if _state == State.DEAD:
		return
	health = maxf(0.0, health - hitbox.damage)
	_juice.flash()
	_juice.punch(Vector2(1.24, 0.8) if hitbox.is_riposte else Vector2(1.12, 0.9))
	Events.hit_landed.emit(hitbox.damage, hitbox.is_riposte)

	var away: int = 1 if hitbox.global_position.x < global_position.x else -1
	velocity.x = float(away) * stats.knockback

	if health <= 0.0:
		_enter(State.DEAD)
	# A stagger outranks a hurt: being parried should not be cut short by chip damage.
	elif _state != State.STAGGER:
		_enter(State.HURT)


func _on_death() -> void:
	_hitbox.deactivate()
	# Stop colliding with the player and stop being hittable, but stay visible so
	# the kill reads. M5 owns corpses, drops and cleanup properly.
	_hurtbox.set_deferred(&"monitorable", false)
	_hurtbox.set_deferred(&"monitoring", false)
	collision_layer = 0
	Events.enemy_died.emit(self)
	_juice.punch(Vector2(1.5, 0.5))
