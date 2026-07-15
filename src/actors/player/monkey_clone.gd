class_name MonkeyClone
extends CharacterBody2D

const STAFF_ATLAS := preload("res://assets/vector/characters/campaign/staff_wukong_frames.svg")

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
	sprite.position.y = -48
	sprite.sprite_frames = create_frames()
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
			sprite.play(&"attack")
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


func create_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation in [&"idle", &"run", &"attack"]:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 8.0)
		frames.set_animation_loop(animation, animation != &"attack")
	var columns := {&"idle": [0, 1], &"run": [2, 3], &"attack": [4, 5]}
	for animation: StringName in columns:
		for column in columns[animation]:
			var texture := AtlasTexture.new()
			texture.atlas = STAFF_ATLAS
			texture.region = Rect2(column * 128, 0, 128, 128)
			frames.add_frame(animation, texture)
	return frames
