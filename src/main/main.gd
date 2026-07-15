extends Node2D
## Boot scene. At M0 its only job is to prove the project runs clean from both
## the editor and the CLI. The gray-box room and player arrive in M1.


func _ready() -> void:
	print("Boot OK: main scene loaded, autoloads up, physics tick %d." % Engine.physics_ticks_per_second)
