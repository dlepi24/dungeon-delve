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
	# plan_for_seed() is pure, so this instance exists only to call it. It MUST
	# not auto-start: a second live Delve would load its own rooms and fight the
	# real one over the same player.
	var delve: Delve = DELVE_SCRIPT.new()
	delve.auto_start = false
	add_child(delve)

	_test_same_seed_same_plan(delve)
	_test_different_seeds_differ(delve)
	_test_plan_shape(delve)
	_test_other_streams_do_not_disturb_layout(delve)
	_test_every_planned_room_exists(delve)
	await _test_rooms_are_walkable()
	await _test_the_run_is_actually_playable()
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


## Everything above passes on a delve where the player is invisible to the world.
## Shipped exactly that: node _ready order meant Delve, Room and every Enemy
## resolved a null player, so enemies stood still, exits never fired, and the
## player was never placed in the room. Nothing errored. This pins the wiring.
func _test_the_run_is_actually_playable() -> void:
	print("the run is wired to the player")
	var run: Node2D = (load("res://src/rooms/delve_run.tscn") as PackedScene).instantiate() as Node2D
	add_child(run)
	# Deferred auto-start needs a frame to land.
	for i: int in 4:
		await get_tree().physics_frame

	var delve: Delve = run.get_node("Delve")
	var player: Player = run.get_node("Player")
	var room: Room = delve.current_room()
	_check(room != null, "the first room loaded")
	if room == null:
		run.queue_free()
		return

	_check(player.global_position.distance_to(room.entry_position()) < 80.0,
		"the player is placed at the room entry, not left where the scene put them")

	var enemies: Array[Enemy] = []
	for child: Node in room.get_children():
		if child is Enemy:
			enemies.append(child as Enemy)
	_check(enemies.size() > 0, "the room spawned enemies (%d)" % enemies.size())
	var sees_player: bool = true
	for enemy: Enemy in enemies:
		if enemy.get_player() == null:
			sees_player = false
	_check(sees_player, "every enemy can see the player")

	# Let them come. If any reaches CHASE, the wiring is live.
	var chased: bool = false
	for i: int in 240:
		await get_tree().physics_frame
		for enemy: Enemy in enemies:
			if is_instance_valid(enemy) and enemy.get_state_name() != "IDLE":
				chased = true
	_check(chased, "at least one enemy actually acts rather than standing still")

	# And the exit advances the run.
	var before: int = delve.current_index()
	player.global_position = room.exit_position()
	player.velocity = Vector2.ZERO
	for i: int in 20:
		await get_tree().physics_frame
	_check(delve.current_index() > before, "reaching the exit advances the delve")
	run.queue_free()
	await get_tree().physics_frame


func _report() -> void:
	if _failures.is_empty():
		print("\nDELVE TEST OK")
		get_tree().quit(0)
		return
	printerr("\n%d delve assertion(s) failed:" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	get_tree().quit(1)
