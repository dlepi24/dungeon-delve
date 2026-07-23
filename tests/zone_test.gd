extends Node
## Pins the zone system: the mine's three strata and the rest camp.
##
## What breaks silently without this: zone resources drifting out of shape
## (a pool naming a room that no longer exists, a music path with a typo — both
## fail as a quiet fallback, not an error), the zone_entered arc firing wrong
## or not at all (the atmosphere just... stays the same, which is exactly the
## repetition complaint this system exists to fix), and the camp regressing
## into a combat room (an enemy marker added to its ASCII would still build).
##
## Run: godot --headless --path . res://tests/zone_test.tscn

const DELVE_SCRIPT: GDScript = preload("res://src/rooms/delve.gd")

var _failures: PackedStringArray = []
var _zones_seen: Array[StringName] = []


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		_failures.append(label)
		print("  FAIL  %s" % label)


func _ready() -> void:
	var delve: Delve = DELVE_SCRIPT.new()
	delve.auto_start = false
	add_child(delve)

	_test_zone_resources(delve)
	_test_banding_is_pure(delve)
	await _test_the_descent_arc()
	_report()


## The three strata load, in order, and everything they name exists on disk.
func _test_zone_resources(delve: Delve) -> void:
	print("zone resources are sane")
	var zones: Array[ZoneData] = delve.zones()
	_check(zones.size() == 3, "three zones load (got %d)" % zones.size())
	if zones.size() != 3:
		return
	_check(zones[0].id == &"upper" and zones[1].id == &"hot_vein" and zones[2].id == &"deadlight",
		"strata order is upper -> hot_vein -> deadlight")

	var broken: PackedStringArray = []
	for zone: ZoneData in zones:
		if zone.display_name.is_empty():
			broken.append("%s: no display name" % zone.id)
		if zone.room_pool.is_empty():
			broken.append("%s: empty room pool" % zone.id)
		for id: String in zone.room_pool:
			if not ResourceLoader.exists("res://src/rooms/delve/%s.tscn" % id):
				broken.append("%s: pool names missing room '%s'" % [zone.id, id])
		for id: String in zone.big_pool:
			if not ResourceLoader.exists("res://src/rooms/delve/%s.tscn" % id):
				broken.append("%s: big pool names missing room '%s'" % [zone.id, id])
		if zone.music_tracks.is_empty():
			broken.append("%s: no music" % zone.id)
		for path: String in zone.music_tracks:
			if not ResourceLoader.exists(path):
				broken.append("%s: music path missing '%s'" % [zone.id, path])
	_check(broken.is_empty(), "every pool entry and track exists (%s)" % [", ".join(broken) if broken.size() > 0 else "ok"])


## Banding must be pure arithmetic: no RNG, no state, same answer every call.
func _test_banding_is_pure(delve: Delve) -> void:
	print("banding is deterministic")
	var stable: bool = true
	for i: int in 6:
		if delve.band_for_index(i, 6) != delve.band_for_index(i, 6):
			stable = false
	_check(stable, "band_for_index answers the same twice")
	_check(delve.band_for_index(0, 6) == 0 and delve.band_for_index(5, 6) == 2,
		"a run opens in the first stratum and bottoms out in the last")


## Walk a full seeded run and watch the journey happen: three zones announced
## in order, the camp empty of enemies but holding its heart, no debris rain at
## the rest stop, and the deep room's economy depth unchanged by the camp.
func _test_the_descent_arc() -> void:
	print("the descent is a journey")
	Events.zone_entered.connect(_on_zone)

	GameState.pending_seed = 12345
	var run: Node2D = (load("res://src/rooms/delve_run.tscn") as PackedScene).instantiate() as Node2D
	add_child(run)
	for i: int in 4:
		await get_tree().physics_frame

	var delve: Delve = run.get_node("Delve")
	var plan: Array[StringName] = delve.get_plan()
	_check(plan.size() == 6, "the run is 6 rooms (got %d)" % plan.size())

	# Walk to the camp (index 4), checking the zone announcements as we go.
	while delve.current_index() < 4:
		delve.descend()
		for i: int in 2:
			await get_tree().physics_frame

	var expected_arc: Array[StringName] = [&"upper", &"hot_vein", &"deadlight"]
	_check(_zones_seen == expected_arc,
		"all three strata announced, in descent order (got %s)" % [_zones_seen])

	var camp: Room = delve.current_room()
	_check(plan[4] == &"camp", "index 4 is the camp (got %s)" % plan[4])
	var enemies: int = 0
	var hearts: int = 0
	var rains: int = 0
	for child: Node in camp.get_children():
		if child is Enemy:
			enemies += 1
		elif child is Pickup and (child as Pickup).kind == Pickup.Kind.HEAL:
			hearts += 1
		elif child is DebrisRain:
			rains += 1
	_check(enemies == 0, "nobody lives at the camp (%d enemies)" % enemies)
	_check(hearts == 1, "the camp keeps exactly one heart (%d)" % hearts)
	_check(rains == 0, "the camp's roof holds — no debris rain")
	_check(GameState.depth == 4, "the camp shares the deep's economy depth (got %d)" % GameState.depth)

	delve.descend()
	for i: int in 2:
		await get_tree().physics_frame
	_check(delve.get_plan()[delve.current_index()] == &"deep", "below the camp is the deep vein")
	_check(GameState.depth == 4, "the deep room pays depth 4, same as before the camp existed (got %d)" % GameState.depth)

	run.queue_free()
	await get_tree().physics_frame


func _on_zone(zone: ZoneData) -> void:
	_zones_seen.append(zone.id)


func _report() -> void:
	if _failures.is_empty():
		print("\nZONE TEST OK")
		get_tree().quit(0)
		return
	printerr("\n%d zone assertion(s) failed:" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	get_tree().quit(1)
