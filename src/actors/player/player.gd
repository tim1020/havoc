class_name Player
extends CharacterBody2D

const STAFF_STATS := preload("res://resources/stats/player_staff.tres")
const STAFF_FRAMES := preload("res://resources/animations/player_staff_frames.tres")
const THROW_PROJECTILE := preload("res://src/combat/player_throw_projectile.gd")
const ARTIFACT_CAST_EFFECT := preload("res://src/combat/artifact_cast_effect.gd")
const ARTIFACT_FIRE_PATCH := preload("res://src/combat/artifact_fire_patch.gd")
const ARTIFACT_CAST_SHEET := preload("res://assets/generated/effects/wukong_artifact_cast_sheet.png")
const THROW_COOLDOWN_MS := 200
const RESPAWN_INVULNERABILITY_MS := 3000

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
var ground_combo_protection_until: int = 0
var invulnerable_until: int = 0
var controls_enabled: bool = true
var respawn_position: Vector2
var last_safe_platform_position: Vector2
var speed_boost_until: int = 0
var slowed_until: int = 0
var rooted_until: int = 0
var confused_until: int = 0
var invisible_until: int = 0
var artifact_selected: bool = false
var next_throw_at: int = 0
var hurt_animation_until: int = 0
var invulnerability_aura: Node2D
var confusion_stars: Node2D
var artifact_cast_sprite: AnimatedSprite2D
var one_way_floor: StaticBody2D


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
	last_safe_platform_position = global_position
	invulnerable_until = Time.get_ticks_msec() + 1000
	attack_area.monitoring = true
	setup_invulnerability_aura()
	setup_confusion_stars()
	setup_artifact_cast_sprite()
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
	remember_one_way_floor()
	if is_on_floor() and has_safe_floor_below(global_position):
		last_safe_platform_position = global_position
	update_status_visual()
	update_invulnerability_aura()
	update_animation(direction)


func try_jump() -> void:
	if Input.is_action_pressed("crouch") and is_on_floor() and drop_through_one_way_floor():
		return
	if jumps_left <= 0:
		return
	velocity.y = -stats.jump_velocity
	jumps_left -= 1
	AudioService.play_sfx(self, AudioService.JUMP)
	play_if_available("jump")


func remember_one_way_floor() -> void:
	one_way_floor = null
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision.get_normal().y > -0.7:
			continue
		var collider := collision.get_collider() as StaticBody2D
		if collider != null and collider.is_in_group(&"drop_through_platforms"):
			one_way_floor = collider
			return


func drop_through_one_way_floor() -> bool:
	if one_way_floor == null or not is_instance_valid(one_way_floor):
		return false
	var shape_node := one_way_floor.get_child(0) as CollisionShape2D
	if shape_node == null:
		return false
	shape_node.set_deferred("disabled", true)
	global_position.y += 8.0
	velocity.y = maxf(velocity.y, 80.0)
	one_way_floor = null
	get_tree().create_timer(0.18).timeout.connect(func() -> void:
		if is_instance_valid(shape_node):
			shape_node.set_deferred("disabled", false)
	)
	return true


func perform_attack() -> void:
	AudioService.play_sfx(self, AudioService.ATTACK)
	var now := Time.get_ticks_msec()
	if now > combo_expires_at:
		combo_index = 0
	var is_final_combo_hit := combo_index == stats.combo_damage.size() - 1
	var damage := stats.combo_damage[combo_index]
	combo_index = (combo_index + 1) % stats.combo_damage.size()
	combo_expires_at = now + int(stats.combo_reset_seconds * 1000.0)
	ground_combo_protection_until = now + 280
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
			if is_final_combo_hit and body is Enemy:
				body.launch_from(global_position, 760.0)


func has_ground_combo_protection() -> bool:
	return Time.get_ticks_msec() < ground_combo_protection_until


