class_name Rumble
extends RefCounted
## Pad haptics, one verb per combat beat. Static helpers like Cursor — no
## autoload, no state, headless-guarded.
##
## The mix mirrors the hitstop ladder: a normal hit is a tap, a riposte is a
## thump, taking damage leans on the heavy motor, dying is the big one. Weak
## motor = high-frequency buzz (impacts you deal), strong motor = low rumble
## (things done to you). No-ops with no pad connected.


static func _buzz(weak: float, strong: float, duration: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, duration)


static func hit() -> void:
	_buzz(0.4, 0.0, 0.1)


static func riposte() -> void:
	_buzz(0.8, 0.4, 0.2)


static func parry() -> void:
	_buzz(0.9, 0.2, 0.12)


static func hurt() -> void:
	_buzz(0.2, 0.7, 0.2)


static func death() -> void:
	_buzz(1.0, 1.0, 0.6)


static func boss() -> void:
	_buzz(0.2, 0.6, 0.5)
