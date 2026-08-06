extends CanvasLayer
## On-screen touch controls for the Android build. Autoloaded (TouchControls) so
## the overlay exists in every scene; it draws nothing and eats no input unless
## touch is actually in play (a touchscreen exists, `force_enabled`, or a
## `--touch` user arg for desktop testing with the mouse).
##
## Everything is injected through Input.parse_input_event() with InputEventAction
## — the same pipeline hardware uses — so is_action_just_pressed/released, event
## handlers (`event.is_action_pressed`) and polled state all behave identically
## to a keyboard. Input.action_press() is deliberately NOT used: see the gotcha
## in CLAUDE.md — synthetic presses through it are invisible to _physics_process
## on the tick they land.
##
## Layout language: floating stick on the left (appears under the finger), a
## verb cluster bottom-right (jump biggest and innermost), and a contextual
## INTERACT CHIP that mirrors whatever WorldPrompt is live — Dustin's "tap the
## prompt, but easy to reach": the world card itself is tappable AND a copy of
## it sits by your thumb. The chip holds too, so HoldInteract commitments work.
##
## The stick injects horizontal movement as ANALOG strength, but up/down as
## THRESHOLD-GATED digital presses (>= vertical_press_at, with hysteresis).
## That is load-bearing, not taste: the `_deliberate` guards in hub/run
## coordinator treat any non-joypad event as deliberate, so an analog trickle of
## move_down events would fire extract/descend on a graze. Gating at the same
## 0.7 the pad stick uses keeps "one honest up/down" true on glass.

const FONT_BOLD: FontFile = preload("res://assets/fonts/Rajdhani-Bold.ttf")

## Mouse pointer pretends to be this finger index when testing on desktop.
const MOUSE_FINGER: int = -1

@export_group("Activation")
## Show the controls even without a touchscreen (desktop testing).
@export var force_enabled: bool = false

@export_group("Look")
## Idle transparency of every element. Low: the game stays visible under thumbs.
@export_range(0.0, 1.0) var idle_alpha: float = 0.36
## Transparency while an element is held.
@export_range(0.0, 1.0) var pressed_alpha: float = 0.85

@export_group("Stick")
## Fraction of the screen width (from the left) where a touch spawns the stick.
@export_range(0.1, 0.6) var stick_zone_width_frac: float = 0.45
## Touches above this fraction of the screen height never spawn the stick, so
## the top of the screen stays free for HUD taps.
@export_range(0.0, 0.6) var stick_zone_top_frac: float = 0.25
@export var stick_base_radius: float = 110.0
@export var stick_knob_radius: float = 44.0
## Tilt below this is ignored; above it, rescaled to 0..1.
@export_range(0.0, 0.9) var stick_deadzone: float = 0.22
## Vertical tilt where the digital move_up/move_down press fires (matches the
## pad's 0.7 "deliberate" law — see the header note).
@export_range(0.0, 1.0) var vertical_press_at: float = 0.7
## Vertical tilt where a held up/down releases (hysteresis, below press_at).
@export_range(0.0, 1.0) var vertical_release_at: float = 0.5

@export_group("Buttons")
## Buttons sit on ARCS around the bottom-right corner, so the thumb pivots at
## the bezel instead of hovering over the playfield (first layout's mistake —
## it sprawled to mid-screen and the hand covered the game). Polar per button:
## angle 0 = along the bottom edge (leftward), 90 = up the right edge;
## dist = px from the corner. Tune angles/distances, arcs stay arcs.
@export var jump_angle_deg: float = 45.0
@export var jump_dist: float = 155.0
@export var jump_radius: float = 72.0
@export var attack_angle_deg: float = 12.0
@export var attack_dist: float = 315.0
@export var attack_radius: float = 58.0
@export var parry_angle_deg: float = 78.0
@export var parry_dist: float = 315.0
@export var parry_radius: float = 58.0
@export var roll_angle_deg: float = 45.0
@export var roll_dist: float = 305.0
@export var roll_radius: float = 50.0
@export var hook_angle_deg: float = 62.0
@export var hook_dist: float = 455.0
@export var hook_radius: float = 40.0
@export var swap_angle_deg: float = 28.0
@export var swap_dist: float = 455.0
@export var swap_radius: float = 36.0
@export var pause_offset: Vector2 = Vector2(-64, 64)
@export var pause_radius: float = 34.0
## Extra grab ring around every button, px. Kept SMALL: generous slop plus a
## dense cluster is why the first layout swung the pickaxe at every stray touch.
@export var touch_slop: float = 8.0

