extends Node
## Headless project check. Exits non-zero if the scaffold contract is broken,
## so it works as a pre-commit gate and, later, in CI.
##
## Run: godot --headless --path . res://tools/check.tscn
##
## Runs as a SCENE, not via --script, and that is load-bearing: --script mode
## never registers autoload singletons, so load() on any script referencing
## Events fails with "Identifier not found" even though the game runs perfectly.
## A gate that reports failures the game does not have is worse than no gate.
##
## This asserts the things docs/GDD.md locks down and that are easy to break by
## accident — the InputMap, the named collision layers, the physics tick, the
## autoloads — plus a parse of every script under src/. Extend it whenever the
## GDD locks something new.

const EXPECTED_ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "roll", "attack", "parry",
	"skill_1", "skill_2", "interact",
	"consumable_1", "consumable_2",
]

## Order is the contract: index N here must be collision layer N+1.
const EXPECTED_LAYERS: PackedStringArray = [
	"World", "Player", "Enemy", "PlayerAttack", "EnemyAttack", "Pickup",
]

## Settings is deliberately LAST in project.godot's [autoload] block: its _ready
## pushes prefs onto Music, so Music must be initialised first. Autoloads load in
## file order, not this list's order.
const EXPECTED_AUTOLOADS: PackedStringArray = ["Events", "GameState", "Hitstop", "Keybinds", "Music", "Rng", "Sfx", "Settings"]

var _failures: PackedStringArray = []


func _fail(message: String) -> void:
	_failures.append(message)


func _check_actions() -> void:
	for action: String in EXPECTED_ACTIONS:
		if not InputMap.has_action(action):
			_fail("InputMap is missing action '%s' (see the input table in docs/GDD.md)." % action)
			continue
		if InputMap.action_get_events(action).is_empty():
			_fail("InputMap action '%s' exists but has no events bound." % action)


func _check_layers() -> void:
	for i: int in EXPECTED_LAYERS.size():
		var key: String = "layer_names/2d_physics/layer_%d" % (i + 1)
		var actual: String = str(ProjectSettings.get_setting(key, ""))
		if actual != EXPECTED_LAYERS[i]:
			_fail("Collision layer %d should be named '%s', found '%s'." % [i + 1, EXPECTED_LAYERS[i], actual])


## The hard rule is that raw layer numbers never appear in code, which only holds
## if the named constants actually match the project. Pins CollisionLayers to
## project.godot so the GDD table, the settings and the code cannot drift.
func _check_layer_constants() -> void:
	for name: String in CollisionLayers.NUMBERS:
		var number: int = CollisionLayers.NUMBERS[name]
		var configured: String = str(ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % number, ""))
		if configured != name:
			_fail("CollisionLayers.NUMBERS says '%s' is layer %d, but that layer is named '%s'." % [name, number, configured])


func _check_physics_tick() -> void:
	var tick: int = Engine.physics_ticks_per_second
	if tick != 60:
		_fail("Physics tick is %d, GDD locks 60/s fixed (determinism)." % tick)


func _check_autoloads() -> void:
	for name: String in EXPECTED_AUTOLOADS:
		if not ProjectSettings.has_setting("autoload/%s" % name):
			_fail("Autoload '%s' is not registered." % name)


func _check_main_scene() -> void:
	var path: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if path.is_empty():
		_fail("No main scene configured.")
		return
	if not ResourceLoader.exists(path):
		_fail("Main scene '%s' does not exist." % path)
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail("Main scene '%s' failed to load." % path)
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		_fail("Main scene '%s' failed to instantiate." % path)
		return
	instance.free()


func _script_paths(dir_path: String, found: PackedStringArray) -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		_fail("Cannot open directory '%s'." % dir_path)
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_script_paths(full, found)
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


## Detecting a parse failure is fiddlier than it looks, so don't "simplify" this:
## load() returns a non-null GDScript even when the script failed to parse, and
## `godot --check-only` exits 0 on a syntax error. can_instantiate() is what
## actually goes false. Caveat: it is also false for an @abstract script, so if
## we ever add one, exempt it explicitly rather than loosening the check.
func _check_scripts_parse() -> void:
	var paths: PackedStringArray = _script_paths("res://src", PackedStringArray())
	_script_paths("res://tools", paths)
	_script_paths("res://tests", paths)
	if paths.is_empty():
		_fail("No scripts found under res://src, res://tools or res://tests.")
		return
	for path: String in paths:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			_fail("Script '%s' failed to parse." % path)
	print("  parsed %d script(s)" % paths.size())


func _ready() -> void:
	_check_actions()
	_check_layers()
	_check_layer_constants()
	_check_physics_tick()
	_check_autoloads()
	_check_main_scene()
	_check_scripts_parse()

	if _failures.is_empty():
		print("CHECK OK — %d actions, %d layers, %d autoloads, main scene loads." % [
			EXPECTED_ACTIONS.size(), EXPECTED_LAYERS.size(), EXPECTED_AUTOLOADS.size(),
		])
		get_tree().quit(0)
		return

	for failure: String in _failures:
		printerr("CHECK FAIL: %s" % failure)
	printerr("%d check(s) failed." % _failures.size())
	get_tree().quit(1)
