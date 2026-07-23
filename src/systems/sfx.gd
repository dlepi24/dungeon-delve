extends Node
## The sound layer. Autoloaded as `Sfx`.
##
## Listens to the Events bus rather than being called by the things that make
## noise, so nothing that makes a sound has to know audio exists. Adding a sound
## to an existing event means editing THIS file only.
##
## Combat is LAYERED (the Dead Cells trick): every connect plays a weapon-class
## *impact* one-shot stacked over the target's *material* one-shot, so a Blunt on
## Armour and a Blade on Flesh are audibly different from a handful of files
## rather than one baked sound per pairing. hit_landed carries both tags.
##
## Three pools on three buses: gameplay voices on SFX, menu ticks on UI, and one
## looping player on Ambience for the mine's wind bed. UI sound is global and
## zero-touch — it rides the viewport's focus changes and the ui_accept/ui_cancel
## actions, gated on "a menu actually has focus" so a jump in the delve is silent.
##
## The pitch jitter uses unseeded RNG, which is safe only because audio never
## feeds back into gameplay. Anything that did would have to come from the seeded
## Rng service or replays would diverge.

const VOICES: int = 14
const UI_VOICES: int = 4

# Weapon-class impact transients — the "what swung" layer.
const IMPACTS: Dictionary = {
	&"pick": preload("res://assets/audio/impact_pick.wav"),
	&"blade": preload("res://assets/audio/impact_blade.wav"),
	&"blunt": preload("res://assets/audio/impact_blunt.wav"),
}
# Material response layers — the "what got hit" layer, stacked under the impact.
const MATERIALS: Dictionary = {
	&"flesh": preload("res://assets/audio/mat_flesh.wav"),
	&"armor": preload("res://assets/audio/mat_armor.wav"),
	&"bone": preload("res://assets/audio/mat_bone.wav"),
	&"stone": preload("res://assets/audio/mat_stone.wav"),
	&"wood": preload("res://assets/audio/mat_wood.wav"),
	&"ecto": preload("res://assets/audio/mat_ecto.wav"),
}

const PARRY: AudioStream = preload("res://assets/audio/parry.wav")
const RIPOSTE: AudioStream = preload("res://assets/audio/riposte.wav")
const POISE_BREAK: AudioStream = preload("res://assets/audio/poise_break.wav")
const WHOOSH_LIGHT: AudioStream = preload("res://assets/audio/whoosh_light.wav")
const WHOOSH_HEAVY: AudioStream = preload("res://assets/audio/whoosh_heavy.wav")
const ENEMY_DEATH: AudioStream = preload("res://assets/audio/enemy_death.wav")
const PLAYER_DEATH: AudioStream = preload("res://assets/audio/player_death.wav")

const JUMP: AudioStream = preload("res://assets/audio/jump.wav")
const LAND: AudioStream = preload("res://assets/audio/land.wav")
const LAND_SOFT: AudioStream = preload("res://assets/audio/land_soft.wav")
const ROLL: AudioStream = preload("res://assets/audio/roll.wav")
const HURT: AudioStream = preload("res://assets/audio/hurt.wav")

const PICKUP_ORE: AudioStream = preload("res://assets/audio/pickup_ore.wav")
const PICKUP_HEART: AudioStream = preload("res://assets/audio/pickup_heart.wav")
const PICKUP_BUFF: AudioStream = preload("res://assets/audio/pickup_buff.wav")
const PICKUP_WEAPON: AudioStream = preload("res://assets/audio/pickup_weapon.wav")
const BUY_UPGRADE: AudioStream = preload("res://assets/audio/buy_upgrade.wav")
const SHRINE_ACCEPT: AudioStream = preload("res://assets/audio/shrine_accept.wav")

const UI_MOVE: AudioStream = preload("res://assets/audio/ui_move.wav")
const UI_SELECT: AudioStream = preload("res://assets/audio/ui_select.wav")
const UI_BACK: AudioStream = preload("res://assets/audio/ui_back.wav")
const UI_PAUSE: AudioStream = preload("res://assets/audio/ui_pause.wav")

const AMB_MINE: AudioStream = preload("res://assets/audio/amb_mine.wav")
const HEARTBEAT: AudioStream = preload("res://assets/audio/heartbeat.wav")

