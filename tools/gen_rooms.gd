extends Node
## Builds room .tscn files from the ASCII maps in tools/rooms/room_layouts.gd.
##
## Run: godot --headless --path . res://tools/gen_rooms.tscn
##
## A SCENE, not --script: it loads room.gd, which depends on Player, which
## references the Events autoload — and --script mode never registers autoloads,
## so it fails with "Identifier not found: Events". Same trap as tools/check.tscn.
##
## Validates before it builds, and refuses to emit a broken room. Hand-authored
## ASCII is exactly where typos hide — a wrong-width row or a stray character
## would otherwise become a silently misaligned level, which is the kind of bug
## you only find by walking into it.

const TILE: int = 32
const SOLID: Vector2i = Vector2i(0, 0)
const ONE_WAY: Vector2i = Vector2i(1, 0)
const ORE: Vector2i = Vector2i(2, 0)
# Tileset art-pass v3 (tools/gen_tileset.gd): cosmetic variants and dressing.
# All four collide exactly like their base tile (or not at all) — the TileSet
# defines it; rooms only choose which face to show.
const SOLID_B: Vector2i = Vector2i(3, 0)
const CRACKED: Vector2i = Vector2i(4, 0)
const MOSSY: Vector2i = Vector2i(5, 0)
const ONE_WAY_B: Vector2i = Vector2i(7, 0)
const BACKDROP: Vector2i = Vector2i(8, 0)
const BEAM: Vector2i = Vector2i(9, 0)
## Roughly one rock tile in this many becomes an ore vein. Purely visual — ore
## collides exactly like rock — so it is scattered deterministically from the
## tile's own coordinates rather than from the seeded RNG. Two players on one
## seed see the same veins because the maths is the same, not because a stream
## was consumed; keeping it out of Rng means it can never shift layout draws.
const ORE_EVERY: int = 9
## How far the backdrop spills past the room border, in tiles. Sized for the
## worst case the camera can show beyond the box: an ultrawide viewport on the
## standard 18-row room leaves ~6 tiles of overshoot per side at zoom 1.45.
const BACKDROP_PAD: int = 8
const OUT_DIR: String = "res://src/rooms/delve"
const TILESET: String = "res://src/rooms/world_tileset.tres"

const LEGEND: String = ".#=PXgbdESCvohF"

## The player's jump rises 109 px = 3.4 tiles, so a 3-tile step lands and a
## 4-tile step is impossible. Every platform must be within this of a surface
## below it, or it is scenery you can only look at. Shipped 6 rooms where every
## platform was exactly one tile too high; nothing errored, they were just
## unreachable. Hence this check.
const MAX_STEP_ROWS: int = 3
## Horizontal reach during a jump is ~218 px = 6.8 tiles. Being generous here is
## fine: the point is to catch platforms with nothing beneath them at all.
const REACH_COLS: int = 6

var _errors: PackedStringArray = []


func _is_surface(rows: Array, x: int, y: int) -> bool:
	# Below the layout is the generated border floor: always solid.
	if y >= rows.size():
		return true
	if y < 0 or x < 0 or x >= (rows[0] as String).length():
		return false
	var c: String = rows[y][x]
	return c == "#" or c == "="


## Contiguous horizontal spans of surface. A span is ONE platform: land anywhere
## on it and you can walk the length of it, so reachability is a property of the
## whole run, not of each tile. Checking tiles individually flags the far end of a
## perfectly good platform.
func _runs(rows: Array) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y: int in rows.size():
		var width: int = (rows[0] as String).length()
		var x: int = 0
		while x < width:
			if not _is_surface(rows, x, y):
				x += 1
				continue
			var start: int = x
			while x < width and _is_surface(rows, x, y):
				x += 1
			# (row, first column, last column)
			out.append(Vector3i(y, start, x - 1))
	return out


