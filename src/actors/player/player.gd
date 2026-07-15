class_name Player
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died
signal respawned

@export var stats: PlayerStats

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var standing_shape: CollisionShape2D = %StandingShape
@onready var attack_area: Area2D = %AttackArea
@onready var attack_effect: AnimatedSprite2D = %AttackEffect

var health: float
var jumps_left: int
var facing: float = 1.0
var combo_index: int = 0
var combo_expires_at: int = 0
var invulnerable_until: int = 0
var controls_enabled: bool = true
var respawn_position: Vector2
var attack_held: bool = false
var attack_consumed: bool = false
var attack_pressed_at: int = 0
var base_sprite_scale: Vector2
var speed_boost_until: int = 0


func _ready() -> void:
	assert(stats != null, "PlayerStats is required")
	health = stats.max_health
	jumps_left = stats.jump_count
	respawn_position = global_position
	attack_area.monitoring = true
	attack_effect.animation_finished.connect(func() -> void:
		attack_effect.stop()
		attack_effect.visible = false
	)
	base_sprite_scale = sprite.scale
	health_changed.emit(health, stats.max_health)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("jump"):
		if attack_held or Input.is_action_pressed("attack"):
			cancel_attack_charge()
			cast_freeze_spell()
		else:
			try_jump()
	elif event.is_action_pressed("attack"):
		if Input.is_action_pressed("jump"):
			attack_consumed = true
			cast_freeze_spell()
		else:
			begin_attack_charge()
	elif event.is_action_released("attack"):
		release_attack_charge()
	elif event.is_action_pressed("item"):
		use_current_artifact()


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
		var speed_multiplier := 2.0 if Time.get_ticks_msec() < speed_boost_until else 1.0
		velocity.x = move_toward(velocity.x, direction * stats.move_speed * speed_multiplier, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.friction * delta)

	move_and_slide()
	update_animation(direction)
	update_charge_feedback()


func try_jump() -> void:
	if jumps_left <= 0:
		return
	velocity.y = -stats.jump_velocity
	jumps_left -= 1
	play_if_available("jump")


func begin_attack_charge() -> void:
	if attack_held:
		return
	attack_held = true
	attack_consumed = false
	attack_pressed_at = Time.get_ticks_msec()


func cancel_attack_charge() -> void:
	attack_held = false
	attack_consumed = true


func release_attack_charge() -> void:
	if not attack_held:
		return
	var held_seconds := float(Time.get_ticks_msec() - attack_pressed_at) / 1000.0
	attack_held = false
	if attack_consumed:
		attack_consumed = false
		return
	if held_seconds >= stats.charge_seconds:
		perform_attack(stats.charged_attack_damage)
	else:
		perform_attack()


func perform_attack(damage_override: float = -1.0) -> void:
	var now := Time.get_ticks_msec()
	var damage := damage_override
	if damage_override >= 0.0:
		combo_index = 0
		play_if_available("attack_3")
	else:
		if now > combo_expires_at:
			combo_index = 0
		damage = stats.combo_damage[combo_index]
		combo_index = (combo_index + 1) % stats.combo_damage.size()
		combo_expires_at = now + int(stats.combo_reset_seconds * 1000.0)
		play_if_available("attack_%d" % (combo_index if combo_index > 0 else 3))
	attack_area.position.x = absf(attack_area.position.x) * facing
	attack_effect.flip_h = facing < 0.0
	attack_effect.position.x = absf(attack_effect.position.x) * facing
	attack_effect.scale = Vector2(1.25, 1.25) if damage_override >= 0.0 else Vector2.ONE
	attack_effect.modulate = Color.WHITE
	attack_effect.visible = true
	attack_effect.play("attack")
	await get_tree().physics_frame
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)


func update_charge_feedback() -> void:
	if not attack_held:
		sprite.modulate = Color.WHITE
		sprite.scale = base_sprite_scale
		return
	var held_seconds := float(Time.get_ticks_msec() - attack_pressed_at) / 1000.0
	var progress := clampf(held_seconds / stats.charge_seconds, 0.0, 1.0)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.025 * progress
	sprite.modulate = Color(1.0, 1.0, 1.0 - progress * 0.35)
	sprite.scale = base_sprite_scale * (1.0 + progress * 0.08) * pulse


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


func apply_healing_item(item: ItemDefinition) -> void:
	health = minf(stats.max_health, health + item.power)
	if item.id == &"wine":
		speed_boost_until = Time.get_ticks_msec() + int(item.duration * 1000.0)
	health_changed.emit(health, stats.max_health)


func use_current_artifact() -> void:
	var item_id := GameState.pop_artifact()
	if item_id.is_empty():
		return
	var item := ItemCatalog.get_definition(item_id)
	if item == null:
		return
	play_if_available("spell")
	attack_effect.modulate = item.color
	attack_effect.scale = Vector2(1.4, 1.4)
	attack_effect.flip_h = facing < 0.0
	attack_effect.position.x = absf(attack_effect.position.x) * facing
	attack_effect.visible = true
	attack_effect.play("attack")
	var enemies := get_tree().get_nodes_in_group("enemies")
	if item.id == &"purple_bell":
		for enemy_node in enemies:
			var enemy := enemy_node as Enemy
			enemy.take_damage(item.power, global_position)
			enemy.freeze_for(item.duration)
		return
	var target := nearest_enemy(enemies)
	if target == null:
		return
	if item.id == &"binding_rope":
		target.freeze_for(2.0 if target.is_in_group("bosses") else item.duration)
	elif item.id == &"fire_spear":
		for enemy_node in enemies:
			var enemy := enemy_node as Enemy
			var offset := enemy.global_position - global_position
			if signf(offset.x) == facing and absf(offset.x) <= 700.0 and absf(offset.y) <= 110.0:
				enemy.take_damage(item.power, global_position)
	else:
		target.take_damage(item.power, global_position)


func nearest_enemy(enemies: Array[Node]) -> Enemy:
	var result: Enemy
	var best_distance := INF
	for enemy_node in enemies:
		var enemy := enemy_node as Enemy
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			result = enemy
	return result


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
