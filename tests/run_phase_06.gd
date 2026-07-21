extends Node

var failures: Array[String] = []


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_phase_06_save.json"
	GameState.has_staff = true
	GameState.game_completed = false
	await run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var scene := load("res://src/levels/level_06/level_06.tscn") as PackedScene
	check(scene != null, "第六关场景可加载")
	var level = scene.instantiate()
	add_child(level)
	for _frame in 8:
		await get_tree().physics_frame
	var enemies := get_tree().get_nodes_in_group("enemies")
	check(enemies.size() == 14, "第六关生成13名普通敌人和哪吒")
	check(count_enemy("黄巾力士") == 4 and count_enemy("卷帘大将") == 3 and count_enemy("御前侍卫") == 3 and count_enemy("哮天犬") == 3, "第六关普通敌人数量符合数值文档")
	check(get_tree().get_nodes_in_group("bosses").size() == 1, "第六关初始仅生成哪吒")
	check(level.find_children("*", "LineHazard", true, false).size() == 7, "第六关生成3处金光阵和4处九龙壁喷火")
	check(get_tree().get_nodes_in_group("dragon_pillars").size() == 4, "第六关生成4根可破坏蟠龙柱")
	check(get_tree().get_nodes_in_group("pursuit_seal").size() == 1, "第六关生成周期追背封印")
	check(get_tree().get_nodes_in_group("standable_surfaces").size() == 14, "第六关14段可站立面均有顶边线")
	var backdrop := level.find_children("*", "CampaignBackdrop", true, false)[0] as CampaignBackdrop
	check(backdrop.level_number == 6, "第六关使用独立凌霄宝殿四分区线稿背景")
	check_animation_coverage(enemies, 5, "第六关初始角色")
	check(level.player.collision_mask & 4 != 0, "第六关玩家与敌人启用双向实体碰撞")

	var pillar = get_tree().get_nodes_in_group("dragon_pillars")[0]
	var yellow := find_enemy("黄巾力士")
	yellow.set_physics_process(false)
	yellow.global_position = pillar.global_position + Vector2(80, 0)
	var yellow_health := yellow.health
	pillar.take_damage(60.0, level.player.global_position)
	check(pillar.broken and yellow.health == yellow_health - 40.0, "蟠龙柱击破后倒塌并伤害附近敌人")
	var seal = get_tree().get_first_node_in_group("pursuit_seal")
	seal.begin_sweep()
	check(seal.active and seal.visible, "追背封印每轮从后方开始推进")

	var royal := find_enemy("御前侍卫")
	royal.set_physics_process(false)
	royal.patrol_direction = 1.0
	level.player.global_position = royal.global_position + Vector2(80, 0)
	level.player.health = 100.0
	level.player.invulnerable_until = 0
	royal.next_attack_at = 0
	royal.try_attack(level.player)
	check(level.player.health == 40.0, "御前侍卫背刺造成双倍60点伤害")

	var nezha := find_enemy("哪吒")
	nezha.set_physics_process(false)
	nezha.invulnerable_until = 0
	nezha.take_damage(350.0, level.player.global_position)
	check(nezha.current_phase == 2 and nezha.phase_two, "哪吒半血进入三头六臂阶段")
	kill_enemy(nezha, level.player)
	await get_tree().process_frame
	var erlang := find_enemy("二郎神")
	check(erlang != null and erlang.sprite.sprite_frames.get_frame_count(&"attack") >= 2, "哪吒败后立即生成逐帧动画二郎神")
	erlang.set_physics_process(false)
	erlang.invulnerable_until = 0
	erlang.take_damage(750.0, level.player.global_position)
	await get_tree().process_frame
	check(erlang.current_phase == 2 and get_tree().get_nodes_in_group("erlang_hounds").size() == 2, "二郎神半血召唤2只哮天犬")
	kill_enemy(erlang, level.player)
	await get_tree().process_frame
	var emperor := find_enemy("玉皇大帝")
	check(emperor != null and emperor.shield_health == 600.0 and emperor.health == 1200.0, "二郎神败后玉帝以1200生命和600护盾登场")

	damage_enemy(emperor, 600.0, level.player)
	check(emperor.shield_health == 0.0 and emperor.health == 1200.0 and level.emperor_shield_breaks == 1, "玉帝第一轮600护盾先于本体承伤并触发封神冲击")
	damage_enemy(emperor, 600.0, level.player)
	check(emperor.health == 600.0 and emperor.shield_health == 600.0 and level.emperor_shield_reset, "玉帝半血进入第三阶段并重置600护盾")
	check(not level.emperor_reinforcement_timer.is_stopped(), "玉帝第三阶段启动天兵持续增援")
	damage_enemy(emperor, 600.0, level.player)
	check(emperor.shield_health == 0.0 and level.emperor_shield_breaks == 2, "玉帝第二轮护盾可再次击破")
	damage_enemy(emperor, 600.0, level.player)
	await get_tree().create_timer(1.0).timeout
	check(level.completed and GameState.game_completed, "击败玉皇大帝完成主线并写入通关状态")
	check(level.hud.get_node("ResultPanel").visible and not level.shop.visible, "最终胜利显示主线通关结算且不打开普通商店")
	check(level.emperor_reinforcement_timer.is_stopped(), "最终胜利停止玉帝增援")
	GameState.game_completed = false
	check(GameState.load_game() and GameState.game_completed, "主线通关状态可从存档恢复")
	check(GameState.SIXTH_LEVEL.ends_with("level_06.tscn"), "第六关路径已纳入全局进度")

	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(GameState.save_path)
	if failures.is_empty():
		print("PHASE 06 CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("PHASE 06 CHECKS FAILED: ", failures.size())
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
	enemy.invulnerable_until = 0
	enemy.take_damage(enemy.health, player.global_position)


func damage_enemy(enemy: Enemy, damage: float, player: Player) -> void:
	enemy.set_physics_process(false)
	enemy.invulnerable_until = 0
	enemy.take_damage(damage, player.global_position)


func check_animation_coverage(enemies: Array[Node], expected_visuals: int, label: String) -> void:
	var paths: Dictionary[String, bool] = {}
	var covered := true
	for enemy_node in enemies:
		var enemy := enemy_node as Enemy
		paths[enemy.animation_atlas.resource_path] = true
		for animation in [&"idle", &"walk", &"attack", &"hurt", &"death"]:
			if enemy.sprite.sprite_frames.get_frame_count(animation) < 2:
				covered = false
	check(paths.size() == expected_visuals, "%s使用独立逐帧图集" % label)
	check(covered, "%s核心状态至少包含2帧" % label)