@export_group("Haptics")
## A tiny vibration tick on every button/chip press and flick-roll, so glass
## acknowledges the thumb without the eye checking. Combat beats (hits, parry,
## hurt) come separately through Rumble at full strength.
@export var press_haptics: bool = true
@export var press_haptic_ms: int = 12
@export_range(0.0, 1.0) var press_haptic_strength: float = 0.3

@export_group("Flick roll")
## Roll rides the STICK: flick it hard left/right and you roll that way — no
## button. Safe to merge precisely because of the roll pillar (always
## available, never punished): a false positive costs nothing, so the gesture
## can be permissive. Parry deliberately gets NO gesture — tap-vs-hold or
## double-tap detection waits before deciding, and a parry that arrives late
## is not a parry.
@export var flick_roll_enabled: bool = true
## Horizontal finger travel (px) inside the window that counts as a flick.
@export var flick_roll_travel: float = 130.0
## How recent that travel must be, ms. Shorter = sharper flick required.
@export var flick_roll_window_ms: int = 90
## Dead time after a flick fires before the next may, ms.
@export var flick_roll_cooldown_ms: int = 250
## Keep the roll button on screen anyway (for A/B-ing the flick against it).
@export var show_roll_button: bool = false

@export_group("Interact chip")
## Chip CENTRE, from the bottom-right corner. Above the button arcs.
@export var chip_offset: Vector2 = Vector2(-320, -560)
@export var chip_size: Vector2 = Vector2(280, 92)

## Panel voice shared with PromptCard, restated here because its styleboxes are
## its own private cache.
const PANEL_BG: Color = Color(0.09, 0.075, 0.06, 0.96)
const PANEL_BORDER: Color = Color(0.4, 0.33, 0.22, 1.0)
const PRESSED_BORDER: Color = Color(1.0, 0.78, 0.38, 1.0)
const INK: Color = Color(0.95, 0.91, 0.83, 1.0)
const FILL_AMBER: Color = Color(1.0, 0.78, 0.38, 0.3)

var _active: bool = false
var _overlay: Control = null
## finger index -> {"kind": &"button"/&"stick"/&"interact", "action": StringName}
var _owners: Dictionary[int, Dictionary] = {}
var _pressed: Dictionary[StringName, bool] = {}

## Recent horizontal stick samples for flick detection, packed as
## Vector2(time_ms, finger_x) — .x is TIME, .y is position; see _check_flick.
var _flick_samples: Array[Vector2] = []
var _flick_block_until_ms: float = 0.0

var _stick_origin: Vector2 = Vector2.ZERO
## Deadzone-shaped stick vector, -1..1 per axis.
var _stick_vec: Vector2 = Vector2.ZERO
var _stick_held: bool = false
var _up_pressed: bool = false
var _down_pressed: bool = false
var _last_left: float = 0.0
var _last_right: float = 0.0


func _ready() -> void:
	layer = 20
	_active = force_enabled \
		or DisplayServer.is_touchscreen_available() \
		or OS.get_cmdline_user_args().has("--touch")
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	visible = false
	# Keep working while the tree pauses so a stuck press can still be released;
	# _showing() hides us and _release_all() drops held verbs the moment a menu
	# or pause takes over.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _active:
		_strip_mouse_bindings()


## On a touch device every tap is ALSO an emulated left mouse click, and the
## KB+M layout binds attack to LMB (parry to RMB) — so tapping ANYWHERE on the
## screen swung the pickaxe, the single worst feel bug of the first device
## build. With touch live, combat verbs may come only from the on-screen
## buttons: strip mouse events from the gameplay actions at runtime. Menus and
## GUI buttons are unaffected (they read raw clicks, not actions). This runs
## for desktop --touch testing too, deliberately — simulating touch means the
## mouse should behave like a finger, not like a mouse.
func _strip_mouse_bindings() -> void:
	for action: StringName in [&"attack", &"parry", &"jump", &"roll", &"skill_1", &"skill_2", &"interact"]:
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)


