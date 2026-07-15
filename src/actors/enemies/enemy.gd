class_name Enemy
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal defeated(spirit_stones: int)
signal hit_received(enemy: Enemy, current: float, maximum: float)

enum Behavior {
	MELEE,
	CHARGE,
	FLYING,
	BOSS,
}

const FRAME_SIZE := Vector2(128.0, 128.0)
const MELEE_EFFECT_ATLAS := preload("res://assets/vector/effects/melee_arc_frames.svg")

@export var stats: EnemyStats
@export var behavior: Behavior = Behavior.MELEE
@export_range(0.0, 1200.0, 1.0) var patrol_distance: float = 220.0
@export var animation_atlas: Texture2D
@export_range(0, 5, 1) var atlas_row: int = 0
@export var visual_scale: Vector2 = Vector2.ONE

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var attack_effect: AnimatedSprite2D = %AttackEffect

var health: float
var spawn_position: Vector2
var patrol_direction: float = -1.0
var frozen_until: int = 0
var invulnerable_until: int = 0
var next_attack_at: int = 0
var next_charge_at: int = 0
var dead: bool = false
var phase_two: bool = false
var current_phase: int = 1
var flight_time: float = 0.0
var visual_time: float = 0.0
var attack_animation_until: int = 0
var hit_reaction_until: int = 0
var base_collision_layer: int
var base_collision_mask: int
var ghost_solid: bool = true
var disguised: bool = false


func _ready() -> void:
	assert(stats != null, "EnemyStats is required")
	assert(animation_atlas != null, "Enemy animation atlas is required")
	add_to_group("enemies")
	if stats.is_boss:
		add_to_group("bosses")
	health = stats.max_health
	base_collision_layer = collision_layer
	base_collision_mask = collision_mask
	spawn_position = global_position
	disguised = stats.disguise_reveal_distance > 0.0
	setup_character_frames()
	setup_attack_effect_frames()
	sprite.scale = visual_scale
	sprite.play("idle")
	health_changed.emit(health, stats.max_health)


func _process(delta: float) -> void:
	if dead:
		return
	visual_time += delta
	update_ghost_state()
	update_visual_animation()


func _physics_process(delta: float) -> void:
	if dead:
		return
	if Time.get_ticks_msec() < frozen_until:
		velocity = Vector2.ZERO
		return

	var player := get_tree().get_first_node_in_group("player") as Player
	if disguised:
		velocity = Vector2.ZERO
		if not update_disguise(player):
			return
	if behavior == Behavior.FLYING:
		update_flying(delta, player)
	else:
		if not is_on_floor():
			velocity.y += stats.gravity * delta
		update_grounded(player)

	move_and_slide()
	apply_contact_damage()


func update_grounded(player: Player) -> void:
	if player == null:
		patrol()
		return
	var distance := player.global_position - global_position
	if absf(distance.x) > stats.detection_range:
		patrol()
		return

	patrol_direction = signf(distance.x)
	sprite.flip_h = patrol_direction > 0.0
	if behavior == Behavior.CHARGE and Time.get_ticks_msec() >= next_charge_at:
		velocity.x = patrol_direction * stats.move_speed * 2.7
		next_charge_at = Time.get_ticks_msec() + 2200
	elif absf(distance.x) > stats.attack_range:
		var multiplier := 1.3 if behavior == Behavior.BOSS and phase_two else 1.0
		velocity.x = patrol_direction * stats.move_speed * multiplier
	else:
		velocity.x = move_toward(velocity.x, 0.0, 80.0)
		try_attack(player)


func patrol() -> void:
	if absf(global_position.x - spawn_position.x) >= patrol_distance:
		patrol_direction = -signf(global_position.x - spawn_position.x)
	velocity.x = patrol_direction * stats.move_speed * 0.45
	sprite.flip_h = patrol_direction > 0.0


func update_flying(delta: float, player: Player) -> void:
	flight_time += delta
	var hover_y := spawn_position.y + sin(flight_time * 2.0) * 24.0
	if player == null or global_position.distance_to(player.global_position) > stats.detection_range:
		velocity.x = patrol_direction * stats.move_speed * 0.4
		velocity.y = (hover_y - global_position.y) * 2.0
		if absf(global_position.x - spawn_position.x) >= patrol_distance:
			patrol_direction *= -1.0
		return
	var target := player.global_position + Vector2(0.0, -54.0)
	velocity = global_position.direction_to(target) * stats.move_speed
	sprite.flip_h = velocity.x > 0.0


func try_attack(player: Player) -> void:
	if Time.get_ticks_msec() < next_attack_at:
		return
	next_attack_at = Time.get_ticks_msec() + (700 if phase_two else 1100)
	attack_animation_until = Time.get_ticks_msec() + 260
	attack_effect.flip_h = sprite.flip_h
	attack_effect.position.x = -58.0 if sprite.flip_h else 58.0
	attack_effect.visible = true
	attack_effect.play("attack")
	player.take_damage(stats.contact_damage * (stats.phase_damage_multiplier if phase_two else 1.0), global_position)
	if stats.contact_slow_seconds > 0.0:
		player.apply_slow(stats.contact_slow_seconds)
	if stats.contact_root_seconds > 0.0:
		player.apply_root(stats.contact_root_seconds)
	if stats.contact_confusion_seconds > 0.0:
		player.apply_confusion(stats.contact_confusion_seconds)
	if stats.pull_distance > 0.0:
		player.global_position.x = move_toward(player.global_position.x, global_position.x, stats.pull_distance)