## Which platforms can actually be stood on, worked out from the ground up.
##
## Seeds with runs resting on solid ground, then repeatedly marks any run within
## one jump of something already reachable, until nothing new is found. A platform
## reachable only from another unreachable platform stays unreachable — which a
## single pass would miss.
func _reachable_runs(rows: Array) -> Dictionary[Vector3i, bool]:
	var runs: Array[Vector3i] = _runs(rows)
	var reach: Dictionary[Vector3i, bool] = {}
	for run: Vector3i in runs:
		if run.x == rows.size() - 1:
			reach[run] = true
			continue
		for c: int in range(run.y, run.z + 1):
			if _is_surface(rows, c, run.x + 1):
				reach[run] = true
				break

	var changed: bool = true
	while changed:
		changed = false
		for run: Vector3i in runs:
			if reach.has(run):
				continue
			for other: Vector3i in reach.keys():
				var rise: int = other.x - run.x
				if rise < 1 or rise > MAX_STEP_ROWS:
					continue
				# Do the spans come within a jump's horizontal reach of each other?
				if other.y - REACH_COLS <= run.z and run.y <= other.z + REACH_COLS:
					reach[run] = true
					changed = true
					break
	return reach


func _check_reachability(id: StringName, rows: Array) -> bool:
	var reach: Dictionary[Vector3i, bool] = _reachable_runs(rows)
	var ok: bool = true
	for run: Vector3i in _runs(rows):
		if reach.has(run):
			continue
		var has_platform: bool = false
		for c: int in range(run.y, run.z + 1):
			if rows[run.x][c] == "=":
				has_platform = true
				break
		if has_platform:
			_errors.append("%s: platform at row %d cols %d-%d cannot be reached (no standable run within %d rows and %d cols below)" % [id, run.x, run.y, run.z, MAX_STEP_ROWS, REACH_COLS])
			ok = false

	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] != "X" and row[x] != "P":
				continue
			if y + 1 >= rows.size():
				continue
			if not _is_surface(rows, x, y + 1):
				_errors.append("%s: the %s marker at row %d col %d has nothing beneath it" % [id, row[x], y, x])
				ok = false
	return ok


func _validate(id: StringName, rows: Array) -> bool:
	var ok: bool = true
	# Height is per-room now too (a chasm can plunge); the standard 18 is the
	# MINIMUM so the camera's vertical framing always has a full room to hold.
	if rows.size() < RoomLayouts.HEIGHT:
		_errors.append("%s: has %d rows, expected at least %d" % [id, rows.size(), RoomLayouts.HEIGHT])
		ok = false
	var entries: int = 0
	var exits: int = 0
	for y: int in rows.size():
		var row: String = rows[y]
		# Width is per-room (a hall can be double-wide); it just has to be
		# consistent, sane, and every row the same.
		if row.length() != (rows[0] as String).length() or row.length() < 40:
			_errors.append("%s row %d: width %d, expected %d" % [id, y, row.length(), RoomLayouts.WIDTH])
			ok = false
		for x: int in row.length():
			var c: String = row[x]
			if not LEGEND.contains(c):
				_errors.append("%s row %d col %d: unknown character '%s' (legend is %s)" % [id, y, x, c, LEGEND])
				ok = false
			if c == "P":
				entries += 1
			elif c == "X":
				exits += 1
	if entries != 1:
		_errors.append("%s: has %d entries (P), expected exactly 1" % [id, entries])
		ok = false
	if exits != 1:
		_errors.append("%s: has %d exits (X), expected exactly 1" % [id, exits])
		ok = false
	return ok


## Deterministic per-cell hash for cosmetic variety. NOT the seeded Rng service
## (same reasoning as ORE_EVERY): bake-time cosmetics must never consume
## gameplay streams, and identical layouts must always bake identical rooms.
func _hash(x: int, y: int, salt: int) -> int:
	var n: int = x * 374761393 + y * 668265263 + salt * 2246822519
	n = (n ^ (n >> 13)) * 1274126177
	return absi(n ^ (n >> 16))


## Rock, with a vein every so often, and the v3 variants mixed in so big walls
## stop reading as wallpaper. Deterministic in the cell coordinates.
func _rock(x: int, y: int) -> Vector2i:
	if (x * 7 + y * 13) % ORE_EVERY == 0:
		return ORE
	var roll: int = _hash(x, y, 1) % 100
	if roll < 22:
		return SOLID_B
	if roll < 34:
		return CRACKED
	return SOLID


