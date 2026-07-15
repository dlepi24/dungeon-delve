extends Node
## Impact freeze. Autoloaded as `Hitstop`. Half of "crunchy" lives here.
##
## NOT implemented with Engine.time_scale = 0. That stops physics stepping
## altogether, so the freeze could only be timed in render frames, which vary
## with framerate and would desync the ghost replays the GDD locks in. Instead
## this keeps its own physics-tick clock and exposes a flag; gameplay systems ask
## is_frozen() and skip their update. Deterministic, and replays stay honest.
##
## Systems must OPT IN by checking is_frozen(). Anything that forgets keeps
## moving through the freeze, which reads as a bug.

## Ticks are counted on our own clock, which never stops — it is the thing
## measuring the freeze.
var _tick: int = 0
var _frozen_until: int = -1


func _ready() -> void:
	# Tick before anything reads is_frozen() this frame.
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	_tick += 1


## Freeze for `ticks` physics ticks. The longest outstanding request wins: a
## parry landing during a normal hit must not be cut short by it.
func request(ticks: int) -> void:
	if ticks <= 0:
		return
	_frozen_until = maxi(_frozen_until, _tick + ticks)


func is_frozen() -> bool:
	return _tick <= _frozen_until


func ticks_left() -> int:
	return maxi(0, _frozen_until - _tick + 1)


## Tests reach for this so one case cannot leak a freeze into the next.
func clear() -> void:
	_frozen_until = -1
