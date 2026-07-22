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
## multiplied by. Cool and a little dark for the delve; the hub overrides it
## warmer and brighter. Keep the play area readable — telegraphs must survive.
@export var darkness: Color = Color(0.46, 0.5, 0.64)

@export_group("Player lamp")
@export var lantern_colour: Color = Color(1.0, 0.86, 0.62)
@export var lantern_energy: float = 1.7
## Glow radius in multiples of 128 px.
@export var lantern_scale: float = 7.0

@export_group("Depth")
## How hard the top of the frame sinks into shadow — this is what makes the
## empty headroom recede into "deep dark cavern" instead of "flat empty wall".
@export_range(0.0, 1.0) var top_shadow: float = 0.7
## Fine dust motes drifting through the light. 0 disables.
@export var dust_amount: int = 34
## Slow, larger haze motes on a second depth plane. 0 disables.
@export var haze_amount: int = 9
## Warm tint of the airborne dust; picks up the lantern.
@export var dust_colour: Color = Color(1.0, 0.9, 0.72)

@export_group("Vignette")
## How dark the screen corners get. 0 disables.
@export_range(0.0, 1.0) var vignette_strength: float = 0.55

var _lantern: PointLight2D = null


func _ready() -> void:
	# Deferred: the scene tree is still assembling during _ready, and the
	# modulate/overlays want to sit on the root next to everything else.
	_build.call_deferred()


func _build() -> void:
	var cm: CanvasModulate = CanvasModulate.new()
	cm.color = darkness
	get_parent().add_child(cm)

	# A screen-fixed overlay canvas above the world (0) but below the HUD (5),
	# so the top shadow and vignette never dim the health bar or room counter.
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	if top_shadow > 0.0:
		var top: TextureRect = TextureRect.new()
		top.texture = _top_texture()
		top.anchor_right = 1.0
		top.anchor_bottom = 0.5
		top.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(top)

	if haze_amount > 0:
		layer.add_child(_motes(haze_amount, 46.0, 90.0, 10.0, 0.06))
	if dust_amount > 0:
		layer.add_child(_motes(dust_amount, 2.5, 6.0, 26.0, 0.14))

	if vignette_strength > 0.0:
		var rect: TextureRect = TextureRect.new()
		rect.texture = _vignette_texture()
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(rect)


## The lantern follows the player; resolved lazily per the CLAUDE.md _ready-order
## discipline, and re-attached if the player is ever rebuilt. Once alive it
## flickers — two incommensurate sines, same trick as the hub lights.
func _process(_delta: float) -> void:
	if _lantern != null and is_instance_valid(_lantern):
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		_lantern.energy = lantern_energy * (0.9 + 0.07 * sin(t * 13.0) + 0.05 * sin(t * 29.3))
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	_lantern = PointLight2D.new()
	_lantern.texture = _light_texture()
	_lantern.color = lantern_colour
	_lantern.energy = lantern_energy
	_lantern.texture_scale = lantern_scale
	# At the helmet, not the feet — the light source is the lamp on his head.
	_lantern.position = Vector2(0, -46)
	player.add_child(_lantern)


## A screen-fixed drift of motes covering the viewport. Two calls make two
## parallax planes: small/fast/near dust and big/slow/far haze. Cosmetic, so it
## uses the particle system's own randomness, never the seeded Rng.
func _motes(amount: int, size_min: float, size_max: float, fall: float, alpha: float) -> CPUParticles2D:
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
	p.direction = Vector2(0.4, 1.0)
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
	# A softer falloff than linear: a bright core that fades gently, so the pool
	# has a centre and an edge rather than a hard disc.
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 256
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