func setup_invulnerability_aura() -> void:
	invulnerability_aura = Node2D.new()
	invulnerability_aura.position = Vector2(0.0, -48.0)
	for ring_index in 3:
		var aura_stream := Line2D.new()
		var points := PackedVector2Array()
		for index in 17:
			var angle := TAU * index / 16.0 + ring_index * 0.8
			var radius := 36.0 + ring_index * 8.0 + sin(angle * 3.0) * 5.0
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.45))
		aura_stream.points = points
		aura_stream.width = 2.4
		aura_stream.default_color = Color("ffd85a", 0.72)
		invulnerability_aura.add_child(aura_stream)
	invulnerability_aura.z_index = 3
	invulnerability_aura.visible = false
	add_child(invulnerability_aura)


func setup_confusion_stars() -> void:
	confusion_stars = Node2D.new()
	confusion_stars.position = Vector2(0.0, -146.0)
	for offset in [Vector2(-22.0, 0.0), Vector2(5.0, -12.0), Vector2(24.0, 5.0)]:
		var star := Label.new()
		star.text = "✦"
		star.position = offset
		star.add_theme_font_size_override("font_size", 22)
		star.add_theme_color_override("font_color", Color("ffe45c"))
		confusion_stars.add_child(star)
	confusion_stars.z_index = 10
	confusion_stars.visible = false
	add_child(confusion_stars)


func update_invulnerability_aura() -> void:
	if invulnerability_aura == null:
		return
	var active := Time.get_ticks_msec() < invulnerable_until
	invulnerability_aura.visible = active
	if active:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.014) * 0.1
		invulnerability_aura.scale = Vector2(pulse, pulse)
		invulnerability_aura.rotation += 0.025

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
	projectile.target = nearest_forward_attack_target()
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
	var confused := Time.get_ticks_msec() < confused_until
	var tint := Color("f2a1cf") if confused else Color.WHITE
	tint.a = 0.42 if is_physically_invisible() else 1.0
	sprite.modulate = tint
	if confusion_stars != null:
		confusion_stars.visible = confused
		if confused:
			confusion_stars.rotation = sin(Time.get_ticks_msec() * 0.012) * 0.12


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
	play_artifact_cast_animation()
	show_artifact_cast_effect(item)
	var enemies := get_tree().get_nodes_in_group("enemies")
	if item.id == &"freeze_talisman":
		for enemy_node in enemies:
			var enemy := enemy_node as Enemy
			if enemy != null and not enemy.dead:
				enemy.freeze_for(item.duration)
		return
	if item.id == &"invisibility_talisman":
		invisible_until = Time.get_ticks_msec() + int(item.duration * 1000.0)
		update_status_visual()
		return
	if item.id == &"samadhi_fire":
		spawn_samadhi_fire(item)
		return
	if item.id == &"banana_fan":
		clear_visible_minions()
		return
	if item.id == &"purple_bell":
		for enemy_node in enemies:
			var enemy := enemy_node as Enemy
			if enemy != null and not enemy.dead:
				enemy.hallucinate_for(item.duration)
		return


func show_artifact_flash(item: ItemDefinition) -> void:
	attack_effect.modulate = item.color
	attack_effect.scale = Vector2(1.4, 1.4)
	attack_effect.flip_h = facing < 0.0
	attack_effect.position.x = absf(attack_effect.position.x) * facing
	attack_effect.visible = true
	attack_effect.play("attack")


func show_artifact_cast_effect(item: ItemDefinition) -> void:
	var effect = ARTIFACT_CAST_EFFECT.new()
	effect.color = item.color
	effect.style = &"fan" if item.id == &"banana_fan" else (&"fire" if item.id == &"samadhi_fire" else &"ring")
	effect.global_position = global_position + Vector2(0.0, -52.0)
	get_tree().current_scene.add_child(effect)


func setup_artifact_cast_sprite() -> void:
	artifact_cast_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation(&"cast")
	var cell_size := Vector2(ARTIFACT_CAST_SHEET.get_size()) / Vector2(4.0, 2.0)
	for frame_index in 8:
		var atlas := AtlasTexture.new()
		atlas.atlas = ARTIFACT_CAST_SHEET
		var column := frame_index % 4
		var row := frame_index / 4
		atlas.region = Rect2(Vector2(column, row) * cell_size + Vector2(4.0, 4.0), cell_size - Vector2(8.0, 8.0))
		frames.add_frame(&"cast", atlas)
	frames.set_animation_speed(&"cast", 12.0)
	frames.set_animation_loop(&"cast", false)
	artifact_cast_sprite.sprite_frames = frames
	artifact_cast_sprite.scale = Vector2(0.34, 0.34)
	artifact_cast_sprite.position = Vector2(0.0, -78.0)
	artifact_cast_sprite.z_index = 8
	artifact_cast_sprite.visible = false
	add_child(artifact_cast_sprite)


