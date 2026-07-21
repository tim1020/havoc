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
	EVADE,
}

const FRAME_SIZE := Vector2(128.0, 128.0)
const ALLY_ALERT_RANGE := 520.0
const PIT_DEATH_Y := 730.0
const STONE_THROW_RANGE := 520.0
const STONE_THROW_DAMAGE := 7.0
const STONE_THROW_SPEED := 440.0
const STONE_THROW_COOLDOWN_MS := 2600
const PLATFORM_JUMP_VELOCITY := 620.0
const PLATFORM_JUMP_HORIZONTAL_RANGE := 300.0
const COMBO_STANDOFF_RANGE := 230.0
const PLAYER_LOST_PATROL_DELAY_MS := 1400
const MELEE_EFFECT_ATLAS := preload("res://assets/vector/effects/melee_arc_frames.svg")
const ENEMY_PROJECTILE := preload("res://src/combat/enemy_projectile.gd")

@export var stats: EnemyStats
@export var behavior: Behavior = Behavior.MELEE
@export_range(0.0, 1200.0, 1.0) var patrol_distance: float = 220.0
@export var animation_atlas: Texture2D
@export_range(0, 5, 1) var atlas_row: int = 0
@export var visual_scale: Vector2 = Vector2.ONE

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var attack_effect: AnimatedSprite2D = %AttackEffect
@onready var body_shape: CollisionShape2D = $BodyShape

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
var shield_health: float = 0.0
var next_projectile_at: int = 0
var next_boss_reposition_at: int = 0
var protected_by_group: StringName = &""
var protects_group: StringName = &""
var bodyguard_attacks: bool = true
var bodyguard_distance: float = 130.0
var protected_damage_multiplier: float = 0.2
var patrol_target_x: float
var next_patrol_decision_at: int = 0
var patrol_pause_until: int = 0
var boss_target_lost_until: int = 0
var next_boss_target_loss_at: int = 0
var visual_facing_direction: float = 1.0
var last_player_side: float = 0.0
var engaged: bool = false
var target_player: Player
var can_reposition: bool = false
var avoiding_player_combo: bool = false
var ambush_until: int = 0
var launched_until: int = 0
var player_lost_since: int = 0
var hallucinated_until: int = 0


func _ready() -> void:
	assert(stats != null, "EnemyStats is required")
	assert(animation_atlas != null, "Enemy animation atlas is required")
	visual_facing_direction = 1.0 if stats.faces_right_by_default else -1.0
	sprite.position.y = stats.sprite_position_y
	add_to_group("enemies")
	if stats.is_boss:
		add_to_group("bosses")
	health = stats.max_health
	shield_health = stats.shield_health
	base_collision_layer = collision_layer
	base_collision_mask = collision_mask
	spawn_position = global_position
	choose_patrol_target()
	next_boss_reposition_at = Time.get_ticks_msec() + randi_range(7000, 10000)
	disguised = stats.disguise_reveal_distance > 0.0
	setup_character_frames()
	setup_attack_effect_frames()
	apply_visual_scale(visual_scale)
	sprite.play("idle")
	health_changed.emit(health, stats.max_health)


func apply_visual_scale(scale_value: Vector2) -> void:
	visual_scale = scale_value
	sprite.scale = scale_value
	body_shape.scale = scale_value
	body_shape.position = Vector2(0.0, -38.0 * scale_value.y)


func _process(delta: float) -> void:
	if dead:
		return
	visual_time += delta
	update_ghost_state()
	update_visual_animation()


