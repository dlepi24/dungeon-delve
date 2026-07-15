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
	# Lock facing now. Committing to a direction is half of what gives an attack
	# weight; being able to spin mid-swing would undo the commitment entirely.
	player.update_facing(player.get_input_direction())

	# The riposte is spent on this swing whether or not it lands. Cashing it in
	# is a decision, so a panicked whiff burns it.
	var was_riposte: bool = player.is_riposte_open()
	player.attack_hitbox.damage = player.attack_damage * (player.riposte_damage_multiplier if was_riposte else 1.0)
	player.attack_hitbox.is_riposte = was_riposte
	player.consume_riposte()


func exit() -> void:
	player.attack_hitbox.deactivate()
	_hitbox_open = false


func physics_update(delta: float) -> StringName:
	_elapsed += 1
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.get_input_direction() * player.attack_move_control)

	var startup: int = player.ms_to_ticks(player.attack_startup_ms)
	var active_end: int = startup + player.ms_to_ticks(player.attack_active_ms)
	var total: int = active_end + player.ms_to_ticks(player.attack_recovery_ms)

	var should_be_open: bool = _elapsed > startup and _elapsed <= active_end
	if should_be_open and not _hitbox_open:
		_hitbox_open = true
		player.attack_hitbox.activate()
	elif not should_be_open and _hitbox_open:
		_hitbox_open = false
		player.attack_hitbox.deactivate()

	if _elapsed >= player.ms_to_ticks(player.attack_cancel_start_ms) and player.try_consume_roll():
		return &"Roll"

	if _elapsed >= total:
		if not player.is_on_floor():
			return &"Air"
		return &"Idle" if is_zero_approx(player.get_input_direction()) else &"Run"
	return &""
