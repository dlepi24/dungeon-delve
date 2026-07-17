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
## Roughly one rock tile in this many becomes an ore vein. Purely visual — ore
## collides exactly like rock — so it is scattered deterministically from the
## tile's own coordinates rather than from the seeded RNG. Two players on one
## seed see the same veins because the maths is the same, not because a stream
## was consumed; keeping it out of Rng means it can never shift layout draws.
const ORE_EVERY: int = 9
const OUT_DIR: String = "res://src/rooms/delve"
const TILESET: String = "res://src/rooms/world_tileset.tres"

const LEGEND: String = ".#=PXgbdES"

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
	if y >= RoomLayouts.HEIGHT:
		return true
	if y < 0 or x < 0 or x >= RoomLayouts.WIDTH:
		return false
	var c: String = rows[y][x]
	return c == "#" or c == "="


## Contiguous horizontal spans of surface. A span is ONE platform: land anywhere
## on it and you can walk the length of it, so reachability is a property of the
## whole run, not of each tile. Checking tiles individually flags the far end of a
## perfectly good platform.
func _runs(rows: Array) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y: int in RoomLayouts.HEIGHT:
		var x: int = 0
		while x < RoomLayouts.WIDTH:
			if not _is_surface(rows, x, y):
				x += 1
				continue
			var start: int = x
			while x < RoomLayouts.WIDTH and _is_surface(rows, x, y):
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
		if run.x == RoomLayouts.HEIGHT - 1:
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
	if rows.size() != RoomLayouts.HEIGHT:
		_errors.append("%s: has %d rows, expected %d" % [id, rows.size(), RoomLayouts.HEIGHT])
		ok = false
	var entries: int = 0
	var exits: int = 0
	for y: int in rows.size():
		var row: String = rows[y]
		if row.length() != RoomLayouts.WIDTH:
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


## Rock, with a vein every so often. Deterministic in the cell coordinates.
func _rock(x: int, y: int) -> Vector2i:
	return ORE if (x * 7 + y * 13) % ORE_EVERY == 0 else SOLID


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

	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "Tiles"
	layer.tile_set = tile_set
	root.add_child(layer)
	layer.owner = root

	# Solid border. Rooms are sealed boxes; the exit is a trigger, not a hole.
	var w: int = RoomLayouts.WIDTH + 2
	var h: int = RoomLayouts.HEIGHT + 2
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
					layer.set_cell(_cell(x, y), 0, ONE_WAY)
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
