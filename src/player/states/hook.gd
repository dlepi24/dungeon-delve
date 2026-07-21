extends PlayerState
## The Timber Hook — the second movement verb (GDD 2026-07-18): skill_2 near a
## timber anchor throws a rope and ZIPS you to the beam.
##
## Two endings, chosen by the button, so a tap and a hold are different tools:
## - TAP: the original zip — arrive, pop upward, done. Deterministic and fast.
## - HOLD skill_2 through arrival: LATCH under the beam and swing as a pendulum.
##   Left/right pumps the swing, releasing the button lets go with your swing
##   momentum, jump adds an upward kick on top. The skill expression is the
##   same as the zip's — letting go at the right moment — with more to express.
##
## The pendulum is tick-stepped and input-driven only (no randomness), so ghost
## replays see the same arc every time. Getting hit still cuts the rope.

## Give up if the beam is somehow never reached (a wall in the way). Zip only —
## a hang has no timeout, you leave it by choice, floor, or a hit.
const MAX_TICKS: int = 70
const ARRIVE_DISTANCE: float = 42.0
## Past-horizontal cap on the swing angle, radians from straight down.
const MAX_SWING_ANGLE: float = 1.9

var _elapsed: int = 0
var _line: Line2D = null
var _hanging: bool = false
## Pendulum state: angle from straight-below-the-anchor, and angular velocity.
var _theta: float = 0.0
var _omega: float = 0.0


func enter() -> void:
	_elapsed = 0
	_hanging = false
	_theta = 0.0
	_omega = 0.0
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


func physics_update(delta: float) -> StringName:
	var anchor: Node2D = player.hook_target
	if anchor == null or not is_instance_valid(anchor):
		return _release()
	if _hanging:
		return _swing(anchor, delta)

	_elapsed += 1
	if _elapsed > MAX_TICKS:
		return _release()

	# Steer straight at the beam every tick — anchors are static, so this is a
	# line, but it self-corrects if a collision nudged us.
	var to_anchor: Vector2 = anchor.global_position - player.global_position
	player.velocity = to_anchor.normalized() * player.hook_speed
	_draw_rope(anchor)

	if to_anchor.length() <= ARRIVE_DISTANCE:
		# Still holding the button at the beam? Latch and swing instead of popping.
		if Input.is_action_pressed(&"skill_2"):
			_latch(anchor)
			return &""
		return _release()
	# Letting go early keeps the momentum — that is the skill.
	if Input.is_action_just_pressed(&"jump"):
		player.velocity.y = minf(player.velocity.y, 0.0) - 220.0
		return &"Air"
	return &""


## Start hanging: pick the pendulum angle nearest where the zip left us, with
## no angular momentum — the first pump comes from the stick, not a snap.
func _latch(anchor: Node2D) -> void:
	_hanging = true
	var length: float = maxf(24.0, player.hook_hang_length)
	_theta = asin(clampf((player.global_position.x - anchor.global_position.x) / length, -0.7, 0.7))
	_omega = 0.0


func _swing(anchor: Node2D, delta: float) -> StringName:
	var length: float = maxf(24.0, player.hook_hang_length)
	# Gravity pulls the bob back to centre; held direction pumps it. Standard
	# pendulum, stepped per physics tick so it is deterministic.
	var input: float = player.get_input_direction()
	_omega += (-(player.hook_swing_gravity / length) * sin(_theta) * delta) \
		+ (input * player.hook_swing_accel * delta)
	_omega = clampf(_omega, -player.hook_swing_max_speed, player.hook_swing_max_speed)
	_theta = clampf(_theta + _omega * delta, -MAX_SWING_ANGLE, MAX_SWING_ANGLE)
	if absf(_theta) >= MAX_SWING_ANGLE:
		_omega = 0.0

	# Chase the point on the arc. Velocity-based (not teleport) so walls and
	# floors still stop us like everything else in the game.
	var target: Vector2 = anchor.global_position + Vector2(sin(_theta), cos(_theta)) * length
	var chase: Vector2 = (target - player.global_position) / maxf(delta, 0.0001)
	player.velocity = chase.limit_length(player.hook_speed)
	if absf(_omega) > 0.4:
		player.update_facing(signf(_omega))
	_draw_rope(anchor)

	# Swung into the floor: the rope has done its job, stand up.
	if player.is_on_floor():
		return &"Idle"
	# Jump flings you along the swing with a kick; releasing the button just
	# lets go, keeping whatever the pendulum gave you.
	if Input.is_action_just_pressed(&"jump"):
		player.velocity = _tangent_velocity(length)
		player.velocity.y = minf(player.velocity.y, 0.0) - player.hook_release_boost
		return &"Air"
	if not Input.is_action_pressed(&"skill_2"):
		player.velocity = _tangent_velocity(length)
		return &"Air"
	return &""


## Velocity along the arc right now — what you fly off with when you let go.
func _tangent_velocity(length: float) -> Vector2:
	return Vector2(cos(_theta), -sin(_theta)) * (_omega * length)


func _draw_rope(anchor: Node2D) -> void:
	if _line != null:
		_line.points = PackedVector2Array([
			player.global_position + Vector2(0, -34), anchor.global_position,
		])


func _release() -> StringName:
	player.velocity = player.velocity * 0.2 + Vector2(0, -player.hook_release_boost)
	return &"Air"


## A hit cuts the rope — no armor on the way up.
func on_hit(_hitbox: Hitbox) -> StringName:
	return &"Hitstun"
