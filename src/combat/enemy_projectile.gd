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
	global_position += direction * speed * delta
	rotation = direction.angle()
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and global_position.distance_to(player.global_position + Vector2(0, -42)) <= 34.0:
		player.take_damage(damage, source_position)
		queue_free()
	elif Time.get_ticks_msec() >= expires_at:
		queue_free()

func setup_sprite() -> void:
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
