class_name Enemy
extends CharacterBody2D
## Approach, telegraph, attack, recover, react, die.
##
## One state machine, parameterised entirely by an EnemyStats resource. There are
## no enemy subclasses: the Dart's lunge is `dash_speed` on an attack, which is a
## number, not a verb. Adding an enemy means adding a `.tres`.
##
## POISE is the reason attacks are worth respecting. From the start of a telegraph
## to the end of the active window, hits chip the attack's poise instead of
## interrupting it — so a heavy swing lands even if you poke it. Outside that
## window the enemy flinches freely, which keeps the pace at Dead Cells rather
## than Dark Souls. See the GDD decision log.
##
## Finds the player through the "player" group, resolved LAZILY. Caching it in
## _ready silently returned null (node _ready order) and the enemy just stood
## there forever. See CLAUDE.md.

enum State { IDLE, CHASE, TELEGRAPH, ATTACK, RECOVER, HURT, STAGGER, DEAD }

const GRAVITY: float = 1800.0

## The buffs an enemy can drop. A new buff for the pool is a .tres path here.
const BUFF_POOL: Array[String] = [
	"res://src/systems/buffs/haste.tres",
	"res://src/systems/buffs/might.tres",
	"res://src/systems/buffs/ironskin.tres",
	"res://src/systems/buffs/frenzy.tres",
]
## The weapons an enemy can drop. A new weapon is a .tres path here.
const WEAPON_POOL: Array[String] = [
	"res://src/systems/weapons/dagger.tres",
	"res://src/systems/weapons/maul.tres",
	"res://src/systems/weapons/spear.tres",
]

@export var stats: EnemyStats

var health: float = 0.0

var _state: State = State.IDLE
var _elapsed: int = 0
var _facing: int = 1
var _player: Player = null

## The attack currently being wound up or swung. Null outside TELEGRAPH/ATTACK.
var _attack: EnemyAttackData = null
## Poise remaining on the current attack. Refills when a new attack starts.
var _poise: float = 0.0
var _dash_direction: int = 1
var _last_jump_tick: int = -10000
var _boss_announced: bool = false
## Full-2D commit direction for a flyer's dive, locked at ATTACK start like the
## horizontal dash direction is.
var _dash_vector: Vector2 = Vector2.RIGHT
## Ticks of recent hits that caused a flinch, oldest first. See flinch fatigue.
var _flinch_ticks: Array[int] = []
## stats.max_health scaled by mine heat at spawn. Health bars divide by this.
var _scaled_max_health: float = 1.0
var _tick: int = 0

@onready var _juice: BodyJuice = $VisualRoot
@onready var _visual: ColorRect = $VisualRoot/Visual
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _hitbox: Hitbox = $Hitbox
@onready var _hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var _health_bar: HealthBar = $HealthBar
@onready var _ground_probe: RayCast2D = $GroundProbe


func _ready() -> void:
	assert(stats != null, "Enemy has no EnemyStats resource assigned.")
	add_to_group(&"enemies")
	# Mine heat (the extract streak) toughens everything at spawn time. The
	# .tres stays the baseline; the multiplier is read once here so a fight
	# never changes difficulty mid-swing.
	_scaled_max_health = stats.max_health * GameState.heat_health_multiplier()
	health = _scaled_max_health
	_apply_stats_to_body()
	_hitbox.deactivate()
	_hitbox.parried.connect(_on_parried)
	_hurtbox.hurt.connect(_on_hurt)
	_enter(State.IDLE)


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

	_health_bar.position = Vector2(0, -stats.body_size.y - 14.0)
	_health_bar.bar_size = Vector2(maxf(38.0, stats.body_size.x * 1.35), 6.0)

	# Probe for the ground ahead, used to decide whether to jump a gap.
	_ground_probe.target_position = Vector2(0, 48)


