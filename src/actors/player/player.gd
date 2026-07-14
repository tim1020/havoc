class_name Player
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died
signal respawned

@export var stats: PlayerStats

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var standing_shape: CollisionShape2D = %StandingShape
@onready var attack_area: Area2D = %AttackArea

var health: float
var jumps_left: int
var facing: float = 1.0
var combo_index: int = 0
var combo_expires_at: int = 0
var invulnerable_until: int = 0
var controls_enabled: bool = true
var respawn_position: Vector2


func _ready() -> void:
	assert(stats != null, "PlayerStats is required")
	health = stats.max_health
	jumps_left = stats.jump_count
	respawn_position = global_position
	attack_area.monitoring = false
	health_changed.emit(health, stats.max_health)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event.is_action_pressed("jump"):
		if Input.is_action_pressed("attack"):
			cast_freeze_spell()
		else:
			try_jump()
	elif event.is_action_pressed("attack"):
		if Input.is_action_pressed("jump"):
			cast_freeze_spell()
		else:
			perform_attack()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += stats.gravity * delta
	else:
		jumps_left = stats.jump_count

	var direction := Input.get_axis("move_left", "move_right") if controls_enabled else 0.0
	if not is_zero_approx(direction):
		facing = signf(direction)
		sprite.flip_h = facing < 0.0
		var accel := stats.acceleration if is_on_floor() else stats.air_acceleration
		velocity.x = move_toward(velocity.x, direction * stats.move_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.friction * delta)

	move_and_slide()
	update_animation(direction)


func try_jump() -> void:
	if jumps_left <= 0:
		return
	velocity.y = -stats.jump_velocity
	jumps_left -= 1
	play_if_available("jump")


func perform_attack() -> void:
	var now := Time.get_ticks_msec()
	if now > combo_expires_at:
		combo_index = 0
	var damage := stats.combo_damage[combo_index]
	combo_index = (combo_index + 1) % stats.combo_damage.size()
	combo_expires_at = now + int(stats.combo_reset_seconds * 1000.0)
	play_if_available("attack_%d" % (combo_index if combo_index > 0 else 3))
	attack_area.position.x = absf(attack_area.position.x) * facing
	attack_area.monitoring = true
	await get_tree().physics_frame
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
	attack_area.monitoring = false


func cast_freeze_spell() -> void:
	if health <= stats.freeze_health_cost:
		return
	health -= stats.freeze_health_cost
	health_changed.emit(health, stats.max_health)
	play_if_available("spell")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("freeze_for"):
			var duration := stats.freeze_boss_seconds if enemy.is_in_group("bosses") else stats.freeze_normal_seconds
			enemy.freeze_for(duration)


func take_damage(damage: float, source_position: Vector2) -> void:
	if Time.get_ticks_msec() < invulnerable_until or not controls_enabled:
		return
	health = maxf(0.0, health - damage)
	invulnerable_until = Time.get_ticks_msec() + int(stats.invulnerability_seconds * 1000.0)
	velocity.x = signf(global_position.x - source_position.x) * stats.knockback_force
	play_if_available("hurt")
	health_changed.emit(health, stats.max_health)
	if is_zero_approx(health):
		die_and_respawn()


func die_and_respawn() -> void:
	controls_enabled = false
	velocity = Vector2.ZERO
	play_if_available("death")
	died.emit()
	await get_tree().create_timer(0.8).timeout
	if not GameState.consume_life():
		GameState.restart_current_level()
		return
	global_position = respawn_position
	health = stats.max_health
	invulnerable_until = Time.get_ticks_msec() + int(stats.respawn_invulnerability_seconds * 1000.0)
	play_if_available("respawn")
	health_changed.emit(health, stats.max_health)
	await get_tree().create_timer(0.35).timeout
	controls_enabled = true
	respawned.emit()


func set_checkpoint(checkpoint: Vector2) -> void:
	respawn_position = checkpoint


func update_animation(direction: float) -> void:
	if not controls_enabled or sprite.is_playing() and sprite.animation.begins_with("attack"):
		return
	if not is_on_floor():
		play_if_available("jump")
	elif Input.is_action_pressed("crouch"):
		play_if_available("crouch")
	elif not is_zero_approx(direction):
		play_if_available("run")
	else:
		play_if_available("idle")


func play_if_available(animation_name: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
