class_name UiScaler
extends RefCounted
## Scales a Control in place around a chosen point on its OWN rect, instead of
## Godot's default top-left pivot, so a menu panel or HUD cluster grows without
## sliding off the edge/corner it is meant to hug. `anchor` is 0..1 per axis:
## (0,0) top-left, (1,0) top-right, (0.5,0) top-centre, (0.5,1) bottom-centre,
## (0.5,0.5) centre — matching whichever corner or edge the control is already
## anchored to in its scene.
##
## Deliberately never touches Window.content_scale_factor or anything the
## camera reads: that was the first attempt at Interface Size, and because it
## scaled the whole rendered viewport, it zoomed the game world right along
## with the UI — which is how a floor hazard disappeared off screen at higher
## settings. Scaling only these Control subtrees keeps gameplay pixel-identical
## no matter what Interface Size is set to.
static func apply(control: Control, scale: float, anchor: Vector2 = Vector2(0.5, 0.5)) -> void:
	control.pivot_offset = control.size * anchor
	control.scale = Vector2(scale, scale)
