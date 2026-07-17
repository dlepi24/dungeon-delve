extends Node
## One-shot bootstrap for the enemy .tres files.
##
## Run: godot --headless --path . res://tools/gen_enemies.tscn
##
## Generated once because a typed Array[EnemyAttackData] with embedded
## sub-resources is genuinely fiddly to hand-write and silently wrong when you
## get it subtly off. After this, the .tres files are ordinary resources — edit
## them in the inspector. This is a bootstrap, not a pipeline: do not re-run it
## over tuned values.

const OUT: String = "res://src/enemies/data"


func _attack(name: String, min_r: float, max_r: float, weight: float,
		telegraph: int, active: int, recover: int, damage: float, poise: float,
		dash: float, size: Vector2, offset: Vector2,
		tele_colour: Color, hit_colour: Color) -> EnemyAttackData:
	var a: EnemyAttackData = EnemyAttackData.new()
	a.display_name = name
	a.min_range = min_r
	a.max_range = max_r
	a.weight = weight
	a.telegraph_ms = telegraph
	a.active_ms = active
	a.recover_ms = recover
	a.damage = damage
	a.poise = poise
	a.dash_speed = dash
	a.hitbox_size = size
	a.hitbox_offset = offset
	a.colour_telegraph = tele_colour
	a.colour_attack = hit_colour
	return a


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)

	# --- GRUNT: generalist. Poise ~2-3 pokes, so it can be muscled through, but
	# not for free. Two attacks so it stops reading like a metronome.
	var grunt: EnemyStats = EnemyStats.new()
	grunt.display_name = "Grunt"
	grunt.sprite_sheet = "grunt"
	grunt.haul_reward = 3
	grunt.heart_chance = 0.12
	grunt.heart_heal = 18
	grunt.max_health = 60.0
	grunt.hurt_ms = 160
	grunt.knockback = 170.0
	grunt.move_speed = 105.0
	grunt.acceleration = 700.0
	grunt.aggro_range = 620.0
	grunt.idle_ms = 380
	grunt.stagger_ms = 850
	grunt.can_jump = true
	grunt.jump_height = 120.0
	grunt.body_size = Vector2(32, 64)
	grunt.colour_idle = Color(0.75, 0.4, 0.4)
	grunt.colour_recover = Color(0.5, 0.35, 0.35)
	grunt.attacks = [
		_attack("jab", 0.0, 74.0, 2.0, 380, 80, 320, 8.0, 24.0, 0.0,
			Vector2(70, 56), Vector2(46, -32), Color(0.95, 0.78, 0.25), Color(0.95, 0.2, 0.2)),
		_attack("lunge", 70.0, 190.0, 1.0, 460, 160, 480, 12.0, 30.0, 420.0,
			Vector2(78, 56), Vector2(50, -32), Color(1.0, 0.6, 0.15), Color(1.0, 0.35, 0.1)),
	]
	print("grunt: %d" % ResourceSaver.save(grunt, "%s/grunt.tres" % OUT))

	# --- BRUTE: the parry teacher. Poise is deliberately far beyond what you can
	# chip during its telegraph, so poking it does NOT stop the swing. Parry or
	# roll. This is the enemy that makes the pillar matter.
	var brute: EnemyStats = EnemyStats.new()
	brute.display_name = "Brute"
	brute.sprite_sheet = "brute"
	brute.haul_reward = 8
	brute.heart_chance = 0.30
	brute.heart_heal = 30
	brute.max_health = 150.0
	brute.hurt_ms = 120
	brute.knockback = 90.0
	brute.move_speed = 62.0
	brute.acceleration = 380.0
	brute.aggro_range = 700.0
	brute.idle_ms = 520
	brute.stagger_ms = 1100
	# Cannot jump: a slow heavy thing that cannot follow you onto a ledge is
	# readable and characterful, and gives you a genuine out.
	brute.can_jump = false
	brute.body_size = Vector2(48, 88)
	brute.colour_idle = Color(0.55, 0.3, 0.5)
	brute.colour_recover = Color(0.4, 0.25, 0.38)
	brute.attacks = [
		_attack("overhead", 0.0, 92.0, 2.0, 750, 120, 700, 26.0, 90.0, 0.0,
			Vector2(104, 78), Vector2(62, -44), Color(1.0, 0.85, 0.3), Color(1.0, 0.15, 0.35)),
		_attack("sweep", 0.0, 140.0, 1.0, 600, 140, 560, 18.0, 70.0, 0.0,
			Vector2(150, 46), Vector2(78, -24), Color(1.0, 0.7, 0.45), Color(1.0, 0.3, 0.5)),
	]
	print("brute: %d" % ResourceSaver.save(brute, "%s/brute.tres" % OUT))

	# --- DART: the roll teacher. Almost no poise, so a single poke interrupts it.
	# Fast and committed: roll through the lunge and it sails past.
	var dart: EnemyStats = EnemyStats.new()
	dart.display_name = "Dart"
	dart.sprite_sheet = "dart"
	dart.haul_reward = 2
	dart.heart_chance = 0.06
	dart.heart_heal = 12
	dart.max_health = 38.0
	dart.hurt_ms = 200
	dart.knockback = 260.0
	dart.move_speed = 150.0
	dart.acceleration = 1100.0
	dart.aggro_range = 720.0
	dart.idle_ms = 300
	dart.stagger_ms = 900
	dart.can_jump = true
	dart.jump_height = 150.0
	dart.jump_cooldown_ms = 500
	dart.body_size = Vector2(26, 48)
	dart.colour_idle = Color(0.35, 0.7, 0.5)
	dart.colour_recover = Color(0.25, 0.45, 0.35)
	dart.attacks = [
		_attack("dash", 96.0, 260.0, 3.0, 300, 200, 480, 8.0, 10.0, 620.0,
			Vector2(44, 44), Vector2(24, -24), Color(0.9, 0.95, 0.35), Color(0.3, 1.0, 0.6)),
		_attack("peck", 0.0, 64.0, 1.0, 220, 70, 300, 5.0, 6.0, 0.0,
			Vector2(40, 40), Vector2(26, -24), Color(0.75, 1.0, 0.5), Color(0.5, 1.0, 0.75)),
	]
	print("dart: %d" % ResourceSaver.save(dart, "%s/dart.tres" % OUT))
	get_tree().quit()
