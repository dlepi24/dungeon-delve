class_name Projectile
extends Hitbox
## A thrown thing in flight — the first ranged threat in the game.
##
## Extends Hitbox so the ENTIRE existing combat contract applies unchanged: the
## player's hurtbox reports it, roll i-frames dodge it, and — the whole point —
## the parry state calls notify_parried() on it exactly as it would on a melee
## swing. A parried projectile REFLECTS: it flies back the way it came, faster,
## hitting enemies for double damage and breaking the thrower's stance. Batting
## a rock back at the slinger is the parry pillar's ranged payoff.
##
## Deterministic: moves on the physics tick, respects hitstop, no randomness.
## Frees itself on walls, on a landed hit, or after its lifetime.

var velocity: Vector2 = Vector2.ZERO
var _life_ticks: int = 0
var _reflected: bool = false

## 4 seconds at the locked 60 Hz — longer than any room crossing.
const MAX_LIFE_TICKS: int = 240
const REFLECT_SPEED_BONUS: float = 1.3
const REFLECT_DAMAGE_MULT: float = 2.0

@onready var _rock: ColorRect = $Rock


static func spawn(parent: Node, from: Vector2, direction: Vector2, attack: EnemyAttackData) -> Projectile:
	var scene: PackedScene = load("res://src/systems/projectile.tscn") as PackedScene
	var projectile: Projectile = scene.instantiate() as Projectile
	parent.add_child(projectile)
	projectile.global_position = from
	projectile.velocity = direction.normalized() * attack.projectile_speed
	projectile.damage = attack.damage * GameState.heat_damage_multiplier()
	# Projectiles never chip poise on the way OUT; the reflected return does.
	projectile.poise_damage = 0.0
	projectile.activate()
	return projectile


func _ready() -> void:
	super()
	body_entered.connect(_on_body_entered)
	parried.connect(_on_parried)


func _physics_process(delta: float) -> void:
	if Hitstop.is_frozen():
		return
	_life_ticks += 1
	if _life_ticks > MAX_LIFE_TICKS:
		queue_free()
		return
	global_position += velocity * delta


## Visual only: the rock tumbles in flight.
func _process(delta: float) -> void:
	super(delta)
	_rock.rotation += 9.0 * delta * signf(velocity.x + 0.001)


func _on_body_entered(_body: Node2D) -> void:
	queue_free()


## One projectile, one consequence: it despawns when a hit actually lands.
## Two exceptions, both deliberate:
## - A rolling (invulnerable) player is not hit at all — the rock sails past,
##   because dodging THROUGH a projectile has to be a real answer to it.
## - A parried hit reflects instead of despawning (notify_parried fires
##   synchronously inside take_hit, so _reflected flips before we return).
func _try_hit(area: Area2D) -> void:
	var hurtbox: Hurtbox = area as Hurtbox
	if hurtbox == null:
		return
	var target: Player = hurtbox.get_parent() as Player
	if target != null and target.invulnerable:
		return
	var was_reflected: bool = _reflected
	super(area)
	if _reflected == was_reflected and is_inside_tree():
		queue_free()


func _on_parried() -> void:
	_reflected = true
	velocity = -velocity * REFLECT_SPEED_BONUS
	damage *= REFLECT_DAMAGE_MULT
	# A returned rock always breaks the thrower's stance — the parry pillar
	# says a good read beats poise, ranged or not.
	poise_damage = 999.0
	is_riposte = true
	# Switch sides: it is the player's projectile now.
	collision_layer = CollisionLayers.PLAYER_ATTACK
	collision_mask = CollisionLayers.ENEMY | CollisionLayers.WORLD
	_rock.color = Color(0.85, 0.95, 1.0)
	# notify_parried() closed the box; reopen it for the return flight.
	activate()
