class_name RoomChunks
extends Object
## Reusable room FRAGMENTS, as ASCII — same discipline and legend as
## room_layouts.gd (see that file's header), one level down in granularity.
##
## PILOT (2026-07-23 decision log, "let's start there and see"): the existing
## big rooms (undercroft, chasm) aren't built by any special system — they are
## just bigger hand-drawn whole rooms. This file is the alternative: a small
## library of smaller pieces that room_stitcher.gd concatenates into many
## distinct composite big rooms, so variety comes from combination instead of
## from hand-drawing every combination whole.
##
## SIZE: HALLS/UNDERCROFT are 116-120 columns; a normal middle room is 58.
## Chunks are sized so entry + TWO middles + exit (gen_rooms.gd's default)
## lands solidly past HALLS/UNDERCROFT scale — the first pass here undersized
## everything and read as "vague variations," see the GDD decision log.
##
## ENEMY PLACEMENT (2026-07-23 clustering pass, Dustin's call after playing
## Dead Cells' pacing for comparison): enemies are grouped into read-able
## clusters — a pair or trio positioned close together — rather than spread
## as evenly-spaced singles. Rule: never Brute+Brute in one cluster (two
## 90/70-poise swings overlapping is not tense, it's a wall you can't
## interrupt at all); a Brute pairs with at most one light add, or stands
## alone as a checkpoint. Entry/exit chunks stay light — the clustering is a
## middle-chunk beat, not the opener or the closer.
##
## Every chunk is exactly RoomLayouts.HEIGHT (18) rows — ONE height class for
## v1, so stitching is plain string concatenation, row for row, with no
## height reconciliation to solve. Every chunk's row 17 (the floor) is solid
## across its FULL width, which is what makes any two chunks compose safely.
##
## A chunk has a ROLE: ENTRY (carries P, leftmost, gentle), MIDDLE (pure
## geometry/combat), EXIT (carries X, rightmost). This inherits the existing
## "exactly one P, one X" validation for free.

enum Role { ENTRY, MIDDLE, EXIT }

## A small adjacent pair (grunt+dart), not a real cluster — entry stays
## "nothing that can kill you before you look around"; the clustering pass
## (2026-07-23) belongs to the middle chunks, not the opener.
const ENTRY_CALM: Array[String] = [
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..............======......",
	"..........................",
	"..P......g...d............",
	"##########################",
]

## A short two-tier climb before the room opens up, teaching the jump the
## way room_layouts.gd's CLIMB does, scaled to a chunk. Same light pairing
## as ENTRY_CALM, kept gentle on purpose.
const ENTRY_CLIMB: Array[String] = [
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"................======......",
	"............................",
	"............................",
	"........======..............",
	"............................",
	"..P........g...d............",
	"############################",
]

## A close guard pair at the door (grunt+brute, adjacent) instead of two
## solo posts spread across the room — a last beat, not a gauntlet.
const EXIT_CALM: Array[String] = [
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..........................",
	"..............g..b....X...",
	"##########################",
]

## The exit sits one hop up on a platform instead of at floor level — echoes
## room_layouts.gd's CLIMB/SHAFT exits-on-ledges pattern. A close guard pair
## before the climb, same pacing as EXIT_CALM.
const EXIT_PERCH: Array[String] = [
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"............................",
	"....................X.......",
	"..................======....",
	"............................",
	"...........g..d.............",
	"############################",
]

## Two read-able clusters (2026-07-23 clustering pass) instead of four
## evenly-spaced singles: a light grunt pair opens, a brute+dart pair closes.
## Never brute+brute — two that heavy overlapping is not fun, it's a wall.
const COMBAT_OPEN: Array[String] = [
	"............................................",
	"............................................",
	"............................................",
	"............................................",
	"............................................",
	"............................................",
	"............................................",
	"............................................",
	"...................======...................",
	"............................................",
	"............................................",
	"............======........======............",
	"............................................",
	"............................................",
	"...======.........................======....",
	"............................................",
	"....g..g.........................b...d......",
	"############################################",
]

## A light ground pair to clear before climbing; the elevated dart stays
## solo on purpose — limited platform space makes an elevated cluster a
## fairness risk, not an intensity win.
const CLIMB_ZIGZAG: Array[String] = [
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"..............................d.........",
	"............................======......",
	"........................................",
	"........................................",
	"....................======..............",
	"........................................",
	"........................................",
	"............======......................",
	"........................................",
	"........................................",
	"....======..............................",
	"........................................",
	"...g..g.................................",
	"########################################",
]

## THE PITCH: generalizes UNDERCROFT's two-tier trick into one chunk. A
## long solid row (7) acts as ceiling for the lower lane AND as a walkable
## roof for anyone who climbs the left tier ladder. The lower lane now holds
## a genuine 3-enemy pack right at the ladder's base (2026-07-23 clustering
## pass) — the floor route is an actual fight to weigh, and the pack's chaos
## doubles as cover for slipping onto the ladder instead of fighting through
## it. The roof keeps one lone guard planted by its shrine: one defender for
## one prize, not a pack for a walkway.
const MEZZANINE: Array[String] = [
	"....................................................",
	"....................................................",
	"....................................................",
	"....................................................",
	"....................................................",
	"....................................................",
	"..............................S..g..................",
	"..............#################################.....",
	"....................................................",
	".................====...............................",
	"....................................................",
	"..........======....................................",
	"....................................................",
	"....................................................",
	"...======...........................................",
	"....................................................",
	"....g..g...d........................................",
	"####################################################",
]

## A light pair up front, a solo Brute planted before the alcove's platform
## (2026-07-23 clustering pass) — the Brute can't jump (ARENA's own pillar),
## so it can never reach the shrine, which is exactly why it reads as
## guarding the approach rather than the prize.
const COMBAT_ALCOVE: Array[String] = [
	"..........................................",
	"..........................................",
	"..........................................",
	"..........................................",
	"..........................................",
	"..........................................",
	"..........................................",
	"..........................................",
	"..........................................",
	"..........................................",
	"..................S.......................",
	".............============.................",
	"..........................................",
	"..........................................",
	"...======...................======........",
	"..........................................",
	"....g..d......................b...........",
	"##########################################",
]


## Every chunk, with its role, keyed by the id it is known by.
static func all() -> Dictionary[StringName, Dictionary]:
	return {
		&"entry_calm": {"rows": ENTRY_CALM, "role": Role.ENTRY},
		&"entry_climb": {"rows": ENTRY_CLIMB, "role": Role.ENTRY},
		&"exit_calm": {"rows": EXIT_CALM, "role": Role.EXIT},
		&"exit_perch": {"rows": EXIT_PERCH, "role": Role.EXIT},
		&"combat_open": {"rows": COMBAT_OPEN, "role": Role.MIDDLE},
		&"climb_zigzag": {"rows": CLIMB_ZIGZAG, "role": Role.MIDDLE},
		&"mezzanine": {"rows": MEZZANINE, "role": Role.MIDDLE},
		&"combat_alcove": {"rows": COMBAT_ALCOVE, "role": Role.MIDDLE},
	}
