extends Node
## Background music. Autoloaded as `Music`.
##
## Placeholder synthwave (tools/gen_music.py), swapped for a real track at M9.
## An autoload so it survives scene changes — the track keeps playing across the
## hub<->delve transition instead of restarting every time.
##
## Two tracks: a driving one for the delve, a calmer one for the hub. Switching
## is a soft fade so it does not jump-cut.

## The delve owns three moods; one is drawn per descent so back-to-back runs
## do not share a soundtrack. The reroll is free: the hub track plays between
## runs, so every entry into the mine is a fresh pick. Plain randomness —
## ambience is not gameplay and must not touch the seeded streams.
const DELVE_VARIANTS: Array[String] = [
	"res://assets/audio/music_delve.wav",
	"res://assets/audio/music_delve_b.wav",
	"res://assets/audio/music_delve_c.wav",
]
const HUB: String = "res://assets/audio/music_hub.wav"
## The boss vamp: cut in when a boss engages, cut back out when it dies or you
## leave the room.
const BOSS: String = "res://assets/audio/music_boss.wav"

## Chance to drift to a DIFFERENT delve mood on a room change, so a long run's
## soundtrack breathes instead of looping one bed for five rooms.
@export_range(0.0, 1.0) var room_shuffle_chance: float = 0.35

## Master music level in dB. Music sits under the SFX; -12 is a starting point.
@export var volume_db: float = -12.0
@export var fade_time: float = 0.8

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current: StringName = &""
var _muted: bool = false
## The player's volume slider, 0..1, applied on top of the tuned bed level.
## Owned and persisted by the Settings autoload; this just enacts it.
var _user_volume: float = 1.0
## Context attenuation in dB, set per play() call by the scene that owns the
## moment (0 title, quieter in the hub, quieter still in the delve).
var _attenuation: float = 0.0
## The delve variant currently underground, so the boss fight can hand back to
## the same mood it interrupted.
var _delve_path: String = ""
var _boss_active: bool = false
var _mix_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_mix_rng.randomize()
	# Two players so we can crossfade one out while the other comes in.
	for i: int in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"Master"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	# The mix reacts to the run: bosses cut in their own vamp, and room changes
	# sometimes drift the delve to another mood. Ambience only — unseeded, and
	# nothing here ever feeds back into gameplay.
	Events.boss_engaged.connect(_on_boss_engaged)
	Events.enemy_died.connect(_on_enemy_died)
	Events.room_entered.connect(_on_room_entered)


func _on_boss_engaged(_enemy: Node2D) -> void:
	if _boss_active or _current != &"delve":
		return
	_boss_active = true
	_crossfade_to(BOSS)


func _on_enemy_died(enemy: Node2D) -> void:
	var fallen: Enemy = enemy as Enemy
	if not _boss_active or fallen == null or not fallen.stats.is_boss:
		return
	_boss_active = false
	_crossfade_to(_delve_path)


func _on_room_entered(_index: int, _id: String) -> void:
	if _current != &"delve":
		return
	if _boss_active:
		# Fled the boss room with the boss alive: the vamp does not follow you.
		_boss_active = false
		_crossfade_to(_delve_path)
		return
	if _mix_rng.randf() < room_shuffle_chance and DELVE_VARIANTS.size() > 1:
		var pool: Array[String] = DELVE_VARIANTS.duplicate()
		pool.erase(_delve_path)
		_delve_path = pool[_mix_rng.randi_range(0, pool.size() - 1)]
		_crossfade_to(_delve_path)


## Play a named track, looping, at a per-context attenuation below the tuned
## bed: the title runs the hub track at full bed, the hub runs it quieter, the
## delve quieter still (Dustin's mix call — menus can be loud, play cannot).
## Re-playing the current track does not restart it, but it DOES fade to the
## new attenuation, which is exactly the title -> hub transition.
func play(track: StringName, attenuation_db: float = 0.0) -> void:
	_attenuation = attenuation_db
	if track == _current:
		if not _players.is_empty():
			_fade(_players[_active], _players[_active].volume_db, _target_db())
		return
	_current = track
	_boss_active = false
	var path: String = HUB
	if track == &"delve":
		path = DELVE_VARIANTS[_mix_rng.randi_range(0, DELVE_VARIANTS.size() - 1)]
		_delve_path = path
	_crossfade_to(path)


## The actual player swap. Everything that changes what is playing goes
## through here — play(), the boss cuts, the room-change drift.
func _crossfade_to(path: String) -> void:
	var stream: AudioStreamWAV = _looped(path)
	if stream == null:
		return

	var incoming: AudioStreamPlayer = _players[1 - _active]
	var outgoing: AudioStreamPlayer = _players[_active]
	_active = 1 - _active

	incoming.stream = stream
	incoming.play()
	_fade(incoming, -80.0, _target_db())
	_fade(outgoing, outgoing.volume_db, -80.0)


## Load a WAV and force it to loop. Imported WAVs default to no loop; setting it
## at runtime avoids fiddling with .import files that Godot regenerates.
func _looped(path: String) -> AudioStreamWAV:
	var base: AudioStreamWAV = load(path) as AudioStreamWAV
	if base == null:
		push_error("Music: no stream at %s — run python3 tools/gen_music.py" % path)
		return null
	var stream: AudioStreamWAV = base.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# 16-bit mono: two bytes per frame.
	stream.loop_end = stream.data.size() / 2
	return stream


func set_muted(muted: bool) -> void:
	_muted = muted
	_fade(_players[_active], _players[_active].volume_db, _target_db())


## Live volume from the settings slider. Applied instantly, not faded — a slider
## that lags its own drag reads as broken.
func set_user_volume(value: float) -> void:
	_user_volume = clampf(value, 0.0, 1.0)
	if not _players.is_empty():
		_players[_active].volume_db = _target_db()


## The level the active player should sit at: the tuned bed (volume_db) scaled
## by the user's slider, or silence when muted / slid to zero.
func _target_db() -> float:
	if _muted or _user_volume <= 0.001:
		return -80.0
	return volume_db + _attenuation + linear_to_db(_user_volume)


func _fade(player: AudioStreamPlayer, from_db: float, to_db: float) -> void:
	player.volume_db = from_db
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, fade_time)
	if to_db <= -79.0:
		tween.tween_callback(player.stop)
