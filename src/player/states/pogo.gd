extends PlayerState
## The Pick Pogo — the traversal verb (GDD 2026-07-18, Dustin's call).
##
## In the air, attack while holding down: the pick strikes BENEATH you, and
## anything it connects with launches you back up past jump height, air
## control refreshed. Enemies, the Overseer, falling debris (destroyed on the
## bounce), even spike beds — struck from above, the mine's teeth are
## footholds. It needs a TARGET, which is the point: pure verticality still
## belongs to the tier layouts; the pogo is expression, earned mid-fight.
##
## Costs no input budget (down + attack, both long bound) and does not consume
## a riposte — that stays the sword's payoff.

var _elapsed: int = 0
var _bounced: bool = false
var _saved_mask: int = 0

const POGO_SIZE: Vector2 = Vector2(54, 34)
const POGO_OFFSET: Vector2 = Vector2(0, 24)


func enter() -> void:
	_elapsed = 0
	_bounced = false
	var hitbox: Hitbox = player.attack_hitbox
	# Strike costs no riposte and chips little poise: movement first, damage second.
	hitbox.damage = player.weapon_damage() * player.pogo_damage_mult * player.damage_multiplier()
	hitbox.poise_damage = player.weapon_poise_damage() * 0.5
	hitbox.is_riposte = false
	var shape: RectangleShape2D = hitbox.get_node("CollisionShape2D").shape as RectangleShape2D
	if shape != null:
		shape.size = POGO_SIZE
	var swing: ColorRect = hitbox.visual as ColorRect
	if swing != null:
		swing.size = POGO_SIZE
		swing.position = -POGO_SIZE * 0.5
		swing.color = player.weapon_swing_colour()
	# Hazards and projectiles live on EnemyAttack; the pick must feel them to
	# bounce off them. Restored on exit.
	_saved_mask = hitbox.collision_mask
	hitbox.collision_mask = _saved_mask | CollisionLayers.ENEMY_ATTACK


func exit() -> void:
	var hitbox: Hitbox = player.attack_hitbox
	hitbox.deactivate()
	hitbox.collision_mask = _saved_mask
	player.reset_attack_hitbox()


func physics_update(delta: float) -> StringName:
	_elapsed += 1
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.get_input_direction() * 0.6)

	var hitbox: Hitbox = player.attack_hitbox
	# The player repositions the hitbox for the equipped weapon every tick;
	# the pogo points it down again after.
	hitbox.position = POGO_OFFSET

	var startup: int = player.ms_to_ticks(player.pogo_startup_ms)
	var active_end: int = startup + player.ms_to_ticks(player.pogo_active_ms)

	if _elapsed == startup:
		hitbox.activate()

	if _elapsed > startup and not _bounced:
		if hitbox.hit_count() > 0:
			_bounce()
		else:
			for area: Area2D in hitbox.get_overlapping_areas():
				if area is Projectile:
					area.queue_free()
					_bounce()
					player.pogo_bounced()
					break
				elif area is Spikes:
					_bounce()
					player.pogo_bounced()
					break

	if _bounced:
		return &"Air"
	if player.is_on_floor():
		return &"Idle"
	if _elapsed >= active_end:
		return &"Air"
	return &""


func _bounce() -> void:
	_bounced = true
	player.velocity.y = -player.pogo_bounce_speed


## Getting hit mid-pogo is a normal hit — no armor, no parry.
func on_hit(_hitbox: Hitbox) -> StringName:
	return &"Hitstun"
