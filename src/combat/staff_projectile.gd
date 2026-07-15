class_name StaffProjectile
extends Node2D

@export var damage: float = 15.0
@export var speed: float = 760.0

var target: Enemy
var source_position: Vector2


func _ready() -> void:
	add_to_group("staff_projectiles")
	$Sprite.play("fly")
	var tween := create_tween().set_loops()
	tween.tween_property($Sprite, "scale", Vector2(1.12, 1.12), 0.08)
	tween.tween_property($Sprite, "scale", Vector2.ONE, 0.08)
	get_tree().create_timer(2.0).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var direction := global_position.direction_to(target.global_position + Vector2(0, -40))
	global_position += direction * speed * delta
	rotation = direction.angle()
	if global_position.distance_to(target.global_position) <= 52.0:
		if target.has_method("take_projectile_damage"):
			target.take_projectile_damage(damage, source_position)
		else:
			target.take_damage(damage, source_position)
		queue_free()
