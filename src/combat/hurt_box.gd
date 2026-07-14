class_name HurtBox
extends Area2D

signal hit_received(damage: float, source_position: Vector2)


func receive_hit(damage: float, source_position: Vector2) -> void:
	hit_received.emit(damage, source_position)
