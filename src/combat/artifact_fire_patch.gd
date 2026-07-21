class_name ArtifactFirePatch
extends Node2D

const FIRE_SHEET := preload("res://assets/generated/effects/samadhi_fire_sheet.png")
const SHEET_COLUMNS := 4
const SHEET_ROWS := 2

var target: Enemy
var damage: float = 10.0
var duration: float = 5.0
var elapsed := 0.0
var next_damage_at := 0
var hits_remaining := 5
var landed := false
var fire_sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group(&"artifact_fire_patches")
	z_index = 5
	setup_fire_sprite()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration or not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var fall_offset := maxf(0.0, 300.0 - elapsed * 900.0)
	global_position = target.global_position + Vector2(0.0, -42.0 - fall_offset)
	if fall_offset > 0.0:
		return
	if not landed:
		landed = true
		fire_sprite.play(&"burn")
	var now := Time.get_ticks_msec()
	if now < next_damage_at or hits_remaining <= 0:
		return
	target.take_damage(damage, global_position)
	hits_remaining -= 1
	next_damage_at = now + 1000


func setup_fire_sprite() -> void:
	fire_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation(&"fall")
	frames.add_animation(&"burn")
	var cell_size := Vector2(FIRE_SHEET.get_size()) / Vector2(SHEET_COLUMNS, SHEET_ROWS)
	for frame_index in SHEET_COLUMNS * SHEET_ROWS:
		var atlas := AtlasTexture.new()
		atlas.atlas = FIRE_SHEET
		var column := frame_index % SHEET_COLUMNS
		var row := frame_index / SHEET_COLUMNS
		atlas.region = Rect2(Vector2(column, row) * cell_size + Vector2(4.0, 4.0), cell_size - Vector2(8.0, 8.0))
		if frame_index < 2:
			frames.add_frame(&"fall", atlas)
		else:
			frames.add_frame(&"burn", atlas)
	frames.set_animation_speed(&"fall", 14.0)
	frames.set_animation_speed(&"burn", 8.0)
	frames.set_animation_loop(&"fall", true)
	frames.set_animation_loop(&"burn", true)
	fire_sprite.sprite_frames = frames
	fire_sprite.scale = Vector2(0.36, 0.36)
	fire_sprite.position = Vector2(0.0, -34.0)
	fire_sprite.play(&"fall")
	add_child(fire_sprite)
