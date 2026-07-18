class_name TimberAnchor
extends Node2D
## A beam the timber hook can bite: an authored anchor point (room glyph 'o'),
## nothing more. All behaviour lives in the player's Hook state; this just
## stands in the dark looking grabbable — a timber crossbeam with a rope knot,
## lit faintly so it reads from across a shaft.


func _ready() -> void:
	add_to_group(&"anchors")

	var beam: ColorRect = ColorRect.new()
	beam.size = Vector2(44, 10)
	beam.position = Vector2(-22, -5)
	beam.color = Color(0.42, 0.32, 0.2)
	add_child(beam)

	var knot: ColorRect = ColorRect.new()
	knot.size = Vector2(10, 16)
	knot.position = Vector2(-5, 2)
	knot.color = Color(0.68, 0.54, 0.34)
	add_child(knot)

	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.BLACK)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 64
	texture.height = 64
	var light: PointLight2D = PointLight2D.new()
	light.texture = texture
	light.color = Color(1.0, 0.85, 0.6)
	light.energy = 0.5
	light.texture_scale = 1.6
	add_child(light)
