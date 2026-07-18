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

	# Inventory rules (Dustin's call, 2026-07-17 evening): a second pickup
	# STOWS quietly — walking over loot never switches your hand. A pickup
	# against a FULL loadout only reaches the player via a deliberate interact
	# (see pickup.gd) and then replaces the STOWED weapon, never the hand.
	_ck(p.held_weapons.size() == 2 and p.active_slot == 0 and p.weapon_name() == maul.display_name,
		"a second pickup stows without switching hands")
	p.select_weapon_slot(1)
	_ck(p.attack_startup_ticks() < base_startup, "the Dagger is faster than the pickaxe")
	p.select_weapon_slot(0)
	_ck(p.weapon_name() == maul.display_name, "swapping puts the Maul back in hand")
	var spear: WeaponData = load("res://src/systems/weapons/spear.tres")
	p.equip_weapon(spear)
	_ck(p.weapon_name() == spear.display_name and p.held_weapons[1] == spear,
		"a deliberate full-loadout take replaces the stowed slot and comes up in hand")
	_ck(p.held_weapons[0] == maul, "the weapon in your hand is never silently replaced")

	# Session scoping (GDD 2026-07-17): surviving keeps the loadout, dying loses
	# it. reset_for_new_run models arriving anywhere alive; lose_run is death.
	p.reset_for_new_run()
	_ck(p.weapon_name() == spear.display_name and p.held_weapons.size() == 2,
		"surviving a run banks the loadout — extract and you stay armed")
	GameState.lose_run()
	p.reset_for_new_run()
	_ck(p.weapon_name() == "Pickaxe", "death resets to the pickaxe")
	_ck(p.held_weapons.is_empty(), "death clears the whole loadout")

	# Honing sharpens a session COPY — the shared .tres must never mutate, or
	# every future drop of that weapon ships pre-honed.
	p.equip_weapon(dagger)
	var dagger_disk_damage: float = dagger.damage
	_ck(p.hone_equipped_weapon(), "honing the held weapon succeeds")
	_ck(p.weapon_damage() > dagger_disk_damage and p.equipped_weapon.hone_level == 1,
		"honing raises damage and marks the level")
	_ck(p.equipped_weapon.display_name.ends_with("+1"), "a honed blade says so in its name")
	_ck(is_equal_approx(dagger.damage, dagger_disk_damage), "the .tres on disk is untouched")
	_ck(GameState.session_weapons[p.active_slot].hone_level == 1, "the honed copy rides the session stash")
	GameState.lose_run()
	p.reset_for_new_run()

	# Meta upgrade persists across that reset; the weapon did not.
	GameState.upgrade_levels[&"damage"] = 3
	_ck(p.attack_speed_multiplier() > 1.0, "the permanent weapon-speed upgrade survives a new run")

	GameState.reset_save()
	p.queue_free()
	if _fail == 0:
		print("\nWEAPON TEST OK"); get_tree().quit(0)
	else:
		printerr("\n%d weapon assertion(s) failed" % _fail); get_tree().quit(1)
