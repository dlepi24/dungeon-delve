extends SceneTree
## One-shot generator for the placeholder tile sheet and its TileSet.
##
## Run: godot --headless --path . --script tools/gen_tileset.gd
##
## Generated rather than drawn, for the same reason the SFX are synthesised:
## reproducible, dependency-free, and unmistakably placeholder. Art is permitted
## after the M2 gate but still not required, and gray-box stays the default until
## it stops carrying the design.
##
## Two tiles, and the second one matters:
##   SOLID    — collides from every side. Walls, floors, ceilings.
##   ONE_WAY  — collides only from above. You jump up THROUGH it and land on top.
##
## ONE_WAY exists because of the constraint M3 hit: a platform low enough to jump
## onto from the floor leaves less headroom than the player's own body, so solid
## reachable platforms are steps that anything walking underneath gets stuck
## inside. One-way platforms have no such problem — you pass through from below —
## so they are how these rooms get vertical without trapping enemies.

const TILE: int = 32
const OUT_TEXTURE: String = "res://assets/tiles/tiles.png"
const OUT_TILESET: String = "res://src/rooms/world_tileset.tres"


func _make_texture() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/tiles")
	var image: Image = Image.create(TILE * 2, TILE, false, Image.FORMAT_RGBA8)

	# Tile 0: solid. Body with a lighter top edge so surfaces read at a glance.
	for x: int in TILE:
		for y: int in TILE:
			var body: Color = Color(0.26, 0.27, 0.33)
			if y < 3:
				body = Color(0.42, 0.45, 0.54)
			elif x == 0 or x == TILE - 1 or y == TILE - 1:
				body = Color(0.19, 0.2, 0.25)
			image.set_pixel(x, y, body)

	# Tile 1: one-way platform. Deliberately reads as a thin ledge with empty
	# space beneath, because that is exactly how it behaves.
	for x: int in TILE:
		for y: int in TILE:
			var colour: Color = Color(0, 0, 0, 0)
			if y < 8:
				colour = Color(0.5, 0.54, 0.62)
				if y < 2:
					colour = Color(0.66, 0.71, 0.8)
			image.set_pixel(TILE + x, y, colour)

	var err: int = image.save_png(OUT_TEXTURE)
	print("texture: %s (err=%d)" % [OUT_TEXTURE, err])


func _make_tileset() -> void:
	var texture: Texture2D = load(OUT_TEXTURE) as Texture2D
	if texture == null:
		printerr("texture not imported yet — run this script twice, or import first")
		return

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)

	# One physics layer, on World. Named via the constant, never a raw number.
	tile_set.add_physics_layer(0)
	tile_set.set_physics_layer_collision_layer(0, CollisionLayers.WORLD)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	# Add the source to the TileSet BEFORE creating any tiles. Tiles inherit the
	# physics layers from their owning TileSet at creation; do this after and
	# add_collision_polygon fails with "physics.size() = 0".
	tile_set.add_source(source, 0)

	var half: float = float(TILE) * 0.5
	var full: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	# The one-way shape is only the top 8 px, matching what is drawn.
	var ledge: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + 8.0), Vector2(-half, -half + 8.0),
	])

	source.create_tile(Vector2i(0, 0))
	var solid: TileData = source.get_tile_data(Vector2i(0, 0), 0)
	solid.add_collision_polygon(0)
	solid.set_collision_polygon_points(0, 0, full)

	source.create_tile(Vector2i(1, 0))
	var one_way: TileData = source.get_tile_data(Vector2i(1, 0), 0)
	one_way.add_collision_polygon(0)
	one_way.set_collision_polygon_points(0, 0, ledge)
	one_way.set_collision_polygon_one_way(0, 0, true)

	var err: int = ResourceSaver.save(tile_set, OUT_TILESET)
	print("tileset: %s (err=%d)  sources=%d" % [OUT_TILESET, err, tile_set.get_source_count()])


func _init() -> void:
	_make_texture()
	_make_tileset()
	quit()
