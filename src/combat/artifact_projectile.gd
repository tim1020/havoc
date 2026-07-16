class_name ArtifactProjectile
extends Node2D

const ARTIFACT_ATLAS := preload("res://assets/generated/effects/artifact_frames.png")
const FRAME_SIZE := Vector2(128, 128)

var item: ItemDefinition
var target: Enemy
var direction: float = 1.0
var source_position: Vector2
var speed: float = 760.0
var elapsed: float = 0.0
var hit_ids: Dictionary[int, bool] = {}
var sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("artifact_projectiles")
	z_index = 6
	setup_sprite()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if item.id == &"purple_bell":
		scale = Vector2.ONE * (1.0 + elapsed * 5.0)
		modulate.a = maxf(0.0, 1.0 - elapsed * 2.5)
		if elapsed >= 0.25:
			for enemy_node in get_tree().get_nodes_in_group("enemies"):
				var enemy := enemy_node as Enemy
				enemy.take_damage(item.power, source_position)
				enemy.freeze_for(item.duration)
			queue_free()
		return
	if item.id == &"fire_spear":
		position.x += direction * speed * delta
		for enemy_node in get_tree().get_nodes_in_group("enemies"):
			var enemy := enemy_node as Enemy
			if not hit_ids.has(enemy.get_instance_id()) and global_position.distance_to(enemy.global_position + Vector2(0, -45)) < 72.0:
				hit_ids[enemy.get_instance_id()] = true
				enemy.take_damage(item.power, source_position)
		if elapsed >= 1.0:
			queue_free()
		return
	if not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var destination := target.global_position + Vector2(0, -45)
	global_position = global_position.move_toward(destination, speed * delta)
	rotation += delta * 8.0
	if global_position.distance_to(destination) <= 18.0:
		impact_target()


func impact_target() -> void:
	if item.id == &"binding_rope":
		target.freeze_for(2.0 if target.is_in_group("bosses") else item.duration)
	else:
		target.take_damage(item.power, source_position)
	queue_free()


func _draw() -> void:
	if sprite != null and sprite.visible:
		return
	var color := item.color if item != null else Color.WHITE
	if item != null and item.id == &"purple_bell":
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, color, 5.0, true)
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color.WHITE, 3.0, true)
	elif item != null and item.id == &"fire_spear":
		draw_line(Vector2(-28, 0), Vector2(28, 0), color, 8.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(34, 0), Vector2(20, -10), Vector2(20, 10)]), Color("fff1a8"))
	else:
		draw_circle(Vector2.ZERO, 16.0, color)
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, Color.WHITE, 3.0, true)


func setup_sprite() -> void:
	var row := {&"cosmic_ring": 0, &"fire_spear": 1, &"heaven_seal": 2}.get(item.id, -1) as int
	if row < 0:
		return
	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"fly")
	frames.set_animation_speed(&"fly", 12.0)
	frames.set_animation_loop(&"fly", true)
	for column in 4:
		var frame := AtlasTexture.new()
		frame.atlas = ARTIFACT_ATLAS
		frame.region = Rect2(Vector2(column, row) * FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(&"fly", frame)
	sprite.sprite_frames = frames
	sprite.scale = Vector2(0.55, 0.55)
	add_child(sprite)
	sprite.play(&"fly")
