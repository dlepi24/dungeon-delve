extends Node2D
## The surface hub between runs. Where banked haul is spent and a new delve begins.
##
## This is the "progress persists" pillar made concrete: you arrive here after
## every run, win or lose, and whatever you banked is still yours to spend. Two
## interaction points — the vendor and the mine mouth — and a warm, safe room to
## stand in. Deliberately small; M6 fleshes out what the hub becomes.

const DELVE_SCENE: String = "res://src/rooms/delve_run.tscn"
## The Train post now routes to the guided intro ("The First Descent"), not the
## old M2 gym. It is death-proof and returns to the hub, so it replays cleanly
## as a from-the-hub refresher. The gym (src/rooms/gym.tscn) still exists as a
## free-play practice space; it is just no longer wired to this button.
const TRAINING_SCENE: String = "res://src/rooms/tutorial_run.tscn"

@export var interact_range: float = 90.0
## How far below the music bed the hub sits. Between the title (0) and the
## delve — the surface should feel calmer than the menu, safer than the mine.
@export var music_attenuation_db: float = -5.0

var _player: Player = null
var _near: StringName = &""

## Each interaction point: its proximity marker, the label its floating prompt
## shows, and the world point the prompt floats above (the building's top-centre).
## First-visit explanations ride these same hover prompts (see _TOUR below).
const _POINTS: Array[Dictionary] = [
	{"id": &"vendor", "label": "Trade", "anchor": Vector2(720, 648)},
	{"id": &"training", "label": "Train", "anchor": Vector2(520, 662)},
	{"id": &"blacksmith", "label": "Blacksmith", "anchor": Vector2(965, 642)},
	{"id": &"mine", "label": "Descend into the mine", "anchor": Vector2(1360, 610)},
]
## THE HOLLOW BELOW's entrance, world point the prompt floats above. Matches
## the mine's own anchor pattern (art centre x, y just above the mouth art).
const _HOLLOW_ANCHOR: Vector2 = Vector2(1650, 610)

var _point_prompts: Dictionary[StringName, WorldPrompt] = {}

## First-visit tour copy. Until the tour is retired, the building hover prompts
## carry a title + a one-line explanation of the whole loop; after that they go
## terse. Kept diegetic (the same floating cards, just richer) rather than a
## screen overlay — a top panel fought the art. The mine's line is the greed
## pillar stated plainly.
const _MINE_TOUR: String = "Deeper pays richer — but the shaft turns on you the further down. Bank your haul before it keeps you."
const _TOUR: Dictionary = {
	&"vendor": {"title": "TRADE", "sub": "Spend banked ore on permanent upgrades — they stack across every run."},
	&"blacksmith": {"title": "BLACKSMITH", "sub": "Buy a sharper tool, or hone the one already in your hand."},
}
## The three stations whose explanation the tour must land before retiring. It
## ends only once the player has stood at ALL of them — NOT on the first descend,
## because a fresh player's instinct after the tutorial is to head straight back
## down, which would nuke the trade/smith cards unread.
const _TOUR_STATIONS: Array[StringName] = [&"vendor", &"blacksmith", &"mine"]
## Which stations have been visited this surface trip. Reset each hub load; the
## small outpost is one lap, so a curious player completes it in a single visit.
var _tour_seen: Dictionary[StringName, bool] = {}

@onready var _vendor_marker: Marker2D = $VendorMarker
@onready var _training_marker: Marker2D = $TrainingMarker
@onready var _smithy_marker: Marker2D = $SmithyMarker
@onready var _mine_marker: Marker2D = $MineMarker
@onready var _hollow_marker: Marker2D = $HollowMarker
@onready var _hollow_mouth: ColorRect = $HollowMouth
@onready var _hollow_mouth_art: AnimatedSprite2D = $HollowMouthArt
@onready var _vendor_panel: CanvasLayer = $VendorPanel
@onready var _blacksmith_panel: CanvasLayer = $BlacksmithPanel
@onready var _banked_card: PanelContainer = $HubHud/BankedCard
@onready var _banked_value: Label = $HubHud/BankedCard/Margin/Rows/Banked/Value
@onready var _heat_pill: PanelContainer = $HubHud/BankedCard/Margin/Rows/Heat
@onready var _heat_label: Label = $HubHud/BankedCard/Margin/Rows/Heat/HeatMargin/HeatLabel


func _ready() -> void:
	# Arriving at the hub means the previous run is over; make sure run state is
	# not lingering, and the player is whole again.
	GameState.end_run()
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null:
		_player.reset_for_new_run()
		_player.global_position = $PlayerStart.global_position
	_vendor_panel.visible = false
	_blacksmith_panel.visible = false
	# THE HOLLOW BELOW's entrance is invisible until earned — the whole point is
	# that it appears where there was solid rock before, the moment you meet the
	# gate. Nothing to build here; the art already exists in the scene, just hidden.
	var unlocked: bool = GameState.threshold_open()
	_hollow_mouth.visible = unlocked
	_hollow_mouth_art.visible = unlocked
	_build_prompts()
	_build_dressing()
	Cursor.gameplay()
	Music.play(&"hub", music_attenuation_db)
	_refresh_banked()
	# Stay live on every path that moves banked haul — a vendor upgrade OR a
	# blacksmith purchase. spend_banked used to change the number silently, so the
	# card went stale after buying a weapon; banked_changed closes that gap.
	Events.banked_changed.connect(func(_banked: int) -> void: _refresh_banked())
	UiScaler.apply(_banked_card, Settings.ui_scale, Vector2(0.0, 0.0))
	Settings.ui_scale_changed.connect(func(s: float) -> void: UiScaler.apply(_banked_card, s, Vector2(0.0, 0.0)))


