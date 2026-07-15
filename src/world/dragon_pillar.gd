class_name DragonPillar
extends StaticBody2D

var health := 60.0
var broken := false


func _ready() -> void:
	add_to_group("dragon_pillars")
	collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(58, 250)
	collision.shape = shape
	collision.position.y = -125
	add_child(collision)
	queue_redraw()


func take_damage(damage: float, source_position: Vector2) -> void:
	if broken:
		return
	health = maxf(0.0, health - damage)
	if is_zero_approx(health):
		broken = true
		collision_layer = 0
		for enemy_node in get_tree().get_nodes_in_group("enemies"):
			var enemy := enemy_node as Enemy
			if not enemy.dead and global_position.distance_to(enemy.global_position) <= 230.0:
				enemy.invulnerable_until = 0
				enemy.take_damage(40.0, source_position)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "rotation", PI * 0.5, 0.35)
		tween.tween_property(self, "modulate:a", 0.25, 0.7)
	queue_redraw()


func _draw() -> void:
	if broken:
		return
	draw_rect(Rect2(-29, -250, 58, 250), Color("d9c16e"), true)
	draw_line(Vector2(-18, -220), Vector2(18, -40), Color("9b5341"), 9, true)
	for y in range(-220, -20, 45):
		draw_circle(Vector2(0, y), 13, Color("e9dd9b"), false, 4)
