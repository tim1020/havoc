class_name MonkeyClone
extends CharacterBody2D

const STAFF_FRAMES := preload("res://resources/animations/player_staff_frames.tres")

var damage: float = 15.0
var expires_at: int
var next_attack_at: int = 0
var sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("monkey_clones")
	collision_layer = 0
	collision_mask = 1
	expires_at = Time.get_ticks_msec() + 8000
	sprite = AnimatedSprite2D.new()
	sprite.position.y = -62
	sprite.scale = Vector2(0.25, 0.25)
	sprite.sprite_frames = STAFF_FRAMES
	sprite.play(&"run")
	add_child(sprite)


func _physics_process(_delta: float) -> void:
	if Time.get_ticks_msec() >= expires_at:
		queue_free()
		return
	var target := nearest_enemy()
	if target == null:
		velocity.x = 0.0
		sprite.play(&"idle")
		return
	var distance := target.global_position - global_position
	sprite.flip_h = distance.x < 0.0
	if absf(distance.x) > 75.0:
		velocity.x = signf(distance.x) * 280.0
		sprite.play(&"run")
	else:
		velocity.x = 0.0
		if Time.get_ticks_msec() >= next_attack_at:
			next_attack_at = Time.get_ticks_msec() + 700
			sprite.play(&"attack_1")
			target.take_damage(damage, global_position)
	move_and_slide()


func nearest_enemy() -> Enemy:
	var result: Enemy
	var best := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.dead:
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < best:
			best = distance
			result = enemy
	return result