## Walkway plank, occasionally the worn variant.
func _walkway(cell: Vector2i) -> Vector2i:
	return ONE_WAY_B if _hash(cell.x, cell.y, 2) % 100 < 35 else ONE_WAY


## A vertical timber post from the walkway down to the first play tile.
## Capped: a drop deeper than 10 tiles (a chasm) stays unpropped.
##
## The post starts in the walkway's OWN cell, not the one below: the plank art
## only fills the top slice of its tile, so a post starting one cell down left
## a visible gap of bare backdrop between plank and post. The beam draws on
## the backdrop layer, so the plank renders over it and the joint reads solid.
func _drop_beam(play: TileMapLayer, backdrop: TileMapLayer, from: Vector2i) -> void:
	var y: int = from.y + 1
	var length: int = 0
	while length < 10 and play.get_cell_source_id(Vector2i(from.x, y)) == -1:
		y += 1
		length += 1
	if play.get_cell_source_id(Vector2i(from.x, y)) == -1:
		return
	for by: int in range(from.y, y):
		backdrop.set_cell(Vector2i(from.x, by), 0, BEAM)


func _cell(x: int, y: int) -> Vector2i:
	# +1 for the border the generator wraps around every room.
	return Vector2i(x + 1, y + 1)


func _world(x: int, y: int) -> Vector2:
	# Centre of the tile, sat on its floor for spawns.
	return Vector2(float(_cell(x, y).x) * TILE + TILE * 0.5, float(_cell(x, y).y) * TILE + TILE)


