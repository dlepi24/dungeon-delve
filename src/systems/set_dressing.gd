class_name SetDressing
extends Object
## Procedural mid-ground props — crates, barrels, rubble, hanging lanterns — that
## fill the flat floors and dead air the atmosphere pass exposed. Built from
## layered, directionally-shaded shapes (light from the upper-left, matching the
## tileset), so under the CanvasModulate grade they read as worked objects in a
## lived-in mine rather than the flat gray-box rects we just tore out.
##
## Pure factories: each make_* returns a Node2D positioned with its BASE at the
## local origin (so callers drop it on a floor with a single position). Visual
## only — nothing here collides, ticks gameplay, or touches the seeded Rng.

const WOOD_BODY: Color = Color(0.32, 0.22, 0.13)
const WOOD_LIT: Color = Color(0.47, 0.34, 0.2)
const WOOD_DARK: Color = Color(0.18, 0.12, 0.07)
const IRON: Color = Color(0.24, 0.22, 0.22)
const ROCK_BODY: Color = Color(0.2, 0.19, 0.2)
const ROCK_LIT: Color = Color(0.32, 0.3, 0.3)
const LANTERN_WARM: Color = Color(1.0, 0.78, 0.42)


static func _rect(parent: Node2D, at: Vector2, size: Vector2, colour: Color) -> void:
	var r: ColorRect = ColorRect.new()
	r.position = at
	r.size = size
	r.color = colour
	parent.add_child(r)


## A wooden crate, base centred on the origin. Body + lit top and left faces +
## an X of planks, so it reads as a box catching the upper-left light.
static func make_crate(w: float = 46.0, h: float = 46.0) -> Node2D:
	var n: Node2D = Node2D.new()
	_rect(n, Vector2(-w * 0.5 - 1, -h - 1), Vector2(w + 2, h + 2), WOOD_DARK)
	_rect(n, Vector2(-w * 0.5, -h), Vector2(w, h), WOOD_BODY)
	_rect(n, Vector2(-w * 0.5, -h), Vector2(w, 4), WOOD_LIT)          # top face
	_rect(n, Vector2(-w * 0.5, -h), Vector2(4, h), WOOD_LIT)          # left face
	# Plank X, drawn as two thin skewed lines via small rects.
	var band: ColorRect = ColorRect.new()
	band.position = Vector2(-w * 0.5, -h * 0.5 - 2)
	band.size = Vector2(w, 4)
	band.color = WOOD_DARK
	n.add_child(band)
	return n


## A barrel: rounded-ish body (stacked tapering rects) with two iron hoops.
static func make_barrel(w: float = 34.0, h: float = 48.0) -> Node2D:
	var n: Node2D = Node2D.new()
	_rect(n, Vector2(-w * 0.5 - 1, -h - 1), Vector2(w + 2, h + 2), WOOD_DARK)
	_rect(n, Vector2(-w * 0.5, -h), Vector2(w, h), WOOD_BODY)
	_rect(n, Vector2(-w * 0.5, -h), Vector2(6, h), WOOD_LIT)          # lit stave
	_rect(n, Vector2(-w * 0.5, -h + 3), Vector2(w, 3), IRON)          # top hoop
	_rect(n, Vector2(-w * 0.5, -6), Vector2(w, 3), IRON)             # bottom hoop
	_rect(n, Vector2(-w * 0.5, -h), Vector2(w, 3), WOOD_LIT)          # lid rim
	return n


## A low pile of broken rock at a wall base. `spread` controls its width.
static func make_rubble(spread: float = 60.0) -> Node2D:
	var n: Node2D = Node2D.new()
	# A few overlapping chunks; sizes/positions derived from the spread, not
	# random, so a given placement is stable across bakes.
	var chunks: Array = [
		[Vector2(-spread * 0.5, -14), Vector2(26, 14)],
		[Vector2(-spread * 0.16, -22), Vector2(30, 22)],
		[Vector2(spread * 0.2, -12), Vector2(24, 12)],
	]
	for c: Array in chunks:
		var at: Vector2 = c[0]
		var size: Vector2 = c[1]
		_rect(n, at, size, ROCK_BODY)
		_rect(n, at, Vector2(size.x, 3), ROCK_LIT)
	return n


## A hanging lantern on a chain from the ceiling: a chain, a warm glowing bulb,
## and a real PointLight2D so it pools light onto the rock. `drop` is chain length.
static func make_lantern(drop: float = 70.0) -> Node2D:
	var n: Node2D = Node2D.new()
	_rect(n, Vector2(-1, 0), Vector2(2, drop), IRON)                  # chain
	_rect(n, Vector2(-6, drop), Vector2(12, 16), Color(0.3, 0.26, 0.2))  # casing
	_rect(n, Vector2(-4, drop + 3), Vector2(8, 10), LANTERN_WARM)     # flame
	var light: PointLight2D = PointLight2D.new()
	light.texture = _glow()
	light.color = LANTERN_WARM
	light.energy = 1.0
	light.texture_scale = 1.6
	light.position = Vector2(0, drop + 8)
	n.add_child(light)
	return n


## A bare hanging chain from the ceiling, ending in a hook or an ore hook-lump.
## No light — it is silhouette depth for the upper dead air. `drop` is length.
static func make_chain(drop: float = 90.0) -> Node2D:
	var n: Node2D = Node2D.new()
	# Links as a dotted column, so it reads as chain rather than a solid bar.
	var y: float = 0.0
	while y < drop:
		_rect(n, Vector2(-1.5, y), Vector2(3, 5), IRON)
		y += 8.0
	_rect(n, Vector2(-4, drop), Vector2(8, 7), Color(0.28, 0.26, 0.26))  # hook lump
	return n


## A shallow timber support bracket tucked against a ceiling — a bit of worked
## structure up in the dead air. Spans `w`, hangs `h` down from the origin.
static func make_bracket(w: float = 70.0, h: float = 20.0) -> Node2D:
	var n: Node2D = Node2D.new()
	_rect(n, Vector2(-w * 0.5, 0), Vector2(w, 7), WOOD_BODY)
	_rect(n, Vector2(-w * 0.5, 0), Vector2(w, 3), WOOD_LIT)
	_rect(n, Vector2(-w * 0.5, 0), Vector2(7, h), WOOD_DARK)      # left post
	_rect(n, Vector2(w * 0.5 - 7, 0), Vector2(7, h), WOOD_DARK)   # right post
	return n


static func _glow() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 128
	t.height = 128
	return t
