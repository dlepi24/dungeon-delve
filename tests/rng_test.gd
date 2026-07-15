extends Node
## Determinism tests for the central RNG service.
##
## These guard the GDD's competition model. A broken guarantee here does not
## crash anything — it just means two players on the same daily seed quietly get
## different levels, and nobody notices until the leaderboard is nonsense.
##
## Run: godot --headless --path . res://tests/rng_test.tscn

var _failures: PackedStringArray = []


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		_failures.append(label)
		print("  FAIL  %s" % label)


func _draw(stream: StringName, count: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in count:
		out.append(Rng.stream(stream).randi_range(0, 999))
	return out


func _ready() -> void:
	_test_same_seed_same_sequence()
	_test_different_seeds_differ()
	_test_streams_are_independent()
	_test_stream_order_does_not_matter()
	_test_text_seeds()
	_report()


func _test_same_seed_same_sequence() -> void:
	print("same seed reproduces the same sequence")
	Rng.set_seed(12345)
	var first: Array[int] = _draw(&"delve", 20)
	Rng.set_seed(12345)
	var second: Array[int] = _draw(&"delve", 20)
	_check(first == second, "seed 12345 twice yields identical draws")


func _test_different_seeds_differ() -> void:
	print("different seeds diverge")
	Rng.set_seed(1)
	var a: Array[int] = _draw(&"delve", 20)
	Rng.set_seed(2)
	var b: Array[int] = _draw(&"delve", 20)
	_check(a != b, "seeds 1 and 2 yield different draws")


## THE important one. If streams shared a sequence, adding a single random call
## to enemy AI would shift every later draw and silently change the level layout
## for every existing seed.
func _test_streams_are_independent() -> void:
	print("streams do not disturb each other")
	Rng.set_seed(777)
	var clean: Array[int] = _draw(&"delve", 20)

	Rng.set_seed(777)
	# Simulate another system drawing heavily before and during layout.
	_draw(&"enemies", 5)
	var interleaved: Array[int] = []
	for i: int in 20:
		interleaved.append(Rng.stream(&"delve").randi_range(0, 999))
		_draw(&"enemies", 3)
		_draw(&"loot", 2)

	_check(clean == interleaved,
		"the delve stream is identical no matter how much other streams drew")


func _test_stream_order_does_not_matter() -> void:
	print("stream creation order is irrelevant")
	Rng.set_seed(999)
	var delve_first: Array[int] = _draw(&"delve", 10)

	Rng.set_seed(999)
	_draw(&"loot", 4)
	_draw(&"enemies", 4)
	var delve_last: Array[int] = _draw(&"delve", 10)

	_check(delve_first == delve_last, "delve draws do not depend on which stream was touched first")


func _test_text_seeds() -> void:
	print("human-typed seeds")
	_check(Rng.seed_from_text("12345") == 12345, "a numeric seed is used verbatim")
	_check(Rng.seed_from_text("cavern") == Rng.seed_from_text("cavern"), "a word seed is stable")
	_check(Rng.seed_from_text(" cavern ") == Rng.seed_from_text("cavern"), "whitespace is ignored")
	_check(Rng.seed_from_text("cavern") != Rng.seed_from_text("caverns"), "similar words differ")
	_check(Rng.daily_seed(2026, 7, 15) == Rng.daily_seed(2026, 7, 15), "a daily seed is stable")
	_check(Rng.daily_seed(2026, 7, 15) != Rng.daily_seed(2026, 7, 16), "consecutive days differ")


func _report() -> void:
	if _failures.is_empty():
		print("\nRNG TEST OK")
		get_tree().quit(0)
		return
	printerr("\n%d rng assertion(s) failed:" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	get_tree().quit(1)
