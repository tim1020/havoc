class_name Player
extends CharacterBody2D

const STAFF_STATS := preload("res://resources/stats/player_staff.tres")
const STAFF_FRAMES := preload("res://resources/animations/player_staff_frames.tres")
const STAFF_PROJECTILE := preload("res://src/combat/staff_projectile.tscn")
const ARTIFACT_PROJECTILE := preload("res://src/combat/artifact_projectile.gd")
const MONKEY_CLONE := preload("res://src/actors/player/monkey_clone.gd")
const ITEM_HOLD_SECONDS := 0.45

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
var slowed_until: int = 0
var rooted_until: int = 0
var confused_until: int = 0
var attack_started_in_air: bool = false
var item_held: bool = false
var item_consumed: bool = false
var item_pressed_at: int = 0


func _ready() -> void:
	if GameState.has_staff:
		stats = STAFF_STATS
		sprite.sprite_frames = STAFF_FRAMES
		sprite.scale = Vector2(0.25, 0.25)
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
		begin_item_hold()
	elif event.is_action_released("item"):
		release_item_hold()


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
	update_animation(direction)
	update_charge_feedback()
	update_item_hold()


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
	attack_started_in_air = not is_on_floor()


func cancel_attack_charge() -> void:
	attack_held = false
	attack_consumed = true
	attack_effect.stop()
	attack_effect.visible = false


func release_attack_charge() -> void:
	if not attack_held:
		return
	var held_seconds := float(Time.get_ticks_msec() - attack_pressed_at) / 1000.0
	attack_held = false
	attack_effect.stop()
	attack_effect.visible = false
	if attack_consumed:
		attack_consumed = false
		return
	if held_seconds >= stats.charge_seconds:
		# 满蓄力只按是否持棒分流，不再区分起跳或落地状态。
		if GameState.has_staff:
			launch_tracking_staffs()
		else:
			perform_roar()
	elif attack_started_in_air:
		# 空中短按是前向重击：第一段普攻伤害与有效距离均加倍。
		perform_attack(-1.0, 2.0, 2.0, true)
	else:
		perform_attack()


func perform_attack(damage_override: float = -1.0, distance_multiplier: float = 1.0, damage_multiplier: float = 1.0, aerial_heavy: bool = false) -> void:
	AudioService.play_sfx(self, AudioService.ATTACK, -4.0)
	var now := Time.get_ticks_msec()
	var damage := damage_override
	if aerial_heavy:
		combo_index = 0
		damage = stats.combo_damage[0]
		play_if_available("attack_3")
	elif damage_override >= 0.0:
		combo_index = 0
		play_if_available("attack_3")
	else:
		if now > combo_expires_at:
			combo_index = 0
		damage = stats.combo_damage[combo_index]
		combo_index = (combo_index + 1) % stats.combo_damage.size()
		combo_expires_at = now + int(stats.combo_reset_seconds * 1000.0)
		play_if_available("attack_%d" % (combo_index if combo_index > 0 else 3))
	damage *= damage_multiplier
	attack_effect.flip_h = facing < 0.0
	attack_effect.position.x = absf(attack_effect.position.x) * facing
	attack_effect.scale = Vector2(1.35, 1.35) if aerial_heavy else Vector2.ONE
	attack_effect.modulate = Color.WHITE
	attack_effect.visible = true
	attack_effect.play(&"attack")
	var attack_shape := attack_area.get_node("Shape").shape as RectangleShape2D
	if distance_multiplier > 1.0:
		var attack_distance := (absf(attack_area.position.x) + attack_shape.size.x * 0.5) * distance_multiplier
		for enemy_node in get_tree().get_nodes_in_group("enemies"):
			var enemy := enemy_node as Enemy
			var offset := enemy.global_position - global_position
			if offset.x * facing > 0.0 and offset.x * facing <= attack_distance and absf(offset.y) <= attack_shape.size.y:
				enemy.take_damage(damage, global_position)
		return
	attack_area.position.x = absf(attack_area.position.x) * facing
	await get_tree().physics_frame
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)


