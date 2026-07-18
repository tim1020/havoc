class_name EnemyProjectile
extends Node2D

const PROJECTILE_ATLAS := preload("res://assets/generated/effects/boss_projectile_frames.png")
const FRAME_SIZE := Vector2(128, 128)

var direction: Vector2 = Vector2.LEFT
var speed: float = 480.0
var damage: float = 15.0
var color: Color = Color("ff7a45")
var style: String = "dragon_orb"
var source_position: Vector2
var expires_at: int
var sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemy_projectiles")
	z_index = 5
	expires_at = Time.get_ticks_msec() + 2600
	setup_sprite()


func _process(delta: float) -> void:
	var previous_position := global_position
	global_position += direction * speed * delta
	rotation = direction.angle()
	var obstacle_query := PhysicsRayQueryParameters2D.create(previous_position, global_position, 1)
	var obstacle_hit := get_world_2d().direct_space_state.intersect_ray(obstacle_query)
	if not obstacle_hit.is_empty():
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var player_center := player.global_position + Vector2(0, -42) if player != null else Vector2.ZERO
	if player != null and segment_distance_to_point(previous_position, global_position, player_center) <= 38.0:
		player.take_damage(damage, source_position)
		queue_free()
	elif Time.get_ticks_msec() >= expires_at:
		queue_free()


func segment_distance_to_point(segment_start: Vector2, segment_end: Vector2, point: Vector2) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if is_zero_approx(length_squared):
		return segment_start.distance_to(point)
	var progress := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_start + segment * progress)

func setup_sprite() -> void:
	if setup_ground_sprite():
		return
	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"fly")
	frames.set_animation_speed(&"fly", 12.0)
	frames.set_animation_loop(&"fly", true)
	var row := {"axe": 0, "dragon_orb": 1, "divine_spear": 2}.get(style, 1) as int
	for column in 4:
		var frame := AtlasTexture.new()
		frame.atlas = PROJECTILE_ATLAS
		frame.region = Rect2(Vector2(column, row) * FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(&"fly", frame)
	sprite.sprite_frames = frames
	sprite.scale = Vector2(0.55, 0.55)
	sprite.modulate = color.lightened(0.12)
	add_child(sprite)
	sprite.play(&"fly")


func setup_ground_sprite() -> bool:
	var designs := {
		"stone": [PackedVector2Array([Vector2(-15, -8), Vector2(-5, -16), Vector2(12, -10), Vector2(17, 4), Vector2(4, 14), Vector2(-13, 9)]), Color("8b6c4b")],
		"fang": [PackedVector2Array([Vector2(-18, 0), Vector2(12, -8), Vector2(18, 0), Vector2(12, 8)]), Color("b7d69a")],
		"tusk": [PackedVector2Array([Vector2(-20, 0), Vector2(13, -11), Vector2(19, 0), Vector2(13, 11)]), Color("efe2c2")],
		"spear": [PackedVector2Array([Vector2(-24, -3), Vector2(8, -3), Vector2(8, -9), Vector2(24, 0), Vector2(8, 9), Vector2(8, 3), Vector2(-24, 3)]), Color("a9d6dd")],
		"shell": [PackedVector2Array([Vector2(-16, 8), Vector2(-12, -7), Vector2(0, -16), Vector2(12, -7), Vector2(16, 8)]), Color("d06b4d")],
		"pearl": [PackedVector2Array([Vector2(-12, 0), Vector2(-7, -10), Vector2(7, -10), Vector2(12, 0), Vector2(7, 10), Vector2(-7, 10)]), Color("a8f0ff")],
		"bone": [PackedVector2Array([Vector2(-20, -5), Vector2(-12, -11), Vector2(-4, -3), Vector2(4, 3), Vector2(12, 11), Vector2(20, 5), Vector2(12, -2), Vector2(4, -8), Vector2(-4, 8), Vector2(-12, 2)]), Color("e6ddd1")],
		"talisman": [PackedVector2Array([Vector2(-12, -16), Vector2(12, -16), Vector2(12, 16), Vector2(-12, 16)]), Color("e9c45c")],
		"petal": [PackedVector2Array([Vector2(-16, 0), Vector2(0, -14), Vector2(16, 0), Vector2(0, 14)]), Color("f49abc")],
		"seed": [PackedVector2Array([Vector2(-15, -5), Vector2(0, -12), Vector2(15, -5), Vector2(15, 5), Vector2(0, 12), Vector2(-15, 5)]), Color("f0a34a")],
		"hammer": [PackedVector2Array([Vector2(-24, -3), Vector2(-2, -3), Vector2(-2, -12), Vector2(15, -12), Vector2(15, 12), Vector2(-2, 12), Vector2(-2, 3), Vector2(-24, 3)]), Color("8995a2")],
		"arrow": [PackedVector2Array([Vector2(-24, -2), Vector2(8, -2), Vector2(8, -9), Vector2(24, 0), Vector2(8, 9), Vector2(8, 2), Vector2(-24, 2)]), Color("d8c076")],
	}
	if not designs.has(style):
		return false
	var definition: Array = designs[style]
	var projectile_shape := Polygon2D.new()
	projectile_shape.polygon = definition[0]
	projectile_shape.color = definition[1]
	projectile_shape.z_index = 1
	add_child(projectile_shape)
	return true
