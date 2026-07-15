extends CanvasLayer
## Minimal in-game HUD. Right now: the player's health.
##
## Exists because health was only visible on the F3 debug panel, which meant the
## fight was unjudgeable — you cannot decide whether to greed a hit or retreat if
## you cannot see how close you are to dying. That is a combat decision, not a
## cosmetic one.
##
## Deliberately thin. M7 owns the real product shell (menus, pause, settings,
## controller glyphs); this is the smallest thing that makes M3 playable.

@export var player: Player

@onready var _bar: HealthBar = $Bar
@onready var _label: Label = $Label


func _ready() -> void:
	if player == null:
		return
	_bar.hide_when_full = false
	_bar.bar_size = Vector2(280, 18)
	_bar.set_ratio(1.0)


func _process(_delta: float) -> void:
	if player == null:
		return
	_bar.set_ratio(player.health / maxf(1.0, player.max_health))
	_label.text = "%d / %d" % [roundi(player.health), roundi(player.max_health)]