## Player.try_consume_parry reads this for the touch parry leniency.
func is_touch_active() -> bool:
	return _active


func _process(_delta: float) -> void:
	if not _active:
		return
	var show: bool = _showing()
	if not show and visible:
		_release_all()
	visible = show
	if visible:
		_overlay.queue_redraw()


## Controls belong on screen only during live gameplay: a player exists, the
## tree is not paused, and no menu owns focus. Every menu in this game grabs
## focus on open (GDD round 6), which makes focus a reliable "a menu is up" flag
## — vendor panels, settings, keybinds all hide the thumbs automatically.
func _showing() -> bool:
	if get_tree().paused:
		return false
	if get_viewport().gui_get_focus_owner() != null:
		return false
	return get_tree().get_first_node_in_group(&"player") != null


# --- Input ---

func _input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_press_at(touch.index, touch.position)
		else:
			_release(touch.index)
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null:
		_drag_to(drag.index, drag.position)
		return
	# Desktop testing: the mouse acts as one extra finger. Ignored when a real
	# touchscreen exists, or every touch would arrive twice via mouse emulation.
	if DisplayServer.is_touchscreen_available():
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			_press_at(MOUSE_FINGER, click.position)
		else:
			_release(MOUSE_FINGER)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _owners.has(MOUSE_FINGER):
		_drag_to(MOUSE_FINGER, motion.position)


func _press_at(finger: int, pos: Vector2) -> void:
	if _owners.has(finger):
		return
	var hit: Dictionary = _button_at(pos)
	if not hit.is_empty():
		var action: StringName = hit["action"]
		_owners[finger] = {"kind": &"button", "action": action}
		_pressed[action] = true
		_inject(action, true, 1.0)
		_press_tick()
		get_viewport().set_input_as_handled()
		return
	if _chip_visible() and _chip_rect().has_point(pos):
		_own_interact(finger)
		return
	if _card_hit(pos):
		_own_interact(finger)
		return
	var view: Vector2 = _overlay.size
	if pos.x <= view.x * stick_zone_width_frac and pos.y >= view.y * stick_zone_top_frac:
		_owners[finger] = {"kind": &"stick"}
		_stick_origin = pos
		_stick_held = true
		_stick_vec = Vector2.ZERO
		_flick_samples.clear()
		get_viewport().set_input_as_handled()


func _own_interact(finger: int) -> void:
	_owners[finger] = {"kind": &"interact"}
	_pressed[&"interact"] = true
	_inject(&"interact", true, 1.0)
	_press_tick()
	get_viewport().set_input_as_handled()


func _press_tick() -> void:
	if press_haptics and DisplayServer.get_name() != "headless":
		Input.vibrate_handheld(press_haptic_ms, press_haptic_strength)


func _drag_to(finger: int, pos: Vector2) -> void:
	if not _owners.has(finger):
		return
	var owner: Dictionary = _owners[finger]
	if owner["kind"] == &"stick":
		_update_stick(pos)
		_check_flick(pos.x)
		return
	if owner["kind"] == &"button":
		# Sliding well off a button releases it — this is what makes a jump cut
		# (release = shorter hop) possible by sliding the thumb away.
		var action: StringName = owner["action"]
		var def: Dictionary = _button_def(action)
		if not def.is_empty() and pos.distance_to(def["pos"]) > (def["radius"] as float) + touch_slop * 4.0:
			_release(finger)


func _release(finger: int) -> void:
	if not _owners.has(finger):
		return
	var owner: Dictionary = _owners[finger]
	_owners.erase(finger)
	match owner["kind"]:
		&"button":
			var action: StringName = owner["action"]
			_pressed[action] = false
			_inject(action, false, 0.0)
		&"interact":
			_pressed[&"interact"] = false
			_inject(&"interact", false, 0.0)
		&"stick":
			_clear_stick()


func _release_all() -> void:
	for finger: int in _owners.keys().duplicate():
		_release(finger)


