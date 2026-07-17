class_name Player
extends CharacterBody2D

const STAFF_STATS := preload("res://resources/stats/player_staff.tres")
const STAFF_FRAMES := preload("res://resources/animations/player_staff_frames.tres")
const ARTIFACT_PROJECTILE := preload("res://src/combat/artifact_projectile.gd")
const MONKEY_CLONE := preload("res://src/actors/player/monkey_clone.gd")
const THROW_PROJECTILE := preload("res://src/combat/player_throw_projectile.gd")
const THROW_COOLDOWN_MS := 200

signal health_changed(current: float, maximum: float)
signal died
signal respawned
signal artifact_selection_changed(selected: bool)

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
var speed_boost_until: int = 0
var slowed_until: int = 0
var rooted_until: int = 0
var confused_until: int = 0
var artifact_selected: bool = false
var next_throw_at: int = 0
var hurt_animation_until: int = 0


func _ready() -> void:
	add_to_group(&"player")
	if GameState.has_staff:
		stats = STAFF_STATS
		sprite.sprite_frames = STAFF_FRAMES
		sprite.scale = Vector2(0.25, 0.25)
	assert(stats != null, "PlayerStats is required")
	health = stats.max_health
	jumps_left = stats.jump_count
	respawn_position = global_position
	invulnerable_until = Time.get_ticks_msec() + 1000
	attack_area.monitoring = true
	attack_effect.animation_finished.connect(func() -> void:
		attack_effect.stop()
		attack_effect.visible = false
	)
	health_changed.emit(health, stats.max_health)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("jump"):
		try_jump()
	elif event.is_action_pressed("attack"):
		if artifact_selected:
			use_current_artifact()
			set_artifact_selected(false)
		elif not is_on_floor():
			perform_aerial_throw()
		else:
			perform_attack()
	elif event.is_action_pressed("item"):
		select_next_artifact()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("crouch"):
		set_artifact_selected(false)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += stats.gravity * delta
	else:
		jumps_left = stats.jump_count

	var direction := movement_direction(Input.get_axis("move_left", "move_right")) if controls_enabled and Time.get_ticks_msec() >= rooted_until else 0.0
	if not is_zero_approx(direction):
		facing = signf(direction)
		sprite.flip_h = facing < 0.0
		var accel := stats.acceleration if is_on_floor() else stats.air_acceleration
		var speed_multiplier := 2.0 if Time.get_ticks_msec() < speed_boost_until else 1.0
		if Time.get_ticks_msec() < slowed_until:
			speed_multiplier *= 0.5
		velocity.x = move_toward(velocity.x, direction * stats.move_speed * speed_multiplier, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.friction * delta)

	move_and_slide()
	update_status_visual()
	update_animation(direction)


func try_jump() -> void:
	if jumps_left <= 0:
		return
	velocity.y = -stats.jump_velocity
	jumps_left -= 1
	AudioService.play_sfx(self, AudioService.JUMP)
	play_if_available("jump")


func perform_attack() -> void:
	AudioService.play_sfx(self, AudioService.ATTACK)
	var now := Time.get_ticks_msec()
	if now > combo_expires_at:
		combo_index = 0
	var damage := stats.combo_damage[combo_index]
	combo_index = (combo_index + 1) % stats.combo_damage.size()
	combo_expires_at = now + int(stats.combo_reset_seconds * 1000.0)
	play_if_available("attack_%d" % (combo_index if combo_index > 0 else 3))
	attack_effect.flip_h = facing < 0.0
	attack_effect.position.x = absf(attack_effect.position.x) * facing
	attack_effect.scale = Vector2.ONE
	attack_effect.modulate = Color.WHITE
	attack_effect.visible = true
	attack_effect.play(&"attack")
	attack_area.position.x = absf(attack_area.position.x) * facing
	await get_tree().physics_frame
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)

func perform_aerial_throw() -> void:
	var now := Time.get_ticks_msec()
	if now < next_throw_at:
		return
	next_throw_at = now + THROW_COOLDOWN_MS
	AudioService.play_sfx(self, AudioService.THROW)
	play_if_available(&"attack_2")
	var projectile := THROW_PROJECTILE.new() as PlayerThrowProjectile
	projectile.kind = PlayerThrowProjectile.Kind.STAFF if GameState.has_staff else PlayerThrowProjectile.Kind.BANANA
	projectile.direction = facing
	projectile.damage = stats.combo_damage[0] * (1.5 if GameState.has_staff else 1.0)
	projectile.source_position = global_position
	projectile.global_position = global_position + Vector2(facing * 48.0, -48.0)
	projectile.target = nearest_forward_visible_enemy()
	get_tree().current_scene.add_child(projectile)


func apply_healing_item(item: ItemDefinition) -> void:
	health = minf(stats.max_health, health + item.power)
	if item.id == &"wine":
		speed_boost_until = Time.get_ticks_msec() + int(item.duration * 1000.0)
	health_changed.emit(health, stats.max_health)


func restore_full_health() -> void:
	health = stats.max_health
	health_changed.emit(health, stats.max_health)


func select_next_artifact() -> void:
	if GameState.artifacts.is_empty():
		set_artifact_selected(false)
		return
	if artifact_selected:
		GameState.rotate_artifacts()
	set_artifact_selected(true)