func _physics_process(delta: float) -> void:
	if dead:
		return
	if is_pit_fall():
		if stats.is_boss:
			rescue_boss_from_pit()
		else:
			die()
		return
	if Time.get_ticks_msec() < frozen_until:
		velocity = Vector2.ZERO
		return
	if Time.get_ticks_msec() < hallucinated_until:
		update_hallucination(delta)
		return
	if Time.get_ticks_msec() < launched_until:
		if behavior != Behavior.FLYING:
			velocity.y += stats.gravity * delta
		move_and_slide()
		return

	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Player
	var player := target_player
	if player != null and player.is_physically_invisible():
		if not stats.is_boss and behavior != Behavior.FLYING:
			player_lost_since = Time.get_ticks_msec() - PLAYER_LOST_PATROL_DELAY_MS
		else:
			velocity = Vector2.ZERO
			return
	if not engaged:
		engaged = should_engage(player)
		if not engaged:
			velocity.x = 0.0
			if behavior == Behavior.FLYING:
				velocity.y = 0.0
			elif not is_on_floor():
				velocity.y += stats.gravity * delta
			move_and_slide()
			return
	if should_resume_patrol(player):
		if behavior == Behavior.FLYING:
			velocity = Vector2.ZERO
		else:
			if not is_on_floor():
				velocity.y += stats.gravity * delta
			patrol()
			stop_at_blocked_path()
		update_player_body_collision(player)
		move_and_slide()
		return
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
		stop_at_blocked_path()
	update_player_body_collision(player)

	move_and_slide()
	apply_contact_damage()


func is_pit_fall() -> bool:
	return behavior != Behavior.FLYING and global_position.y > PIT_DEATH_Y


func rescue_boss_from_pit() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	health = maxf(1.0, health - stats.max_health * 0.12)
	invulnerable_until = Time.get_ticks_msec() + 500
	hit_reaction_until = Time.get_ticks_msec() + 260
	health_changed.emit(health + shield_health, stats.max_health + stats.shield_health)
	hit_received.emit(self, health + shield_health, stats.max_health + stats.shield_health)


func should_engage(player: Player) -> bool:
	if player == null:
		return false
	return can_see_player(player)


func can_see_player(player: Player) -> bool:
	return player != null and global_position.distance_to(player.global_position) <= maxf(stats.detection_range, 360.0) and has_clear_line_to_player(player)


func should_resume_patrol(player: Player) -> bool:
	if stats.is_boss or behavior == Behavior.FLYING:
		return false
	if can_see_player(player):
		player_lost_since = 0
		return false
	if player_lost_since == 0:
		player_lost_since = Time.get_ticks_msec()
	return Time.get_ticks_msec() - player_lost_since >= PLAYER_LOST_PATROL_DELAY_MS


func engage_nearby_allies() -> void:
	engaged = true
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var ally := enemy_node as Enemy
		if ally == self or ally.dead or not is_same_section(ally):
			continue
		if global_position.distance_to(ally.global_position) <= ALLY_ALERT_RANGE:
			ally.engaged = true


func is_same_section(ally: Enemy) -> bool:
	if has_meta(&"section_index") and ally.has_meta(&"section_index"):
		return int(get_meta(&"section_index")) == int(ally.get_meta(&"section_index"))
	return true


func stop_at_blocked_path() -> void:
	if absf(velocity.x) < 1.0 or not is_on_floor():
		return
	var direction := signf(velocity.x)
	var ray_start := global_position + Vector2(direction * 42.0, -8.0)
	var ray_end := ray_start + Vector2(0.0, 90.0)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end, 1)
	query.exclude = [get_rid()]
	if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		velocity.x = 0.0