## Master trim for the synthesised set, in dB. They are loud by design.
@export var volume_db: float = -6.0
## Random pitch spread per shot. Without this, repeated hits sound like a machine;
## a little variation is most of what makes them read as impacts.
@export var pitch_jitter: float = 0.12
## The mine wind bed's level below the SFX bed — atmosphere sits well under play.
@export var ambience_db: float = -20.0
## Below this health ratio the low-health heartbeat starts; above it, it stops.
@export_range(0.0, 1.0) var heartbeat_ratio: float = 0.3
## The heartbeat's level. Tension, not a jump-scare.
@export var heartbeat_db: float = -8.0
## A soft landing plays below this fall speed (px/s); a hard thud at or above.
@export var hard_land_speed: float = 520.0

var _voices: Array[AudioStreamPlayer] = []
var _ui_voices: Array[AudioStreamPlayer] = []
var _amb: AudioStreamPlayer = null
var _heart: AudioStreamPlayer = null
var _next: int = 0
var _ui_next: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	# ALWAYS, so menu ticks (select/back, driven from _input) still sound while the
	# tree is paused — the pause and settings menus run paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i: int in VOICES:
		_voices.append(_make_voice(&"SFX"))
	for i: int in UI_VOICES:
		_ui_voices.append(_make_voice(&"UI"))
	_amb = _make_voice(&"Ambience")
	_heart = _make_voice(&"SFX")

	# Combat.
	Events.hit_landed.connect(_on_hit_landed)
	Events.parry_succeeded.connect(_on_parry_succeeded)
	Events.poise_broken.connect(_on_poise_broken)
	Events.player_attacked.connect(_on_player_attacked)
	Events.enemy_died.connect(_on_enemy_died)
	# Movement + damage.
	Events.player_hurt.connect(_on_player_hurt)
	Events.player_jumped.connect(_on_player_jumped)
	Events.player_landed.connect(_on_player_landed)
	Events.player_rolled.connect(_on_player_rolled)
	Events.player_died.connect(_on_player_died)
	Events.player_health_changed.connect(_on_health_changed)
	# Pickups + economy.
	Events.haul_collected.connect(_on_haul_collected)
	Events.player_healed.connect(_on_player_healed)
	Events.buff_gained.connect(_on_buff_gained)
	Events.weapon_equipped.connect(_on_weapon_taken)
	Events.weapon_stowed.connect(_on_weapon_taken)
	Events.upgrade_purchased.connect(_on_upgrade_purchased)
	Events.shrine_accepted.connect(_on_shrine_accepted)
	# The mine's own breath: on underground, off when the run ends.
	Events.run_started.connect(_on_run_started)
	Events.run_extracted.connect(_on_run_ended.unbind(1))
	Events.run_lost.connect(_on_run_ended.unbind(1))
	Events.delve_completed.connect(_on_run_ended)

	# UI sound, wired once, globally. Focus moving = a nav tick; the accept/cancel
	# actions = select/back — but only while a Control owns focus, so gameplay
	# verbs that share those keys stay silent.
	get_tree().root.gui_focus_changed.connect(_on_focus_changed)


