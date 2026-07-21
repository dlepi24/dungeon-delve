extends SceneTree
## Generates the mine tile sheet and its TileSet. (Art-pass v3, 2026-07-21.)
##
## Run: godot --headless --path . --script tools/gen_tileset.gd
## On a clean checkout run it TWICE — the PNG must be imported before the TileSet
## can reference it.
##
## Setting is locked (GDD, 2026-07-15): a collapsing mine. v3 renders BIG
## READABLE SHAPES instead of per-pixel speckle: rock is fractured chunks
## (jittered Voronoi facets) with beveled light and dark crevices, ore is
## faceted amber crystal inside a rimmed seam, timber has bevels + wavy grain.
## One global style rule everywhere: warm lantern light from the upper-left,
## cool blue shadow below — that is what makes the set cohesive.
##
## All noise is 32-bit-masked and lattice-wrapped so (a) walls tile seamlessly
## and (b) the browser preview tool reproduces the bake bit-for-bit.
##
## ATLAS — ids 0..2 keep their coords; 3..9 are NEW and need the room
## generator / autotiling to place them (developer wiring):
##   0 SOLID      — rock. Collides from every side.               (stable id)
##   1 ONE_WAY    — timber walkway. Collides only from above.     (stable id)
##   2 ORE        — rock with a crystal vein. Collides as SOLID.  (stable id)
##   3 SOLID_B    — rock, re-salted chunks (mix in to break tiling)
##   4 CRACKED    — rock with a crack seam (visual only, full collision)
##   5 MOSSY      — moss clumps on the lit lip
##   6 ORE_RICH   — two seams, wider band (deep rooms / heat)
##   7 ONE_WAY_B  — worn walkway: chipped planks, moss at the ends
##   8 BACKDROP   — dim cool rock, NO collision. Fill the WHOLE room interior
##                  with it on a layer behind the play tiles — the void must
##                  never show. (See Tile Set Preview mock room.)
##   9 BEAM       — timber support post, NO collision. Stack vertically under
##                  walkways / against walls; iron collar at each tile top.

const TILE: int = 32
const OUT_TEXTURE: String = "res://assets/tiles/tiles.png"
const OUT_TILESET: String = "res://src/rooms/world_tileset.tres"

const ROCK_DEEP: Color = Color(0.13, 0.11, 0.10)
const ROCK_BODY: Color = Color(0.22, 0.19, 0.17)
const ROCK_LIT: Color = Color(0.44, 0.35, 0.26)
const TIMBER: Color = Color(0.42, 0.29, 0.17)
const ORE: Color = Color(0.86, 0.62, 0.22)
const ORE_HOT: Color = Color(1.0, 0.82, 0.42)
const ORE_RIM: Color = Color(0.38, 0.26, 0.12)
const MOSS: Color = Color(0.30, 0.42, 0.22)
const MOSS_LIT: Color = Color(0.44, 0.56, 0.28)
const IRON: Color = Color(0.30, 0.31, 0.35)
const WARM: Color = Color(0.98, 0.80, 0.52)   # lantern light
const COOL: Color = Color(0.07, 0.07, 0.11)   # cave shadow


## Cheap deterministic hash, 32-bit ops only (matches the JS preview exactly).
func _noise(x: int, y: int, salt: int) -> float:
	var n: int = (x * 374761393 + y * 668265263 + salt * 1274126177) & 0xFFFFFFFF
	n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


func _h2(x: int, y: int, salt: int, wrap: int) -> float:
	if wrap > 0:
		x = ((x % wrap) + wrap) % wrap
		y = ((y % wrap) + wrap) % wrap
	return _noise(x, y, salt)


## Value noise: smoothstep-bilinear over a lattice, wrapped over the tile.
func _vnoise(x: int, y: int, salt: int, cell: int = 8) -> float:
	var wrap: int = TILE / cell
	var gx: int = int(floor(float(x) / float(cell)))
	var gy: int = int(floor(float(y) / float(cell)))
	var fx: float = float(x % cell) / float(cell)
	var fy: float = float(y % cell) / float(cell)
	var sx: float = fx * fx * (3.0 - 2.0 * fx)
	var sy: float = fy * fy * (3.0 - 2.0 * fy)
	var v00: float = _h2(gx, gy, salt, wrap)
	var v10: float = _h2(gx + 1, gy, salt, wrap)
	var v01: float = _h2(gx, gy + 1, salt, wrap)
	var v11: float = _h2(gx + 1, gy + 1, salt, wrap)
	return (v00 * (1.0 - sx) + v10 * sx) * (1.0 - sy) + (v01 * (1.0 - sx) + v11 * sx) * sy