func update_charge_feedback() -> void:
	if not attack_held:
		sprite.modulate = Color("ffc1e7") if Time.get_ticks_msec() < confused_until else Color.WHITE
		sprite.scale = base_sprite_scale
		return
	if Time.get_ticks_msec() - attack_pressed_at < 120:
		return
	if not GameState.has_staff:
		# 空手蓄力复用角色图集里的周身怒火帧，避免待机常驻该效果。
		attack_effect.stop()
		attack_effect.visible = false
		play_if_available(&"respawn")
		return
	attack_effect.flip_h = facing < 0.0
	attack_effect.position.x = absf(attack_effect.position.x) * facing
	attack_effect.scale = Vector2.ONE * (1.15 + sin(Time.get_ticks_msec() * 0.018) * 0.08)
	attack_effect.modulate = Color("ffd34f")
	if not attack_effect.visible or not attack_effect.is_playing():
		attack_effect.visible = true
		attack_effect.play(&"attack")


func perform_roar() -> void:
	AudioService.play_sfx(self, AudioService.ATTACK, -2.0)
	play_if_available(&"spell")
	spawn_roar_effects()
	var attack_shape := attack_area.get_node("Shape").shape as RectangleShape2D
	# 怒吼只命中面朝方向，水平范围为普通攻击有效距离的三倍。
	var attack_distance := (absf(attack_area.position.x) + attack_shape.size.x * 0.5) * 3.0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		var offset := enemy.global_position - global_position
		if offset.x * facing > 0.0 and offset.x * facing <= attack_distance and absf(offset.y) <= attack_shape.size.y:
			enemy.take_damage(stats.charged_attack_damage, global_position)


func spawn_roar_effects() -> void:
	# 三段弧光覆盖近、中、远距离，让表现范围与怒吼判定范围一致。
	for index in 3:
		var wave := AnimatedSprite2D.new()
		wave.add_to_group(&"roar_effects")
		wave.sprite_frames = attack_effect.sprite_frames
		wave.animation = &"attack"
		wave.position = Vector2(facing * (90.0 + index * 95.0), -54.0)
		wave.flip_h = facing < 0.0
		wave.scale = Vector2.ONE * (1.35 + index * 0.28)
		wave.modulate = Color("ffd34f")
		wave.z_index = 2
		wave.animation_finished.connect(wave.queue_free)
		add_child(wave)
		wave.play()


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


func restore_full_health() -> void:
	health = stats.max_health
	health_changed.emit(health, stats.max_health)


func begin_item_hold() -> void:
	if item_held:
		return
	item_held = true
	item_consumed = false
	item_pressed_at = Time.get_ticks_msec()


func update_item_hold() -> void:
	if item_held and not item_consumed and Time.get_ticks_msec() - item_pressed_at >= int(ITEM_HOLD_SECONDS * 1000.0):
		item_consumed = true
		use_current_artifact()


func release_item_hold() -> void:
	if not item_held:
		return
	item_held = false
	if not item_consumed:
		GameState.rotate_artifacts()
	item_consumed = false


func apply_slow(seconds: float) -> void:
	slowed_until = maxi(slowed_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func apply_root(seconds: float) -> void:
	rooted_until = maxi(rooted_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	velocity.x = 0.0


func apply_confusion(seconds: float) -> void:
	confused_until = maxi(confused_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func movement_direction(raw_direction: float) -> float:
	return -raw_direction if Time.get_ticks_msec() < confused_until else raw_direction


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
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			result = enemy
	return result


func launch_tracking_staffs() -> void:
	var targets: Array[Enemy] = []
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if not enemy.dead:
			targets.append(enemy)
	if targets.is_empty():
		return
	targets.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	for index in 3:
		var projectile := STAFF_PROJECTILE.instantiate() as StaffProjectile
		projectile.global_position = global_position + Vector2(facing * 44.0, -30.0 - index * 30.0)
		projectile.source_position = global_position
		projectile.target = targets[index % targets.size()]
		projectile.damage = stats.combo_damage[0]
		get_tree().current_scene.add_child(projectile)
	play_if_available("spell")


func play_victory() -> void:
	attack_held = false
	item_held = false
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
	AudioService.play_sfx(self, AudioService.HIT, -3.0)
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
