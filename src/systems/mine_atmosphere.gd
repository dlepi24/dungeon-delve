extends Node
## The mine's atmosphere: the pass that turns "sprites on a flat dark field"
## into a place with light, depth and a unifying grade. Built entirely from
## gradients and particles at runtime — no textures on disk — so gray-box
## discipline holds while the scene stops looking like an editor viewport.
##
## Four layers, all VISUAL ONLY (never _physics_process, never the seeded Rng —
## a ghost replay must not see any of this):
##   1. GRADE + DARKNESS — a CanvasModulate tints AND dims the whole world
##      canvas, so cold rock, warm timber and tinted enemies read as one graded
##      world instead of three asset packs. The HUD is on its own canvas, so it
##      stays full-bright.
##   2. LIGHT — a warm lamp rides the player and casts real Light2D pools into
##      that darkness; shrines/anchors/forges bring their own.
##   3. DEPTH — layered drifting dust and slow haze motes give the flat backdrop
##      volume, and a top-of-frame shadow sinks the empty headroom into dark so
##      it recedes instead of reading as an empty canvas.
##   4. VIGNETTE — pulls the screen edges in, focusing the eye on the action.
##
## Readability is the hard constraint (GDD: telegraphs ARE the combat language),
## so the play-area ambient stays legible — the drama comes from the lit/unlit
## CONTRAST and the sunk headroom, not from crushing the whole frame. Every
## value is exported; Dustin tunes the mood in the inspector while playing.

@export_group("Grade + darkness")
## World tint AND dim in one: the CanvasModulate colour every world sprite is
## multiplied by. Cool and genuinely dark for the delve; the hub overrides it
## warmer and brighter. The dark is the POINT — it is what the lamp contrasts
## against, so the lit pool reads as the focal point. Keep the play area
## readable enough that telegraphs survive (they get lit by the lamp anyway).
@export var darkness: Color = Color(0.3, 0.34, 0.44)

@export_group("Player lamp")
## The travel pool: a warm lamp that lights the GROUND the player stands on and
## the area he fights in. Dimmed and tightened from the old floodlight — a big
## bright pool washed the whole frame and flattened the player's own shading.
## Its hot core sits low (at the feet) so the character's body catches the
## gentler mid-falloff instead of the blow-out centre.
@export var lantern_colour: Color = Color(1.0, 0.86, 0.62)
@export var lantern_energy: float = 1.15
## Glow radius in multiples of 128 px. 4.0 ≈ 512 px — an intimate pool, not the
## old ~900 px floodlight.
@export var lantern_scale: float = 4.0

@export_group("Player key light")
## A SEPARATE, tight light on the player's body. This is what makes him "the
## main thing": a small warm-white pool centred on his torso that catches the
## sprite and falls off before it reaches the ground, so he is the brightest
## island in the frame without the travel pool having to flood everything.
## Keep it gentle — its job is to define him, not to clip his shading to white.
@export var key_colour: Color = Color(1.0, 0.94, 0.85)
@export var key_energy: float = 0.7
## Radius in multiples of 128 px. Small on purpose — roughly the character's
## own footprint, so only he is lit this hot.
@export var key_scale: float = 1.7
## How bright the very CENTRE of the light is, where the player stands. The old
## texture was pure white at the core, so he sat in the hotspot and blew out.
## Below 1.0 the brightest point becomes a ring just outside centre and the
## middle stays soft — the glow still radiates, the character no longer blasts.
@export_range(0.0, 1.0) var lamp_core: float = 0.45

@export_group("Depth")
## How hard the top of the frame sinks into shadow — this is what makes the
## empty headroom recede into "deep dark cavern" instead of "flat empty wall".
@export_range(0.0, 1.0) var top_shadow: float = 0.7
## Fine dust motes drifting through the light. 0 disables.
@export var dust_amount: int = 14
## Slow, larger haze motes on a second depth plane. 0 disables. Kept sparse —
## more than a few big soft blobs reads as smudges on the lens, not depth.
@export var haze_amount: int = 4
## Warm tint of the airborne dust; picks up the lantern.
@export var dust_colour: Color = Color(1.0, 0.9, 0.72)

@export_group("Vignette")
## How dark the screen corners get. 0 disables.
@export_range(0.0, 1.0) var vignette_strength: float = 0.55

@export_group("Bottom glow")
## Light bleeding up from BELOW the frame — the zone's underworld showing: the
## Hot Vein's magma, the Deadlight's pale shine. 0 (the default, and the Upper
## Workings) disables; zones drive it.
@export_range(0.0, 1.0) var bottom_glow: float = 0.0
@export var bottom_glow_colour: Color = Color(1.0, 0.45, 0.18)