func update_grounded(player: Player) -> void:
	if player == null:
		velocity.x = 0.0
		return
	if can_reposition and Time.get_ticks_msec() >= next_boss_reposition_at and (behavior == Behavior.EVADE or not has_clear_line_to_player(player)):
		reposition_boss()
	if not protects_group.is_empty() and update_bodyguard_position(player):
		return
	var distance := player.global_position - global_position
	var detection_range := maxf(stats.detection_range, 720.0)
	if behavior == Behavior.BOSS and update_boss_target_loss(player, distance):
		return
	if behavior == Behavior.BOSS and absf(distance.x) > detection_range:
		try_ranged_attack(player)

	patrol_direction = signf(distance.x)
	face_direction(patrol_direction)
	if not stats.is_boss and player.has_ground_combo_protection():
		avoid_player_combo(distance)
		return
	if avoiding_player_combo:
		avoiding_player_combo = false
		ambush_until = Time.get_ticks_msec() + 420
	if try_jump_to_player_platform(distance):
		return
	if can_throw_ground_projectile_at(player, distance):
		velocity.x = move_toward(velocity.x, 0.0, 160.0)
		try_ranged_attack(player, true)
		return
	if behavior == Behavior.EVADE:
		patrol_direction = -patrol_direction
		face_direction(patrol_direction)
		velocity.x = patrol_direction * stats.move_speed
	elif behavior == Behavior.CHARGE and Time.get_ticks_msec() >= next_charge_at:
		velocity.x = patrol_direction * stats.move_speed * 2.7
		next_charge_at = Time.get_ticks_msec() + 2200
	elif behavior == Behavior.BOSS and absf(distance.x) > stats.attack_range and try_ranged_attack(player):
		velocity.x = move_toward(velocity.x, 0.0, 160.0)
	elif absf(distance.x) > stats.attack_range:
		var multiplier := 1.3 if behavior == Behavior.BOSS and phase_two else 1.0
		var ambush_multiplier := 2.0 if Time.get_ticks_msec() < ambush_until and not stats.is_boss else 1.0
		velocity.x = patrol_direction * stats.move_speed * multiplier * ambush_multiplier
	else:
		velocity.x = move_toward(velocity.x, 0.0, 80.0)
		try_attack(player)


func update_boss_target_loss(player: Player, distance: Vector2) -> bool:
	var now := Time.get_ticks_msec()
	if now < boss_target_lost_until:
		velocity.x = move_toward(velocity.x, 0.0, 140.0)
		return true
	var player_side := signf(distance.x)
	var crossed_behind := not is_zero_approx(last_player_side) and not is_zero_approx(player_side) and player_side != last_player_side
	var jumped_past := crossed_behind and absf(distance.x) < 320.0 and player.global_position.y < global_position.y + 30.0
	last_player_side = player_side
	if jumped_past and now >= next_boss_target_loss_at:
		boss_target_lost_until = now + randi_range(600, 1000)
		next_boss_target_loss_at = boss_target_lost_until + randi_range(1800, 2800)
		velocity.x = move_toward(velocity.x, 0.0, 140.0)
		return true
	return false


func reposition_boss() -> void:
	next_boss_reposition_at = Time.get_ticks_msec() + randi_range(7000, 10000)
	var section_width := 2560.0
	var section := floori(global_position.x / section_width)
	var level := get_parent()
	var valid_ground: Array[Rect2] = []
	if level != null and level.has_method(&"ground_rects"):
		for ground_value in level.ground_rects():
			var ground := ground_value as Rect2
			if floori(ground.get_center().x / section_width) == section and ground.size.x > 180.0:
				valid_ground.append(ground)
	valid_ground.shuffle()
	for ground in valid_ground:
		var target_x := randf_range(ground.position.x + 80.0, ground.end.x - 80.0)
		if absf(target_x - global_position.x) < 320.0:
			continue
		global_position = Vector2(target_x, ground.position.y - 70.0)
		velocity = Vector2.ZERO
		spawn_position = global_position
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.25, 0.06)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.08)
		return


func update_bodyguard_position(player: Player) -> bool:
	var protected := get_tree().get_first_node_in_group(protects_group) as Enemy
	if protected == null or protected.dead:
		return false
	var player_direction := signf(player.global_position.x - protected.global_position.x)
	if is_zero_approx(player_direction):
		player_direction = 1.0
	var guard_position := protected.global_position.x + player_direction * bodyguard_distance
	var distance_to_guard_position := guard_position - global_position.x
	patrol_direction = signf(distance_to_guard_position)
	face_direction(player.global_position.x - global_position.x)
	if bodyguard_attacks and absf(player.global_position.x - global_position.x) <= stats.attack_range:
		velocity.x = move_toward(velocity.x, 0.0, 100.0)
		try_attack(player)
	elif absf(distance_to_guard_position) > 35.0:
		velocity.x = patrol_direction * stats.move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 100.0)
	return true


