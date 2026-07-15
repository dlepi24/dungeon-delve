extends Node
## M4's exit criterion, as a test: "same seed produces the same delve".
##
## This is the guarantee the whole competition model rests on. It cannot be
## checked by playing — two runs look identical until they aren't — so it gets
## pinned here instead.
##
## Run: godot --headless --path . res://tests/delve_test.tscn

const DELVE_SCRIPT: GDScript = preload("res://src/rooms/delve.gd")
const ROOM_DIR: String = "res://src/rooms/delve"

var _failures: PackedStringArray = []


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		_failures.append(label)
		print("  FAIL  %s" % label)


func _plan(delve: Delve, seed_value: int, count: int = 5) -> Array[StringName]:
	return delve.plan_for_seed(seed_value, count)


func _ready() -> void:
	var delve: Delve = DELVE_SCRIPT.new()
	add_child(delve)

	_test_same_seed_same_plan(delve)
	_test_different_seeds_differ(delve)
	_test_plan_shape(delve)
	_test_other_streams_do_not_disturb_layout(delve)
	_test_every_planned_room_exists(delve)
	await _test_rooms_are_walkable()
	_report()


func _test_same_seed_same_plan(delve: Delve) -> void:
	print("same seed reproduces the same delve")
	var identical: bool = true
	for seed_value: int in [0, 1, 42, 12345, -7, 999999]:
		var a: Array[StringName] = _plan(delve, seed_value)
		var b: Array[StringName] = _plan(delve, seed_value)
		if a != b:
			identical = false
			print("    seed %d: %s vs %s" % [seed_value, a, b])
	_check(identical, "six different seeds each reproduce exactly")

	# And again after other work has happened, to catch hidden global state.
	var before: Array[StringName] = _plan(delve, 42)
	for i: int in 50:
		Rng.stream(&"noise").randi()
	var after: Array[StringName] = _plan(delve, 42)
	_check(before == after, "a plan is stable even after unrelated RNG use")


func _test_different_seeds_differ(delve: Delve) -> void:
	print("seeds actually produce variety")
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in range(60):
		seen[", ".join(PackedStringArray(_plan(delve, seed_value)))] = true
	# Not asking for all-unique — with 4 middle rooms there are only 4^3 = 64
	# possible plans, so collisions are expected and fine. Asking for "not one
	# single layout", which is what a broken seed would produce.
	_check(seen.size() > 10, "60 seeds yield %d distinct plans (want > 10)" % seen.size())


func _test_plan_shape(delve: Delve) -> void:
	print("plan shape")
	var plan: Array[StringName] = _plan(delve, 12345, 5)
	_check(plan.size() == 5, "a 5-room delve has 5 rooms (got %d)" % plan.size())
	_check(plan[0] == &"entry", "always opens with the gentle room (got %s)" % plan[0])
	_check(plan[plan.size() - 1] == &"deep", "always ends deep (got %s)" % plan[plan.size() - 1])

	var repeats: int = 0
	for seed_value: int in range(40):
		var p: Array[StringName] = _plan(delve, seed_value, 5)
		for i: int in range(1, p.size()):
			if p[i] == p[i - 1]:
				repeats += 1
	# The re-draw makes back-to-back repeats rare, not impossible. It must not be
	# common, or runs read as buggy.
	_check(repeats < 12, "back-to-back identical rooms are rare across 40 seeds (%d)" % repeats)


## The reason streams exist. If layout shared a sequence with combat, this fails.
func _test_other_streams_do_not_disturb_layout(delve: Delve) -> void:
	print("layout is immune to other systems' randomness")
	var clean: Array[StringName] = _plan(delve, 555)

	Rng.set_seed(555)
	for i: int in 100:
		Rng.stream(&"enemies").randf()
		Rng.stream(&"loot").randi()
	var generator: RandomNumberGenerator = Rng.stream(&"delve")
	var noisy: Array[StringName] = [Delve.FIRST_ROOM]
	var previous: StringName = Delve.FIRST_ROOM
	for i: int in 3:
		var choice: StringName = Delve.MIDDLE_POOL[generator.randi_range(0, Delve.MIDDLE_POOL.size() - 1)]
		if choice == previous and Delve.MIDDLE_POOL.size() > 1:
			choice = Delve.MIDDLE_POOL[generator.randi_range(0, Delve.MIDDLE_POOL.size() - 1)]
		noisy.append(choice)
		previous = choice
	noisy.append(Delve.LAST_ROOM)

	_check(clean == noisy, "the delve stream ignores 200 draws from other streams")


func _test_every_planned_room_exists(delve: Delve) -> void:
	print("every room a plan can name is on disk")
	var missing: PackedStringArray = []
	var ids: Array[StringName] = [Delve.FIRST_ROOM, Delve.LAST_ROOM]
	ids.append_array(Delve.MIDDLE_POOL)
	for id: StringName in ids:
		if not ResourceLoader.exists("%s/%s.tscn" % [ROOM_DIR, id]):
			missing.append(String(id))
	_check(missing.is_empty(), "all room scenes exist (missing: %s)" % [", ".join(missing) if missing.size() > 0 else "none"])


## A room whose exit sits inside a wall, or whose entry is in the ceiling, would
## be a run-ending bug that only shows up by walking into it.
func _test_rooms_are_walkable() -> void:
	print("rooms are structurally sane")
	var ids: Array[StringName] = [Delve.FIRST_ROOM, Delve.LAST_ROOM]
	ids.append_array(Delve.MIDDLE_POOL)
	var problems: PackedStringArray = []
	for id: StringName in ids:
		var packed: PackedScene = load("%s/%s.tscn" % [ROOM_DIR, id]) as PackedScene
		if packed == null:
			problems.append("%s: will not load" % id)
			continue
		var room: Room = packed.instantiate() as Room
		add_child(room)
		await get_tree().physics_frame

		var tiles: TileMapLayer = room.get_node("Tiles")
		if room.entry_position() == Vector2.ZERO:
			problems.append("%s: no entry marker" % id)
		if room.exit_position() == Vector2.ZERO:
			problems.append("%s: no exit marker" % id)
		if room.entry_position().distance_to(room.exit_position()) < 200.0:
			problems.append("%s: entry and exit are on top of each other" % id)
		# Markers sit at FEET level, which is the exact boundary between the empty
		# tile you stand in and the floor beneath it — sampling the marker point
		# itself rounds down onto the floor and always reports "solid". Sample the
		# tile the body actually occupies, half a tile up, and the one above it.
		for label: String in ["entry", "exit"]:
			var at: Vector2 = room.entry_position() if label == "entry" else room.exit_position()
			for height: int in [16, 48]:
				var cell: Vector2i = tiles.local_to_map(tiles.to_local(at - Vector2(0, float(height))))
				if tiles.get_cell_source_id(cell) != -1:
					problems.append("%s: %s marker is embedded in a tile at +%d" % [id, label, height])
			# And there must be ground under your feet, or you spawn falling.
			var below: Vector2i = tiles.local_to_map(tiles.to_local(at + Vector2(0, 8.0)))
			if tiles.get_cell_source_id(below) == -1:
				problems.append("%s: nothing solid under the %s marker" % [id, label])
		room.queue_free()
		await get_tree().physics_frame
	_check(problems.is_empty(), "all rooms have usable entry/exit (%s)" % [", ".join(problems) if problems.size() > 0 else "ok"])


func _report() -> void:
	if _failures.is_empty():
		print("\nDELVE TEST OK")
		get_tree().quit(0)
		return
	printerr("\n%d delve assertion(s) failed:" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	get_tree().quit(1)