var _lantern: PointLight2D = null
var _key: PointLight2D = null
## Built nodes, kept so a zone change can regrade them live instead of
## rebuilding the world. Null until _build runs.
var _cm: CanvasModulate = null
var _layer: CanvasLayer = null
var _top_rect: TextureRect = null
var _bottom_rect: TextureRect = null
var _vignette_rect: TextureRect = null
var _mote_nodes: Array[CPUParticles2D] = []
## How the air moves right now — &"dust" falls, &"embers" rise, &"spores"
## hang. Zones set it; the exported defaults describe the Upper Workings.
var _mote_style: StringName = &"dust"


func _ready() -> void:
	# Deferred: the scene tree is still assembling during _ready, and the
	# modulate/overlays want to sit on the root next to everything else.
	_build.call_deferred()
	# Zones regrade the whole pass. Signal-driven, so the Delve never needs a
	# reference to this node — and the hub's copy simply never hears it fire.
	Events.zone_entered.connect(_on_zone_entered)


func _build() -> void:
	_cm = CanvasModulate.new()
	_cm.color = darkness
	get_parent().add_child(_cm)

	# A screen-fixed overlay canvas above the world (0) but below the HUD (5),
	# so the top shadow and vignette never dim the health bar or room counter.
	_layer = CanvasLayer.new()
	_layer.layer = 2
	add_child(_layer)

	if top_shadow > 0.0:
		_top_rect = TextureRect.new()
		_top_rect.texture = _top_texture()
		_top_rect.anchor_right = 1.0
		_top_rect.anchor_bottom = 0.5
		_top_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_top_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(_top_rect)

	_update_bottom_glow()
	_build_motes()

	if vignette_strength > 0.0:
		_vignette_rect = TextureRect.new()
		_vignette_rect.texture = _vignette_texture()
		_vignette_rect.anchor_right = 1.0
		_vignette_rect.anchor_bottom = 1.0
		_vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(_vignette_rect)


## (Re)create or retint the bottom glow band. Lazy: the Upper Workings (and
## the hub) run at 0 and never build the rect at all.
func _update_bottom_glow() -> void:
	if _layer == null:
		return
	if bottom_glow <= 0.0:
		if _bottom_rect != null and is_instance_valid(_bottom_rect):
			_bottom_rect.queue_free()
			_bottom_rect = null
		return
	if _bottom_rect == null or not is_instance_valid(_bottom_rect):
		_bottom_rect = TextureRect.new()
		_bottom_rect.anchor_top = 0.55
		_bottom_rect.anchor_right = 1.0
		_bottom_rect.anchor_bottom = 1.0
		_bottom_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bottom_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Under the motes and vignette: world light, not screen dressing.
		_layer.add_child(_bottom_rect)
		_layer.move_child(_bottom_rect, 0)
	_bottom_rect.texture = _bottom_texture()
	_bottom_rect.modulate = bottom_glow_colour


## (Re)build the two mote planes for the current style. Vignette must stay the
## topmost child, so motes are added just before it when it exists.
func _build_motes() -> void:
	for old: CPUParticles2D in _mote_nodes:
		if is_instance_valid(old):
			old.queue_free()
	_mote_nodes.clear()
	if _layer == null:
		return
	# Haze: big and very faint, so it reads as diffuse depth rather than a
	# handful of discrete blobs. Dust/embers/spores: the near plane, moving the
	# way this zone's air moves.
	if haze_amount > 0:
		_add_mote_plane(_motes(haze_amount, 90.0, 160.0, 8.0, 0.011))
	if dust_amount > 0:
		match _mote_style:
			&"embers":
				# Rising sparks off the hot rock: quicker, brighter, upward —
				# and plenty of them. The vein should feel like standing over
				# a forge, not near a candle.
				_add_mote_plane(_motes(dust_amount + 14, 2.0, 5.0, 46.0, 0.3, Vector2(0.12, -1.0)))
			&"spores":
				# Deadlight spores hang in the air and barely drift.
				_add_mote_plane(_motes(dust_amount + 2, 3.0, 7.0, 9.0, 0.13, Vector2(0.35, 0.25)))
			_:
				_add_mote_plane(_motes(dust_amount, 2.0, 5.0, 24.0, 0.11))


