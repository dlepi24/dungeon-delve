class_name Hurtbox
extends Area2D
## A volume that can be hit. Reports the hit and decides nothing.
##
## Whether a hit becomes damage, a parry, or is ignored for i-frames is the
## owner's call — the hurtbox just says "this landed on you".

signal hurt(hitbox: Hitbox)


func take_hit(hitbox: Hitbox) -> void:
	hurt.emit(hitbox)
