extends Node2D
## Behaviour test for the feel stack. Not a feel judgement — that is Dustin's
## call at the M1 gate — but proof that the mechanisms actually fire.
##
## Coyote time, input buffering and i-frames all fail *silently*: the game still
## runs, it just feels inexplicably bad, and you cannot tell whether a number is
## wrong or the feature never ran. This pins the mechanism so tuning is tuning.
##
## Run: godot --headless --path . res://tests/feel_test.tscn
## Exits 0 if every assertion holds, 1 otherwise.

const PLAYER: PackedScene = preload("res://src/player/player.tscn")
## Floor surface sits at y = 0; the platform ends at this x so we can run off it.
const PLATFORM_EDGE_X: float = 100.0

var _failures: PackedStringArray = []
var _player: Player


func _ready() -> void:
	_build_world()
	await _test_coyote_within_window()
	await _test_coyote_after_window()
	await _test_buffered_jump_fires_on_landing()
	await _test_stale_jump_does_not_fire()
	await _test_roll_iframe_window()
	await _test_roll_has_no_cooldown()
	await _test_parry_inside_window_deflects()
	await _test_parry_whiff_is_punishable()
	await _test_roll_cannot_cancel_parry_recovery()
	await _test_attack_cancel_window()
	await _test_riposte_multiplies_damage()
	_report()


## A platform from x=-400 to x=+100 with its surface at y=0, and nothing beyond
## it, so running right walks off into open air.
func _build_world() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(500, 80)
	shape.shape = rect
	shape.position = Vector2(-150, 40)
	body.add_child(shape)
	add_child(body)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		_failures.append(label)
		print("  FAIL  %s" % label)


func _tick(count: int = 1) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Queue a press for the tick that is about to run.
##
## Deliberately not Input.action_press(): a synthetic press does not reach
## is_action_just_pressed() inside _physics_process on the tick it was injected
## (it surfaces around the release instead), so tests built on it pass or fail
## for reasons unrelated to the code. Held state like move_left/move_right is
## fine through Input, because that reads is_action_pressed rather than
## just_pressed — so movement below still drives the real input path.
func _press(action: StringName) -> void:
	_player.get_buffer().press(action, _player.get_tick() + 1)


