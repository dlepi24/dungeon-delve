extends Node2D
## Behaviour test for the touch control layer. Pins the ONE thing that decides
## whether virtual buttons are trustworthy: an InputEventAction injected through
## Input.parse_input_event() must surface in Input.is_action_just_pressed()
## inside _physics_process — the path Input.action_press() famously fails (see
## the gotcha in CLAUDE.md). If this ever breaks (engine upgrade, input
## buffering change), every touch verb dies silently while looking like bad
## tuning, exactly like the rest of the feel stack.
##
## Also pins the stick's "one honest up/down" law on glass: a lazy vertical
## tilt must NOT press move_up/move_down (the _deliberate guards would treat
## any such event as a deliberate extract/descend); a firm tilt must.
##
## Run: godot --headless --path . res://tests/touch_test.tscn
## Exits 0 if every assertion holds, 1 otherwise.

var _failures: PackedStringArray = []

## Written by _physics_process each tick; the assertions read it.
var _saw_just_pressed: bool = false
var _saw_just_released: bool = false
var _watching: StringName = &""


func _ready() -> void:
	# The layer gates real input on _active/visible; the test drives the press
	# handlers directly, which is the same seam the touch events feed.
	TouchControls._active = true
	# Settle first: one InputEventAction injected within the first few frames
	# after process boot can be silently lost (engine boot-window wart, found
	# while building this — press-then-release left the action stuck held).
	# Real fingers cannot reach a button that fast through a title screen, so
	# the game needs no defence; the TEST must not race the window.
	for i: int in 30:
		await get_tree().physics_frame
	await _test_button_press_reaches_physics()
	await _test_button_release_reaches_physics()
	await _test_stick_axis_strength()
	await _test_lazy_tilt_never_presses_vertical()
	await _test_firm_tilt_presses_vertical()
	await _test_release_all_clears_held_state()
	await _test_intro_crawl_accepts_a_tap()
	await _test_result_screen_dismisses_on_tap()
	_test_touch_strips_mouse_combat()
	await _test_stick_flick_rolls()
	_report()


## Flick-to-roll: a sharp horizontal flick fires roll; a plain tilt must not.
## Travel-based detection is what makes this pinnable headless.
func _test_stick_flick_rolls() -> void:
	var origin: Vector2 = Vector2(300, 700)
	_watch(&"roll")
	TouchControls._press_at(1, origin)
	for i: int in 5:
		TouchControls._drag_to(1, origin + Vector2(40.0 * float(i + 1), 0))
	for i: int in 8:
		await get_tree().physics_frame
	_assert(_saw_just_pressed, "a hard stick flick never fired roll")
	TouchControls._release(1)
	for i: int in 3:
		await get_tree().physics_frame
	_assert(not Input.is_action_pressed(&"roll"), "flick roll stuck held after its synthetic tap")
	# Let the flick cooldown lapse first, or this phase can't fire regardless
	# and would pass for the wrong reason.
	for i: int in 20:
		await get_tree().physics_frame
	# Gentle tilt: two drags so sampling is genuinely engaged, but the travel
	# stays under the threshold. Must not roll.
	_watch(&"roll")
	TouchControls._press_at(1, origin)
	TouchControls._drag_to(1, origin + Vector2(35, 0))
	TouchControls._drag_to(1, origin + Vector2(70, 0))
	for i: int in 3:
		await get_tree().physics_frame
	_assert(not _saw_just_pressed, "a gentle tilt fired roll — walking would dodge constantly")
	TouchControls._release(1)
	_watching = &""


## With touch live, no gameplay verb may keep a mouse binding: Android turns
## every tap into an emulated left click, and attack-on-LMB meant tapping
## ANYWHERE swung the pickaxe (shipped, device build 4, 2026-07-29).
func _test_touch_strips_mouse_combat() -> void:
	TouchControls._strip_mouse_bindings()
	for action: StringName in [&"attack", &"parry", &"jump", &"roll"]:
		for ev: InputEvent in InputMap.action_get_events(action):
			_assert(not (ev is InputEventMouseButton),
				"%s still carries a mouse binding under touch — every tap fires it" % action)