func patrol() -> void:
	var now := Time.get_ticks_msec()
	if now < patrol_pause_until:
		velocity.x = move_toward(velocity.x, 0.0, 100.0)
		return
	if now >= next_patrol_decision_at or absf(global_position.x - patrol_target_x) < 28.0:
		if randf() < 0.35:
			patrol_pause_until = now + randi_range(250, 850)
		choose_patrol_target()
	patrol_direction = signf(patrol_target_x - global_position.x)
	velocity.x = patrol_direction * stats.move_speed * randf_range(0.35, 0.65)
	face_direction(patrol_direction)


func choose_patrol_target() -> void:
	patrol_target_x = spawn_position.x + randf_range(-patrol_distance, patrol_distance)
	next_patrol_decision_at = Time.get_ticks_msec() + randi_range(900, 2400)


func update_flying(delta: float, player: Player) -> void:
	flight_time += delta
	if player == null:
		velocity = Vector2.ZERO
		return
	var target := player.global_position + Vector2(0.0, -54.0)
	var flank := signf(global_position.x - player.global_position.x)
	if is_zero_approx(flank):
		flank = -1.0 if sprite.flip_h else 1.0
	if stats.flying_attack_style == "shock":
		target = player.global_position + Vector2(flank * 80.0, -56.0)
	elif stats.flying_attack_style == "wail":
		target = player.global_position + Vector2(flank * 58.0, -48.0)
	elif stats.flying_attack_style == "projectile":
		target = player.global_position + Vector2(flank * 150.0, -140.0)
	velocity = Vector2.ZERO if global_position.distance_to(target) < 28.0 else global_position.direction_to(target) * stats.move_speed * 0.5
	face_direction(velocity.x)
	if not has_clear_line_to_player(player):
		return
	if stats.flying_attack_style == "projectile":
		try_ranged_attack(player)
	elif global_position.distance_to(player.global_position + Vector2(0.0, -42.0)) <= stats.attack_range:
		try_attack(player)


func face_direction(direction: float) -> void:
	if is_zero_approx(direction):
		return
	visual_facing_direction = direction
	apply_sprite_facing(sprite.animation)


func apply_sprite_facing(animation: StringName) -> void:
	var flip := visual_facing_direction < 0.0 if stats.faces_right_by_default else visual_facing_direction > 0.0
	if animation == &"attack" and stats.attack_frames_face_opposite:
		flip = not flip
	sprite.flip_h = flip


func update_player_body_collision(player: Player) -> void:
	if player == null:
		return
	var shares_horizontal_plane := absf(player.global_position.y - global_position.y) <= 90.0
	var player_mask := 2 if shares_horizontal_plane else 0
	collision_mask = (base_collision_mask & ~2) | player_mask
	if shares_horizontal_plane:
		remove_collision_exception_with(player)
		player.remove_collision_exception_with(self)
	else:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


func can_throw_ground_projectile_at(player: Player, distance: Vector2) -> bool:
	if player == null or behavior == Behavior.FLYING or stats.is_boss:
		return false
	if absf(distance.y) > 100.0 or absf(distance.x) <= stats.attack_range or absf(distance.x) > STONE_THROW_RANGE:
		return false
	return signf(distance.x) == patrol_direction and ground_path_blocked_toward_player()


func ground_path_blocked_toward_player() -> bool:
	if is_on_wall():
		return true
	var direction := patrol_direction
	if is_zero_approx(direction):
		return false
	var ray_start := global_position + Vector2(direction * 52.0, -12.0)
	var ray_end := ray_start + Vector2(0.0, 100.0)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end, 1)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func avoid_player_combo(distance: Vector2) -> void:
	avoiding_player_combo = true
	if absf(distance.x) < COMBO_STANDOFF_RANGE:
		velocity.x = -patrol_direction * stats.move_speed * 0.8
	else:
		velocity.x = move_toward(velocity.x, 0.0, 180.0)


