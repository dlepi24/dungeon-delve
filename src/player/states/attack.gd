extends PlayerState
## Animation commitment with a cancel window, per the GDD.
##
## Shape: startup (wind-up) -> active (hitbox open) -> recovery (the punish
## window). Facing locks at the start, so you commit to a direction as well as to
## the timing. Cancel-into-roll opens partway through; where it opens is the
## primary tuning knob the GDD calls out.

var _elapsed: int = 0
var _hitbox_open: bool = false


func enter() -> void:
	_elapsed = 0
	_hitbox_open = false
	# Lock facing now. Holding a direction commits to it (weight); with no
	# direction, aim at the nearest enemy so a deliberate swing lands instead of
	# whiffing behind you.
	var dir: float = player.get_input_direction()
	if is_zero_approx(dir):
		player.aim_at_nearest_enemy()
	else:
		player.update_facing(dir)

	# The riposte is spent on this swing whether or not it lands. Cashing it in
	# is a decision, so a panicked whiff burns it.
	var was_riposte: bool = player.is_riposte_open()
	# Riposte bonus and the permanent damage upgrade stack multiplicatively.
	var multiplier: float = (player.riposte_damage_multiplier if was_riposte else 1.0) * player.damage_multiplier()
	player.attack_hitbox.damage = player.weapon_damage() * multiplier
	# A riposte chips poise just as hard as it damages, so cashing one in also
	# blows through armor. Parry already broke their stance; this keeps it broken.
	player.attack_hitbox.poise_damage = player.weapon_poise_damage() * multiplier
	player.attack_hitbox.is_riposte = was_riposte
	player.consume_riposte()


func exit() -> void:
	player.attack_hitbox.deactivate()
	_hitbox_open = false


func physics_update(delta: float) -> StringName:
	_elapsed += 1
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.get_input_direction() * player.weapon_move_control())

	# Scaled by attack speed (weapon upgrade + Haste/Frenzy), so a faster swing is
	# genuinely faster, not just bigger numbers.
	var startup: int = player.attack_startup_ticks()
	var active_end: int = startup + player.attack_active_ticks()
	var total: int = active_end + player.attack_recovery_ticks()

	var should_be_open: bool = _elapsed > startup and _elapsed <= active_end
	if should_be_open and not _hitbox_open:
		_hitbox_open = true
		player.attack_hitbox.activate()
	elif not should_be_open and _hitbox_open:
		_hitbox_open = false
		player.attack_hitbox.deactivate()

	if _elapsed >= player.attack_cancel_ticks() and player.try_consume_roll():
		return &"Roll"

	if _elapsed >= total:
		if not player.is_on_floor():
			return &"Air"
		return &"Idle" if is_zero_approx(player.get_input_direction()) else &"Run"
	return &""
