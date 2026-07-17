class_name Cursor
extends RefCounted
## Mouse-cursor policy, in one place: hidden during play, visible in menus.
##
## Static helpers rather than an autoload so the check gate's autoload list does
## not grow for two one-liners. Safe to call from anywhere.
##
## LMB/RMB are attack/parry with no cursor aiming, so hiding the cursor during
## play costs nothing and removes the one thing on screen that is not the game.
##
## Every call is headless-guarded: tools/check.tscn and the test scenes run with
## no display server, and asking a headless driver to change the mouse mode logs
## an error per call (same story as Keybinds.label_for).


static func gameplay() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


static func menu() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
