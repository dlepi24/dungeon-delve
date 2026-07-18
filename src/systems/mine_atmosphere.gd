extends Node
## The mine's darkness: a CanvasModulate dims the world, a warm lantern light
## rides the player, and a vignette pulls the screen edges in. Built entirely
## from gradients at runtime — no textures on disk, so gray-box discipline
## holds while the scene stops looking like an editor viewport.
##
## Readability is the constraint (GDD: telegraphs ARE the combat language), so
## the darkness is deliberately mild and every value is exported for tuning.
## The HUD lives on CanvasLayers — separate canvases — so it stays full bright.

## World tint. 1,1,1 = off. Keep it gentle: telegraph colours must survive.
@export var darkness: Color = Color(0.58, 0.58, 0.68)
@export var lantern_colour: Color = Color(1.0, 0.88, 0.7)
@export var lantern_energy: float = 1.1
## Light texture scale — roughly the glow radius in multiples of 128 px.
@export var lantern_scale: float = 5.0
## How dark the screen corners get. 0 disables the vignette.
@export_range(0.0, 1.0) var vignette_strength: float = 0.4

var _lantern: PointLight2D = null


func _ready() -> void:
	# Deferred: the scene tree is still assembling during _ready and the
	# modulate/vignette want to sit on the root.
	_build.call_deferred()


func _build() -> void:
	var cm: CanvasModulate = CanvasModulate.new()
	cm.color = darkness
	get_parent().add_child(cm)

	if vignette_strength > 0.0:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 25
		var rect: TextureRect = TextureRect.new()
		rect.texture = _vignette_texture()
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(rect)
		add_child(layer)


## The lantern follows the player; resolved lazily per the CLAUDE.md
## _ready-order discipline, and re-attached if the player is ever rebuilt.
func _process(_delta: float) -> void:
	if _lantern != null and is_instance_valid(_lantern):
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	_lantern = PointLight2D.new()
	_lantern.texture = _light_texture()
	_lantern.color = lantern_colour
	_lantern.energy = lantern_energy
	_lantern.texture_scale = lantern_scale
	_lantern.position = Vector2(0, -30)
	player.add_child(_lantern)


func _light_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.BLACK)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 256
	texture.height = 256
	return texture


func _vignette_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, vignette_strength),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 512
	texture.height = 512
	return texture
