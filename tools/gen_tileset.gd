extends SceneTree
## Generates the mine tile sheet and its TileSet.
##
## Run: godot --headless --path . --script tools/gen_tileset.gd
## On a clean checkout run it TWICE — the PNG must be imported before the TileSet
## can reference it.
##
## Setting is locked (GDD, 2026-07-15): a collapsing mine. The palette says it:
## cold dark rock, warm lantern light on every upward face, amber for ore because
## amber is what you are down here for, and timber for the platforms because a
## mine's walkways are propped, not poured.
##
## Still generated rather than drawn. That is not laziness — it keeps the tiles
## reproducible and tweakable by editing numbers, and the M9 art pass can replace
## the PNG without touching a line of game code.
##
## Tiles:
##   0 SOLID    — rock. Collides from every side.
##   1 ONE_WAY  — timber walkway. Collides only from above; you jump up through it.
##   2 ORE      — rock with a vein in it. Same collision as SOLID; it exists to
##                break up big walls and to say "there is value in this rock".

const TILE: int = 32
const OUT_TEXTURE: String = "res://assets/tiles/tiles.png"
const OUT_TILESET: String = "res://src/rooms/world_tileset.tres"

const ROCK_DEEP: Color = Color(0.13, 0.11, 0.10)
const ROCK_BODY: Color = Color(0.22, 0.19, 0.17)
const ROCK_LIT: Color = Color(0.44, 0.35, 0.26)
const ROCK_LIP: Color = Color(0.58, 0.47, 0.34)
const TIMBER: Color = Color(0.42, 0.29, 0.17)
const TIMBER_LIT: Color = Color(0.62, 0.45, 0.26)
const TIMBER_DARK: Color = Color(0.24, 0.16, 0.10)
const ORE: Color = Color(0.86, 0.62, 0.22)
const ORE_HOT: Color = Color(1.0, 0.82, 0.42)


## Cheap deterministic hash. Not from Rng: this is authoring a texture, not
## gameplay, so it must never touch the seeded service.
func _noise(x: int, y: int, salt: int) -> float:
	var n: int = (x * 374761393 + y * 668265263 + salt * 1274126177)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


func _rock_pixel(x: int, y: int, salt: int) -> Color:
	var body: Color = ROCK_BODY
	# Grain, so a wall of these does not read as one flat slab.
	var n: float = _noise(x, y, salt)
	if n > 0.86:
		body = body.lightened(0.10)
	elif n < 0.16:
		body = body.darkened(0.12)
	# Lantern light falls on upward faces. This is the whole read: which surface
	# can I stand on.
	if y < 3:
		body = ROCK_LIP
	elif y < 6:
		body = ROCK_LIT.lerp(ROCK_BODY, float(y - 3) / 3.0)
	if y == TILE - 1 or x == TILE - 1:
		body = ROCK_DEEP
	if x == 0 and y > 3:
		body = body.darkened(0.08)
	return body


func _make_texture() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/tiles")
	var image: Image = Image.create(TILE * 3, TILE, false, Image.FORMAT_RGBA8)

	# --- Tile 0: solid rock.
	for x: int in TILE:
		for y: int in TILE:
			image.set_pixel(x, y, _rock_pixel(x, y, 1))

	# --- Tile 1: timber walkway, one-way. Deliberately reads as a plank with air
	# under it, because that is exactly how it behaves.
	for x: int in TILE:
		for y: int in TILE:
			var colour: Color = Color(0, 0, 0, 0)
			if y < 9:
				colour = TIMBER
				if y < 2:
					colour = TIMBER_LIT          # lit top: land here
				elif y >= 7:
					colour = TIMBER_DARK         # underside
				# Plank seams and grain.
				if x % 8 == 0:
					colour = colour.darkened(0.35)
				elif _noise(x, y, 7) > 0.9:
					colour = colour.lightened(0.08)
			image.set_pixel(TILE + x, y, colour)

	# --- Tile 2: rock with an ore vein. Same collision as rock.
	for x: int in TILE:
		for y: int in TILE:
			var colour: Color = _rock_pixel(x, y, 3)
			# A rough diagonal seam with a couple of blobs on it.
			var on_vein: bool = absf(float(y) - (6.0 + float(x) * 0.55)) < 2.2
			var blob: bool = _noise(x / 5, y / 5, 11) > 0.72
			if on_vein and y > 5 and blob:
				colour = ORE
				if _noise(x, y, 13) > 0.6:
					colour = ORE_HOT
			image.set_pixel(TILE * 2 + x, y, colour)

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

	source.create_tile(Vector2i(0, 0))
	var solid: TileData = source.get_tile_data(Vector2i(0, 0), 0)
	solid.add_collision_polygon(0)
	solid.set_collision_polygon_points(0, 0, full)

	source.create_tile(Vector2i(1, 0))
	var one_way: TileData = source.get_tile_data(Vector2i(1, 0), 0)
	one_way.add_collision_polygon(0)
	one_way.set_collision_polygon_points(0, 0, plank)
	one_way.set_collision_polygon_one_way(0, 0, true)

	source.create_tile(Vector2i(2, 0))
	var ore: TileData = source.get_tile_data(Vector2i(2, 0), 0)
	ore.add_collision_polygon(0)
	ore.set_collision_polygon_points(0, 0, full)

	var err: int = ResourceSaver.save(tile_set, OUT_TILESET)
	print("tileset: %s (err=%d)  tiles=%d" % [OUT_TILESET, err, source.get_tiles_count()])


func _init() -> void:
	_make_texture()
	_make_tileset()
	quit()
