extends Node

const LEVEL_06 := preload("res://src/levels/level_06/level_06.tscn")

var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_path = "/tmp/havoc_level06_final_battle_save.json"
	GameState.settings.reduced_motion = true
	await run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var level = LEVEL_06.instantiate()
	add_child(level)
	while get_tree().paused:
		await get_tree().create_timer(0.05, true).timeout
	await get_tree().process_frame

	var yellow_scale := Vector2.ZERO
	var thunder_scale := Vector2.ZERO
	var lightning_mother_scale := Vector2.ZERO
	for enemy_spec in level.enemy_specs():
		if enemy_spec.stats == level.YELLOW:
			yellow_scale = enemy_spec.scale
		elif enemy_spec.stats == level.THUNDER:
			thunder_scale = enemy_spec.scale
		elif enemy_spec.stats == level.LIGHTNING_MOTHER:
			lightning_mother_scale = enemy_spec.scale
	check(yellow_scale == Vector2(1.5, 1.5) and level.YELLOW.animation_frame_size == Vector2(256.0, 256.0), "黄巾力士使用清晰的256像素新图集")
	check(thunder_scale == Vector2(1.5, 1.5) and level.THUNDER.animation_frame_size == Vector2(256.0, 256.0), "雷公使用无串帧的256像素新图集")
	check(lightning_mother_scale == Vector2(1.1, 1.1) and level.LIGHTNING_MOTHER.animation_frame_size == Vector2(256.0, 256.0), "电母使用清晰的256像素新图集")
	check(level.ROYAL.sprite_position_y == -66.15, "御前侍卫放大后保持脚底落地")
	var li_jing := level.spawn_enemy(Vector2(900.0, 580.0), level.LI_JING, level.LI_JING_FRAMES, &"atlas_test") as Enemy
	li_jing.apply_visual_scale(Vector2(0.75, 0.75))
	li_jing.set_physics_process(false)
	var li_jing_hurt_frame := li_jing.sprite.sprite_frames.get_frame_texture(&"hurt", 0) as AtlasTexture
	check(level.LI_JING.animation_frame_size == Vector2(256.0, 256.0) and li_jing_hurt_frame.region == Rect2(1536.0, 0.0, 256.0, 256.0), "李靖受击动画使用无串帧的256像素新图集")
	check(absf(li_jing.sprite.position.y + (225.0 - 128.0) * li_jing.visual_scale.y) < 1.0, "李靖新图集脚底与地面误差小于1像素")
	li_jing.queue_free()
	await get_tree().process_frame

	level.current_section = 4
	level.load_section_content(4)
	for corridor_enemy in level.enemy_tracker.alive_enemies(4):
		if not (corridor_enemy.has_meta(&"final_boss") and bool(corridor_enemy.get_meta(&"final_boss"))):
			level.enemy_tracker.remove(corridor_enemy, 4)
			corridor_enemy.queue_free()
	await get_tree().process_frame
	level.refresh_section_gate(4)
	await get_tree().process_frame
	check(is_instance_valid(level.emperor) and not level.final_guardians_spawned, "抵达凌霄殿时只出现玉帝")
	check(final_character_count(level) == 1, "悟空动手前五名中Boss不会提前出现")
	level.emperor.invulnerable_until = 0
	var emperor_health_before_trigger: float = level.emperor.health
	level.emperor.take_damage(20.0, level.player.global_position)
	check(level.emperor.health == emperor_health_before_trigger - 20.0, "悟空实际命中玉帝一次后触发最终战")
	check(level.final_guardians_spawned and final_character_count(level) == 6, "玉帝被命中后五名中Boss立即现身")
	check(get_tree().get_nodes_in_group(&"emperor_soldiers").size() == 4, "玉帝被命中后四名御前侍卫立即现身")
	check(attacker_is(level, level.THUNDER) and attacker_is(level, level.LIGHTNING_MOTHER), "第一阶段只有雷公电母主动攻击")
	check(protector_is(level, level.NEZHA) and protector_is(level, level.LI_JING) and protector_is(level, level.ERLANG), "第一阶段哪吒李靖二郎神只保护玉帝")
	check(level.get_final_guardian(level.NEZHA).engaged and level.get_final_guardian(level.LI_JING).engaged and level.get_final_guardian(level.ERLANG).engaged, "三名保护型中Boss生成后立即进入护卫状态")
	var nezha: Enemy = level.get_final_guardian(level.NEZHA)
	level.player.global_position = nezha.global_position + Vector2(nezha.stats.attack_range - 10.0, 0.0)
	var player_health_before_guard_contact: float = level.player.health
	level.player.invulnerable_until = 0
	level.player.controls_enabled = true
	nezha.next_attack_at = 0
	nezha.update_bodyguard_position(level.player)
	check(level.player.health < player_health_before_guard_contact, "保护型中Boss在悟空靠近时会主动反击")
	check(nezha.bodyguard_distance > level.get_final_guardian(level.LI_JING).bodyguard_distance and level.get_final_guardian(level.LI_JING).bodyguard_distance > level.get_final_guardian(level.ERLANG).bodyguard_distance, "三名护卫分层挡在玉帝前方而不重叠")
	level.emperor.invulnerable_until = 0
	var protected_health_before: float = level.emperor.health
	level.emperor.take_damage(100.0, level.player.global_position)
	check(level.emperor.health == protected_health_before - 20.0, "召集护卫后玉帝只承受两成伤害")
	level.emperor.global_position.x = 12400.0
	level.player.global_position.x = level.emperor.global_position.x - 1200.0
	for stats_value in [level.NEZHA, level.LI_JING, level.ERLANG]:
		var following_guardian: Enemy = level.get_final_guardian(stats_value)
		following_guardian.global_position.x = level.emperor.global_position.x - following_guardian.bodyguard_distance - 260.0
		level.emperor.global_position.x += 80.0
		following_guardian.update_bodyguard_position(level.player)
		check(following_guardian.velocity.x > 0.0, "%s会跟随移动后的玉帝调整保护位置" % following_guardian.stats.display_name)
	var emperor_x_before_reposition: float = level.emperor.global_position.x
	level.emperor.can_reposition = true
	level.emperor.next_boss_reposition_at = 0
	level.emperor.update_grounded(level.player)
	check(not is_equal_approx(level.emperor.global_position.x, emperor_x_before_reposition), "玉帝会定期跳到其它位置躲避悟空")
	level.emperor.can_reposition = false
	level.player.global_position.x = level.emperor.global_position.x - 500.0
	level.emperor.update_grounded(level.player)
	check(level.emperor.behavior == Enemy.Behavior.EVADE and level.emperor.velocity.x > 0.0, "玉帝持续远离左侧的悟空")
	level.emperor.global_position.y = 650.0
	level.emperor.set_physics_process(false)
	for stats_value in level.final_guardians:
		var guardian: Enemy = level.get_final_guardian(stats_value)
		guardian.global_position.y = 650.0
		guardian.set_physics_process(false)
	for soldier_reference in level.final_soldiers:
		var soldier := soldier_reference.get_ref() as Enemy
		soldier.global_position.y = 650.0
		soldier.set_physics_process(false)
	var camera := level.player.get_node("Camera") as Camera2D
	camera.limit_left = 10240
	camera.limit_right = 12800
	camera.position_smoothing_enabled = false
	level.player.global_position = Vector2(11950.0, 570.0)
	camera.reset_smoothing()
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		check(get_viewport().get_texture().get_image().save_png("/tmp/havoc_level06_guard_phase.png") == OK, "第六关护卫阶段实际画面可渲染")

	var released_thunder: Enemy = level.get_final_guardian(level.THUNDER)
	level.enemy_tracker.remove(released_thunder, 4)
	released_thunder.queue_free()
	await get_tree().process_frame
	check(level.get_final_guardian(level.THUNDER) == null, "已释放的中Boss弱引用会安全失效")
	mark_defeated(level, level.LIGHTNING_MOTHER)
	level.update_emperor_guard_phase(0)
	check(true, "中Boss已释放后继续切换阶段不会赋值已释放实例")
	check(attacker_is(level, level.NEZHA) and attacker_is(level, level.LI_JING), "雷公电母阵亡后哪吒和李靖转为攻击")
	check(protector_is(level, level.ERLANG), "哪吒李靖攻击时二郎神继续保护玉帝")

	mark_defeated(level, level.NEZHA)
	mark_defeated(level, level.LI_JING)
	level.update_emperor_guard_phase(0)
	check(attacker_is(level, level.ERLANG), "哪吒李靖阵亡后二郎神转为攻击")
	check(get_tree().get_nodes_in_group(&"emperor_protectors").is_empty(), "二郎神攻击后玉帝无人保护")
	check(get_tree().get_nodes_in_group(&"emperor_soldiers").is_empty(), "最终阶段御前侍卫撤离")
	level.emperor.invulnerable_until = 0
	var unprotected_health_before: float = level.emperor.health
	level.emperor.take_damage(100.0, level.player.global_position)
	check(level.emperor.health == unprotected_health_before - 100.0, "无人保护时玉帝承受完整伤害")

	level.queue_free()
	await get_tree().process_frame
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(GameState.save_path)
	if failures.is_empty():
		print("LEVEL 06 FINAL BATTLE CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("LEVEL 06 FINAL BATTLE CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func final_character_count(level) -> int:
	var count := 0
	for enemy_node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := enemy_node as Enemy
		if enemy != null and enemy.has_meta(&"final_boss") and bool(enemy.get_meta(&"final_boss")):
			count += 1
	return count


func attacker_is(level, stats: EnemyStats) -> bool:
	var guardian: Enemy = level.get_final_guardian(stats)
	return guardian != null and guardian.is_in_group(&"emperor_attackers") and guardian.protects_group.is_empty() and guardian.bodyguard_attacks


func protector_is(level, stats: EnemyStats) -> bool:
	var guardian: Enemy = level.get_final_guardian(stats)
	return guardian != null and guardian.is_in_group(&"emperor_protectors") and guardian.protects_group == &"jade_emperor" and guardian.bodyguard_attacks


func mark_defeated(level, stats: EnemyStats) -> void:
	var guardian: Enemy = level.get_final_guardian(stats)
	guardian.dead = true
	guardian.remove_from_group(&"emperor_protectors")
	guardian.remove_from_group(&"emperor_attackers")