func try_jump_to_player_platform(distance: Vector2) -> bool:
	if stats.is_boss or not is_on_floor() or distance.y >= -70.0 or absf(distance.x) > PLATFORM_JUMP_HORIZONTAL_RANGE:
		return false
	if ground_path_blocked_toward_player():
		return false
	var landing_x := global_position.x + patrol_direction * minf(absf(distance.x), PLATFORM_JUMP_HORIZONTAL_RANGE)
	var ray_start := Vector2(landing_x, global_position.y - 300.0)
	var ray_end := Vector2(landing_x, global_position.y + 30.0)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end, 1)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.position as Vector2).y >= global_position.y - 45.0:
		return false
	var arc_query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -72.0), Vector2(landing_x, global_position.y - 260.0), 1)
	arc_query.exclude = [get_rid()]
	if not get_world_2d().direct_space_state.intersect_ray(arc_query).is_empty():
		return false
	velocity.y = -PLATFORM_JUMP_VELOCITY
	return true


func try_ranged_attack(player: Player, force_forward_stone: bool = false) -> bool:
	if not bodyguard_attacks:
		return false
	var throws_ground_projectile := force_forward_stone and not stats.is_boss
	if player == null or not has_clear_line_to_player(player) or (stats.projectile_damage <= 0.0 and not throws_ground_projectile) or Time.get_ticks_msec() < next_projectile_at:
		return false
	next_projectile_at = Time.get_ticks_msec() + (STONE_THROW_COOLDOWN_MS if throws_ground_projectile else int(stats.projectile_cooldown * 1000.0))
	AudioService.play_sfx(self, AudioService.ENEMY_THROW, -1.0)
	attack_animation_until = Time.get_ticks_msec() + 320
	var aim := Vector2(patrol_direction, 0.0) if throws_ground_projectile else (player.global_position + Vector2(0, -42) - (global_position + Vector2(0, -52))).normalized()
	face_direction(player.global_position.x - global_position.x)
	var angles := [-0.18, 0.0, 0.18] if phase_two else [0.0]
	for angle in angles:
		var projectile = ENEMY_PROJECTILE.new()
		projectile.direction = aim.rotated(angle)
		projectile.speed = STONE_THROW_SPEED if throws_ground_projectile else stats.projectile_speed
		projectile.damage = STONE_THROW_DAMAGE if throws_ground_projectile else stats.projectile_damage * (stats.phase_damage_multiplier if phase_two else 1.0)
		projectile.color = stats.projectile_color
		projectile.style = stats.ground_projectile_style if throws_ground_projectile else stats.projectile_style
		projectile.source_position = global_position
		projectile.global_position = global_position + Vector2(0, -52)
		get_tree().current_scene.add_child(projectile)
	return true


func try_attack(player: Player) -> void:
	if not bodyguard_attacks:
		return
	if not has_clear_line_to_player(player):
		return
	if behavior != Behavior.FLYING and absf(player.global_position.y - global_position.y) > 90.0:
		return
	if not stats.is_boss and player.has_ground_combo_protection():
		return
	if Time.get_ticks_msec() < next_attack_at:
		return
	next_attack_at = Time.get_ticks_msec() + (700 if phase_two else 1100)
	AudioService.play_sfx(self, AudioService.ENEMY_ATTACK, -1.0)
	attack_animation_until = Time.get_ticks_msec() + 260
	attack_effect.flip_h = sprite.flip_h
	attack_effect.position.x = -58.0 if sprite.flip_h else 58.0
	attack_effect.visible = true
	attack_effect.play("attack")
	var backstab := signf(player.global_position.x - global_position.x) == patrol_direction
	var damage := stats.contact_damage * (stats.phase_damage_multiplier if phase_two else 1.0)
	player.take_damage(damage * (stats.backstab_multiplier if backstab else 1.0), global_position)
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


