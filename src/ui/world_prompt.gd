class_name WorldPrompt
extends Node2D
## An interaction prompt that floats ABOVE a world object instead of sitting in
## the middle of the screen. Position the node at the object's top-centre; the
## card rises a little above that and follows the object (and the camera) for
## free because it lives in the world, not on a HUD layer.
##
## It renders through PromptCard, so a building prompt, a shrine offer and a
## weapon pickup all look like one system. Fades and lifts in when shown, and
## redraws when the player swaps keyboard↔pad. Visual only: no _physics_process,
## no seeded Rng — a ghost replay must never see a prompt.
##
## Usage:
##     var p := WorldPrompt.new()
##     add_child(p)
##     p.position = Vector2(building_x, building_top_y)
##     p.set_action(&"interact", "Trade")            # simple: one key + label
##     # or the full card — title, flavour line, any rows:
##     p.set_card("Overseer's Whisper", "+damage, -health", [
##         PromptCard.action_row(&"interact", "Accept")])
##     p.show_prompt()  # ... p.hide_prompt() when the player walks away

## How far above the node's origin the card floats.
@export var lift: float = 22.0
## Seconds for the fade / rise-in.
@export var appear_time: float = 0.16
## Keep the whole card inside the visible screen: it still sits above the object
## when there's room, but slides inward at a screen edge (a door near the right
## wall, or a high exit) so it never bleeds off where you can't read it.
@export var clamp_to_view: bool = true
## Gap kept between the card and the screen edge when clamping.
@export var screen_margin: float = 20.0
## Arbitration weight. Only ONE world prompt is ever visible at a time — the
## highest-priority one currently asking to show — so cards never stack or
## overlap. Interaction prompts (shrine/pickup 20, extract 30) outrank an
## instructional card (the tutorial's teaching card, 0), which yields while you
## stand at a thing and returns when you leave. Same-priority ties: whoever asked
## first holds the slot until it hides.
@export var priority: int = 0

var _title: String = ""
var _subtitle: String = ""
var _rows: Array = []

# 0 = hidden, 1 = fully shown; eased toward the arbitration result each frame.
var _shown: float = 0.0
var _want: bool = false

## Every prompt currently ASKING to show (show_prompt called, not yet hidden).
## The single visible card is the highest-priority member — see _winner().
static var _wanting: Array[WorldPrompt] = []


func _ready() -> void:
	# Above the props and the player; the prompt must never be occluded by the
	# thing it points at.
	z_index = 500
	visible = false
	modulate.a = 0.0
	# A freed prompt must leave the arbitration set, or it holds the slot forever.
	tree_exiting.connect(func() -> void: _wanting.erase(self))
	# Direction chips are device-agnostic, but action chips (F↔A) are not, so a
	# redraw on device change keeps the glyph honest.
	Keybinds.input_device_changed.connect(func() -> void: queue_redraw())


## The common case: one row, one action key, one label.
func set_action(action: StringName, text: String) -> void:
	set_card("", "", [PromptCard.action_row(action, text)])


## The full card: optional title + flavour line + any rows (see PromptCard).
func set_card(title: String, subtitle: String, rows: Array) -> void:
	_title = title
	_subtitle = subtitle
	_rows = rows
	queue_redraw()


func show_prompt() -> void:
	_want = true
	if not _wanting.has(self):
		_wanting.append(self)


func hide_prompt() -> void:
	_want = false
	_wanting.erase(self)


## The one prompt allowed to show right now: highest priority among those asking,
## ties broken by who asked first (array order). Invalid entries are skipped.
static func _winner() -> WorldPrompt:
	var best: WorldPrompt = null
	for prompt: WorldPrompt in _wanting:
		if not is_instance_valid(prompt):
			continue
		if best == null or prompt.priority > best.priority:
			best = prompt
	return best


func _process(delta: float) -> void:
	# Show only if we both want to AND won arbitration — that is what stops two
	# cards ever occupying the screen at once.
	var winning: bool = _want and _winner() == self
	var target: float = 1.0 if winning else 0.0
	if appear_time > 0.0:
		_shown = move_toward(_shown, target, delta / appear_time)
	else:
		_shown = target
	visible = _shown > 0.005
	modulate.a = _shown
	# The bob and the rise-in both need a fresh frame; only redraw while visible.
	if visible:
		queue_redraw()


func _draw() -> void:
	if _rows.is_empty() and _title == "":
		return
	var size: Vector2 = PromptCard.measure(_title, _subtitle, _rows)
	# Slow idle bob so it feels alive, plus a short upward slide as it fades in.
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var bob: float = sin(t * 2.2) * 2.0
	var rise: float = (1.0 - _shown) * 12.0
	# Ideal spot: centred above the object. Computed in WORLD space so it can be
	# clamped against the visible screen, then converted back to this node's local
	# space for drawing.
	var world_tl: Vector2 = global_position + Vector2(-size.x * 0.5, -lift - size.y + bob + rise)
	if clamp_to_view:
		world_tl = _clamp_to_view(world_tl, size)
	PromptCard.draw(self, to_local(world_tl), _title, _subtitle, _rows)


## Push a card top-left so the whole card stays inside the camera's visible world
## rect (with a margin). The canvas transform maps world→screen and carries no
## rotation, so its inverse gives axis-aligned world bounds for the screen corners.
func _clamp_to_view(world_tl: Vector2, size: Vector2) -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return world_tl
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var view_min: Vector2 = inv * Vector2.ZERO
	var view_max: Vector2 = inv * vp.get_visible_rect().size
	var lo: Vector2 = view_min + Vector2(screen_margin, screen_margin)
	var hi: Vector2 = view_max - Vector2(screen_margin, screen_margin) - size
	# maxf guards the degenerate case of a card wider/taller than the view.
	return Vector2(
		clampf(world_tl.x, lo.x, maxf(lo.x, hi.x)),
		clampf(world_tl.y, lo.y, maxf(lo.y, hi.y)),
	)