func apply_contact_damage() -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider()
		if collider is Player:
			try_attack(collider)


func take_damage(damage: float, source_position: Vector2) -> void:
	if dead or not ghost_solid or Time.get_ticks_msec() < invulnerable_until:
		return
	var source_direction := signf(source_position.x - global_position.x)
	if not is_zero_approx(source_direction) and is_equal_approx(source_direction, patrol_direction):
		damage *= stats.front_damage_multiplier
	health = maxf(0.0, health - damage)
	invulnerable_until = Time.get_ticks_msec() + int(stats.invulnerability_seconds * 1000.0)
	hit_reaction_until = Time.get_ticks_msec() + 220
	velocity.x = signf(global_position.x - source_position.x) * stats.knockback_force
	health_changed.emit(health, stats.max_health)
	hit_received.emit(self, health, stats.max_health)
	if behavior == Behavior.BOSS:
		current_phase = 1
		for threshold in stats.phase_thresholds:
			if health <= stats.max_health * threshold:
				current_phase += 1
		phase_two = current_phase > 1
	if is_zero_approx(health):
		die()


func take_projectile_damage(damage: float, source_position: Vector2) -> bool:
	if stats.reflects_projectiles:
		attack_animation_until = Time.get_ticks_msec() + 260
		return false
	take_damage(damage, source_position)
	return true


func reveal_disguise() -> void:
	disguised = false
	attack_animation_until = Time.get_ticks_msec() + 500
	sprite.play("attack")


func update_disguise(player: Player) -> bool:
	if player == null or global_position.distance_to(player.global_position) > stats.disguise_reveal_distance:
		return false
	reveal_disguise()
	return true


func update_ghost_state() -> void:
	if stats.ghost_cycle_seconds <= 0.0:
		return
	var cycle_ms := int(stats.ghost_cycle_seconds * 1000.0)
	var solid_ms := int(stats.ghost_solid_seconds * 1000.0)
	var next_solid := Time.get_ticks_msec() % cycle_ms < solid_ms
	if next_solid == ghost_solid:
		return
	ghost_solid = next_solid
	collision_layer = base_collision_layer if ghost_solid else 0
	collision_mask = base_collision_mask if ghost_solid else 0
	sprite.modulate.a = 1.0 if ghost_solid else 0.35


func update_visual_animation() -> void:
	var now := Time.get_ticks_msec()
	var flash_amount := 0.0
	var next_animation := &"idle"

	if now < hit_reaction_until:
		var pulse := sin(float(hit_reaction_until - now) * 0.045)
		flash_amount = clampf(absf(pulse), 0.25, 0.62)
		next_animation = &"hurt"
	elif now < frozen_until:
		next_animation = sprite.animation
	elif now < attack_animation_until:
		next_animation = &"attack"
	elif absf(velocity.x) > 8.0 or behavior == Behavior.FLYING:
		next_animation = &"walk"
	if sprite.animation != next_animation:
		sprite.play(next_animation)
	sprite.speed_scale = 0.0 if now < frozen_until else (1.35 if phase_two else 1.0)
	var shader_material := sprite.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("flash_amount", flash_amount)


func setup_character_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var definitions := {
		&"idle": [0, 1, 3.0, true],
		&"walk": [2, 3, 8.0, true],
		&"attack": [4, 5, 9.0, false],
		&"hurt": [6, 7, 10.0, false],
		&"death": [8, 9, 6.0, false],
	}
	for animation: StringName in definitions:
		var definition: Array = definitions[animation]
		frames.add_animation(animation)
		frames.set_animation_speed(animation, definition[2])
		frames.set_animation_loop(animation, definition[3])
		for column in range(definition[0], definition[1] + 1):
			frames.add_frame(animation, create_atlas_frame(animation_atlas, column, atlas_row))
	sprite.sprite_frames = frames


func setup_attack_effect_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"attack")
	frames.set_animation_speed(&"attack", 14.0)
	frames.set_animation_loop(&"attack", false)
	for column in 4:
		frames.add_frame(&"attack", create_atlas_frame(MELEE_EFFECT_ATLAS, column, 0))
	attack_effect.sprite_frames = frames
	attack_effect.visible = false
	attack_effect.animation_finished.connect(func() -> void:
		attack_effect.stop()
		attack_effect.visible = false
	)


func create_atlas_frame(atlas: Texture2D, column: int, row: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = atlas
	frame.region = Rect2(Vector2(column, row) * FRAME_SIZE, FRAME_SIZE)
	return frame


func freeze_for(seconds: float) -> void:
	frozen_until = maxi(frozen_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.15, 0.9, 0.35), 0.08)
	tween.tween_interval(seconds)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func die() -> void:
	dead = true
	set_physics_process(false)
	defeated.emit(stats.spirit_stones)
	sprite.play("death")
	await sprite.animation_finished
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	await tween.finished
	queue_free()