func _physics_process(_delta: float) -> void:
	if _watching == &"":
		return
	if Input.is_action_just_pressed(_watching):
		_saw_just_pressed = true
	if Input.is_action_just_released(_watching):
		_saw_just_released = true


func _watch(action: StringName) -> void:
	_watching = action
	_saw_just_pressed = false
	_saw_just_released = false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Screen position of the jump button, asked from the layer itself so layout
## tuning can never break the test.
func _jump_pos() -> Vector2:
	return TouchControls._button_def(&"jump")["pos"]


func _test_button_press_reaches_physics() -> void:
	_watch(&"jump")
	TouchControls._press_at(0, _jump_pos())
	for i: int in 4:
		await get_tree().physics_frame
	_assert(_saw_just_pressed,
		"injected jump press never surfaced in is_action_just_pressed during _physics_process")
	_assert(Input.is_action_pressed(&"jump"),
		"injected jump press did not hold: is_action_pressed is false while the finger is down")


func _test_button_release_reaches_physics() -> void:
	# Finger from the previous test is still down; lift it. Release visibility is
	# what the jump cut (try_jump_cut) reads, so it is load-bearing, not tidiness.
	TouchControls._release(0)
	for i: int in 4:
		await get_tree().physics_frame
	_assert(_saw_just_released,
		"injected jump release never surfaced in is_action_just_released during _physics_process")
	_assert(not Input.is_action_pressed(&"jump"),
		"jump still reads held after the finger lifted")
	_watching = &""


func _test_stick_axis_strength() -> void:
	var origin: Vector2 = Vector2(300, 700)
	TouchControls._press_at(1, origin)
	_assert(TouchControls._owners.has(1), "a touch in the stick zone did not spawn the stick")
	# Full tilt right: axis should read ~1 the same way a held key would.
	TouchControls._drag_to(1, origin + Vector2(TouchControls.stick_base_radius * 2.0, 0))
	for i: int in 3:
		await get_tree().physics_frame
	var axis: float = Input.get_axis(&"move_left", &"move_right")
	_assert(axis > 0.9, "full right tilt reads axis %.2f, expected ~1.0" % axis)
	# Half tilt: analog, not digital — somewhere clearly between 0 and 1.
	# Measured from the LIVE origin: the full-tilt drag above dragged the base
	# along (follow behaviour), so the original origin is stale on purpose.
	TouchControls._drag_to(1, (TouchControls._stick_origin as Vector2) + Vector2(TouchControls.stick_base_radius * 0.55, 0))
	for i: int in 3:
		await get_tree().physics_frame
	axis = Input.get_axis(&"move_left", &"move_right")
	_assert(axis > 0.05 and axis < 0.95,
		"half tilt reads axis %.2f, expected partial strength (analog stick, not a button)" % axis)
	TouchControls._release(1)
	await get_tree().physics_frame


func _test_lazy_tilt_never_presses_vertical() -> void:
	var origin: Vector2 = Vector2(300, 700)
	TouchControls._press_at(1, origin)
	# Tilt down at just past half — below the 0.7 deliberate law.
	TouchControls._drag_to(1, origin + Vector2(0, TouchControls.stick_base_radius * 0.55))
	for i: int in 3:
		await get_tree().physics_frame
	_assert(not Input.is_action_pressed(&"move_down"),
		"a lazy down tilt pressed move_down — extract/descend would fire on a graze")
	TouchControls._release(1)
	await get_tree().physics_frame