## Voronoi over a jittered grid, wrapped. Returns [f1, f2, seed_x, seed_y, id].
func _voro(x: int, y: int, salt: int, cell: int = 10) -> Array:
	var wrap_i: int = int(ceil(float(TILE) / float(cell)))
	var gx: int = int(floor(float(x) / float(cell)))
	var gy: int = int(floor(float(y) / float(cell)))
	var f1: float = 1e9
	var f2: float = 1e9
	var sx: float = 0.0
	var sy: float = 0.0
	var id: int = 0
	for j: int in range(-1, 2):
		for i: int in range(-1, 2):
			var cx: int = gx + i
			var cy: int = gy + j
			var wcx: int = ((cx % wrap_i) + wrap_i) % wrap_i
			var wcy: int = ((cy % wrap_i) + wrap_i) % wrap_i
			var px: float = float(cx * cell) + (0.15 + 0.7 * _noise(wcx, wcy, salt)) * float(cell)
			var py: float = float(cy * cell) + (0.15 + 0.7 * _noise(wcx, wcy, salt + 500)) * float(cell)
			var d: float = Vector2(float(x) + 0.5 - px, float(y) + 0.5 - py).length()
			if d < f1:
				f2 = f1
				f1 = d
				sx = px
				sy = py
				id = wcx * 97 + wcy
			elif d < f2:
				f2 = d
	return [f1, f2, sx, sy, id]


## THE style rule: one light for the whole set. l in [-1, 1]; positive pulls
## toward warm lantern light, negative toward cool cave shadow.
func _shade(base: Color, l: float) -> Color:
	l = clampf(l, -1.0, 1.0)
	if l >= 0.0:
		return base.lerp(WARM, l * 0.55)
	return base.lerp(COOL, -l * 0.75)


func _rock_pixel(x: int, y: int, salt: int, cracked: bool = false,
		mossy: bool = false, backdrop: bool = false) -> Color:
	var v: Array = _voro(x, y, salt, 10)
	var edge: float = v[1] - v[0]
	var cv: float = _noise(v[4] & 0xFFFF, (v[4] >> 4) & 0xFFFF, salt + 7)
	var base: Color = ROCK_BODY.lerp(ROCK_LIT, cv * 0.35)
	var nx: float = (float(x) + 0.5 - v[2]) / 6.0
	var ny: float = (float(y) + 0.5 - v[3]) / 6.0
	var l: float = -nx * 0.45 - ny * 0.8                     # facet bevel
	l += (_vnoise(x, y, salt + 31) - 0.5) * 0.35             # large-scale variation
	if y < 7:                                                # lantern on the top
		l += float(7 - y) / 7.0 * (1.0 if y < 2 else 0.55)
	if y > 20:                                               # depth cools
		l -= float(y - 20) / 11.0 * 0.45
	if backdrop:
		l = l * 0.3 - 0.55
		if y < 7:
			l -= float(7 - y) / 7.0 * 0.3
	var body: Color = _shade(base, l)
	if edge < 1.3:                                           # crevices
		body = body.lerp(ROCK_DEEP, 0.5 if backdrop else 0.8)
	elif edge < 2.2:
		body = body.lerp(ROCK_DEEP, 0.25 if backdrop else 0.4)
	elif not backdrop and ny < -0.3 and _noise(x, y, salt + 41) > 0.94:
		body = body.lightened(0.25)                          # glints on lit tops
	if cracked:
		var jag: float = (_noise(x / 2, 0, salt + 51) - 0.5) * 3.0
		var d: float = absf(float(y) - (10.0 + float(x) * 0.35 + jag))
		var d2: float = 99.0
		if x > 14 and x < 24:
			d2 = absf(float(y) - (14.0 + float(x - 14) * 1.2 + jag))
		if minf(d, d2) < 0.9:
			body = ROCK_DEEP.darkened(0.3)
		elif minf(d, d2) < 1.8:
			body = body.lerp(ROCK_DEEP, 0.45)
	if mossy:
		var fringe: int = 2 + int(_vnoise(x, 0, salt + 61, 4) * 5.0)
		var clump: bool = _vnoise(x, y, salt + 66, 4) > 0.55 and y < fringe + 5
		if y < fringe or clump:
			var ml: float = 0.5 if y < 2 \
				else (0.2 if clump and _noise(x, y, salt + 67) > 0.6 else -0.2)
			body = _shade(MOSS_LIT if y < 2 else MOSS, ml)
	return body


