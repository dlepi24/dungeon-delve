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
## Seconds you must hold interact to accept the bargain. Tuned to clear a panic
## tap; see HoldInteract.
@export var accept_hold_time: float = 0.24

var _accepted: bool = false
var _player: Player = null
var _light: PointLight2D = null
## The altar's sacred hum — a positional loop that swells as you approach and
## dies when the bargain is taken. This is the drone the roadmap deferred for
## "needs an audio asset"; it now has one (assets/audio/shrine_hum.wav).
var _hum: AudioStreamPlayer2D = null

## The pulsing offering light. Baked near-white on the sheet precisely so this
## modulate tint (the bargain's colour) reads through it.
var _glow: BakedSprite = null

## The offer card, floating above the altar. Built in code (same WorldPrompt as
## the shops), so a shrine reads as a shop card: bargain name, its flavour line,
## and one big Accept — or a greyed "need N ore" when you cannot pay.
var _offer: WorldPrompt = null
## Whether the player is currently in range — the hold check reads this rather
## than the card's fading visibility.
var _offered: bool = false
## A bargain can take something from you, so accepting is a deliberate HOLD, not
## a tap — the panic jump that shares the button can't sign you up for a debuff.
## See HoldInteract.
var _hold: HoldInteract = HoldInteract.new()


func _ready() -> void:
	_hold.hold_time = accept_hold_time
	# Grouped so a director (the tutorial) can find and clear stray altars.
	add_to_group(&"shrines")
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
		# the room — bigger and slow-pulsing now, so it reads as a live shrine
		# and not a static prop. Dies to an ember on accept, with the glow.
		_light = PointLight2D.new()
		_light.texture = _radial_light()
		_light.color = data.colour
		_light.energy = 1.15
		_light.texture_scale = 3.2
		_light.position = Vector2(0, -46)
		add_child(_light)
		# Offering motes drifting up off the altar, tinted to the bargain.
		add_child(_altar_dust())
		# And the hum: positional, so walking toward a lit altar brings it up out
		# of the mine bed. On the Ambience bus (reverbed, scaled by the SFX slider).
		_hum = AudioStreamPlayer2D.new()
		_hum.bus = &"Ambience"
		_hum.stream = _looped_hum()
		_hum.volume_db = -8.0
		_hum.max_distance = offer_range * 2.4
		_hum.attenuation = 1.4
		_hum.position = Vector2(0, -46)
		add_child(_hum)
		_hum.play()
	# The offer card floats above the altar (art top ≈ y -56).
	_offer = WorldPrompt.new()
	_offer.position = Vector2(0, -64)
	_offer.priority = 20
	add_child(_offer)


## Slow pulse on the light and glow (visual only) while the offer stands. Stops
## once accepted — the spent altar keeps a steady ember, set in _accept.
func _process(_delta: float) -> void:
	if _accepted or _light == null:
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(t * 2.4)
	_light.energy = 0.95 + 0.45 * pulse
	_glow.modulate.a = 0.7 + 0.3 * pulse


func _altar_dust() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.amount = 12
	p.lifetime = 3.2
	p.preprocess = 3.0
	p.position = Vector2(0, -30)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(18, 6)
	p.direction = Vector2(0, -1)
	p.spread = 24.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = Color(data.colour.r, data.colour.g, data.colour.b, 0.32)
	return p


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


func _physics_process(delta: float) -> void:
	if _accepted or data == null:
		return
	# Lazy player lookup, per the CLAUDE.md _ready-order discipline.
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	var near: bool = global_position.distance_to(_player.global_position) <= offer_range
	_offered = near
	# You can only hold to accept what you can afford; the gated card can't charge.
	var affordable: bool = data.ore_cost <= 0 or GameState.carried_haul >= data.ore_cost
	if _hold.poll(near and affordable, delta):
		_accept()
		return
	# On the pad, interact and jump share A: eat the hop once the hold is committed
	# so it stops knocking you off the altar. Keyboard keeps jump live.
	if _hold.committing and _player != null and Keybinds.using_gamepad:
		_player.swallow_jump()
	if near:
		_refresh_offer()
		_offer.show_prompt()
	else:
		_offer.hide_prompt()


func _refresh_offer() -> void:
	var rows: Array = []
	if data.ore_cost > 0 and GameState.carried_haul < data.ore_cost:
		rows = [PromptCard.gated_row("need %d carried ore" % data.ore_cost)]
	else:
		rows = [PromptCard.hold_row(&"interact", "Hold to Accept", _hold.progress)]
	_offer.set_card(data.display_name, data.bargain_text, rows)


func _accept() -> void:
	if not GameState.spend_carried(data.ore_cost):
		return
	_accepted = true
	GameState.apply_modifier(data)
	# A max-health bargain must not leave current health above the new cap.
	if _player != null:
		_player.health = minf(_player.health, _player.effective_max_health())
	_offered = false
	_offer.hide_prompt()
	# The spent altar keeps a coal of its colour, so you can see what you took.
	_glow.modulate = Color(data.colour, 0.25)
	if _light != null:
		_light.energy = 0.25
	# The hum dies with the offer — a spent altar is quiet stone.
	if _hum != null:
		_hum.stop()


## The imported WAV loops only if we force it at runtime (same as Music/Sfx).
func _looped_hum() -> AudioStream:
	var base: AudioStreamWAV = load("res://assets/audio/shrine_hum.wav") as AudioStreamWAV
	if base == null:
		return null
	var stream: AudioStreamWAV = base.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	return stream
