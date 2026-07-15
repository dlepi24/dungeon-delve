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


func _report() -> void:
	if _failures.is_empty():
		print("\nFEEL TEST OK")
		get_tree().quit(0)
		return
	printerr("\n%d feel assertion(s) failed:" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	get_tree().quit(1)