func _timber_pixel(x: int, y: int, worn: bool) -> Color:
	if y >= 9:
		return Color(0, 0, 0, 0)
	var px: int = x % 8
	if worn and (y == 0 or y == 8) and (px == 1 or px == 7) \
			and _noise(x / 8, y, 73) > 0.5:
		return Color(0, 0, 0, 0)                             # chipped corners
	var base: Color = TIMBER
	var grain: float = _vnoise(x * 2, y * 5, 7, 8)           # wavy streaks
	if grain > 0.62:
		base = base.darkened(0.14)
	elif grain < 0.3:
		base = base.lightened(0.08)
	var l: float = 0.0
	if y == 0:
		l = 0.75                                             # lit top: land here
	elif y == 1:
		l = 0.45
	elif y >= 7:
		l = -0.6                                             # underside
	elif y == 6:
		l = -0.25
	if px == 1:
		l += 0.2                                             # plank edge bevel
	if px == 7:
		l -= 0.2
	var colour: Color = _shade(base, l)
	if px == 0:
		colour = colour.lerp(ROCK_DEEP, 0.75)                # seam
	if px == 4 and (y == 2 or y == 6):
		colour = IRON.lightened(0.2) if y == 2 else IRON     # nails
	if worn:
		if _noise(x, y, 71) > 0.9:
			colour = colour.darkened(0.3)
		if y < 2 and px >= 5 and _noise(x / 3, 0, 72) > 0.5:
			colour = _shade(MOSS, 0.3 if y == 0 else -0.1)
	return colour


func _beam_pixel(x: int, y: int) -> Color:
	if x < 11 or x > 20:
		return Color(0, 0, 0, 0)
	var base: Color = TIMBER
	var grain: float = _vnoise(x * 5, y * 2, 81, 8)
	if grain > 0.62:
		base = base.darkened(0.14)
	elif grain < 0.3:
		base = base.lightened(0.08)
	var l: float = 0.0
	if x == 12:
		l = 0.5                                              # lit left face
	elif x == 13:
		l = 0.25
	elif x == 19:
		l = -0.5
	elif x == 18:
		l = -0.2
	var colour: Color = _shade(base, l)
	if x == 11 or x == 20:
		colour = colour.lerp(ROCK_DEEP, 0.7)                 # silhouette
	if y < 3:                                                # iron collar + bolts
		colour = IRON.lightened(0.25) if y == 0 \
			else (IRON if y == 1 else IRON.darkened(0.35))
		if x == 11 or x == 20:
			colour = IRON.darkened(0.55)
		if y == 1 and (x == 13 or x == 18):
			colour = IRON.lightened(0.5)
	return colour


## Distance to the ore seam, wobbled by value noise so it wanders.
func _vein_dist(x: int, y: int, salt: int, rich: bool) -> float:
	var wob: float = (_vnoise(x, y, salt + 90, 8) - 0.5) * 6.0
	var d_a: float = absf(float(y) - (9.0 + float(x) * 0.5 + wob))
	if not rich:
		return d_a
	var d_b: float = absf(float(y) - (24.0 - float(x) * 0.55 + wob))
	return minf(d_a, d_b)


