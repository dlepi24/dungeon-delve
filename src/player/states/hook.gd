extends PlayerState
## The Timber Hook — the second movement verb (GDD 2026-07-18): skill_2 near a
## timber anchor throws a rope and ZIPS you to the beam, ending in an upward
## pop. The fast way up a shaft, the flashy way over a pit.
##
## Deliberately a straight zip, not a pendulum: deterministic, readable, and
## it ships. Swinging physics can upgrade this state later without touching
## the anchors or the input.
##
## Jump releases the rope early, keeping momentum — the skill expression is
## letting go at the right moment. Getting hit cuts the rope.

## Give up if the beam is somehow never reached (a wall in the way).
const MAX_TICKS: int = 70
const ARRIVE_DISTANCE: float = 42.0

var _elapsed: int = 0
var _line: Line2D = null


func enter() -> void:
	_elapsed = 0
	var anchor: Node2D = player.hook_target
	if anchor != null:
		player.update_facing(signf(anchor.global_position.x - player.global_position.x))
	_line = Line2D.new()
	_line.width = 3.0
	_line.default_color = Color(0.82, 0.66, 0.42, 0.95)
	_line.z_index = 12
	player.get_parent().add_child(_line)
	Sfx.play(Sfx.ROLL, 1.4, 2.0)


func exit() -> void:
	if _line != null:
		_line.queue_free()
		_line = null
	player.hook_target = null


func physics_update(_delta: float) -> StringName:
	_elapsed += 1
	var anchor: Node2D = player.hook_target
	if anchor == null or not is_instance_valid(anchor) or _elapsed > MAX_TICKS:
		return _release()

	# Steer straight at the beam every tick — anchors are static, so this is a
	# line, but it self-corrects if a collision nudged us.
	var to_anchor: Vector2 = anchor.global_position - player.global_position
	player.velocity = to_anchor.normalized() * player.hook_speed
	if _line != null:
		_line.points = PackedVector2Array([
			player.global_position + Vector2(0, -34), anchor.global_position,
		])

	if to_anchor.length() <= ARRIVE_DISTANCE:
		return _release()
	# Letting go early keeps the momentum — that is the skill.
	if Input.is_action_just_pressed(&"jump"):
		player.velocity.y = minf(player.velocity.y, 0.0) - 220.0
		return &"Air"
	return &""


func _release() -> StringName:
	player.velocity = player.velocity * 0.2 + Vector2(0, -player.hook_release_boost)
	return &"Air"


## A hit cuts the rope — no armor on the way up.
func on_hit(_hitbox: Hitbox) -> StringName:
	return &"Hitstun"
