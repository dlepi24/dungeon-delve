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
var _light: PointLight2D = null

## The pulsing offering light. Baked near-white on the sheet precisely so this
## modulate tint (the bargain's colour) reads through it.
var _glow: BakedSprite = null

@onready var _offer: Label = $Offer


func _ready() -> void:
	# The altar art, feet at y=0 like the old pedestal rect.
	var altar: BakedSprite = BakedSprite.make("shrine", 1.0, &"altar")
	altar.centered = false
	altar.offset = Vector2(-24, -56)
	add_child(altar)
	_glow = BakedSprite.make("shrine", 2.5, &"glow")
	_glow.centered = false
	_glow.offset = Vector2(-24, -56)
	add_child(_glow)
	if data != null:
		_glow.modulate = data.colour
		# A real light in the mine's darkness, so an altar beckons from across
		# the room. Dies to an ember on accept, with the glow.
		_light = PointLight2D.new()
		_light.texture = _radial_light()
		_light.color = data.colour
		_light.energy = 0.9
		_light.texture_scale = 2.2
		_light.position = Vector2(0, -46)
		add_child(_light)
	_offer.visible = false


func _radial_light() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.BLACK)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 128
	texture.height = 128
	return texture


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
		line += "[%s] Accept" % Keybinds.hint_for(&"interact")
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
	_glow.modulate = Color(data.colour, 0.25)
	if _light != null:
		_light.energy = 0.25
