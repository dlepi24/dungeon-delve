class_name Ticks
extends Object
## Milliseconds-to-ticks conversion, in one place.
##
## Every timing window in the game is counted in physics ticks rather than
## wall-clock time, because daily seeds and ghost replays need identical results
## from identical inputs. Designers still think in milliseconds, so exports stay
## in ms and convert through here.


static func from_ms(ms: int) -> int:
	return roundi(float(ms) * float(Engine.physics_ticks_per_second) / 1000.0)