## A sharp horizontal flick of the stick fires a roll. Detection is TRAVEL
## INSIDE A TIME WINDOW rather than instantaneous velocity: it is robust to
## uneven touch event timing, and it is deterministic to test (a distance
## threshold can be exercised headless; a wall-clock speed cannot).
func _check_flick(x: float) -> void:
	if not flick_roll_enabled:
		return
	var now: float = float(Time.get_ticks_msec())
	if now < _flick_block_until_ms:
		return
	_flick_samples.append(Vector2(now, x))
	while not _flick_samples.is_empty() and now - _flick_samples[0].x > float(flick_roll_window_ms):
		_flick_samples.remove_at(0)
	if _flick_samples.size() < 2:
		return
	if absf(x - _flick_samples[0].y) < flick_roll_travel:
		return
	_flick_samples.clear()
	_flick_block_until_ms = now + float(flick_roll_cooldown_ms)
	_inject(&"roll", true, 1.0)
	_press_tick()
	# Release a beat later — a same-frame press+release can slip between
	# physics polls and read as never-pressed. Roll has no hold semantics, so
	# a 60 ms synthetic tap is exactly a tap.
	get_tree().create_timer(0.06).timeout.connect(
		func() -> void: _inject(&"roll", false, 0.0))


func _clear_stick() -> void:
	_stick_held = false
	_stick_vec = Vector2.ZERO
	_flick_samples.clear()
	_send_axis(&"move_left", 0.0)
	_send_axis(&"move_right", 0.0)
	_last_left = 0.0
	_last_right = 0.0
	if _up_pressed:
		_up_pressed = false
		_inject(&"move_up", false, 0.0)
	if _down_pressed:
		_down_pressed = false
		_inject(&"move_down", false, 0.0)


func _update_stick(pos: Vector2) -> void:
	var raw: Vector2 = (pos - _stick_origin) / stick_base_radius
	if raw.length() > 1.0:
		# The base FOLLOWS a big swipe (drag past the rim pulls the whole stick
		# along), so a broad thumb sweep re-centres instead of pinning at full
		# tilt in a stale direction — reversals stay one motion.
		_stick_origin = pos - raw.normalized() * stick_base_radius
		raw = raw.normalized()
	# Deadzone, rescaled so control starts at zero right past it.
	var len: float = raw.length()
	if len < stick_deadzone:
		_stick_vec = Vector2.ZERO
	else:
		_stick_vec = raw.normalized() * ((len - stick_deadzone) / (1.0 - stick_deadzone))

	var left: float = maxf(0.0, -_stick_vec.x)
	var right: float = maxf(0.0, _stick_vec.x)
	if absf(left - _last_left) > 0.01 or (left > 0.0) != (_last_left > 0.0):
		_send_axis(&"move_left", left)
		_last_left = left
	if absf(right - _last_right) > 0.01 or (right > 0.0) != (_last_right > 0.0):
		_send_axis(&"move_right", right)
		_last_right = right

	# Digital, hysteresis-gated vertical — see the header note on _deliberate.
	if not _down_pressed and _stick_vec.y >= vertical_press_at:
		_down_pressed = true
		_inject(&"move_down", true, 1.0)
	elif _down_pressed and _stick_vec.y <= vertical_release_at:
		_down_pressed = false
		_inject(&"move_down", false, 0.0)
	if not _up_pressed and -_stick_vec.y >= vertical_press_at:
		_up_pressed = true
		_inject(&"move_up", true, 1.0)
	elif _up_pressed and -_stick_vec.y <= vertical_release_at:
		_up_pressed = false
		_inject(&"move_up", false, 0.0)


func _send_axis(action: StringName, strength: float) -> void:
	_inject(action, strength > 0.0, strength)


func _inject(action: StringName, pressed: bool, strength: float) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength
	Input.parse_input_event(ev)


# --- Android back button: pause, don't quit ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _active:
		_inject(&"pause", true, 1.0)
		_inject(&"pause", false, 0.0)


# --- Geometry ---