func play_artifact_cast_animation() -> void:
	artifact_cast_sprite.flip_h = facing < 0.0
	artifact_cast_sprite.visible = true
	artifact_cast_sprite.play(&"cast")
	sprite.visible = false
	await get_tree().create_timer(0.68).timeout
	if is_instance_valid(artifact_cast_sprite):
		artifact_cast_sprite.visible = false
		sprite.visible = true


func spawn_samadhi_fire(item: ItemDefinition) -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy == null or enemy.dead or not is_enemy_on_screen(enemy):
			continue
		var flame = ARTIFACT_FIRE_PATCH.new()
		flame.target = enemy
		flame.damage = stats.combo_damage[0]
		flame.duration = item.duration
		flame.global_position = enemy.global_position + Vector2(0.0, -342.0)
		get_tree().current_scene.add_child(flame)


func clear_visible_minions() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy != null and not enemy.dead and not enemy.stats.is_boss and is_enemy_on_screen(enemy):
			enemy.launch_from(global_position, 1500.0)


func is_physically_invisible() -> bool:
	return Time.get_ticks_msec() < invisible_until


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


func nearest_forward_attack_target() -> Node2D:
	var enemy := nearest_forward_visible_enemy()
	if enemy != null:
		return enemy
	var result: Node2D
	var best_distance := INF
	for projectile_node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		var enemy_projectile := projectile_node as Node2D
		if enemy_projectile == null or enemy_projectile.is_queued_for_deletion() or not is_position_on_screen(enemy_projectile.global_position):
			continue
		var offset := enemy_projectile.global_position - global_position
		if offset.x * facing <= 0.0:
			continue
		var distance := offset.length_squared()
		if distance < best_distance:
			best_distance = distance
			result = enemy_projectile
	return result


func is_enemy_on_screen(enemy: Enemy) -> bool:
	return is_position_on_screen(enemy.global_position + Vector2(0, -48))


func is_position_on_screen(position_value: Vector2) -> bool:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return true
	var visible_size := get_viewport_rect().size / camera.zoom
	var visible_rect := Rect2(camera.get_screen_center_position() - visible_size * 0.5, visible_size)
	return visible_rect.grow(48.0).has_point(position_value)


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
		die_and_respawn(global_position if has_safe_floor_below(global_position) else safe_respawn_position())


func fall_into_pit() -> void:
	if not controls_enabled:
		return
	die_and_respawn(safe_respawn_position())


func die_and_respawn(revive_position: Vector2) -> void:
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
	global_position = revive_position
	health = stats.max_health
	invulnerable_until = Time.get_ticks_msec() + RESPAWN_INVULNERABILITY_MS
	repel_nearby_enemies()
	play_if_available("respawn")
	health_changed.emit(health, stats.max_health)
	await get_tree().create_timer(0.35).timeout
	controls_enabled = true
	respawned.emit()


func set_checkpoint(checkpoint: Vector2) -> void:
	respawn_position = checkpoint
	last_safe_platform_position = checkpoint


func has_safe_floor_below(position_value: Vector2) -> bool:
	for offset_x in [-24.0, 0.0, 24.0]:
		var query := PhysicsRayQueryParameters2D.create(position_value + Vector2(offset_x, -8.0), position_value + Vector2(offset_x, 90.0), 1)
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func safe_respawn_position() -> Vector2:
	return last_safe_platform_position if has_safe_floor_below(last_safe_platform_position) else respawn_position


func repel_nearby_enemies() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy != null and not enemy.dead and global_position.distance_to(enemy.global_position) <= 250.0:
			enemy.launch_from(global_position, 680.0)


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
