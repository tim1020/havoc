class_name ChargedFlameProjectile
extends Node2D

var direction: float = 1.0
var total_damage: float = 30.0
var source_position: Vector2
var speed: float = 720.0
var elapsed: float = 0.0
var target: Enemy
var impacting: bool = false


func _ready() -> void:
	add_to_group(&"charged_flame_projectiles")
	z_index = 7
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if impacting:
		queue_redraw()
		return
	position.x += direction * speed * delta
	if not is_position_on_screen(global_position):
		queue_free()
		return
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if not enemy.dead and is_position_on_screen(enemy.global_position + Vector2(0, -48)) and global_position.distance_to(enemy.global_position + Vector2(0, -48)) <= 72.0:
			impact(enemy)
			return
	if elapsed >= 1.6:
		queue_free()
		return
	queue_redraw()


func impact(enemy: Enemy) -> void:
	impacting = true
	target = enemy
	for hit_index in 3:
		if not is_instance_valid(target) or target.dead:
			break
		target.take_damage(total_damage / 3.0, source_position)
		scale = Vector2.ONE * (1.0 + hit_index * 0.18)
		modulate = Color.WHITE if hit_index % 2 == 0 else Color("ffd34f")
		queue_redraw()
		# 高于当前敌人最长 0.2 秒受击无敌，确保三段伤害都能实际生效。
		await get_tree().create_timer(0.22).timeout
	queue_free()


func is_position_on_screen(world_position: Vector2) -> bool:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return true
	var visible_size := get_viewport_rect().size / camera.zoom
	var visible_rect := Rect2(camera.get_screen_center_position() - visible_size * 0.5, visible_size)
	return visible_rect.grow(48.0).has_point(world_position)


func _draw() -> void:
	var pulse := 1.0 + sin(elapsed * 18.0) * 0.12
	var length := 92.0 if not impacting else 126.0
	for index in 7:
		var progress := float(index) / 6.0
		var x := direction * (progress * length - 34.0)
		var y := sin(elapsed * 16.0 + index * 1.7) * (10.0 + progress * 9.0)
		draw_flame(Vector2(x, y), pulse * (0.65 + progress * 0.45))


func draw_flame(center: Vector2, flame_scale: float) -> void:
	var width := 13.0 * flame_scale
	var height := 28.0 * flame_scale
	var outer := PackedVector2Array([
		center + Vector2(-width, height * 0.42),
		center + Vector2(-width * 0.65, -height * 0.08),
		center + Vector2(0, -height),
		center + Vector2(width * 0.7, -height * 0.05),
		center + Vector2(width, height * 0.42),
	])
	draw_colored_polygon(outer, Color("ff4f20"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-width * 0.42, height * 0.3),
		center + Vector2(0, -height * 0.45),
		center + Vector2(width * 0.45, height * 0.3),
	]), Color("ffd43b"))
