extends Node
## The central seeded RNG service the GDD requires. Autoloaded as `Rng`.
##
## Every gameplay random draw must come from here. The moment one system calls
## randi() directly, the same daily seed stops producing the same delve and ghost
## replays desync — and that failure is invisible until someone compares two runs.
##
## STREAMS are the important idea. Each concern draws from its own generator,
## derived from the master seed by name. Without that, every draw shares one
## sequence, so adding a single random call to enemy AI would shift every
## subsequent draw and silently change the level layout for the same seed. With
## streams, layout is reproducible even as combat code churns.
##
## Visual-only randomness (screen shake, audio pitch) deliberately does NOT come
## from here. It never touches gameplay, and routing it through the seed would
## make replays depend on how many frames were rendered.

## Master seed for the run. 0 until set_seed() is called.
var _seed: int = 0
var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


## Start a run. Clears every stream so nothing carries over from the last one.
func set_seed(value: int) -> void:
	_seed = value
	_streams.clear()


func get_seed() -> int:
	return _seed


## Self-owned FNV-1a (32-bit) — replaces the engine's hash() for every seed
## derivation (2026-07-28, the pre-publish hardening pass). Godot documents no
## cross-version stability for hash(); if an engine upgrade ever changed it,
## every daily seed and every stream would silently reshuffle, and players on
## mixed game versions would race DIFFERENT mines on the same daily. This
## function is ours, pinned by rng_test, and can never move underneath us.
## (Landing it was itself a one-time reshuffle of all prior seeds — accepted
## now, before any seed has been shared or ranked online.)
func fnv32(text: String) -> int:
	var h: int = 0x811C9DC5
	for b: int in text.to_utf8_buffer():
		h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
	return h


## The seed for a given calendar day, for the daily-seed mode. Derived from the
## date so every player gets the same delve. Callers must pass the UTC date —
## one shared day worldwide, or two timezones rank different mines.
func daily_seed(year: int, month: int, day: int) -> int:
	return fnv32("daily:%04d-%02d-%02d" % [year, month, day])


## Turn a human-typed seed ("cavern", "12345") into a master seed, so seeds can
## be shared as words.
func seed_from_text(text: String) -> int:
	var trimmed: String = text.strip_edges()
	if trimmed.is_valid_int():
		return trimmed.to_int()
	return fnv32(trimmed)


## An independent generator for one concern. Same master seed + same stream name
## always yields the same sequence, no matter what other streams did.
##
## Use a stable name: renaming a stream reshuffles its sequence, which for
## &"delve" means every existing seed produces a different level.
func stream(name: StringName) -> RandomNumberGenerator:
	if not _streams.has(name):
		var generator: RandomNumberGenerator = RandomNumberGenerator.new()
		# Mixing the name into the seed is what makes streams independent rather
		# than merely separate cursors into one sequence. Self-owned fnv32 for
		# the same reason as daily_seed: engine hash() may move between
		# versions, and streams ARE the delve layout.
		generator.seed = fnv32("%d:%s" % [_seed, name])
		_streams[name] = generator
	return _streams[name]


## Rewind a single stream to its start. Used when re-generating a delve from the
## same seed without disturbing anything else.
func reset_stream(name: StringName) -> void:
	_streams.erase(name)