func _test_firm_tilt_presses_vertical() -> void:
	var origin: Vector2 = Vector2(300, 700)
	TouchControls._press_at(1, origin)
	TouchControls._drag_to(1, origin + Vector2(0, -TouchControls.stick_base_radius * 2.0))
	for i: int in 3:
		await get_tree().physics_frame
	_assert(Input.is_action_pressed(&"move_up"),
		"a full up tilt never pressed move_up — extract/enter-mine would be unreachable on touch")
	TouchControls._release(1)
	for i: int in 3:
		await get_tree().physics_frame
	_assert(not Input.is_action_pressed(&"move_up"),
		"move_up still held after the stick was released")


func _test_release_all_clears_held_state() -> void:
	# A menu opening mid-hold must drop every verb, or the player walks by
	# themselves under the pause screen.
	TouchControls._press_at(0, _jump_pos())
	var origin: Vector2 = Vector2(300, 700)
	TouchControls._press_at(1, origin)
	TouchControls._drag_to(1, origin + Vector2(TouchControls.stick_base_radius * 2.0, 0))
	for i: int in 3:
		await get_tree().physics_frame
	TouchControls._release_all()
	for i: int in 3:
		await get_tree().physics_frame
	_assert(not Input.is_action_pressed(&"jump"), "release_all left jump held")
	var axis: float = Input.get_axis(&"move_left", &"move_right")
	_assert(is_zero_approx(axis), "release_all left the stick reading %.2f" % axis)
	_assert(TouchControls._owners.is_empty(), "release_all left finger owners behind")


## A bare screen tap, through the REAL input pipeline (GUI phase included).
func _tap_screen(at: Vector2) -> void:
	var down: InputEventScreenTouch = InputEventScreenTouch.new()
	down.index = 0
	down.position = at
	down.pressed = true
	Input.parse_input_event(down)
	var up: InputEventScreenTouch = InputEventScreenTouch.new()
	up.index = 0
	up.position = at
	up.pressed = false
	Input.parse_input_event(up)


## The two screens a touch player cannot escape via the overlay's buttons must
## answer a bare tap. Both SHIPPED soft-locked on the first Android install
## (2026-07-29): their Control roots' default mouse_filter (STOP) ate the tap
## in the GUI phase before _unhandled_input ever saw it — so these tests tap
## through the real pipeline, not by calling the handler directly.

func _test_intro_crawl_accepts_a_tap() -> void:
	var intro: Control = (load("res://src/rooms/intro_sequence.tscn") as PackedScene).instantiate() as Control
	add_child(intro)
	# Instanced under this Node2D the Control root collapses to 0x0 (the known
	# gotcha), which would let the tap MISS it and pass the test even with the
	# bug present. Give it the rect it really has as the current scene.
	intro.position = Vector2.ZERO
	intro.size = get_viewport().get_visible_rect().size
	for i: int in 3:
		await get_tree().physics_frame
	_tap_screen(Vector2(960, 540))
	for i: int in 3:
		await get_tree().physics_frame
	_assert(intro.get("_started") == true,
		"a tap did not start the intro crawl — touch players are locked at 'Press to begin.'")
	intro.queue_free()
	await get_tree().physics_frame


func _test_result_screen_dismisses_on_tap() -> void:
	var screen: CanvasLayer = (load("res://src/rooms/result_screen.tscn") as PackedScene).instantiate() as CanvasLayer
	add_child(screen)
	await get_tree().physics_frame
	screen.call(&"show_result", &"died", 7)
	_assert(get_tree().paused, "result screen did not pause the tree on show")
	_tap_screen(Vector2(960, 540))
	for i: int in 3:
		await get_tree().physics_frame
	_assert(not get_tree().paused,
		"a tap did not dismiss the result screen — every touch run dead-ends at YOU DIED")
	get_tree().paused = false
	screen.queue_free()
	await get_tree().physics_frame


func _report() -> void:
	if _failures.is_empty():
		print("TOUCH OK — injected input reaches _physics_process, stick laws hold.")
		get_tree().quit(0)
		return
	print("%d touch assertion(s) failed:" % _failures.size())
	for failure: String in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)
