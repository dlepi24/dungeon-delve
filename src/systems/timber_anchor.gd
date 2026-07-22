class_name TimberAnchor
extends Node2D
## A beam the timber hook can bite: an authored anchor point (room glyph 'o'),
## nothing more. All behaviour lives in the player's Hook state; this just
## stands in the dark looking grabbable — a timber crossbeam with a rope knot,
## lit faintly so it reads from across a shaft.


func _ready() -> void:
	add_to_group(&"anchors")

	# anchor.png: crossbeam with the rope knot, the beam band centred where the
	# old 44x10 rect sat (sprite top at y=-5).
	var art: BakedSprite = BakedSprite.make("anchor", 1.0)
	art.centered = false
	art.offset = Vector2(-22, -5)
	add_child(art)

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
