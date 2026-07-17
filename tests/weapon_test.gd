extends Node2D
## Weapons change how you fight — reach, speed, damage, poise — and are run-scoped
## (found in the mine, lost on death/extract, while permanent stat upgrades stay).
## The root fix for "upgrades feel flat": a weapon reshapes combat, not a number.
##
## Run: godot --headless --path . res://tests/weapon_test.tscn

const PLAYER := preload("res://src/player/player.tscn")
var _fail := 0
func _ck(c: bool, m: String) -> void:
	if c: print("  PASS  " + m)
	else: _fail += 1; print("  FAIL  " + m)

func _ready() -> void:
	GameState.reset_save()
	var p: Player = PLAYER.instantiate()
	add_child(p)
	await get_tree().physics_frame

	_ck(p.weapon_name() == "Pickaxe", "player starts on the base pickaxe")
	var base_dmg := p.weapon_damage()
	var base_startup := p.attack_startup_ticks()
	var base_reach := p.weapon_hitbox_size().x

	var maul: WeaponData = load("res://src/systems/weapons/maul.tres")
	p.equip_weapon(maul)
	_ck(p.weapon_damage() > base_dmg and p.attack_startup_ticks() > base_startup and p.weapon_hitbox_size().x > base_reach,
		"the Maul is slower, stronger and longer than the pickaxe")
	_ck(is_equal_approx((p.attack_hitbox.get_node("CollisionShape2D").shape as RectangleShape2D).size.x, maul.hitbox_size.x),
		"equipping physically resizes the attack hitbox")

	var dagger: WeaponData = load("res://src/systems/weapons/dagger.tres")
	p.equip_weapon(dagger)
	_ck(p.attack_startup_ticks() < base_startup, "the Dagger is faster than the pickaxe")

	p.reset_for_new_run()
	_ck(p.weapon_name() == "Pickaxe", "a new run resets to the pickaxe (weapons are run-scoped)")

	# Meta upgrade persists across that reset; the weapon did not.
	GameState.upgrade_levels[&"damage"] = 3
	_ck(p.attack_speed_multiplier() > 1.0, "the permanent weapon-speed upgrade survives a new run")

	GameState.reset_save()
	p.queue_free()
	if _fail == 0:
		print("\nWEAPON TEST OK"); get_tree().quit(0)
	else:
		printerr("\n%d weapon assertion(s) failed" % _fail); get_tree().quit(1)