## Button table, rebuilt per call so inspector tuning applies live mid-play.
## Each entry carries its resolved screen "pos". Only the four core verbs and
## pause are always present — "too many buttons" is real, so the situational
## verbs earn their screen space contextually: the hook only near an anchor it
## could actually reach, the swap only while two weapons are held.
func _button_defs() -> Array[Dictionary]:
	var defs: Array[Dictionary] = [
		{"action": &"jump", "pos": _arc_pos(jump_angle_deg, jump_dist), "radius": jump_radius},
		{"action": &"attack", "pos": _arc_pos(attack_angle_deg, attack_dist), "radius": attack_radius},
		{"action": &"parry", "pos": _arc_pos(parry_angle_deg, parry_dist), "radius": parry_radius},
		{"action": &"pause", "pos": _corner_pos(pause_offset, true), "radius": pause_radius},
	]
	if show_roll_button or not flick_roll_enabled:
		defs.append({"action": &"roll", "pos": _arc_pos(roll_angle_deg, roll_dist), "radius": roll_radius})
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player != null:
		if player.call(&"find_hook_anchor") != null:
			defs.append({"action": &"skill_2", "pos": _arc_pos(hook_angle_deg, hook_dist), "radius": hook_radius})
		var held: Variant = player.get(&"held_weapons")
		if held is Array and (held as Array).size() >= 2:
			defs.append({"action": &"skill_1", "pos": _arc_pos(swap_angle_deg, swap_dist), "radius": swap_radius})
	return defs


func _button_def(action: StringName) -> Dictionary:
	for def: Dictionary in _button_defs():
		if def["action"] == action:
			return def
	return {}


func _button_at(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INF
	for def: Dictionary in _button_defs():
		var d: float = pos.distance_to(def["pos"])
		if d <= (def["radius"] as float) + touch_slop and d < best_d:
			best_d = d
			best = def
	return best


## Polar around the bottom-right corner: angle 0 = leftward along the bottom
## edge, 90 = up the right edge. Safe-area inset applied.
func _arc_pos(angle_deg: float, dist: float) -> Vector2:
	var corner: Vector2 = _corner_pos(Vector2.ZERO, false)
	var a: float = deg_to_rad(angle_deg)
	return corner + Vector2(-cos(a) * dist, -sin(a) * dist)


func _corner_pos(offset: Vector2, top: bool) -> Vector2:
	var view: Vector2 = _overlay.size
	var inset: Vector2 = _safe_insets()
	if top:
		return Vector2(view.x + offset.x - inset.x, offset.y)
	return view + offset - inset


## Notch/home-bar insets on the right and bottom, converted from physical pixels
## into the stretched viewport's units. Zero on desktop.
func _safe_insets() -> Vector2:
	var window: Vector2i = DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0:
		return Vector2.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var right_px: float = maxf(0.0, float(window.x - (safe.position.x + safe.size.x)))
	var bottom_px: float = maxf(0.0, float(window.y - (safe.position.y + safe.size.y)))
	var view: Vector2 = _overlay.size
	return Vector2(right_px * view.x / float(window.x), bottom_px * view.y / float(window.y))


func _chip_rect() -> Rect2:
	var centre: Vector2 = _corner_pos(chip_offset, false)
	return Rect2(centre - chip_size * 0.5, chip_size)


## The live prompt's first interact row, {} when there is none to mirror.
func _chip_info() -> Dictionary:
	var prompt: WorldPrompt = WorldPrompt.active_prompt()
	if prompt == null or not prompt.visible:
		return {}
	return prompt.interact_row()


func _chip_visible() -> bool:
	return not _chip_info().is_empty()


## Was this touch on the world prompt card itself? Screen -> world through the
## camera's canvas transform, tested against the card's last drawn rect.
func _card_hit(pos: Vector2) -> bool:
	var prompt: WorldPrompt = WorldPrompt.active_prompt()
	if prompt == null or not prompt.visible or prompt.interact_row().is_empty():
		return false
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * pos
	return prompt.last_card_rect.grow(touch_slop).has_point(world)


# --- Drawing (visuals only; all state above is written by input, never here) ---

func _draw_overlay() -> void:
	var ci: Control = _overlay
	# Stick: live under the finger, or a faint resting hint so the zone reads.
	if _stick_held:
		_draw_stick(ci, _stick_origin, idle_alpha)
	else:
		var view: Vector2 = ci.size
		_draw_stick(ci, Vector2(view.x * 0.16, view.y * 0.74), idle_alpha * 0.35)
	for def: Dictionary in _button_defs():
		_draw_button(ci, def)
	if _chip_visible():
		_draw_chip(ci)


func _draw_stick(ci: Control, origin: Vector2, alpha: float) -> void:
	ci.draw_circle(origin, stick_base_radius, Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha * 0.6))
	ci.draw_arc(origin, stick_base_radius, 0.0, TAU, 48, Color(PANEL_BORDER, alpha), 3.0, true)
	var knob_at: Vector2 = origin
	if _stick_held:
		knob_at = origin + _stick_vec * (stick_base_radius - stick_knob_radius * 0.5)
	var knob_border: Color = PRESSED_BORDER if _stick_held and _stick_vec != Vector2.ZERO else PANEL_BORDER
	ci.draw_circle(knob_at, stick_knob_radius, Color(INK.r, INK.g, INK.b, alpha * 0.35))
	ci.draw_arc(knob_at, stick_knob_radius, 0.0, TAU, 32, Color(knob_border, minf(1.0, alpha * 1.6)), 3.0, true)
	# Faint chevrons at the rim while held: "flick me sideways" (the roll).
	if flick_roll_enabled and _stick_held:
		var chev: Color = Color(INK, alpha * 0.7)
		for side: float in [-1.0, 1.0]:
			var rim: Vector2 = origin + Vector2(side * (stick_base_radius - 16.0), 0.0)
			for k: int in 2:
				var base_x: float = rim.x - side * float(k) * 12.0
				ci.draw_polyline(PackedVector2Array([
					Vector2(base_x - side * 8.0, rim.y - 9.0),
					Vector2(base_x, rim.y),
					Vector2(base_x - side * 8.0, rim.y + 9.0)]), chev, 3.0, true)


