extends Control
## The settings screen: music volume, window mode, and the key rebinder.
## Reachable from the title menu and from pause.
##
## Thin by design — every row just calls into the autoload that owns the state
## (Settings for volume/window, Keybinds via the embedded KeybindScreen), so
## opening this from two places cannot produce two divergent behaviours.

signal closed

@onready var _panel: PanelContainer = $Panel
@onready var _volume: HSlider = $Panel/Margin/Rows/VolumeRow/Slider
@onready var _volume_value: Label = $Panel/Margin/Rows/VolumeRow/Value
@onready var _fullscreen: CheckButton = $Panel/Margin/Rows/FullscreenRow/Toggle
@onready var _controls: Button = $Panel/Margin/Rows/Controls
@onready var _back: Button = $Panel/Margin/Rows/Back
@onready var _keybinds: Control = $KeybindScreen


func _ready() -> void:
	# Usable while the tree is paused (opened from the pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_keybinds.visible = false
	_keybinds.closed.connect(_on_keybinds_closed)
	_controls.pressed.connect(_on_controls)
	_back.pressed.connect(func() -> void: closed.emit())
	_volume.value_changed.connect(_on_volume_changed)
	_fullscreen.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))


## Sync the widgets from live state every time the menu opens — it can be
## changed elsewhere (another session, a hand-edited cfg) and stale widgets
## would then LIE, then clobber.
func open() -> void:
	visible = true
	_panel.visible = true
	_keybinds.visible = false
	_volume.set_value_no_signal(Settings.music_volume * 100.0)
	_volume_value.text = "%d%%" % roundi(Settings.music_volume * 100.0)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)


func _on_volume_changed(value: float) -> void:
	Settings.set_music_volume(value / 100.0)
	_volume_value.text = "%d%%" % roundi(value)


func _on_controls() -> void:
	_panel.visible = false
	_keybinds.visible = true


func _on_keybinds_closed() -> void:
	_keybinds.visible = false
	_panel.visible = true