## One floating prompt per interaction point, parked above its building. They
## live in the world, so they sit over the thing and ride the camera — no more
## single Label pinned to screen centre.
func _build_prompts() -> void:
	# On the first surface visit the prompts do double duty as a quiet tour of the
	# loop; every later visit gets the terse originals.
	var tour: bool = not GameState.hub_toured
	# THE THRESHOLD: a 5th point, appended only once earned — _POINTS stays the
	# fixed 4 so nothing else that iterates it needs to know this one exists.
	var points: Array[Dictionary] = _POINTS.duplicate()
	if GameState.threshold_open():
		points.append({"id": &"hollow", "label": "Enter the Hollow Below", "anchor": _HOLLOW_ANCHOR})
	for point: Dictionary in points:
		var prompt: WorldPrompt = WorldPrompt.new()
		add_child(prompt)
		prompt.position = point["anchor"]
		var id: StringName = point["id"]
		var label: String = point["label"]
		# The mine is entered by pressing DOWN (descend), the way you leave a
		# room downward in the delve — more intuitive than a generic Interact.
		# The shops are a plain Interact.
		if id == &"mine":
			var mine_sub: String = _MINE_TOUR if tour else ""
			var mine_title: String = "THE MINE" if tour else ""
			prompt.set_card(mine_title, mine_sub, [PromptCard.dir_row(false, label)])
		elif id == &"hollow":
			# THE THRESHOLD (2026-07-23, revised): a SEPARATE opening rather than a
			# second option buried at the ordinary mine mouth — Dustin's own read
			# after playing it: "maybe we have different mine entrances... we've
			# unlocked a new mine." Always carries its title; unlike the vendor/
			# smith tour cards this one never goes terse, since you only ever stand
			# here occasionally, after specifically earning it.
			prompt.set_card("THE HOLLOW BELOW", "A way down that wasn't there before.",
				[PromptCard.dir_row(false, label)])
		elif tour and _TOUR.has(id):
			var t: Dictionary = _TOUR[id]
			prompt.set_card(t["title"], t["sub"], [PromptCard.action_row(&"interact", label)])
		else:
			prompt.set_action(&"interact", label)
		_point_prompts[id] = prompt


## Warm clutter so the outpost reads as lived-in, not four buildings on an empty
## floor. Props are set dressing (no collision), placed by hand at floor height
## (y=780); hanging lanterns drop from the dark ceiling as warm points of light.
func _build_dressing() -> void:
	var floor_y: float = 780.0
	var props: Array[Node2D] = [
		SetDressing.make_rubble(76),
		SetDressing.make_crate(48, 48),
		SetDressing.make_crate(30, 30),
		SetDressing.make_barrel(),
		SetDressing.make_barrel(30, 42),
		SetDressing.make_crate(42, 42),
	]
	var spots: Array[Vector2] = [
		Vector2(400, floor_y), Vector2(630, floor_y), Vector2(650, floor_y - 48),
		Vector2(1085, floor_y), Vector2(1112, floor_y), Vector2(1250, floor_y),
	]
	for i: int in props.size():
		props[i].position = spots[i]
		add_child(props[i])
	# 268 is the gantry beam's underside (hub_scenery.gd): with open sky behind
	# the frame, a chain has to visibly start AT the timber, not float below it.
	for at: Vector2 in [Vector2(845, 268), Vector2(1180, 268)]:
		var lantern: Node2D = SetDressing.make_lantern(120.0)
		lantern.position = at
		add_child(lantern)
	# Story props (round 5): a lost-crew helmet pile by the training post, a coal
	# heap by the smithy, and an abandoned ore cart at the mine mouth apron.
	_story_prop("helmets", &"idle", 26, 14, Vector2(470, floor_y))
	_story_prop("coal", &"idle", 30, 12, Vector2(900, floor_y))
	_story_prop("cart", &"empty", 36, 26, Vector2(1300, floor_y))


## A baked story prop standing on the floor (bottom at `at.y`). No collision —
## set dressing, drawn behind the player.
func _story_prop(sheet: String, anim: StringName, w: int, h: int, at: Vector2) -> void:
	var prop: BakedSprite = BakedSprite.make(sheet, 1.0, anim)
	prop.centered = false
	prop.offset = Vector2(-w * 0.5, -h)
	prop.position = at
	add_child(prop)


