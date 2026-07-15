extends Node

var failures: Array[String] = []


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_phase_05_save.json"
	GameState.has_staff = true
	await run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var scene := load("res://src/levels/level_05/level_05.tscn") as PackedScene
	check(scene != null, "第五关场景可加载")
	var level = scene.instantiate()
	add_child(level)
	for _frame in 8:
		await get_tree().physics_frame
	var enemies := get_tree().get_nodes_in_group("enemies")
	check(enemies.size() == 16, "第五关生成15名普通敌人和增长天王幻影")
	check(count_enemy("金甲天兵") == 5 and count_enemy("天弓手") == 4 and count_enemy("云中仙") == 3 and count_enemy("天门力士") == 3, "第五关普通敌人数量符合数值文档")
	check(get_tree().get_nodes_in_group("bosses").size() == 1, "第五关初始仅生成增长天王幻影")
	check(level.find_children("*", "LineHazard", true, false).size() == 6, "第五关生成天雷、罡风和石像激光")
	check(get_tree().get_nodes_in_group("timed_platforms").size() == 3, "第五关碎云砖站立2秒后下沉")
	check(get_tree().get_nodes_in_group("standable_surfaces").size() == 17, "第五关17段可站立面均有顶边线")
	var backdrop := level.find_children("*", "CampaignBackdrop", true, false)[0] as CampaignBackdrop
	check(backdrop.level_number == 5, "第五关使用独立南天门四分区线稿背景")
	check_animation_coverage(enemies, 5, "第五关道中")
	check(level.player.collision_mask & 4 != 0, "第五关玩家与敌人启用双向实体碰撞")
	var wind_found := false
	for hazard_node in level.find_children("*", "LineHazard", true, false):
		var hazard := hazard_node as LineHazard
		if hazard.kind == LineHazard.Kind.WIND and hazard.push_force >= 380.0:
			wind_found = true
	check(wind_found, "罡风区域持续施加水平推力")

	var phantom := find_enemy("增长天王幻影")
	phantom.set_physics_process(false)
	phantom.invulnerable_until = 0
	phantom.take_damage(250.0, level.player.global_position)
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("heaven_illusions").size() == 2, "增长天王幻影半血生成2个分身")

	check(level.gate.health == 500.0 and not level.gate.broken, "南天门具有独立500点血量和实体碰撞")
	check(not level.reinforcement_timer.is_stopped() and level.reinforcement_timer.wait_time == 6.0, "南天门击破前每6秒持续增援")
	level.spawn_gate_reinforcement()
	check(get_tree().get_nodes_in_group("gate_reinforcements").size() == 1, "南天门增援实际生成金甲天兵或天弓手")
	level.gate.take_damage(500.0, level.player.global_position)
	await get_tree().process_frame
	check(level.gate.broken and level.reinforcement_timer.is_stopped() and level.current_king_index == 0, "击破南天门停止增援并立即开始四天王连战")

	var king := find_enemy("持国天王")
	check(king != null and king.sprite.sprite_frames.get_frame_count(&"attack") >= 2, "持国天王使用独立逐帧动画")
	level.player.rooted_until = 0
	level.player.invulnerable_until = 0
	king.next_attack_at = 0
	king.try_attack(level.player)
	check(level.player.rooted_until > Time.get_ticks_msec(), "持国天王音符命中定身2秒")
	kill_enemy(king, level.player)
	await get_tree().process_frame
	check(level.current_king_index == 1 and count_rewards() == 1, "持国天王死亡后立即登场增长天王并掉落蟠桃")

	king = find_enemy("增长天王")
	king.set_physics_process(false)
	king.invulnerable_until = 0
	king.take_damage(300.0, level.player.global_position)
	check(king.current_phase == 2 and king.phase_two, "增长天王半血进入剑气风暴阶段")
	kill_enemy(king, level.player)
	await get_tree().process_frame
	check(level.current_king_index == 2 and count_rewards() == 2, "增长天王死亡后立即登场广目天王")

	king = find_enemy("广目天王")
	level.player.slowed_until = 0
	level.player.invulnerable_until = 0
	king.next_attack_at = 0
	king.try_attack(level.player)
	check(level.player.slowed_until > Time.get_ticks_msec(), "广目天王毒蛇命中使玩家减速")
	kill_enemy(king, level.player)
	await get_tree().process_frame
	check(level.current_king_index == 3 and count_rewards() == 3, "广目天王死亡后立即登场多闻天王")

	king = find_enemy("多闻天王")
	king.set_physics_process(false)
	var health_before := king.health
	var accepted := king.take_projectile_damage(15.0, level.player.global_position)
	check(not accepted and king.health == health_before, "多闻天王混元伞反射追踪棒")
	kill_enemy(king, level.player)
	await get_tree().process_frame
	check(count_rewards() == 4, "四天王每场胜利均掉落1个蟠桃")
	check(level.completed and level.shop.visible, "四天王连战结束后完成第五关并打开商店")
	check(GameState.FIFTH_LEVEL.ends_with("level_05.tscn"), "第五关路径已纳入全局进度")

	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(GameState.save_path)
	if failures.is_empty():
		print("PHASE 05 CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("PHASE 05 CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func find_enemy(display_name: String) -> Enemy:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.stats.display_name == display_name and not enemy.dead:
			return enemy
	return null


func count_enemy(display_name: String) -> int:
	var count := 0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if (enemy_node as Enemy).stats.display_name == display_name:
			count += 1
	return count


func kill_enemy(enemy: Enemy, player: Player) -> void:
	enemy.set_physics_process(false)
	enemy.invulnerable_until = 0
	enemy.take_damage(enemy.health, player.global_position)


func count_rewards() -> int:
	return get_tree().get_nodes_in_group("king_rewards").size()


func check_animation_coverage(enemies: Array[Node], expected_visuals: int, label: String) -> void:
	var paths: Dictionary[String, bool] = {}
	var covered := true
	for enemy_node in enemies:
		var enemy := enemy_node as Enemy
		paths[enemy.animation_atlas.resource_path] = true
		for animation in [&"idle", &"walk", &"attack", &"hurt", &"death"]:
			if enemy.sprite.sprite_frames.get_frame_count(animation) < 2:
				covered = false
	check(paths.size() == expected_visuals, "%s角色使用独立逐帧图集" % label)
	check(covered, "%s角色核心状态至少包含2帧" % label)