func _release_all() -> void:
	for action: String in ["move_left", "move_right", "jump", "roll"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _respawn(at: Vector2) -> void:
	_release_all()
	if _player != null:
		_player.free()
	_player = PLAYER.instantiate()
	_player.position = at
	add_child(_player)
	await _tick(2)


## Runs right off the platform edge and returns on the first airborne tick.
func _run_off_edge() -> void:
	Input.action_press(&"move_right")
	var guard: int = 0
	while _player.is_on_floor() and guard < 300:
		guard += 1
		await _tick()
	Input.action_release(&"move_right")


func _test_coyote_within_window() -> void:
	print("coyote: jump inside the window")
	await _respawn(Vector2(0, 0))
	await _run_off_edge()
	# Airborne, well inside the 80 ms (~5 tick) window.
	await _tick(2)
	_press(&"jump")
	await _tick()
	_check(_player.velocity.y < 0.0, "jump fires after walking off a ledge (velocity.y=%.1f)" % _player.velocity.y)


func _test_coyote_after_window() -> void:
	print("coyote: jump after the window has closed")
	await _respawn(Vector2(0, 0))
	await _run_off_edge()
	# 20 ticks is well past 80 ms; coyote must have expired.
	await _tick(20)
	_press(&"jump")
	await _tick()
	_check(_player.velocity.y > 0.0, "jump is refused once coyote expires (velocity.y=%.1f)" % _player.velocity.y)


func _test_buffered_jump_fires_on_landing() -> void:
	print("buffer: press just before touchdown")
	# Dropped from 6 px, so landing happens inside the 100 ms buffer window.
	await _respawn(Vector2(-150, -6))
	_press(&"jump")
	await _tick(10)
	_check(_player.velocity.y < 0.0, "jump pressed before landing fires on touchdown (velocity.y=%.1f)" % _player.velocity.y)


func _test_stale_jump_does_not_fire() -> void:
	print("buffer: press far too early must expire, not queue forever")
	# Dropped from 300 px: landing is ~28 ticks away, far outside the window.
	await _respawn(Vector2(-150, -300))
	_press(&"jump")
	var guard: int = 0
	while not _player.is_on_floor() and guard < 300:
		guard += 1
		await _tick()
	await _tick(2)
	_check(_player.velocity.y >= 0.0, "a stale press does not resurrect on landing (velocity.y=%.1f)" % _player.velocity.y)


## The GDD asks for i-frames over "roughly the middle 200 ms" of a ~350 ms roll.
## This checks the window is the right length and genuinely in the middle, rather
## than starting at tick 0 (which would make roll strictly better than it should be).
func _test_roll_iframe_window() -> void:
	print("roll: i-frame window shape")
	await _respawn(Vector2(-150, 0))
	var duration: int = _player.ms_to_ticks(_player.roll_duration_ms)
	var expected_start: int = _player.ms_to_ticks(_player.roll_iframe_start_ms)
	var expected_len: int = _player.ms_to_ticks(_player.roll_iframe_duration_ms)

	_press(&"roll")
	await _tick()

	var invuln_ticks: Array[int] = []
	for i: int in duration:
		if _player.invulnerable:
			invuln_ticks.append(i)
		await _tick()

	_check(_player.get_state_name() != &"Roll" or invuln_ticks.size() > 0, "roll actually entered")
	_check(invuln_ticks.size() == expected_len,
		"i-frames last %d ticks (got %d)" % [expected_len, invuln_ticks.size()])
	if invuln_ticks.size() > 0:
		_check(invuln_ticks[0] >= expected_start,
			"i-frames start after the startup window, not instantly (first invulnerable tick=%d, startup=%d)" % [invuln_ticks[0], expected_start])
		_check(invuln_ticks[invuln_ticks.size() - 1] < duration,
			"i-frames end before the roll does (last=%d, duration=%d)" % [invuln_ticks[invuln_ticks.size() - 1], duration])


## Pillar check: roll is never punished. No stamina, no cooldown in v1.
func _test_roll_has_no_cooldown() -> void:
	print("roll: back-to-back with no cooldown")
	await _respawn(Vector2(-150, 0))
	var duration: int = _player.ms_to_ticks(_player.roll_duration_ms)

	_press(&"roll")
	await _tick(duration + 2)

	_press(&"roll")
	await _tick(2)
	_check(_player.get_state_name() == &"Roll", "a second roll starts immediately (state=%s)" % _player.get_state_name())


## An enemy swing, not yet thrown. Kept separate from _strike_player so a test
## can attach listeners before the hit lands.
func _make_hitbox() -> Hitbox:
	var hitbox: Hitbox = Hitbox.new()
	hitbox.damage = 10.0
	hitbox.global_position = _player.global_position + Vector2(60, -28)
	add_child(hitbox)
	return hitbox


## Fires a hit at the player as though an enemy swing connected, so parry can be
## tested without depending on the dummy's timing loop. Exactly once — hitting
## twice would parry the first and stun on the second.
func _strike_player() -> Hitbox:
	var hitbox: Hitbox = _make_hitbox()
	_player.hurtbox.take_hit(hitbox)
	return hitbox


func _test_parry_inside_window_deflects() -> void:
	print("parry: hit inside the active window")
	await _respawn(Vector2(-150, 0))
	var parried: Array[bool] = [false]
	_press(&"parry")
	await _tick(2)
	_check(_player.get_state_name() == &"Parry", "parry state entered (state=%s)" % _player.get_state_name())

	var hitbox: Hitbox = _make_hitbox()
	hitbox.parried.connect(func() -> void: parried[0] = true)
	_player.hurtbox.take_hit(hitbox)
	await _tick()

	_check(_player.get_state_name() != &"Hitstun", "a parried hit does not cause hitstun (state=%s)" % _player.get_state_name())
	_check(_player.is_riposte_open(), "a successful parry opens the riposte window")
	# The attacker must be told, or nothing would ever stagger.
	_check(parried[0], "the attacker is notified it was parried")
	_check(not hitbox.is_active(), "a parried attack is closed and cannot also land")


func _test_parry_whiff_is_punishable() -> void:
	print("parry: hit during the recovery tail")
	await _respawn(Vector2(-150, 0))
	_press(&"parry")
	await _tick(2)
	# Wait out the active window, land inside the recovery tail.
	await _tick(_player.ms_to_ticks(_player.parry_active_ms) + 4)
	_strike_player()
	await _tick()
	_check(_player.get_state_name() == &"Hitstun",
		"whiffing the window and getting hit is punished (state=%s)" % _player.get_state_name())


## The GDD tension: roll is "always available" but a parry whiff must be
## "punishable". Those cannot both be literally true. Recovery wins.
func _test_roll_cannot_cancel_parry_recovery() -> void:
	print("parry: roll must not cancel the recovery tail")
	await _respawn(Vector2(-150, 0))
	_press(&"parry")
	await _tick(2)
	await _tick(_player.ms_to_ticks(_player.parry_active_ms) + 4)
	_press(&"roll")
	await _tick(2)
	_check(_player.get_state_name() != &"Roll",
		"roll does not bail you out of a whiffed parry (state=%s)" % _player.get_state_name())


func _test_attack_cancel_window() -> void:
	print("attack: commitment then cancel window")
	await _respawn(Vector2(-150, 0))
	_press(&"attack")
	await _tick(2)
	_check(_player.get_state_name() == &"Attack", "attack state entered (state=%s)" % _player.get_state_name())

	# Early in the swing, roll must NOT cancel — that is the commitment.
	_press(&"roll")
	await _tick()
	_check(_player.get_state_name() == &"Attack",
		"roll cannot cancel attack startup (state=%s)" % _player.get_state_name())

	# Past the cancel point, it must.
	await _tick(_player.ms_to_ticks(_player.attack_cancel_start_ms))
	_press(&"roll")
	await _tick(2)
	_check(_player.get_state_name() == &"Roll",
		"roll cancels attack once the window opens (state=%s)" % _player.get_state_name())


func _test_riposte_multiplies_damage() -> void:
	print("riposte: parry payoff multiplies attack damage")
	await _respawn(Vector2(-150, 0))
	_press(&"attack")
	await _tick(_player.ms_to_ticks(_player.attack_startup_ms) + 2)
	var normal: float = _player.attack_hitbox.damage
	await _tick(_player.ms_to_ticks(_player.attack_recovery_ms) + _player.ms_to_ticks(_player.attack_active_ms) + 4)

	_player.open_riposte()
	_press(&"attack")
	await _tick(_player.ms_to_ticks(_player.attack_startup_ms) + 2)
	var boosted: float = _player.attack_hitbox.damage

	_check(is_equal_approx(boosted, normal * _player.riposte_damage_multiplier),
		"riposte damage is %.1fx normal (normal=%.1f, riposte=%.1f)" % [_player.riposte_damage_multiplier, normal, boosted])
	_check(not _player.is_riposte_open(), "the riposte is spent once cashed in")


func _report() -> void:
	if _failures.is_empty():
		print("\nFEEL TEST OK")
		get_tree().quit(0)
		return
	printerr("\n%d feel assertion(s) failed:" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	get_tree().quit(1)