func _physics_process(delta: float) -> void:
	if Hitstop.is_frozen():
		return

	_tick += 1
	_elapsed += 1

	if not is_on_floor() and not stats.can_fly:
		velocity.y += GRAVITY * delta

	match _state:
		State.IDLE:
			_decelerate(delta)
			_face_player()
			if _player_distance() <= stats.aggro_range and _elapsed >= Ticks.from_ms(stats.idle_ms):
				_enter(State.CHASE)
				# A boss announces itself the FIRST time the fight starts, not
				# every time you kite out of range and back in.
				if stats.is_boss and not _boss_announced:
					_boss_announced = true
					Events.boss_engaged.emit(self)
					Rumble.boss()
		State.CHASE:
			_chase(delta)
			var attack: EnemyAttackData = _pick_attack()
			if attack != null and _roughly_level_with_player():
				_begin_attack(attack)
			elif _player_distance() > stats.aggro_range:
				_enter(State.IDLE)
		State.TELEGRAPH:
			_decelerate(delta)
			_face_player()
			if _elapsed >= Ticks.from_ms(_attack.telegraph_ms):
				_enter(State.ATTACK)
		State.ATTACK:
			if _attack.dash_speed > 0.0:
				if stats.can_fly:
					# A dive commits along the locked 2D line.
					velocity = _dash_vector * _attack.dash_speed
				else:
					velocity.x = float(_dash_direction) * _attack.dash_speed
			else:
				_decelerate(delta)
			if _elapsed >= Ticks.from_ms(_attack.active_ms):
				_enter(State.RECOVER)
		State.RECOVER:
			_decelerate(delta)
			if _elapsed >= Ticks.from_ms(_attack.recover_ms if _attack != null else 400):
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
			_update_corpse()

	move_and_slide()


## Poise only exists while an attack is committed. Everywhere else a hit flinches.
func _has_poise() -> bool:
	return (_state == State.TELEGRAPH or _state == State.ATTACK) and _attack != null


## Attacks whose range band contains the player, picked by weight.
##
## Randomness comes from the seeded service, not randf(): an enemy's choices are
## gameplay, and an unseeded draw would desync ghost replays. The stream is named
## separately from "delve" so combat decisions can never shift the level layout.
func _pick_attack() -> EnemyAttackData:
	if stats.attacks.is_empty():
		return null
	var distance: float = _player_distance()
	var options: Array[EnemyAttackData] = []
	var total: float = 0.0
	for attack: EnemyAttackData in stats.attacks:
		if distance >= attack.min_range and distance <= attack.max_range:
			options.append(attack)
			total += maxf(0.0, attack.weight)
	if options.is_empty():
		return null
	if total <= 0.0:
		return options[0]
	var roll: float = Rng.stream(&"enemy_ai").randf() * total
	for attack: EnemyAttackData in options:
		roll -= maxf(0.0, attack.weight)
		if roll <= 0.0:
			return attack
	return options[options.size() - 1]


## Do not swing at someone standing on a ledge above your head.
## Where a thrown projectile leaves from: chest height, leading edge.
func _muzzle() -> Vector2:
	return global_position + Vector2(float(_facing) * stats.body_size.x * 0.5, -stats.body_size.y * 0.6)


## Spawned into the ROOM, not this enemy, so a rock in flight outlives its
## thrower. Aims at the player's centre at release — the telegraph was the
## warning; the release is honest.
func _fire_projectile() -> void:
	var direction: Vector2 = Vector2(float(_facing), 0.0)
	var player: Player = get_player()
	if player != null:
		direction = (player.global_position + Vector2(0, -30) - _muzzle())
	Projectile.spawn(get_parent(), _muzzle(), direction, _attack)


## Aim for a flyer's dive, locked at ATTACK start.
func _aim_at_player() -> Vector2:
	var player: Player = get_player()
	if player == null:
		return Vector2(float(_facing), 0.0)
	return (player.global_position + Vector2(0, -28) - global_position).normalized()