func set_artifact_selected(selected: bool) -> void:
	artifact_selected = selected and not GameState.artifacts.is_empty()
	artifact_selection_changed.emit(artifact_selected)


func apply_slow(seconds: float) -> void:
	slowed_until = maxi(slowed_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func apply_root(seconds: float) -> void:
	rooted_until = maxi(rooted_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	velocity.x = 0.0


func apply_confusion(seconds: float) -> void:
	confused_until = maxi(confused_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func movement_direction(raw_direction: float) -> float:
	return -raw_direction if Time.get_ticks_msec() < confused_until else raw_direction


func update_status_visual() -> void:
	sprite.modulate = Color("f2a1cf") if Time.get_ticks_msec() < confused_until else Color.WHITE


func use_current_artifact() -> void:
	var item_id := GameState.pop_artifact()
	if item_id.is_empty():
		return
	var item := ItemCatalog.get_definition(item_id)
	if item == null:
		return
	if item.category == ItemDefinition.Category.HEALING:
		apply_healing_item(item)
		show_artifact_flash(item)
		return
	play_if_available("spell")
	show_artifact_flash(item)
	var enemies := get_tree().get_nodes_in_group("enemies")
	if item.id == &"monkey_hair":
		spawn_monkey_clones(item)
		return
	var target := nearest_enemy(enemies)
	if target == null and item.id != &"purple_bell" and item.id != &"fire_spear":
		return
	var projectile = ARTIFACT_PROJECTILE.new()
	projectile.item = item
	projectile.target = target
	projectile.direction = facing
	projectile.source_position = global_position
	projectile.global_position = global_position + Vector2(facing * 45.0, -55.0)
	get_tree().current_scene.add_child(projectile)


func show_artifact_flash(item: ItemDefinition) -> void:
	attack_effect.modulate = item.color
	attack_effect.scale = Vector2(1.4, 1.4)
	attack_effect.flip_h = facing < 0.0
	attack_effect.position.x = absf(attack_effect.position.x) * facing
	attack_effect.visible = true
	attack_effect.play("attack")


func spawn_monkey_clones(item: ItemDefinition) -> void:
	for offset in [-65.0, 0.0, 65.0]:
		var clone = MONKEY_CLONE.new()
		clone.damage = item.power
		clone.global_position = global_position + Vector2(offset, 0)
		get_tree().current_scene.add_child(clone)


func nearest_enemy(enemies: Array[Node]) -> Enemy:
	var result: Enemy
	var best_distance := INF
	for enemy_node in enemies:
		var enemy := enemy_node as Enemy
		if enemy == null or enemy.dead:
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			result = enemy
	return result


func nearest_forward_visible_enemy() -> Enemy:
	var result: Enemy
	var best_distance := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy == null or enemy.dead or not is_enemy_on_screen(enemy):
			continue
		var offset := enemy.global_position - global_position
		if offset.x * facing <= 0.0:
			continue
		var distance := offset.length_squared()
		if distance < best_distance:
			best_distance = distance
			result = enemy
	return result


func is_enemy_on_screen(enemy: Enemy) -> bool:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return true
	var visible_size := get_viewport_rect().size / camera.zoom
	var visible_rect := Rect2(camera.get_screen_center_position() - visible_size * 0.5, visible_size)
	return visible_rect.grow(48.0).has_point(enemy.global_position + Vector2(0, -48))


func play_victory() -> void:
	set_artifact_selected(false)
	restore_full_health()
	controls_enabled = false
	velocity = Vector2.ZERO
	if not sprite.sprite_frames.has_animation(&"victory"):
		sprite.sprite_frames.add_animation(&"victory")
		sprite.sprite_frames.set_animation_speed(&"victory", 5.0)
		sprite.sprite_frames.set_animation_loop(&"victory", true)
		for source_animation in [&"respawn", &"attack_3"]:
			if sprite.sprite_frames.has_animation(source_animation):
				for index in sprite.sprite_frames.get_frame_count(source_animation):
					sprite.sprite_frames.add_frame(&"victory", sprite.sprite_frames.get_frame_texture(source_animation, index))
	play_if_available(&"victory")
	attack_effect.modulate = Color("ffd34f")
	attack_effect.scale = Vector2(1.8, 1.8)
	attack_effect.visible = true
	attack_effect.play(&"attack")


func take_damage(damage: float, source_position: Vector2) -> void:
	if Time.get_ticks_msec() < invulnerable_until or not controls_enabled:
		return
	health = maxf(0.0, health - damage)
	AudioService.play_sfx(self, AudioService.PLAYER_HURT, 6.0)
	invulnerable_until = Time.get_ticks_msec() + int(stats.invulnerability_seconds * 1000.0)
	velocity.x = signf(global_position.x - source_position.x) * stats.knockback_force
	hurt_animation_until = Time.get_ticks_msec() + 450
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
		var game_hud := get_tree().get_first_node_in_group(&"game_hud") as GameHud
		if game_hud == null:
			GameState.return_to_menu()
			return
		game_hud.show_game_over()
		await game_hud.game_over_continue
		GameState.call_deferred(&"return_to_menu")
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
	if Time.get_ticks_msec() < hurt_animation_until:
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
