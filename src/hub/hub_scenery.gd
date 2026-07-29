extends Node2D
## The hub's outdoor set: a dusk sky with moon and stars, silhouette ridgelines,
## real world-tileset ground under the walk line, and a tiled rock face the two
## mine mouths bore into. Replaces the old pit-head shell of flat ColorRects —
## the one part of the game that never went through an art pass.
##
## Everything here is VISUAL ONLY: the tile layers run with collision disabled
## (the hub's Geometry StaticBody keeps owning collision, so this stays a pure
## art change), nothing ticks in _physics_process, and nothing touches the
## seeded Rng — star and ridge shapes come from a fixed-seed local generator,
## so the surface looks identical every visit without burning a seeded draw.
##
## Colours are authored PRE-grade: the hub's MineAtmosphere multiplies the whole
## world canvas by a warm (0.72, 0.64, 0.55), so blues here are set brighter
## than the dusk they should read as after the grade.

const TILE: int = 32
## The walk line every marker and prompt in hub.tscn is authored against.
const FLOOR_Y: float = 780.0

## Atlas coords in world_tileset.tres — same stable ids gen_rooms.gd uses.
const SOLID: Vector2i = Vector2i(0, 0)
const SOLID_B: Vector2i = Vector2i(3, 0)
const CRACKED: Vector2i = Vector2i(4, 0)
const MOSSY: Vector2i = Vector2i(5, 0)

@export_group("Sky")
## Top-of-frame night. Reads as deep indigo once the warm hub grade multiplies it.
@export var sky_top: Color = Color(0.07, 0.078, 0.18)
@export var sky_mid: Color = Color(0.17, 0.13, 0.24)
## The ember band sitting right on the horizon — the sun is just gone.
@export var sky_glow: Color = Color(0.42, 0.26, 0.24)
@export var sky_horizon: Color = Color(0.78, 0.47, 0.24)
@export var star_count: int = 44
## Kept ABOVE the gantry beam (y 244): the first framing had the beam slicing
## straight through the moon's disc.
@export var moon_position: Vector2 = Vector2(400, 205)
@export var moon_colour: Color = Color(1.0, 0.97, 0.88)

@export_group("Horizon")
## Far ridge: hazy, close to the sky's own value so it recedes.
@export var far_ridge_colour: Color = Color(0.14, 0.12, 0.19)
## Near ridge: darker, framing the ground line.
@export var near_ridge_colour: Color = Color(0.09, 0.08, 0.11)
## The distant headframe silhouette on the ridge — the rest of the mining
## country this outpost belongs to.
@export var headframe_colour: Color = Color(0.11, 0.095, 0.145)

@export_group("Ground")
## Moss chance on the walk-line lip. Richer than the delve's 30 — the surface
## is the one overgrown place in the game.
@export_range(0, 100) var moss_percent: int = 65

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	# Fixed seed: same sky every visit, zero interaction with the run's seed.
	_rng.seed = 0x5EA5C4
	_build_sky()
	_build_ridges()
	_build_ground()
	_build_rock_face()
	_build_canopy()


## ---------------------------------------------------------------- sky ----

func _build_sky() -> void:
	var sky: TextureRect = TextureRect.new()
	sky.z_index = -100
	sky.position = Vector2(-400, -200)
	sky.size = Vector2(2720, 1000)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.texture = _sky_texture()
	add_child(sky)

	var stars: Node2D = Node2D.new()
	stars.z_index = -99
	add_child(stars)
	for i: int in star_count:
		var star: ColorRect = ColorRect.new()
		var size: float = 3.0 if _rng.randf() > 0.7 else 2.0
		star.size = Vector2(size, size)
		star.position = Vector2(_rng.randf_range(60.0, 1860.0), _rng.randf_range(-40.0, 430.0))
		star.color = Color(1.0, 0.95, 0.85, _rng.randf_range(0.25, 0.85))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.add_child(star)

	var moon: Sprite2D = Sprite2D.new()
	moon.z_index = -98
	moon.texture = _moon_texture()
	moon.position = moon_position
	moon.modulate = moon_colour
	add_child(moon)


## Vertical dusk ramp: night at the top, an ember band right on the horizon.
## The rect spans y -200..800, so the hot stop lands at the 780 walk line.
func _sky_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 0.86, 1.0])
	gradient.colors = PackedColorArray([sky_top, sky_mid, sky_glow, sky_horizon])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 1024
	return texture


## A soft disc with a faint halo: bright core, quick falloff, wide fade.
func _moon_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.52, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 128
	texture.height = 128
	return texture


## ------------------------------------------------------------- horizon ----

func _build_ridges() -> void:
	# Far ridge first (drawn behind), then the darker near ridge over it.
	add_child(_ridge(-90, far_ridge_colour, 645.0, 38.0, 0.0021, 1.7, 20.0, 0.0057, 0.4, 8.0))
	_build_headframe()
	add_child(_ridge(-85, near_ridge_colour, 742.0, 16.0, 0.0034, 2.9, 9.0, 0.0091, 1.1, 5.0))


## One silhouette ridgeline: two incommensurate sines plus jitter, closed well
## below the walk line so the ground tiles cover the seam.
func _ridge(z: int, colour: Color, base_y: float, amp_a: float, freq_a: float,
		phase_a: float, amp_b: float, freq_b: float, phase_b: float, jitter: float) -> Polygon2D:
	var points: PackedVector2Array = PackedVector2Array()
	var x: float = -400.0
	while x <= 2320.0:
		var y: float = base_y \
			+ amp_a * sin(x * freq_a + phase_a) \
			+ amp_b * sin(x * freq_b + phase_b) \
			+ _rng.randf_range(-jitter, jitter)
		points.append(Vector2(x, y))
		x += 64.0
	points.append(Vector2(2320, 830))
	points.append(Vector2(-400, 830))
	var ridge: Polygon2D = Polygon2D.new()
	ridge.z_index = z
	ridge.polygon = points
	ridge.color = colour
	return ridge


