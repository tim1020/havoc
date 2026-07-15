class_name EnemyProjectile
extends Node2D

var direction: Vector2 = Vector2.LEFT
var speed: float = 480.0
var damage: float = 15.0
var color: Color = Color("ff7a45")
var source_position: Vector2
var expires_at: int


func _ready() -> void:
	add_to_group("enemy_projectiles")
	z_index = 5
	expires_at = Time.get_ticks_msec() + 2600
	queue_redraw()


func _process(delta: float) -> void:
	global_position += direction * speed * delta
	rotation = direction.angle()
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and global_position.distance_to(player.global_position + Vector2(0, -42)) <= 34.0:
		player.take_damage(damage, source_position)
		queue_free()
	elif Time.get_ticks_msec() >= expires_at:
		queue_free()


func _draw() -> void:
	draw_line(Vector2(-30, 0), Vector2(8, 0), Color(color, 0.35), 12.0, true)
	draw_circle(Vector2.ZERO, 11.0, color)
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
