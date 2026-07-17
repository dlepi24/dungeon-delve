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

	# M7: the 2-slot loadout. Both weapons are held, the newest is in hand, and
	# swapping is live. A third pickup replaces the slot you are NOT holding.
	_ck(p.held_weapons.size() == 2 and p.active_slot == 1, "two pickups fill both slots, newest in hand")
	p.select_weapon_slot(0)
	_ck(p.weapon_name() == maul.display_name, "swapping to slot 1 puts the Maul back in hand")
	var spear: WeaponData = load("res://src/systems/weapons/spear.tres")
	p.equip_weapon(spear)
	_ck(p.weapon_name() == spear.display_name and p.held_weapons[1] == spear,
		"a third weapon replaces the inactive slot and comes up in hand")
	_ck(p.held_weapons[0] == maul, "the weapon you were holding is never silently replaced")

	# Session scoping (GDD 2026-07-17): surviving keeps the loadout, dying loses
	# it. reset_for_new_run models arriving anywhere alive; lose_run is death.
	p.reset_for_new_run()
	_ck(p.weapon_name() == spear.display_name and p.held_weapons.size() == 2,
		"surviving a run banks the loadout — extract and you stay armed")
	GameState.lose_run()
	p.reset_for_new_run()
	_ck(p.weapon_name() == "Pickaxe", "death resets to the pickaxe")
	_ck(p.held_weapons.is_empty(), "death clears the whole loadout")

	# Meta upgrade persists across that reset; the weapon did not.
	GameState.upgrade_levels[&"damage"] = 3
	_ck(p.attack_speed_multiplier() > 1.0, "the permanent weapon-speed upgrade survives a new run")

	GameState.reset_save()
	p.queue_free()
	if _fail == 0:
		print("\nWEAPON TEST OK"); get_tree().quit(0)
	else:
		printerr("\n%d weapon assertion(s) failed" % _fail); get_tree().quit(1)