func has_clear_line_to_player(player: Player) -> bool:
	if player == null or player.is_physically_invisible():
		return false
	var ray_start := global_position + Vector2(0.0, -52.0)
	var ray_end := player.global_position + Vector2(0.0, -42.0)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end, 3)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player


func take_damage(damage: float, source_position: Vector2) -> void:
	if dead or not ghost_solid or Time.get_ticks_msec() < invulnerable_until:
		return
	engage_nearby_allies()
	if has_active_protector():
		damage *= protected_damage_multiplier
	AudioService.play_sfx(self, AudioService.ENEMY_HURT)
	if shield_health > 0.0:
		shield_health = maxf(0.0, shield_health - damage)
		invulnerable_until = Time.get_ticks_msec() + int(stats.invulnerability_seconds * 1000.0)
		hit_reaction_until = Time.get_ticks_msec() + 180
		hit_received.emit(self, health + shield_health, stats.max_health + stats.shield_health)
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


func has_active_protector() -> bool:
	if protected_by_group.is_empty():
		return false
	for protector_node in get_tree().get_nodes_in_group(protected_by_group):
		var protector := protector_node as Enemy
		if protector != null and not protector.dead:
			return true
	return false


func take_projectile_damage(damage: float, source_position: Vector2) -> bool:
	if stats.reflects_projectiles:
		attack_animation_until = Time.get_ticks_msec() + 260
		return false
	take_damage(damage, source_position)
	return true


func launch_from(source_position: Vector2, force: float) -> void:
	var direction := global_position - source_position
	if direction.length_squared() < 1.0:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	velocity = Vector2(direction.x * force, -force * 0.42)
	launched_until = Time.get_ticks_msec() + 360


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
	apply_sprite_facing(next_animation)
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
			frames.add_frame(animation, create_atlas_frame(animation_atlas, column, atlas_row, stats.animation_frame_size))
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


func create_atlas_frame(atlas: Texture2D, column: int, row: int, frame_size: Vector2 = FRAME_SIZE) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = atlas
	frame.region = Rect2(Vector2(column, row) * frame_size, frame_size)
	return frame


func freeze_for(seconds: float) -> void:
	frozen_until = maxi(frozen_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.15, 0.9, 0.35), 0.08)
	tween.tween_interval(seconds)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func hallucinate_for(seconds: float) -> void:
	hallucinated_until = maxi(hallucinated_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func update_hallucination(delta: float) -> void:
	var target: Enemy
	var best_distance := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var ally := enemy_node as Enemy
		if ally == null or ally == self or ally.dead or not is_same_section(ally):
			continue
		var distance := global_position.distance_squared_to(ally.global_position)
		if distance < best_distance:
			best_distance = distance
			target = ally
	if target == null:
		velocity = Vector2.ZERO
		return
	var distance_to_target := target.global_position - global_position
	face_direction(distance_to_target.x)
	if not is_on_floor():
		velocity.y += stats.gravity * delta
	if absf(distance_to_target.x) > stats.attack_range:
		velocity.x = signf(distance_to_target.x) * stats.move_speed
	else:
		velocity.x = 0.0
		if Time.get_ticks_msec() >= next_attack_at:
			next_attack_at = Time.get_ticks_msec() + 1100
			target.take_damage(stats.contact_damage, global_position)
			attack_animation_until = Time.get_ticks_msec() + 260
	move_and_slide()


func die() -> void:
	dead = true
	set_physics_process(false)
	AudioService.play_sfx(self, AudioService.ENEMY_DEATH, 1.0)
	defeated.emit(stats.spirit_stones)
	sprite.speed_scale = 1.0
	sprite.play("death")
	await sprite.animation_finished
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	await tween.finished
	queue_free()
