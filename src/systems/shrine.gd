class_name Shrine
extends Node2D
## An altar offering one ShrineData bargain. Walk close and the offer appears in
## plain words over the stone; press interact to accept, walk away to refuse for
## free. Accepting is forever (this run) — the glow dies and the altar is spent.
##
## Which altars are lit and which bargain each offers is decided by the Delve
## from the seeded stream — the shrine itself is dumb presentation plus one
## input check, so daily seeds see identical offers.

@export var data: ShrineData
## How close the player must stand for the offer (and the interact) to be live.
@export var offer_range: float = 130.0

var _accepted: bool = false
var _player: Player = null

@onready var _glow: ColorRect = $Glow
@onready var _offer: Label = $Offer


func _ready() -> void:
	if data != null:
		_glow.color = data.colour
	_offer.visible = false


func _physics_process(_delta: float) -> void:
	if _accepted or data == null:
		return
	# Lazy player lookup, per the CLAUDE.md _ready-order discipline.
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	var near: bool = global_position.distance_to(_player.global_position) <= offer_range
	_offer.visible = near
	if near:
		_refresh_offer()


func _refresh_offer() -> void:
	var line: String = "%s\n%s\n" % [data.display_name, data.bargain_text]
	if data.ore_cost > 0 and GameState.carried_haul < data.ore_cost:
		line += "(need %d carried ore)" % data.ore_cost
	else:
		line += "[%s] Accept" % Keybinds.label_for(&"interact")
	_offer.text = line


func _unhandled_input(event: InputEvent) -> void:
	if _accepted or data == null or not _offer.visible:
		return
	if not event.is_action_pressed(&"interact"):
		return
	get_viewport().set_input_as_handled()
	_accept()


func _accept() -> void:
	if not GameState.spend_carried(data.ore_cost):
		return
	_accepted = true
	GameState.apply_modifier(data)
	# A max-health bargain must not leave current health above the new cap.
	if _player != null:
		_player.health = minf(_player.health, _player.effective_max_health())
	_offer.visible = false
	# The spent altar keeps a coal of its colour, so you can see what you took.
	_glow.color = Color(data.colour, 0.25)
