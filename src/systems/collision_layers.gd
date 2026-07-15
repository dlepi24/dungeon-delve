class_name CollisionLayers
extends Object
## Named collision layers, mirroring the table in docs/GDD.md.
##
## The hard rule is that raw layer numbers never appear in code. These are the
## names. tools/check.gd asserts each constant still lines up with the layer name
## configured in project.godot, so the GDD, the project settings and this file
## cannot drift apart silently.
##
## Values are bitmasks: layer N is 1 << (N - 1).

const WORLD: int = 1 << 0
const PLAYER: int = 1 << 1
const ENEMY: int = 1 << 2
const PLAYER_ATTACK: int = 1 << 3
const ENEMY_ATTACK: int = 1 << 4
const PICKUP: int = 1 << 5

## Layer number (1-based, as shown in the inspector) for each name above.
const NUMBERS: Dictionary[String, int] = {
	"World": 1,
	"Player": 2,
	"Enemy": 3,
	"PlayerAttack": 4,
	"EnemyAttack": 5,
	"Pickup": 6,
}
