extends Node

const LEVEL_05 := preload("res://src/levels/level_05/level_05.tscn")
const ARCHER := preload("res://resources/stats/enemies/heaven_archer.tres")
const ARCHER_FRAMES := preload("res://assets/generated/characters/campaign/heaven_archer_frames.png")
const GIANT := preload("res://resources/stats/enemies/giant_spirit.tres")
const VAISHRAVANA := preload("res://resources/stats/enemies/vaishravana.tres")
const VAISHRAVANA_FRAMES := preload("res://assets/generated/characters/campaign/vaishravana_frames_v2.png")

var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_path = "/tmp/havoc_level05_adjustments_save.json"
	GameState.settings.reduced_motion = true
	await run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var level = LEVEL_05.instantiate()
	add_child(level)
	while get_tree().paused:
		await get_tree().create_timer(0.05, true).timeout
	await get_tree().process_frame

	var giant_scale := Vector2.ZERO
	for enemy_spec in level.enemy_specs():
		if enemy_spec.stats == GIANT:
			giant_scale = enemy_spec.scale
			break
	check(giant_scale == Vector2(1.8, 1.8) and GIANT.animation_frame_size == Vector2(256.0, 256.0), "巨灵神使用高清大尺寸动画帧")
	var giant := level.spawn_enemy(level.player.global_position + Vector2(300.0, 0.0), GIANT, level.GIANT_FRAMES, &"adjustment_test") as Enemy
	giant.apply_visual_scale(giant_scale)
	giant.set_physics_process(false)
	var giant_hurt_frame := giant.sprite.sprite_frames.get_frame_texture(&"hurt", 0) as AtlasTexture
	check(giant.animation_atlas.resource_path.ends_with("giant_spirit_frames_v2.png") and giant_hurt_frame.region == Rect2(1536.0, 0.0, 256.0, 256.0), "巨灵神受击动画使用新图集中的完整独立帧")
	check(absf(giant.sprite.position.y + (226.0 - 128.0) * giant_scale.y) < 1.0, "巨灵神脚底与地面误差小于1像素")
	check(giant.body_shape.scale == giant_scale and is_equal_approx(giant.body_shape.position.y, -68.4), "巨灵神碰撞体随视觉等比放大并保持底部落地")
	giant.queue_free()
	await get_tree().process_frame

	var archer := level.spawn_enemy(level.player.global_position + Vector2(240.0, 0.0), ARCHER, ARCHER_FRAMES, &"adjustment_test") as Enemy
	archer.set_physics_process(false)
	archer.sprite.flip_h = true
	archer.patrol_direction = -1.0
	archer.next_projectile_at = 0
	var archer_fired := archer.try_ranged_attack(level.player, true)
	archer.update_visual_animation()
	check(archer_fired and archer.sprite.animation == &"attack" and archer.sprite.flip_h, "天弓手攻击帧始终朝向左侧的悟空")
	var arrow := get_tree().get_nodes_in_group(&"enemy_projectiles").back() as EnemyProjectile
	var arrow_sprite := arrow.get_child(0) as Sprite2D
	check(arrow.style == "arrow" and arrow_sprite.texture == EnemyProjectile.HEAVEN_ARROW_TEXTURE, "天弓手使用新生成的透明箭矢效果")
	arrow.queue_free()
	archer.queue_free()
	await get_tree().process_frame

	var king := level.spawn_enemy(level.player.global_position + Vector2(260.0, 0.0), VAISHRAVANA, VAISHRAVANA_FRAMES, &"adjustment_test") as Enemy
	king.behavior = Enemy.Behavior.BOSS
	king.apply_visual_scale(Vector2(1.5, 1.5))
	king.set_physics_process(false)
	king.invulnerable_until = 0
	var vaishravana_hurt_frame := king.sprite.sprite_frames.get_frame_texture(&"hurt", 0) as AtlasTexture
	check(VAISHRAVANA.animation_frame_size == Vector2(256.0, 256.0) and vaishravana_hurt_frame.region == Rect2(1536.0, 0.0, 256.0, 256.0), "多闻天王使用无串帧的高清新图集")
	check(absf(king.sprite.position.y + (199.0 - 128.0) * king.visual_scale.y) < 1.0, "多闻天王脚底与地面误差小于1像素")
	var health_before := king.health
	var accepted := king.take_projectile_damage(15.0, level.player.global_position)
	await get_tree().process_frame
	check(accepted and king.health == health_before - 15.0, "多闻天王被远程命中后正常扣血")
	check(level.hud.enemy_panel.visible and level.hud.enemy_name_label.text == "多闻天王", "多闻天王被命中后显示Boss血条")
	king.queue_free()
	await get_tree().process_frame

	check(level.KING_STATS[0].contact_root_seconds > 0.0, "持国天王使用定身攻击")
	check(level.KING_STATS[1].projectile_style == "divine_spear" and not level.KING_STATS[1].phase_thresholds.is_empty(), "增长天王使用剑气和半血强化")
	check(level.KING_STATS[2].contact_slow_seconds > 0.0, "广目天王使用减速攻击")
	check(level.KING_STATS[3].contact_confusion_seconds > 0.0, "多闻天王使用混乱攻击")
	var king_cooldowns_are_faster := true
	for stats: EnemyStats in level.KING_STATS:
		king_cooldowns_are_faster = king_cooldowns_are_faster and stats.projectile_cooldown <= 1.3
	check(king_cooldowns_are_faster, "四大天王攻击冷却统一加快")

	level.spawn_final_boss(4)
	check(level.king_rotation_timer.wait_time == 10.0 and active_king_count() == 1 and level.active_king.stats.display_name == "持国天王", "最终决战只让持国天王首先出场")
	check(level.king_reposition_timer.wait_time >= 2.4 and level.king_reposition_timer.wait_time <= 4.0, "当前天王会按随机间隔变换位置")
	var first_king_position: Vector2 = level.active_king.global_position
	level.active_king.invulnerable_until = 0
	level.active_king.take_damage(40.0, level.player.global_position)
	var first_king_health: float = level.active_king.health
	check(absf(level.active_king.sprite.position.y + (123.0 - 64.0) * level.active_king.visual_scale.y) < 1.0, "四大天王脚底与地面误差小于1像素")
	check(level.active_king.body_shape.scale == Vector2(1.5, 1.5) and level.active_king.body_shape.position.y == -57.0, "四大天王碰撞体随视觉等比放大并保持底部落地")
	level.active_king.set_physics_process(false)
	level.active_king.global_position = Vector2(11820.0, 650.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	var player_shape_query := PhysicsShapeQueryParameters2D.new()
	player_shape_query.shape = level.player.standing_shape.shape
	player_shape_query.transform = level.active_king.body_shape.global_transform
	player_shape_query.collision_mask = 4
	player_shape_query.collide_with_bodies = true
	player_shape_query.exclude = [level.player.get_rid()]
	var boss_hits: Array[Dictionary] = level.get_world_2d().direct_space_state.intersect_shape(player_shape_query)
	var boss_collision_found := false
	for hit in boss_hits:
		if hit.collider == level.active_king:
			boss_collision_found = true
			break
	check(boss_collision_found and level.active_king.collision_mask & 2 != 0, "第五关Boss实体会阻挡玩家")
	var tracked_throw := PlayerThrowProjectile.new()
	tracked_throw.kind = PlayerThrowProjectile.Kind.STAFF
	tracked_throw.direction = 1.0
	tracked_throw.target = level.active_king
	add_child(tracked_throw)
	tracked_throw.set_physics_process(false)
	level.king_rotation_timer.wait_time = 0.05
	level.king_rotation_timer.start()
	await level.king_rotation_timer.timeout
	await get_tree().process_frame
	var tracked_throw_start := tracked_throw.global_position
	tracked_throw._physics_process(0.05)
	check(tracked_throw.target == null and tracked_throw.global_position.x > tracked_throw_start.x, "投棒目标天王退场释放后安全改为直飞")
	tracked_throw.queue_free()
	check(active_king_count() == 1 and level.active_king.stats.display_name == "增长天王", "持国退场后只出现增长天王")
	check(level.active_king.global_position != first_king_position, "轮换后的天王从不同位置出场")
	await level.king_rotation_timer.timeout
	await get_tree().process_frame
	check(active_king_count() == 1 and level.active_king.stats.display_name == "广目天王", "增长退场后只出现广目天王")
	level.king_rotation_timer.wait_time = level.KING_TURN_SECONDS
	var frozen_outgoing_king: Enemy = level.active_king
	frozen_outgoing_king.freeze_for(0.08)
	level.rotate_king()
	check(active_king_count() == 1 and level.active_king.stats.display_name == "多闻天王", "广目退场后只出现多闻天王")
	check(is_instance_valid(frozen_outgoing_king) and frozen_outgoing_king.visible and not frozen_outgoing_king.is_physics_processing(), "被定身的当前天王不会隐身且新天王立即出场")
	await get_tree().create_timer(0.12).timeout
	await get_tree().process_frame
	check(not is_instance_valid(frozen_outgoing_king), "定身解除后旧天王才退场")
	level.rotate_king()
	check(active_king_count() == 1 and level.active_king.stats.display_name == "持国天王" and level.active_king.health == first_king_health, "多闻退场后循环到持国并保留血量")
	defeat_active_king(level)
	check(active_king_count() == 1 and level.active_king.stats.display_name == "增长天王", "持国被击败后立即退场并换增长天王")
	level.rotate_king()
	level.rotate_king()
	level.rotate_king()
	check(active_king_count() == 1 and level.active_king.stats.display_name == "增长天王", "后续轮换跳过已被击败的持国天王")
	defeat_active_king(level)
	defeat_active_king(level)
	defeat_active_king(level)
	check(level.completed and active_king_count() == 0, "四大天王全部被击败后才完成第五关")

	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(GameState.save_path)
	if failures.is_empty():
		print("LEVEL 05 ADJUSTMENT CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("LEVEL 05 ADJUSTMENT CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func active_king_count() -> int:
	var count := 0
	for king_node in get_tree().get_nodes_in_group(&"active_king"):
		if not king_node.is_queued_for_deletion():
			count += 1
	return count


func defeat_active_king(level) -> void:
	level.active_king.invulnerable_until = 0
	level.active_king.take_damage(level.active_king.health, level.player.global_position)
