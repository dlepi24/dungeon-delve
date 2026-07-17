class_name EnemyStats
extends Resource
## Everything that makes one enemy differ from another by numbers rather than by
## code. Per the hard rule: adding content means adding a `.tres`, not editing a
## system.
##
## Attacks live in their own resources (see EnemyAttackData) and are chosen by
## range. There is no longer any enemy behaviour that needs a subclass — the
## Dart's lunge turned out to be a number.

@export var display_name: String = "Enemy"

@export_group("Health")
@export var max_health: float = 60.0
## How long a flinch locks the enemy up. Long enough to read, short enough that it
## is not a free stunlock.
@export var hurt_ms: int = 160
@export var knockback: float = 170.0

@export_group("Movement")
@export var move_speed: float = 95.0
@export var acceleration: float = 700.0
## Notice the player at this distance.
@export var aggro_range: float = 620.0
## Beat between attacks once in range. Gives you a window to act.
@export var idle_ms: int = 420
## How long a parry staggers it. Must comfortably exceed the player's
## riposte_window_ms or the parry reward is a lie.
@export var stagger_ms: int = 850

@export_group("Jumping")
## Whether this enemy can leave the ground at all. A Brute that cannot follow you
## onto a ledge is a Brute you can safely snipe from one — but one that cannot
## jump is also readable and characterful. Dustin's dial.
@export var can_jump: bool = true
## Peak height of the enemy's jump, px. Compare the player's 109.
@export var jump_height: float = 120.0
## Seconds to the top of that jump.
@export var jump_time_to_peak: float = 0.36
## Only jump for the player if they are at least this far above us, so enemies do
## not hop constantly over tiny height differences.
@export var jump_if_player_above: float = 44.0
## Beat between jump attempts, so a blocked enemy does not pogo.
@export var jump_cooldown_ms: int = 700

@export_group("Attacks")
## Chosen by range each time the enemy commits. Empty means it never attacks.
@export var attacks: Array[EnemyAttackData] = []

@export_group("Death")
## Haul this enemy drops when killed. The Brute is worth more than the Dart, so
## fighting the dangerous thing pays — which is what makes pushing deeper tempting.
@export var haul_reward: int = 2
## Chance (0..1) this enemy drops a healing heart. Kept low: hearts are the
## in-run healing economy, and free healing everywhere would erase the risk of
## going deep. Tune per enemy.
@export var heart_chance: float = 0.12
## Health a dropped heart restores.
@export var heart_heal: int = 20
## Chance (0..1) this enemy drops a temporary buff. Rare — buffs are a treat, and
## the run should be mostly about your own skill, not power-ups raining down.
@export var buff_chance: float = 0.06
## How long the corpse lingers before fading out and freeing itself.
@export var corpse_linger_ms: int = 260
@export var corpse_fade_ms: int = 420

@export_group("Art")
## Which sprite sheet under assets/sprites/. The art is greyscale; the colours
## below tint it, so a new enemy skin is a sheet plus a palette in this file.
@export var sprite_sheet: String = "grunt"

@export_group("Readability")
@export var colour_idle: Color = Color(0.75, 0.4, 0.4)
@export var colour_recover: Color = Color(0.5, 0.35, 0.35)
@export var colour_stagger: Color = Color(0.35, 0.65, 1.0)

@export_group("Body")
@export var body_size: Vector2 = Vector2(32, 64)


## The closest an attack wants the player. The enemy stops approaching here.
func preferred_range() -> float:
	if attacks.is_empty():
		return 62.0
	var closest: float = 0.0
	for attack: EnemyAttackData in attacks:
		closest = maxf(closest, attack.max_range)
	return closest
