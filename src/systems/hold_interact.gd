class_name HoldInteract
extends RefCounted
## Turns the shared interact button into a deliberate HOLD for the two actions
## you can regret: swapping the weapon in your hand, and accepting a shrine
## bargain that takes something from you. A tap does nothing here — and since
## interact shares the jump button on the pad (A / cross, no free face button
## left), that is the whole point: a panic jump is a tap, so it can never commit
## you to a weapon swap or a debuff. Only a press held ~hold_time long fires.
##
## Poll it once per physics frame with the prompt's live state; it returns true
## on the single frame the hold completes. Read `progress` (0..1) to draw the
## fill on the prompt chip so the player sees the commitment building.
##
## The pad's catch: that same press ALSO fires one jump, and the little hop can
## carry you off the prompt and reset the charge mid-hold — which made a weapon
## pickup near the edge of its range nearly unwinnable. Two guards fix it: the
## charge coasts through a brief drop out of range (`reacquire_grace`) so the hop
## can't abort it, and once the hold is clearly deliberate (`committing`) the
## caller swallows further jumps. See the callers in pickup.gd / shrine.gd.
##
## Arming rule: the button must be released at least once AFTER the prompt opens
## before a hold can count. Without it, walking up to an altar while already
## holding the jump/interact button would fill and commit on its own — the exact
## accident this exists to stop.

## Seconds of held interact required to commit. Long enough that a panic jump
## (a tap) never reaches it, short enough that a deliberate take feels near-instant.
var hold_time: float = 0.24
## Once held this long it is clearly an interact, not a panic tap, so from here
## `committing` is true and the caller eats the shared jump. A tap released before
## this keeps its jump — panic stays safe.
var swallow_after: float = 0.09
## The charge coasts through a drop in `active` this long (usually the hop the
## press itself caused lifting you out of range), as long as the button stays
## held. Without it a single hop resets the charge and the hold can't finish.
var reacquire_grace: float = 0.18

## 0 while idle, climbs to 1 as the hold completes. Drive the prompt fill from it.
var progress: float = 0.0
## True once the hold is deliberate enough that the caller should swallow the
## shared jump (pad only — on keyboard the buttons don't collide). Read AFTER poll().
var committing: bool = false

var _armed: bool = false
var _elapsed: float = 0.0
var _grace_left: float = 0.0


## Call every physics frame. `active` is whether the prompt is live (in range,
## affordable, not yet taken). Returns true on the frame the hold fills.
func poll(active: bool, delta: float) -> bool:
	committing = false
	var held: bool = Input.is_action_pressed(&"interact")
	if not active:
		# Off the prompt. If we were mid-charge and the button is still down, this
		# is almost always the hop the press caused — coast on grace rather than
		# throw the charge away. Anything else resets.
		if _armed and _elapsed > 0.0 and held and _grace_left > 0.0:
			_grace_left -= delta
			committing = _elapsed >= swallow_after
			return false
		_reset()
		return false
	if not held:
		# Released: arm for a fresh hold and clear any part-filled progress.
		_armed = true
		_elapsed = 0.0
		_grace_left = 0.0
		progress = 0.0
		return false
	if not _armed:
		# Held since before the prompt opened — ignore until released once.
		return false
	_grace_left = reacquire_grace
	_elapsed += delta
	progress = clampf(_elapsed / hold_time, 0.0, 1.0)
	committing = _elapsed >= swallow_after
	if _elapsed >= hold_time:
		_reset()
		return true
	return false


func _reset() -> void:
	_armed = false
	_elapsed = 0.0
	_grace_left = 0.0
	progress = 0.0
	committing = false