func _draw_button(ci: Control, def: Dictionary) -> void:
	var action: StringName = def["action"]
	var pos: Vector2 = def["pos"]
	var radius: float = def["radius"]
	var down: bool = _pressed.get(action, false)
	var alpha: float = pressed_alpha if down else idle_alpha
	ci.draw_circle(pos, radius, Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha))
	ci.draw_arc(pos, radius, 0.0, TAU, 40, Color(PRESSED_BORDER if down else PANEL_BORDER, alpha), 3.0, true)
	# Glyphs live in TouchGlyphs so prompt chips (KeyChip's touch mode) draw
	# the exact same shapes the thumb already knows.
	TouchGlyphs.draw(ci, action, pos, radius * 0.44, Color(INK, alpha + 0.08))


func _draw_chip(ci: Control) -> void:
	var info: Dictionary = _chip_info()
	var rect: Rect2 = _chip_rect()
	var down: bool = _pressed.get(&"interact", false)
	var alpha: float = pressed_alpha if down else minf(1.0, idle_alpha + 0.25)
	ci.draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Color(0, 0, 0, 0.35 * alpha))
	ci.draw_rect(rect, Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha))
	if info["hold"] and (info["progress"] as float) > 0.0:
		var fill: Rect2 = Rect2(rect.position, Vector2(rect.size.x * (info["progress"] as float), rect.size.y))
		ci.draw_rect(fill, Color(FILL_AMBER, FILL_AMBER.a + (0.2 if down else 0.0)))
	ci.draw_rect(rect, Color(PRESSED_BORDER if down else PANEL_BORDER, alpha), false, 3.0)
	var fs: int = 26
	var label: String = info["label"]
	var text_w: float = FONT_BOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline: float = rect.position.y + (rect.size.y - (FONT_BOLD.get_ascent(fs) + FONT_BOLD.get_descent(fs))) * 0.5 + FONT_BOLD.get_ascent(fs)
	ci.draw_string(FONT_BOLD, Vector2(rect.position.x + (rect.size.x - text_w) * 0.5, baseline), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, minf(1.0, alpha + 0.1)))