func _refresh_banked() -> void:
	_banked_value.text = str(GameState.banked_haul)
	# The streak is a possession — showing it on the surface is what makes
	# descending at heat 4 feel like carrying something breakable. It only earns
	# its red pill when it exists.
	_heat_pill.visible = GameState.mine_heat > 0
	if _heat_pill.visible:
		_heat_label.text = "MINE HEAT  %d" % GameState.mine_heat


func _physics_process(_delta: float) -> void:
	if _player == null:
		_show_only(&"")
		return
	# Walking away from a stall closes it — you are not paused while shopping,
	# so leaving without closing left a dead panel over the screen.
	if _vendor_panel.visible:
		if _player.global_position.distance_to(_vendor_marker.global_position) > interact_range * 1.6:
			_vendor_panel.close()
		_show_only(&"")
		return
	if _blacksmith_panel.visible:
		if _player.global_position.distance_to(_smithy_marker.global_position) > interact_range * 1.6:
			_blacksmith_panel.close()
		_show_only(&"")
		return
	var near: StringName = &""
	if _player.global_position.distance_to(_vendor_marker.global_position) <= interact_range:
		near = &"vendor"
	elif _player.global_position.distance_to(_training_marker.global_position) <= interact_range:
		near = &"training"
	elif _player.global_position.distance_to(_smithy_marker.global_position) <= interact_range:
		near = &"blacksmith"
	elif _player.global_position.distance_to(_mine_marker.global_position) <= interact_range:
		near = &"mine"
	elif _hollow_mouth.visible and _player.global_position.distance_to(_hollow_marker.global_position) <= interact_range:
		near = &"hollow"
	_near = near
	_note_tour_progress(near)
	_show_only(near)


## Mark a tour station seen when the player stands at it, and retire the tour once
## all three have been. This is what makes the explanations survive an early
## descend: the mine card alone no longer ends the tour — the shops must be seen
## too. Persisted the moment it completes, so it never fires again.
func _note_tour_progress(near: StringName) -> void:
	if GameState.hub_toured or near == &"" or not _TOUR_STATIONS.has(near):
		return
	_tour_seen[near] = true
	for station: StringName in _TOUR_STATIONS:
		if not _tour_seen.get(station, false):
			return
	GameState.hub_toured = true
	GameState.save_game()


## Show the one prompt whose point the player stands at; fade the rest out.
func _show_only(id: StringName) -> void:
	for key: StringName in _point_prompts:
		if key == id:
			_point_prompts[key].show_prompt()
		else:
			_point_prompts[key].hide_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _vendor_panel.visible or _blacksmith_panel.visible:
		return
	# Both mine mouths take a deliberate DOWN, same verb, same fiction; the
	# shops take Interact.
	if _near == &"mine":
		if event.is_action_pressed(&"move_down") and _deliberate(event):
			get_viewport().set_input_as_handled()
			_descend()
		return
	if _near == &"hollow":
		if event.is_action_pressed(&"move_down") and _deliberate(event):
			get_viewport().set_input_as_handled()
			_descend_hollow_below()
		return
	if not event.is_action_pressed(&"interact"):
		return
	# Interact and jump share A on a pad. Opening a storefront off that press must
	# not also hop — but pressing interact next to nothing still jumps normally.
	if _near == &"vendor" or _near == &"training" or _near == &"blacksmith":
		_player.swallow_jump()
	if _near == &"vendor":
		get_viewport().set_input_as_handled()
		_vendor_panel.visible = true
		_vendor_panel.open()
	elif _near == &"training":
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file.call_deferred(TRAINING_SCENE)
	elif _near == &"blacksmith":
		get_viewport().set_input_as_handled()
		_blacksmith_panel.open()


## A stick press only counts at a committed tilt — walking toward the mine with
## the thumb angled slightly down should not descend. Keys and D-pad are always
## deliberate. (Same guard the delve's extract uses.)
func _deliberate(event: InputEvent) -> bool:
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion == null:
		return true
	return absf(motion.axis_value) >= 0.7


func _descend() -> void:
	# NOTE: descending no longer retires the tour — that is _note_tour_progress's
	# job, gated on having stood at the shops. A player who dives straight back down
	# still gets the trade/smith cards on their next surface visit.
	# A fresh run gets a fresh seed. Choosing a seed is the one legitimately
	# arbitrary thing in the loop, so it does NOT come from the seeded service
	# (that would make the seed depend on the seed). Daily-seed mode is M8.
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.randomize()
	GameState.pending_seed = generator.randi()
	GameState.pending_mode = &"free"
	get_tree().change_scene_to_file.call_deferred(DELVE_SCENE)


## THE HOLLOW BELOW: the same delve scene, same seed-picking rule as an
## ordinary descent — the mode swap (Delve.start reads pending_mode) is what
## routes it to the shorter single-zone chain instead of the usual three.
func _descend_hollow_below() -> void:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.randomize()
	GameState.pending_seed = generator.randi()
	GameState.pending_mode = &"hollow"
	get_tree().change_scene_to_file.call_deferred(DELVE_SCENE)