func _ore_pixel(x: int, y: int, salt: int, rich: bool) -> Color:
	var d: float = _vein_dist(x, y, salt, rich)
	var band: float = 3.8 if rich else 3.4
	if d >= band:
		return _rock_pixel(x, y, salt)
	var v: Array = _voro(x, y, salt + 200, 5)                # faceted crystals
	var in_crystal: bool = d < band - 1.2 and v[1] - v[0] > 1.0
	if not in_crystal:
		var body: Color = _rock_pixel(x, y, salt)            # rimmed seam rock
		return body.lerp(ORE_RIM, 0.85 if d < band - 0.8 else 0.45)
	var cv: float = _noise(v[4] & 0xFFFF, (v[4] >> 4) & 0xFFFF, salt + 9)
	var base: Color = ORE.lerp(ORE_HOT, cv * 0.7)
	var nx: float = (float(x) + 0.5 - v[2]) / 3.0
	var ny: float = (float(y) + 0.5 - v[3]) / 3.0
	var body: Color = _shade(base, -nx * 0.5 - ny * 0.85 + 0.15)
	if ny < -0.4 and _noise(x, y, salt + 43) > 0.9:
		body = Color(1.0, 0.95, 0.75)                        # facet sparkle
	return body


func _make_texture() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/tiles")
	const COUNT: int = 10
	var image: Image = Image.create(TILE * COUNT, TILE, false, Image.FORMAT_RGBA8)
	for x: int in TILE:
		for y: int in TILE:
			image.set_pixel(x, y, _rock_pixel(x, y, 1))                        # 0 solid
			image.set_pixel(TILE + x, y, _timber_pixel(x, y, false))           # 1 one-way
			image.set_pixel(TILE * 2 + x, y, _ore_pixel(x, y, 3, false))       # 2 ore
			image.set_pixel(TILE * 3 + x, y, _rock_pixel(x, y, 5))             # 3 solid B
			image.set_pixel(TILE * 4 + x, y, _rock_pixel(x, y, 9, true))       # 4 cracked
			image.set_pixel(TILE * 5 + x, y, _rock_pixel(x, y, 15, false, true))  # 5 mossy
			image.set_pixel(TILE * 6 + x, y, _ore_pixel(x, y, 17, true))       # 6 rich ore
			image.set_pixel(TILE * 7 + x, y, _timber_pixel(x, y, true))        # 7 worn walkway
			image.set_pixel(TILE * 8 + x, y, _rock_pixel(x, y, 23, false, false, true))  # 8 backdrop
			image.set_pixel(TILE * 9 + x, y, _beam_pixel(x, y))                # 9 beam
	var err: int = image.save_png(OUT_TEXTURE)
	print("texture: %s (err=%d)" % [OUT_TEXTURE, err])


func _make_tileset() -> void:
	var texture: Texture2D = load(OUT_TEXTURE) as Texture2D
	if texture == null:
		printerr("texture not imported yet — run this script twice on a clean checkout")
		quit(1)
		return

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer(0)
	tile_set.set_physics_layer_collision_layer(0, CollisionLayers.WORLD)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	# Add the source BEFORE creating tiles: tiles inherit physics layers at
	# creation, and the other order fails with "physics.size() = 0".
	tile_set.add_source(source, 0)

	var half: float = float(TILE) * 0.5
	var full: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	# The one-way shape matches the drawn plank, not the whole cell.
	var plank: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + 9.0), Vector2(-half, -half + 9.0),
	])

	# coord x -> collision kind. "none" tiles are decor: backdrop + beam.
	var kinds: Array[String] = [
		"full", "plank", "full",           # 0..2 stable ids
		"full", "full", "full", "full",    # 3 solid B, 4 cracked, 5 mossy, 6 rich ore
		"plank",                           # 7 worn walkway
		"none", "none",                    # 8 backdrop, 9 beam
	]
	for i: int in kinds.size():
		source.create_tile(Vector2i(i, 0))
		if kinds[i] == "none":
			continue
		var data: TileData = source.get_tile_data(Vector2i(i, 0), 0)
		data.add_collision_polygon(0)
		if kinds[i] == "plank":
			data.set_collision_polygon_points(0, 0, plank)
			data.set_collision_polygon_one_way(0, 0, true)
		else:
			data.set_collision_polygon_points(0, 0, full)

	var err: int = ResourceSaver.save(tile_set, OUT_TILESET)
	print("tileset: %s (err=%d)  tiles=%d" % [OUT_TILESET, err, source.get_tiles_count()])


func _init() -> void:
	_make_texture()
	_make_tileset()
	quit()