func _add_mote_plane(plane: CPUParticles2D) -> void:
	_layer.add_child(plane)
	if _vignette_rect != null and is_instance_valid(_vignette_rect):
		_layer.move_child(_vignette_rect, _layer.get_child_count() - 1)
	_mote_nodes.append(plane)


## A zone crossed: regrade the world to its palette. The CanvasModulate glides
## rather than cuts — descending should feel like the air changing around you,
## not a light switch. Motes rebuild outright (particles are cheap and the
## preprocess hides the swap); shadow and vignette re-bake their textures.
func _on_zone_entered(zone: ZoneData) -> void:
	darkness = zone.darkness
	dust_colour = zone.dust_colour
	_mote_style = zone.mote_style
	top_shadow = zone.top_shadow
	vignette_strength = zone.vignette_strength
	bottom_glow = zone.bottom_glow
	bottom_glow_colour = zone.bottom_glow_colour
	if _cm == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_cm, "color", darkness, 1.6)
	_update_bottom_glow()
	_build_motes()
	if _top_rect != null and is_instance_valid(_top_rect):
		_top_rect.texture = _top_texture()
	if _vignette_rect != null and is_instance_valid(_vignette_rect):
		_vignette_rect.texture = _vignette_texture()


## The lantern follows the player; resolved lazily per the CLAUDE.md _ready-order
## discipline, and re-attached if the player is ever rebuilt. Once alive it
## flickers — two incommensurate sines, same trick as the hub lights.
func _process(_delta: float) -> void:
	if _lantern != null and is_instance_valid(_lantern):
		# One flicker signal drives both lights together, so the lamp and the key
		# breathe as one source rather than beating against each other.
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var flicker: float = 0.9 + 0.07 * sin(t * 13.0) + 0.05 * sin(t * 29.3)
		_lantern.energy = lantern_energy * flicker
		if _key != null and is_instance_valid(_key):
			_key.energy = key_energy * flicker
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	# Travel pool: hot core LOW (at the feet) so it lights the ground he stands
	# and fights on, and his body only catches the softer mid-falloff — that is
	# what stops the old flood from clipping his sprite to white.
	_lantern = PointLight2D.new()
	_lantern.texture = _light_texture()
	_lantern.color = lantern_colour
	_lantern.energy = lantern_energy
	_lantern.texture_scale = lantern_scale
	_lantern.position = Vector2(0, -10)
	player.add_child(_lantern)
	# Key light: small and centred on the torso, so HE is the brightest island
	# in the frame without the travel pool having to flood the whole area.
	_key = PointLight2D.new()
	_key.texture = _light_texture()
	_key.color = key_colour
	_key.energy = key_energy
	_key.texture_scale = key_scale
	_key.position = Vector2(0, -46)
	player.add_child(_key)


## A screen-fixed drift of motes covering the viewport. Two calls make two
## parallax planes: a near plane (dust/embers/spores) and big slow far haze.
## Direction is per-style — down for dust, UP for embers, a hang for spores.
## Cosmetic, so it uses the particle system's own randomness, never the seeded
## Rng.
func _motes(amount: int, size_min: float, size_max: float, fall: float, alpha: float,
		direction: Vector2 = Vector2(0.4, 1.0)) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.randomness = 1.0
	# Emit across a generous screen box (design res is 1920x1080; expand shows
	# more, so overfill). Screen-fixed layer, so this stays on camera.
	p.position = Vector2(960, 400)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1500, 900)
	p.direction = direction
	p.spread = 40.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = fall * 0.6
	p.initial_velocity_max = fall
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.color = Color(dust_colour.r, dust_colour.g, dust_colour.b, alpha)
	p.texture = _mote_texture()
	return p


func _mote_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 16
	texture.height = 16
	return texture


func _light_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	# A soft-cored falloff: the centre (where the player stands) is dimmed to
	# `lamp_core`, the brightest point sits as a ring just outside it, then it
	# fades gently to the edge. That is what keeps the glow radiating outward
	# without blasting the character at the middle.
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, lamp_core), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 256
	texture.height = 256
	return texture


## The underworld's light: transparent at its top edge, the glow colour rising
## to `bottom_glow` alpha at the frame's bottom. Colour comes from modulate.
func _bottom_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, bottom_glow * 0.35), Color(1, 1, 1, bottom_glow),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 256
	return texture


## A vertical dark band along the top of the frame — the headroom sinks into it.
func _top_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, top_shadow), Color(0, 0, 0, 0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 256
	return texture


func _vignette_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	gradient.colors = PackedColorArray([
		Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, vignette_strength),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 512
	texture.height = 512
	return texture
