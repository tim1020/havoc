class_name Enemy
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal defeated(spirit_stones: int)

enum Behavior {
	MELEE,
	CHARGE,
	FLYING,
	BOSS,
}

@export var stats: EnemyStats
@export var behavior: Behavior = Behavior.MELEE
@export_range(0.0, 1200.0, 1.0) var patrol_distance: float = 220.0
@export var visual_texture: Texture2D
@export var visual_scale: Vector2 = Vector2(0.1, 0.1)

@onready var sprite: Sprite2D = %Sprite

var health: float
var spawn_position: Vector2
var patrol_direction: float = -1.0
var frozen_until: int = 0
var invulnerable_until: int = 0
var next_attack_at: int = 0
var next_charge_at: int = 0
var dead: bool = false
var phase_two: bool = false
var flight_time: float = 0.0


func _ready() -> void:
	assert(stats != null, "EnemyStats is required")
	assert(visual_texture != null, "Enemy visual texture is required")
	add_to_group("enemies")
	if stats.is_boss:
		add_to_group("bosses")
	health = stats.max_health
	spawn_position = global_position
	sprite.texture = visual_texture
	sprite.scale = visual_scale
	health_changed.emit(health, stats.max_health)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if Time.get_ticks_msec() < frozen_until:
		velocity = Vector2.ZERO
		return

	var player := get_tree().get_first_node_in_group("player") as Player
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
	player.take_damage(stats.contact_damage * (1.5 if phase_two else 1.0), global_position)


func apply_contact_damage() -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider()
		if collider is Player:
			try_attack(collider)


func take_damage(damage: float, source_position: Vector2) -> void:
	if dead or Time.get_ticks_msec() < invulnerable_until:
		return
	health = maxf(0.0, health - damage)
	invulnerable_until = Time.get_ticks_msec() + int(stats.invulnerability_seconds * 1000.0)
	velocity.x = signf(global_position.x - source_position.x) * stats.knockback_force
	health_changed.emit(health, stats.max_health)
	if behavior == Behavior.BOSS and not phase_two and health <= stats.max_health * 0.5:
		phase_two = true
	if is_zero_approx(health):
		die()


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
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_property(sprite, "scale", sprite.scale * 0.7, 0.35)
	await tween.finished
	queue_free()