func _roughly_level_with_player() -> bool:
	if stats.can_fly:
		# Being above you is a flyer's whole job; the gate would mute it.
		return true
	var player: Player = get_player()
	if player == null:
		return false
	return absf(player.global_position.y - global_position.y) <= stats.body_size.y + 24.0


func _begin_attack(attack: EnemyAttackData) -> void:
	_attack = attack
	_poise = attack.poise
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = attack.hitbox_size
	_hitbox_shape.shape = rect
	_hitbox.damage = attack.damage * GameState.heat_damage_multiplier()
	var swing: ColorRect = _hitbox.visual as ColorRect
	if swing != null:
		swing.size = attack.hitbox_size
		swing.position = -attack.hitbox_size * 0.5
		swing.color = attack.colour_attack
	_enter(State.TELEGRAPH)


func _update_corpse() -> void:
	var linger: int = Ticks.from_ms(stats.corpse_linger_ms)
	var fade: int = Ticks.from_ms(stats.corpse_fade_ms)
	if _elapsed <= linger:
		return
	var progress: float = float(_elapsed - linger) / maxf(1.0, float(fade))
	_juice.modulate.a = clampf(1.0 - progress, 0.0, 1.0)
	if _elapsed >= linger + fade:
		queue_free()


func _enter(next: State) -> void:
	var previous: State = _state
	_state = next
	_elapsed = 0

	if next == State.ATTACK:
		# Lock the lunge direction now: a dash that steers mid-flight is
		# unreadable, and the commitment is what makes it fair to roll.
		_dash_direction = _facing
		_dash_vector = _aim_at_player()
		if _attack != null and _attack.projectile_speed > 0.0:
			# A throw, not a swing: the projectile IS the attack; the melee
			# box stays shut. Parryable in flight instead of at the arm.
			_fire_projectile()
		else:
			_hitbox.activate()
	elif previous == State.ATTACK:
		_hitbox.deactivate()

	if next == State.IDLE or next == State.HURT or next == State.STAGGER:
		_attack = null

	if next == State.DEAD:
		_on_death()

	_juice.set_base_colour(_colour_for(next))


func _colour_for(state: State) -> Color:
	match state:
		State.TELEGRAPH:
			return _attack.colour_telegraph if _attack != null else stats.colour_idle
		State.ATTACK:
			return _attack.colour_attack if _attack != null else stats.colour_idle
		State.RECOVER:
			return stats.colour_recover
		State.STAGGER:
			return stats.colour_stagger
		State.DEAD:
			return Color(0.2, 0.2, 0.22)
		_:
			return stats.colour_idle


func _decelerate(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, stats.acceleration * delta)


func _chase(delta: float) -> void:
	_face_player()
	var player: Player = get_player()
	if player == null:
		return
	if stats.can_fly:
		# Hold a perch beside and above the player, then let range checks
		# decide when to dive. Full-2D steering — hovering is the flyer's walk.
		var perch: Vector2 = player.global_position + Vector2(stats.hover_offset.x * float(-_facing), stats.hover_offset.y)
		var to_perch: Vector2 = perch - global_position
		velocity = velocity.move_toward(to_perch.normalized() * stats.move_speed * minf(1.0, to_perch.length() / 40.0), stats.acceleration * delta)
		return
	# Stop closing once in range of the longest attack, so they do not shove into
	# you and swing from inside your body.
	if _player_distance() > stats.preferred_range():
		velocity.x = move_toward(velocity.x, float(_facing) * stats.move_speed, stats.acceleration * delta)
	else:
		_decelerate(delta)
	_try_jump()


