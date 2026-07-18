extends Node2D
## The surface hub between runs. Where banked haul is spent and a new delve begins.
##
## This is the "progress persists" pillar made concrete: you arrive here after
## every run, win or lose, and whatever you banked is still yours to spend. Two
## interaction points — the vendor and the mine mouth — and a warm, safe room to
## stand in. Deliberately small; M6 fleshes out what the hub becomes.

const DELVE_SCENE: String = "res://src/rooms/delve_run.tscn"

@export var interact_range: float = 90.0

var _player: Player = null
var _near: StringName = &""

@onready var _vendor_marker: Marker2D = $VendorMarker
@onready var _smithy_marker: Marker2D = $SmithyMarker
@onready var _mine_marker: Marker2D = $MineMarker
@onready var _vendor_panel: CanvasLayer = $VendorPanel
@onready var _blacksmith_panel: CanvasLayer = $BlacksmithPanel
@onready var _prompt: Label = $HubHud/Prompt
@onready var _banked_label: Label = $HubHud/Banked


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
	Cursor.gameplay()
	Music.play(&"hub")
	_refresh_banked()
	Events.upgrade_purchased.connect(func(_id: StringName, _lvl: int) -> void: _refresh_banked())


func _refresh_banked() -> void:
	var text: String = "Banked haul: %d" % GameState.banked_haul
	if GameState.mine_heat > 0:
		# The streak is a possession — naming it on the surface is what makes
		# descending at heat 4 feel like carrying something breakable.
		text += "\nMine heat: %d  (extractions since your last death)" % GameState.mine_heat
	_banked_label.text = text


func _physics_process(_delta: float) -> void:
	if _player == null:
		_prompt.text = ""
		return
	# Walking away from a stall closes it — you are not paused while shopping,
	# so leaving without closing left a dead panel over the screen.
	if _vendor_panel.visible:
		if _player.global_position.distance_to(_vendor_marker.global_position) > interact_range * 1.6:
			_vendor_panel.close()
		_prompt.text = ""
		return
	if _blacksmith_panel.visible:
		if _player.global_position.distance_to(_smithy_marker.global_position) > interact_range * 1.6:
			_blacksmith_panel.close()
		_prompt.text = ""
		return
	var near: StringName = &""
	if _player.global_position.distance_to(_vendor_marker.global_position) <= interact_range:
		near = &"vendor"
	elif _player.global_position.distance_to(_smithy_marker.global_position) <= interact_range:
		near = &"blacksmith"
	elif _player.global_position.distance_to(_mine_marker.global_position) <= interact_range:
		near = &"mine"
	_near = near
	match near:
		&"vendor":
			_prompt.text = "[F] Trade"
		&"blacksmith":
			_prompt.text = "[F] Blacksmith"
		&"mine":
			_prompt.text = "[F] Descend into the mine"
		_:
			_prompt.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if _vendor_panel.visible or _blacksmith_panel.visible:
		return
	if not event.is_action_pressed(&"interact"):
		return
	if _near == &"vendor":
		get_viewport().set_input_as_handled()
		_vendor_panel.visible = true
		_vendor_panel.open()
	elif _near == &"blacksmith":
		get_viewport().set_input_as_handled()
		_blacksmith_panel.open()
	elif _near == &"mine":
		get_viewport().set_input_as_handled()
		_descend()


func _descend() -> void:
	# A fresh run gets a fresh seed. Choosing a seed is the one legitimately
	# arbitrary thing in the loop, so it does NOT come from the seeded service
	# (that would make the seed depend on the seed). Daily-seed mode is M8.
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.randomize()
	GameState.pending_seed = generator.randi()
	get_tree().change_scene_to_file.call_deferred(DELVE_SCENE)
