extends Node
## Placeholder sound. Autoloaded as `Sfx`.
##
## Listens to the Events bus rather than being called by the player or the dummy,
## so nothing that makes a noise has to know that audio exists. Adding a sound to
## an existing event means editing this file only.
##
## Voices are pooled: a fresh AudioStreamPlayer per sound would cut off the
## previous one mid-tail, so rapid hits would click instead of overlapping.
##
## The pitch jitter uses unseeded RNG, which is safe only because audio never
## feeds back into gameplay. Anything that did would have to come from the GDD's
## central seeded service or replays would diverge.

const VOICES: int = 12

const HIT: AudioStream = preload("res://assets/audio/hit.wav")
const PARRY: AudioStream = preload("res://assets/audio/parry.wav")
const JUMP: AudioStream = preload("res://assets/audio/jump.wav")
const LAND: AudioStream = preload("res://assets/audio/land.wav")
const ROLL: AudioStream = preload("res://assets/audio/roll.wav")
const HURT: AudioStream = preload("res://assets/audio/hurt.wav")

## Master trim for the placeholders, in dB. They are synthesised and loud.
@export var volume_db: float = -6.0
## Random pitch spread per shot. Without this, repeated hits sound like a
## machine; a little variation is most of what makes them sound like impacts.
@export var pitch_jitter: float = 0.12

var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The player's SFX slider (0..1) as a dB trim, added to every voice.
var _user_db: float = 0.0


## Settings drives this from the options screen's SFX slider.
func set_user_volume(value: float) -> void:
	_user_db = -80.0 if value <= 0.001 else linear_to_db(clampf(value, 0.0, 1.0))


func _ready() -> void:
	_rng.randomize()
	for i: int in VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_voices.append(player)

	Events.hit_landed.connect(_on_hit_landed)
	Events.parry_succeeded.connect(_on_parry_succeeded)
	Events.player_hurt.connect(_on_player_hurt)
	Events.player_jumped.connect(_on_player_jumped)
	Events.player_landed.connect(_on_player_landed)
	Events.player_rolled.connect(_on_player_rolled)


func play(stream: AudioStream, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if stream == null:
		return
	# Round-robin. Oldest voice loses, which at 12 voices is inaudible.
	var voice: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = maxf(0.01, pitch + _rng.randf_range(-pitch_jitter, pitch_jitter))
	voice.volume_db = volume_db + volume_offset_db + _user_db
	voice.play()


func _on_hit_landed(_damage: float, was_riposte: bool) -> void:
	# A riposte should sound like a payoff: lower and louder reads as heavier.
	play(HIT, 0.8 if was_riposte else 1.0, 3.0 if was_riposte else 0.0)


func _on_parry_succeeded() -> void:
	play(PARRY, 1.0, 2.0)


func _on_player_hurt(_damage: float) -> void:
	play(HURT)


func _on_player_jumped() -> void:
	play(JUMP)


func _on_player_landed() -> void:
	play(LAND)


func _on_player_rolled() -> void:
	play(ROLL)