## A distant pit headframe on the far ridge, framed in the gap between the
## smithy and the mine wall: A-frame legs, a crossbar, the winding wheel, a
## hoist cable, and a low shed. Pure silhouette — it is scenery-of-scenery.
func _build_headframe() -> void:
	var frame: Node2D = Node2D.new()
	frame.z_index = -89
	frame.position = Vector2(1120, 660)
	add_child(frame)
	# Bases run to +56: the far ridge wobbles as low as ~711 world, so feet at
	# the frame's 660 origin could float against sky. 716 is always buried.
	_silhouette(frame, [Vector2(-28, 56), Vector2(-16, 56), Vector2(2, -136), Vector2(-6, -136)])
	_silhouette(frame, [Vector2(28, 56), Vector2(16, 56), Vector2(-2, -136), Vector2(6, -136)])
	_silhouette(frame, [Vector2(-22, -100), Vector2(22, -100), Vector2(22, -92), Vector2(-22, -92)])
	_silhouette(frame, [Vector2(-1, -140), Vector2(1, -140), Vector2(1, 56), Vector2(-1, 56)])
	_silhouette(frame, _wheel_points(Vector2(0, -152), 18.0))
	_silhouette(frame, [Vector2(30, 8), Vector2(94, 8), Vector2(94, 56), Vector2(30, 56)])


func _silhouette(parent: Node2D, points: Array[Vector2]) -> void:
	var poly: Polygon2D = Polygon2D.new()
	poly.polygon = PackedVector2Array(points)
	poly.color = headframe_colour
	parent.add_child(poly)


func _wheel_points(centre: Vector2, radius: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0
		points.append(centre + Vector2(cos(a), sin(a)) * radius)
	return points


## -------------------------------------------------------------- ground ----

## The ground the outpost stands on: a mossy walk-line lip with the delve's own
## shaded rock below it. Collision stays on the Geometry StaticBody — this
## layer only LOOKS like the delve's floor.
func _build_ground() -> void:
	var layer: TileMapLayer = _tile_layer(-50, Vector2(0, FLOOR_Y))
	for y: int in range(0, 11):
		for x: int in range(-2, 63):
			var tile: Vector2i = _rock(x, y)
			if y == 0 and _hash(x, y, 3) % 100 < moss_percent:
				tile = MOSSY
			layer.set_cell(Vector2i(x, y), 0, tile)


## The rock face the mine bores into: the hub's right end rises in mossy-lipped
## terraces from the walk line, and both mouth arts sit carved into it. Before
## the Threshold opens, the Hollow's spot really is solid rock — the reveal the
## GDD asks for comes free.
func _build_rock_face() -> void:
	var layer: TileMapLayer = _tile_layer(-60, Vector2.ZERO)
	for x: int in range(39, 63):
		var top: int = 17 if x < 43 else (16 if x < 48 else 15)
		for y: int in range(top, 25):
			var tile: Vector2i = MOSSY if y == top and _hash(x, y, 4) % 100 < 40 else _rock(x, y)
			layer.set_cell(Vector2i(x, y), 0, tile)


func _tile_layer(z: int, at: Vector2) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.z_index = z
	layer.position = at
	layer.tile_set = load("res://src/rooms/world_tileset.tres") as TileSet
	# Visual only: hub collision belongs to the Geometry StaticBody in hub.tscn.
	layer.collision_enabled = false
	add_child(layer)
	return layer


## Same variant mix as gen_rooms._rock, minus the ore veins: the surface is
## mined out — that is the whole reason anyone goes down.
func _rock(x: int, y: int) -> Vector2i:
	var roll: int = _hash(x, y, 1) % 100
	if roll < 22:
		return SOLID_B
	if roll < 34:
		return CRACKED
	return SOLID


func _hash(x: int, y: int, salt: int) -> int:
	var n: int = x * 374761393 + y * 668265263 + salt * 2246822519
	n = (n ^ (n >> 13)) * 1274126177
	return absi(n ^ (n >> 16))


## -------------------------------------------------------------- canopy ----

const _WOOD: Color = Color(0.32, 0.22, 0.13)
const _WOOD_LIT: Color = Color(0.47, 0.34, 0.2)
const _WOOD_DARK: Color = Color(0.18, 0.12, 0.07)

## The pit-head gantry: the open-air timber frame the hanging lanterns drop
## from. The old shell hid its posts against a rock ceiling; under a real sky
## they run full height to the ground, so the frame reads as a built structure
## instead of floating timber.
func _build_canopy() -> void:
	var canopy: Node2D = Node2D.new()
	canopy.z_index = -50
	add_child(canopy)
	_canopy_rect(canopy, Vector2(120, 244), Vector2(1680, 24), _WOOD_DARK)
	_canopy_rect(canopy, Vector2(120, 244), Vector2(1680, 6), _WOOD_LIT)
	for px: float in [180.0, 720.0, 1260.0, 1740.0]:
		_canopy_rect(canopy, Vector2(px, 268), Vector2(16, FLOOR_Y - 268.0), _WOOD_DARK)
		_canopy_rect(canopy, Vector2(px, 268), Vector2(4, FLOOR_Y - 268.0), _WOOD)


func _canopy_rect(parent: Node2D, at: Vector2, size: Vector2, colour: Color) -> void:
	var rect: ColorRect = ColorRect.new()
	rect.position = at
	rect.size = size
	rect.color = colour
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