func _make_voice(bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


## Play a one-shot on the next SFX voice. Round-robin: the oldest voice loses,
## which at this pool size is inaudible.
func play(stream: AudioStream, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if stream == null:
		return
	var voice: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = maxf(0.01, pitch + _rng.randf_range(-pitch_jitter, pitch_jitter))
	voice.volume_db = volume_db + volume_offset_db
	voice.play()


## A menu tick on the UI bus (dry, and scaled by the SFX slider via the bus graph).
func play_ui(stream: AudioStream, volume_offset_db: float = 0.0) -> void:
	if stream == null:
		return
	var voice: AudioStreamPlayer = _ui_voices[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_voices.size()
	voice.stream = stream
	voice.pitch_scale = 1.0
	voice.volume_db = volume_db + volume_offset_db
	voice.play()


# --- combat ----------------------------------------------------------------

func _on_hit_landed(damage: float, was_riposte: bool, impact: StringName, material: StringName) -> void:
	# Bigger hits read louder and a touch lower — weight without a new sample.
	var heft: float = clampf((damage - 12.0) / 40.0, 0.0, 1.0)
	var vol: float = lerpf(0.0, 4.0, heft) + (3.0 if was_riposte else 0.0)
	var pitch: float = (0.8 if was_riposte else 1.0) - 0.08 * heft

	play(IMPACTS.get(impact, IMPACTS[&"pick"]) as AudioStream, pitch, vol)
	play(MATERIALS.get(material, MATERIALS[&"flesh"]) as AudioStream, pitch, vol - 1.0)
	if was_riposte:
		# The payoff gets its own heavy confirm on top of the layered connect.
		play(RIPOSTE, 1.0, 2.0)


func _on_parry_succeeded() -> void:
	play(PARRY, 1.0, 2.0)


func _on_poise_broken(_enemy: Node2D) -> void:
	play(POISE_BREAK, 1.0, 1.0)


func _on_player_attacked(impact: StringName) -> void:
	# Blunt weapons cut the air heavier; everything else gets the quick light air.
	var whoosh: AudioStream = WHOOSH_HEAVY if impact == &"blunt" else WHOOSH_LIGHT
	play(whoosh, 1.0, -4.0)


func _on_enemy_died(enemy: Node2D) -> void:
	play(ENEMY_DEATH, 0.95, 1.0)
	# Colour the death with the same material layer, pitched down — a slain wraith
	# dissolves, a slain brute clatters.
	var fallen: Enemy = enemy as Enemy
	if fallen != null and fallen.stats != null:
		play(MATERIALS.get(fallen.stats.material, MATERIALS[&"flesh"]) as AudioStream, 0.75, -2.0)


# --- movement + damage -----------------------------------------------------

func _on_player_hurt(_damage: float) -> void:
	play(HURT)


func _on_player_jumped() -> void:
	play(JUMP)


func _on_player_landed(fall_speed: float) -> void:
	# A short hop scuffs; a real drop thuds and hits a touch louder for its weight.
	if fall_speed >= hard_land_speed:
		play(LAND, 1.0, 1.0)
	else:
		play(LAND_SOFT)


func _on_player_rolled() -> void:
	play(ROLL)


func _on_player_died() -> void:
	play(PLAYER_DEATH, 1.0, 3.0)
	# You can't have a heart still beating on the death screen.
	_stop_heartbeat()


## The low-health heartbeat: on below the threshold, off above. Driven off health
## changes rather than polled, and it rides its own looping voice so it does not
## fight the round-robin pool.
func _on_health_changed(current: float, max_value: float) -> void:
	var ratio: float = current / maxf(1.0, max_value)
	if current > 0.0 and ratio <= heartbeat_ratio:
		if not _heart.playing:
			_heart.stream = _looped(HEARTBEAT)
			_heart.volume_db = heartbeat_db
			_heart.play()
	else:
		_stop_heartbeat()


func _stop_heartbeat() -> void:
	if _heart.playing:
		_heart.stop()


# --- pickups + economy -----------------------------------------------------

func _on_haul_collected(_amount: int, _at: Vector2) -> void:
	# A tiny random pitch step reads as coins clinking rather than one repeated beep.
	play(PICKUP_ORE, 1.0 + _rng.randf_range(-0.06, 0.1))


func _on_player_healed(_amount: float) -> void:
	play(PICKUP_HEART, 1.0, 1.0)


func _on_buff_gained(_buff: BuffData) -> void:
	play(PICKUP_BUFF, 1.0, 1.0)


func _on_weapon_taken(_weapon: WeaponData) -> void:
	play(PICKUP_WEAPON, 1.0, 1.0)


func _on_upgrade_purchased(_id: StringName, _new_level: int) -> void:
	play(BUY_UPGRADE, 1.0, 1.0)


func _on_shrine_accepted(_shrine: ShrineData) -> void:
	play(SHRINE_ACCEPT, 1.0, 1.0)


# --- mine ambience ---------------------------------------------------------

func _on_run_started(_seed_value: int) -> void:
	if _amb.playing:
		return
	_amb.stream = _looped(AMB_MINE)
	_amb.volume_db = ambience_db
	_amb.play()


func _on_run_ended() -> void:
	_amb.stop()
	# Extracting at a sliver of health shouldn't leave the heart pounding in the hub.
	_stop_heartbeat()


## Imported WAVs default to no loop; force it at runtime rather than fighting the
## .import files Godot regenerates. Mirrors Music._looped.
func _looped(base: AudioStream) -> AudioStream:
	var wav: AudioStreamWAV = base as AudioStreamWAV
	if wav == null:
		return base
	var stream: AudioStreamWAV = wav.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2  # 16-bit mono: two bytes per frame.
	return stream


# --- UI sound (global) -----------------------------------------------------

func _on_focus_changed(control: Control) -> void:
	# A real navigation move only — not a null defocus.
	if control != null:
		play_ui(UI_MOVE)


func _input(event: InputEvent) -> void:
	# Only speak for menus: if nothing has GUI focus we're in gameplay, where
	# ui_accept/ui_cancel double as jump/pause and must stay silent here. Uses
	# _input, not _unhandled_input, because a focused Button consumes ui_accept
	# before it reaches the unhandled pass — the click would go unheard.
	if get_viewport().gui_get_focus_owner() == null:
		return
	if event.is_action_pressed(&"ui_accept"):
		play_ui(UI_SELECT)
	elif event.is_action_pressed(&"ui_cancel"):
		play_ui(UI_BACK)
