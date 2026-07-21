extends Node

var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.settings.reduced_motion = true
	await check_level_one()
	await check_campaign_level()
	get_tree().paused = false
	if failures.is_empty():
		print("ENEMY WAVE CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("ENEMY WAVE CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func check_level_one() -> void:
	var level := (load("res://src/levels/level_01/level_01.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	var original_count: int = level.section_wave_specs[0].size()
	check(original_count == 6, "第一关第一小节原有6名小兵")
	check(count_section_enemies(level, 0) == original_count * 2, "第一关载入时一次性生成双倍普通兵")
	check(all_ground_enemies_have_floor(level, 0), "第一关第一小节地面敌兵不会出生在沟壑中")
	check(level.current_section_enemy_count == original_count * 2 and level.get_current_section_enemy_snapshot().size() == original_count * 2, "第一关追踪器保存当前小节敌兵总数与明细")
	var tracked_enemy: Enemy = level.enemy_tracker.alive_enemies(0)[0] as Enemy
	tracked_enemy.global_position.x += 37.0
	check(enemy_snapshot_position(level.get_current_section_enemy_snapshot(), tracked_enemy.get_instance_id()).x == tracked_enemy.global_position.x, "第一关追踪器返回敌兵实时位置")
	tracked_enemy.global_position.y = Enemy.PIT_DEATH_Y + 1.0
	tracked_enemy._physics_process(0.0)
	await get_tree().process_frame
	check(tracked_enemy.dead and level.current_section_enemy_count == original_count * 2 - 1, "被击退掉入沟底的敌兵死亡并立即从小节计数移除")
	level.player.global_position = Vector2(150.0, 560.0)
	level.player.move_and_collide(Vector2(280.0, 0.0))
	check(level.player.global_position.x > 400.0, "第一关出生点附近有敌兵时悟空仍能向右通行")
	level.player.global_position.x = level.SECTION_WIDTH - level.SCREEN_WIDTH * 0.25
	var last_alive: Enemy
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if not enemy.dead and level.enemy_section(enemy) == 0:
			if last_alive == null:
				last_alive = enemy
			else:
				enemy.invulnerable_until = 0
				enemy.take_damage(enemy.health + enemy.shield_health + 1.0, level.player.global_position)
	last_alive.engaged = false
	level.refresh_section_gate(0)
	check(level.section_gates.has(0), "未进入战斗状态的存活敌人仍会阻止过节")
	check(absf(last_alive.global_position.x - level.player.global_position.x) <= level.SCREEN_WIDTH * 0.5, "身后不可见的掉队敌兵会返回末屏继续战斗")
	level.player.global_position.x = 150.0
	var cleared_gate := level.section_gates[0] as StaticBody2D
	last_alive.invulnerable_until = 0
	last_alive.take_damage(last_alive.health + last_alive.shield_health + 1.0, level.player.global_position)
	await get_tree().process_frame
	check(not level.section_gates.has(0), "双倍敌兵全部清除后立即开放下一小节")
	check(level.current_section_enemy_count == 0, "第一关敌兵死亡后当前小节计数归零")
	await get_tree().physics_frame
	check(not is_instance_valid(cleared_gate), "第一关清关门已从物理世界销毁")
	level.player.global_position = Vector2(level.SECTION_WIDTH - 80.0, 560.0)
	level.player.move_and_collide(Vector2(160.0, 0.0))
	check(level.player.global_position.x > level.SECTION_WIDTH, "第一关悟空能够实际穿过下一小节边界")

	clear_regular_enemies(level, 4)
	level.refresh_section_gate(4)
	check(level.final_boss_spawned and level.section_boss_reinforcement_waves[4] == 2 and level.count_regular_enemies(4) == 2, "第一关清完首波后才出关底Boss并补第二波")
	clear_regular_enemies(level, 4)
	level.update_section_waves(4)
	check(level.section_boss_reinforcement_waves[4] == 3 and level.count_regular_enemies(4) == 2, "第一关小兵少于2时补下一波")
	for _wave in 2:
		clear_regular_enemies(level, 4)
		level.update_section_waves(4)
	clear_regular_enemies(level, 4)
	level.update_section_waves(4)
	check(level.section_boss_reinforcement_waves[4] == 5 and level.count_regular_enemies(4) == 0, "第一关补兵最多五波")
	get_tree().paused = false
	level.queue_free()
	await get_tree().process_frame


func check_campaign_level() -> void:
	var level := (load("res://src/levels/level_02/level_02.tscn") as PackedScene).instantiate() as CampaignLevel
	add_child(level)
	await get_tree().process_frame
	var original_count: int = level.section_wave_specs[0].size()
	check(count_section_enemies(level, 0) == original_count * 2, "第二至第六关载入时一次性生成双倍普通兵")
	check(level.current_section_enemy_count == original_count * 2 and level.get_current_section_enemy_snapshot().size() == original_count * 2, "共享关卡追踪器保存当前小节敌兵总数与明细")
	var last_alive: Enemy
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if not enemy.dead and level.enemy_section(enemy) == 0:
			if last_alive == null:
				last_alive = enemy
			else:
				enemy.dead = true
	level.player.global_position.x = level.SECTION_WIDTH - level.SCREEN_WIDTH * 0.25
	level.refresh_section_gate(0)
	check(level.section_gates.has(0) and absf(last_alive.global_position.x - level.player.global_position.x) <= level.SCREEN_WIDTH * 0.5, "共享关卡掉队敌兵会返回末屏且继续阻止过节")
	last_alive.dead = true
	level.player.global_position.x = 150.0
	var cleared_gate := level.section_gates[0] as StaticBody2D
	level.refresh_section_gate(0)
	check(not level.section_gates.has(0) and level.loaded_sections.has(1), "共享关卡清空双倍敌兵后立即开放门并载入下一小节")
	await get_tree().physics_frame
	check(not is_instance_valid(cleared_gate), "共享关卡清关门已从物理世界销毁")
	level.player.global_position = Vector2(level.SECTION_WIDTH - 80.0, 560.0)
	level.player.move_and_collide(Vector2(160.0, 0.0))
	check(level.player.global_position.x > level.SECTION_WIDTH, "共享关卡悟空能够实际穿过下一小节边界")

	level.load_section_content(4)
	clear_regular_enemies(level, 4)
	level.refresh_section_gate(4)
	check(level.section_final_boss_spawned[4] and level.section_boss_reinforcement_waves[4] == 2 and level.count_regular_enemies(4) == 2, "共享关卡清完首波后才出关底Boss并补第二波")
	clear_regular_enemies(level, 4)
	level.update_section_waves(4)
	check(level.section_boss_reinforcement_waves[4] == 3 and level.count_regular_enemies(4) == 2, "共享关卡小兵少于2时补下一波")
	get_tree().paused = false
	level.queue_free()
	await get_tree().process_frame


func count_section_enemies(level: Node, section: int) -> int:
	var count := 0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if not enemy.dead and level.enemy_section(enemy) == section:
			count += 1
	return count


func clear_regular_enemies(level: Node, section: int) -> void:
	for enemy in level.enemy_tracker.alive_enemies(section):
		if not (enemy.has_meta(&"final_boss") and bool(enemy.get_meta(&"final_boss"))):
			enemy.dead = true


func enemy_snapshot_position(snapshot: Array[Dictionary], enemy_id: int) -> Vector2:
	for entry in snapshot:
		if int(entry.id) == enemy_id:
			return entry.position as Vector2
	return Vector2.INF


func all_ground_enemies_have_floor(level: Node, section: int) -> bool:
	for enemy in level.enemy_tracker.alive_enemies(section):
		if enemy.behavior == Enemy.Behavior.FLYING:
			continue
		var has_floor := false
		for rect in level.campaign_ground_rects():
			if rect.position.x <= enemy.global_position.x and enemy.global_position.x <= rect.end.x:
				has_floor = true
				break
		if not has_floor:
			return false
	return true
