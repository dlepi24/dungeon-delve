class_name RoomStitcher
extends Object
## Pure functions: no RNG, no file I/O, no autoloads — same discipline as
## Delve.options_for_seed(), so this is unit-testable in isolation and never
## touches the seeded gameplay streams (stitching happens at BAKE TIME, not
## play time; see room_chunks.gd's header for why that split is deliberate).
##
## The whole mechanism is: enumerate() picks every valid (entry, middles...,
## exit) sequence from the chunk library, stitch() concatenates each sequence
## row-by-row into one ordinary room grid, and tools/gen_rooms.gd runs that
## grid through the EXACT SAME _validate()/_check_reachability() every
## hand-drawn room already goes through. Nothing downstream needs to know or
## care that the grid was assembled rather than typed by hand.

## Local row indices where this chunk's edge column (0 for "left", the last
## column for "right") is solid/standable. A cheap pre-filter, belt-and-
## suspenders alongside the real reachability check in gen_rooms.gd — every
## v1 chunk keeps its floor row (17) solid full-width by convention, so this
## always includes at least row 17 and stitching never depends on luck.
static func socket_rows(chunk_rows: Array, side: String) -> Array[int]:
	var rows: Array[int] = []
	for y: int in chunk_rows.size():
		var row: String = chunk_rows[y]
		var c: String = row[0] if side == "left" else row[row.length() - 1]
		if c == "#" or c == "=":
			rows.append(y)
	return rows


## Whether chunk A's right edge and chunk B's left edge share at least one
## standable row — i.e. the seam has a walkable floor-level connection.
static func compatible(a_rows: Array, b_rows: Array) -> bool:
	var a_right: Array[int] = socket_rows(a_rows, "right")
	var b_left: Array[int] = socket_rows(b_rows, "left")
	for y: int in a_right:
		if b_left.has(y):
			return true
	return false


## Concatenate a left-to-right sequence of same-height chunks into one grid.
## Row i of the result is row i of every chunk, joined in order — nothing
## more, since no chunk carries its own border (see room_chunks.gd header).
static func stitch(chunks: Array[Array]) -> Array[String]:
	var height: int = chunks[0].size()
	var out: Array[String] = []
	for y: int in height:
		var row: String = ""
		for chunk: Array in chunks:
			row += chunk[y]
		out.append(row)
	return out


## Every valid (entry, middles..., exit) sequence, for each middle-chain
## length in `middle_counts` (0 means entry+exit directly). Middles within one
## composite are always DISTINCT (no chunk repeated in the same room) — small
## library, so this stays a short, fully reviewable, stable-id list rather
## than a random sample that would need discarding failures.
static func enumerate(entries: Dictionary, middles: Dictionary, exits: Dictionary, middle_counts: Array[int]) -> Dictionary[StringName, Array]:
	var out: Dictionary[StringName, Array] = {}
	var middle_ids: Array[StringName] = []
	for id: StringName in middles:
		middle_ids.append(id)

	for entry_id: StringName in entries:
		for exit_id: StringName in exits:
			for count: int in middle_counts:
				# _permutations returns untyped Array (each element is itself an
				# Array[StringName] built inside that function) — GDScript's typed
				# arrays lose their element typing once erased through a plain
				# Array return, so the loop variable here has to stay untyped too.
				for sequence: Array in _permutations(middle_ids, count):
					var chunks: Array[Array] = [entries[entry_id]]
					for mid_id: StringName in sequence:
						chunks.append(middles[mid_id])
					chunks.append(exits[exit_id])
					var ok: bool = true
					for i: int in chunks.size() - 1:
						if not compatible(chunks[i], chunks[i + 1]):
							ok = false
							break
					if not ok:
						continue
					var parts: PackedStringArray = [String(entry_id)]
					for mid_id: StringName in sequence:
						parts.append(String(mid_id))
					parts.append(String(exit_id))
					var composite_id: StringName = StringName("big_" + "_".join(parts))
					out[composite_id] = stitch(chunks)
	return out


## Ordered sequences of `count` distinct ids drawn from `pool`, count == 0
## yielding exactly one (empty) sequence — plain recursive permutation, no
## external dependency, since GDScript has no stdlib itertools equivalent.
static func _permutations(pool: Array[StringName], count: int) -> Array:
	if count <= 0:
		return [[]]
	var out: Array = []
	for i: int in pool.size():
		var rest: Array[StringName] = pool.duplicate()
		rest.remove_at(i)
		for tail: Array in _permutations(rest, count - 1):
			var seq: Array[StringName] = [pool[i]]
			seq.append_array(tail)
			out.append(seq)
	return out