func _build(id: StringName, rows: Array, tile_set: TileSet) -> void:
	var root: Node2D = Node2D.new()
	root.name = "Room_" + String(id)
	root.set_script(load("res://src/rooms/room.gd"))

	var w: int = (rows[0] as String).length() + 2
	var h: int = rows.size() + 2

	# Backdrop first (tree order = draw order, so it sits BEHIND the play
	# tiles): dim cool rock over the entire box, because the black void must
	# never show through a room's interior. No collision — the TileSet says so.
	# It overspills the box by BACKDROP_PAD tiles on every side: rooms shorter
	# or narrower than the camera view let the clamped camera see PAST the
	# border, and that spill was a hard black frame around the whole room.
	var backdrop: TileMapLayer = TileMapLayer.new()
	backdrop.name = "Backdrop"
	backdrop.tile_set = tile_set
	root.add_child(backdrop)
	backdrop.owner = root
	for y: int in range(-BACKDROP_PAD, h + BACKDROP_PAD):
		for x: int in range(-BACKDROP_PAD, w + BACKDROP_PAD):
			backdrop.set_cell(Vector2i(x, y), 0, BACKDROP)

	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "Tiles"
	layer.tile_set = tile_set
	root.add_child(layer)
	layer.owner = root

	# Solid border. Rooms are sealed boxes; the exit is a trigger, not a hole.
	for x: int in w:
		layer.set_cell(Vector2i(x, 0), 0, _rock(x, 0))
		layer.set_cell(Vector2i(x, h - 1), 0, _rock(x, h - 1))
	for y: int in h:
		layer.set_cell(Vector2i(0, y), 0, _rock(0, y))
		layer.set_cell(Vector2i(w - 1, y), 0, _rock(w - 1, y))

	var spawns: Array[Dictionary] = []
	var entry: Vector2 = Vector2.ZERO
	var exit_at: Vector2 = Vector2.ZERO

	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			match row[x]:
				"#":
					var cell: Vector2i = _cell(x, y)
					layer.set_cell(cell, 0, _rock(cell.x, cell.y))
				"=":
					layer.set_cell(_cell(x, y), 0, _walkway(_cell(x, y)))
				"P":
					entry = _world(x, y)
				"X":
					exit_at = _world(x, y)
				"g":
					spawns.append({"kind": "grunt", "at": _world(x, y)})
				"b":
					spawns.append({"kind": "brute", "at": _world(x, y)})
				"d":
					spawns.append({"kind": "dart", "at": _world(x, y)})
				"E":
					spawns.append({"kind": "overseer", "at": _world(x, y)})
				"S":
					spawns.append({"kind": "shrine", "at": _world(x, y)})
				"C":
					spawns.append({"kind": "crumble", "at": _world(x, y)})
				"v":
					spawns.append({"kind": "spikes", "at": _world(x, y)})
				"o":
					spawns.append({"kind": "anchor", "at": _world(x, y)})
				"h":
					spawns.append({"kind": "heart", "at": _world(x, y)})
				"F":
					spawns.append({"kind": "hearth", "at": _world(x, y)})

	# Moss takes the lit lip: rock whose cell above is open air. A post-pass,
	# because "is the air open" is only known once every play tile is down.
	for cell: Vector2i in layer.get_used_cells():
		if cell.y == 0:
			continue  # the ceiling's top face points out of the room
		var tile: Vector2i = layer.get_cell_atlas_coords(cell)
		if tile != SOLID and tile != SOLID_B:
			continue
		if layer.get_cell_source_id(cell + Vector2i.UP) != -1:
			continue
		if _hash(cell.x, cell.y, 3) % 100 < 30:
			layer.set_cell(cell, 0, MOSSY)

	# Timber posts prop the walkways (backdrop layer — set dressing, no
	# collision): a stack under each end of a run and every 4th column of long
	# ones, dropped until they meet rock. An unproppable span (nothing below
	# within reach) gets no post — better bare than a beam hanging in air.
	for y: int in rows.size():
		var row: String = rows[y]
		var x: int = 0
		while x < row.length():
			if row[x] != "=":
				x += 1
				continue
			var start: int = x
			while x < row.length() and row[x] == "=":
				x += 1
			var posts: Array[int] = [start, x - 1]
			var c: int = start + 3
			while c < x - 1:
				posts.append(c)
				c += 4
			for col: int in posts:
				_drop_beam(layer, backdrop, _cell(col, y))

	var entry_marker: Marker2D = Marker2D.new()
	entry_marker.name = "Entry"
	entry_marker.position = entry
	root.add_child(entry_marker)
	entry_marker.owner = root

	var exit_marker: Marker2D = Marker2D.new()
	exit_marker.name = "Exit"
	exit_marker.position = exit_at
	root.add_child(exit_marker)
	exit_marker.owner = root

	var spawn_root: Node2D = Node2D.new()
	spawn_root.name = "Spawns"
	root.add_child(spawn_root)
	spawn_root.owner = root
	for i: int in spawns.size():
		var marker: Marker2D = Marker2D.new()
		marker.name = "%s_%d" % [spawns[i]["kind"], i]
		marker.position = spawns[i]["at"]
		marker.set_meta(&"kind", spawns[i]["kind"])
		spawn_root.add_child(marker)
		marker.owner = root

	root.set("room_id", String(id))
	root.set("room_size", Vector2(float(w * TILE), float(h * TILE)))

	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	var path: String = "%s/%s.tscn" % [OUT_DIR, id]
	var err: int = ResourceSaver.save(packed, path)
	print("  %-9s %d spawns, %s (err=%d)" % [id, spawns.size(), path, err])
	root.free()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var tile_set: TileSet = load(TILESET) as TileSet
	if tile_set == null:
		printerr("no tileset at %s — run tools/gen_tileset.gd first" % TILESET)
		get_tree().quit(1)
		return

	var layouts: Dictionary[StringName, Array] = RoomLayouts.all()

	print("validating %d layouts:" % layouts.size())
	var all_ok: bool = true
	for id: StringName in layouts:
		# Shape first: reachability analysis on a malformed grid is meaningless.
		if not _validate(id, layouts[id]):
			all_ok = false
		elif not _check_reachability(id, layouts[id]):
			all_ok = false
	if not all_ok:
		for e: String in _errors:
			printerr("  INVALID  %s" % e)
		printerr("refusing to generate rooms from broken layouts")
		get_tree().quit(1)
		return
	print("  all layouts valid")

	print("building:")
	for id: StringName in layouts:
		_build(id, layouts[id], tile_set)
	print("done")
	get_tree().quit(0)