## Simple heuristics, not pathfinding: jump if the player is above us, or if the
## ground runs out ahead and they are further on. Enough to stop enemies standing
## uselessly while you snipe them from a ledge, without inventing a nav system.
func _try_jump() -> void:
	if not stats.can_jump or not is_on_floor():
		return
	if _tick - _last_jump_tick < Ticks.from_ms(stats.jump_cooldown_ms):
		return
	var player: Player = get_player()
	if player == null:
		return

	var player_is_above: bool = global_position.y - player.global_position.y > stats.jump_if_player_above
	# The probe rides ahead of us; nothing under it means a gap or a ledge.
	_ground_probe.position = Vector2(float(_facing) * (stats.body_size.x * 0.5 + 12.0), 0.0)
	_ground_probe.force_raycast_update()
	var gap_ahead: bool = not _ground_probe.is_colliding() and absf(velocity.x) > 10.0

	if not player_is_above and not gap_ahead:
		return
	_last_jump_tick = _tick
	velocity.y = -2.0 * stats.jump_height / maxf(0.001, stats.jump_time_to_peak)


func _face_player() -> void:
	var player: Player = get_player()
	if player == null:
		return
	_facing = 1 if player.global_position.x > global_position.x else -1


func _player_distance() -> float:
	var player: Player = get_player()
	if player == null:
		return INF
	return absf(player.global_position.x - global_position.x)


func get_facing() -> int:
	return _facing


## Resolved lazily and cached. Looking this up in _ready is a trap: node _ready
## order is not guaranteed, and a null here fails silently — the enemy simply
## stands still forever with no error.
func get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	return _player


func get_state_name() -> String:
	return State.keys()[_state]


## This enemy's real, heat-scaled maximum. The boss bar divides by this.
func max_health_value() -> float:
	return _scaled_max_health


func get_attack_name() -> String:
	return _attack.display_name if _attack != null else "-"


func get_poise() -> float:
	return _poise if _has_poise() else 0.0


func is_dead() -> bool:
	return _state == State.DEAD


## A parry breaks poise outright, whatever it is. That is the whole point: parry
## is the answer to a heavy attack you cannot poke through.
func _on_parried() -> void:
	if _state == State.DEAD:
		return
	_poise = 0.0
	_enter(State.STAGGER)
	_juice.punch(Vector2(0.78, 1.24))


func _on_hurt(hitbox: Hitbox) -> void:
	if _state == State.DEAD:
		return
	health = maxf(0.0, health - hitbox.damage)
	_health_bar.set_ratio(health / _scaled_max_health)
	_juice.flash()
	_juice.punch(Vector2(1.24, 0.8) if hitbox.is_riposte else Vector2(1.12, 0.9))
	Events.hit_landed.emit(hitbox.damage, hitbox.is_riposte)

	# Parented to our parent, not to us: a number or a spark stuck to a corpse
	# would fade out with it, and the kill is exactly when you want to read them.
	var host: Node = get_parent()
	var at: Vector2 = global_position - Vector2(0, stats.body_size.y * 0.6)
	if host != null:
		DamageNumber.spawn(host, at, hitbox.damage, hitbox.is_riposte)
		HitSpark.burst(host, at, _away_from(hitbox), hitbox.is_riposte)

	if health <= 0.0:
		_enter(State.DEAD)
		return

	# Poise: mid-attack, chip it rather than interrupting. Knockback is scaled
	# down too — shoving a committed enemy out of its own swing would undo the
	# armor just as surely as cancelling it.
	if _has_poise():
		_poise -= hitbox.poise_damage
		if _poise > 0.0:
			velocity.x = float(_away_from(hitbox)) * stats.knockback * 0.15
			return
		Events.poise_broken.emit(self)
		# A poise break staggers but grants NO riposte. Only a parry does, or
		# parry becomes a worse version of attacking.
		_enter(State.STAGGER)
		velocity.x = float(_away_from(hitbox)) * stats.knockback
		return

	# Flinch fatigue: hits keep hurting, but only flinch_limit of them can
	# INTERRUPT within the window. Past that the enemy shrugs through — the
	# infinite poke-chain was beating everything heavier than a grunt, which
	# made weapon choice and parry timing irrelevant against big enemies.
	var window: int = Ticks.from_ms(stats.flinch_window_ms)
	while not _flinch_ticks.is_empty() and _tick - _flinch_ticks[0] > window:
		_flinch_ticks.remove_at(0)
	if _flinch_ticks.size() >= stats.flinch_limit:
		return
	_flinch_ticks.append(_tick)
	velocity.x = float(_away_from(hitbox)) * stats.knockback
	if _state != State.STAGGER:
		_enter(State.HURT)


func _away_from(hitbox: Hitbox) -> int:
	return 1 if hitbox.global_position.x < global_position.x else -1


func _on_death() -> void:
	_hitbox.deactivate()
	_health_bar.visible = false
	_death_burst()
	_hurtbox.set_deferred(&"monitorable", false)
	_hurtbox.set_deferred(&"monitoring", false)
	collision_layer = 0
	_drop_haul()
	Events.enemy_died.emit(self)
	_juice.punch(Vector2(1.5, 0.5))


## Scatter the reward as pickups: mostly small ore, an occasional big chunk, and
## sometimes a heart. A shower of loot reads better than one lump.
##
## Drop rolls come from the SEEDED service, not randf(): drops are gameplay, so
## two players on one daily seed must get the same loot. The stream is named apart
## from "delve" so it can never shift the level layout.
## A burst of body-coloured chunks on the kill, so a death reads as an impact
## even while the corpse lingers. Parented to the room — it must outlive us.
func _death_burst() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 14
	burst.lifetime = 0.55
	burst.direction = Vector2(0, -1)
	burst.spread = 80.0
	burst.initial_velocity_min = 70.0
	burst.initial_velocity_max = 190.0
	burst.gravity = Vector2(0, 620)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = stats.colour_idle
	host.add_child(burst)
	burst.global_position = global_position + Vector2(0, -stats.body_size.y * 0.5)
	burst.finished.connect(burst.queue_free)


func _drop_haul() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var scene: PackedScene = load("res://src/systems/pickup.tscn") as PackedScene
	if scene == null:
		return
	var rng: RandomNumberGenerator = Rng.stream(&"drops")
	var origin: Vector2 = global_position + Vector2(0, -stats.body_size.y * 0.5)
	# Each ore unit is worth more the deeper you are — the incentive to push on.
	var per_unit: int = maxi(1, roundi(GameState.depth_haul_multiplier()))

	for i: int in stats.haul_reward:
		# Roughly one in five nuggets is a big chunk worth several.
		var big: bool = rng.randf() < 0.2
		var nugget: Pickup = scene.instantiate() as Pickup
		nugget.kind = Pickup.Kind.HAUL
		nugget.amount = per_unit * (5 if big else 1)
		nugget.global_position = origin
		host.add_child(nugget)

	if rng.randf() < stats.heart_chance and stats.heart_heal > 0:
		var heart: Pickup = scene.instantiate() as Pickup
		heart.kind = Pickup.Kind.HEAL
		heart.amount = stats.heart_heal
		heart.global_position = origin
		host.add_child(heart)

	if rng.randf() < stats.buff_chance and not BUFF_POOL.is_empty():
		var choice: String = BUFF_POOL[rng.randi_range(0, BUFF_POOL.size() - 1)]
		var b: Pickup = scene.instantiate() as Pickup
		b.kind = Pickup.Kind.BUFF
		b.buff = load(choice) as BuffData
		b.global_position = origin
		host.add_child(b)

	if rng.randf() < stats.weapon_chance and not WEAPON_POOL.is_empty():
		var wchoice: String = WEAPON_POOL[rng.randi_range(0, WEAPON_POOL.size() - 1)]
		var w: Pickup = scene.instantiate() as Pickup
		w.kind = Pickup.Kind.WEAPON
		w.weapon = load(wchoice) as WeaponData
		w.global_position = origin
		host.add_child(w)
