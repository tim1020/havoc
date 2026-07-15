extends Node

const TEST_SAVE := "/tmp/havoc_phase_03_save.json"

var failures: Array[String] = []


func _ready() -> void:
	GameState.save_path = TEST_SAVE
	GameState.stones = 0
	GameState.artifacts.clear()
	GameState.has_staff = false
	await run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var level2_scene := load("res://src/levels/level_02/level_02.tscn") as PackedScene
	var level3_scene := load("res://src/levels/level_03/level_03.tscn") as PackedScene
	check(level2_scene != null and level3_scene != null, "第二、三关场景可加载")
	var level2 := level2_scene.instantiate() as CampaignLevel
	add_child(level2)
	for _frame in 6:
		await get_tree().physics_frame
	var level2_enemies := get_tree().get_nodes_in_group("enemies")
	check(level2_enemies.size() == 19, "第二关生成17名普通敌人和2个Boss")
	check(get_tree().get_nodes_in_group("bosses").size() == 2, "第二关生成龟丞相和东海龙王")
	check(level2.find_children("*", "LineHazard", true, false).size() == 4, "第二关生成海胆和电流阵")
	check(level2.find_children("*", "CampaignBackdrop", true, false).size() == 1, "第二关使用连续四分区龙宫线稿背景")
	check(get_tree().get_nodes_in_group("standable_surfaces").size() == 11, "第二关11段可站立面均有顶边线")
	check(level2.player.collision_mask & 4 != 0, "第二关玩家与敌人启用双向实体碰撞")
	check_enemy_animation_coverage(level2_enemies, 6, "第二关")

	var crab := find_enemy("蟹将")
	crab.set_physics_process(false)
	crab.patrol_direction = 1.0
	crab.invulnerable_until = 0
	var crab_health := crab.health
	crab.take_damage(10.0, crab.global_position + Vector2.RIGHT * 100.0)
	check(crab.health == crab_health - 5.0, "蟹将正面受到攻击时减伤50%")
	var jelly := find_enemy("电水母")
	level2.player.invulnerable_until = 0
	level2.player.slowed_until = 0
	jelly.next_attack_at = 0
	jelly.try_attack(level2.player)
	check(level2.player.slowed_until > Time.get_ticks_msec(), "电水母命中使玩家减速2秒")
	var maiden := find_enemy("龙宫侍女")
	level2.player.invulnerable_until = 0
	level2.player.rooted_until = 0
	maiden.next_attack_at = 0
	maiden.try_attack(level2.player)
	check(level2.player.rooted_until > Time.get_ticks_msec(), "龙宫侍女泡泡使玩家无法移动2秒")

	var dragon := find_enemy("东海龙王")
	dragon.set_physics_process(false)
	dragon.invulnerable_until = 0
	dragon.take_damage(400.0, level2.player.global_position)
	check(dragon.current_phase == 2, "东海龙王60%生命进入第二阶段")
	dragon.invulnerable_until = 0
	dragon.take_damage(300.0, level2.player.global_position)
	check(dragon.current_phase == 3, "东海龙王30%生命进入化龙阶段")
	dragon.invulnerable_until = 0
	dragon.take_damage(300.0, level2.player.global_position)
	await get_tree().process_frame
	check(level2.completed and level2.shop.visible, "击败东海龙王完成第二关并打开商店")
	check(GameState.has_staff, "击败东海龙王永久解锁金箍棒")
	level2.shop.close_shop()
	level2.queue_free()
	for _frame in 3:
		await get_tree().process_frame

	var level3 := level3_scene.instantiate() as CampaignLevel
	add_child(level3)
	for _frame in 6:
		await get_tree().physics_frame
	var level3_enemies := get_tree().get_nodes_in_group("enemies")
	check(level3_enemies.size() == 21, "第三关生成18名普通敌人和3个Boss")
	check(get_tree().get_nodes_in_group("bosses").size() == 3, "第三关生成牛头、马面和阎罗王")
	check(level3.find_children("*", "LineHazard", true, false).size() == 4, "第三关生成鬼火和轮回漩涡")
	check(level3.find_children("*", "CampaignBackdrop", true, false)[0].level_number == 3, "第三关使用独立地府四分区线稿背景")
	check(get_tree().get_nodes_in_group("standable_surfaces").size() == 13, "第三关13段可站立面均有顶边线")
	check_enemy_animation_coverage(level3_enemies, 7, "第三关")
	var player := level3.player as Player
	check(player.stats.combo_damage == PackedFloat32Array([15.0, 15.0, 15.0]), "第三关切换15点三连棒法")
	check(player.sprite.sprite_frames.get_frame_count(&"staff_fly") == 2, "御棒飞行使用真实2帧角色动画")

	var skeleton := find_enemy("骷髅兵")
	skeleton.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = Vector2(500, 580)
	skeleton.global_position = Vector2(570, 580)
	skeleton.patrol_direction = 1.0
	skeleton.invulnerable_until = 0
	var skeleton_health := skeleton.health
	player.facing = 1.0
	player.start_staff_flight()
	for _frame in 2:
		await get_tree().physics_frame
	player.apply_staff_flight_damage()
	check(player.is_staff_flying() and player.staff_flying_until > Time.get_ticks_msec(), "地面满蓄力进入2秒御棒飞行")
	check(skeleton.health == skeleton_health - 20.0, "御棒撞击造成20点伤害")
	skeleton.invulnerable_until = 0
	player.global_position = skeleton.global_position + Vector2(0, -80)
	player.staff_slam()
	check(skeleton.health == 0.0, "御棒飞行中攻击触发40点下劈")
	player.set_physics_process(true)

	var targets: Array[Enemy] = []
	var remote_index := 0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if not enemy.dead:
			enemy.set_physics_process(false)
			enemy.global_position = Vector2(2800 + remote_index * 90, 520)
			enemy.invulnerable_until = 0
			enemy.ghost_solid = true
			enemy.patrol_direction = 1.0
			remote_index += 1
			if targets.size() < 3 and enemy.stats.ghost_cycle_seconds == 0.0 and enemy.health > 15.0:
				targets.append(enemy)
	for index in targets.size():
		targets[index].global_position = Vector2(900 + index * 170, 520)
	var target_health := 0.0
	for target in targets:
		target_health += target.health
	player.global_position = Vector2(620, 500)
	player.launch_tracking_staffs()
	await get_tree().process_frame
	var projectiles := get_tree().get_nodes_in_group("staff_projectiles")
	check(projectiles.size() == 3, "空中满蓄力生成3根追踪棒")
	if not projectiles.is_empty():
		check((projectiles[0] as StaffProjectile).get_node("Sprite").sprite_frames.get_frame_count(&"fly") == 4, "追踪棒攻击特效包含4个图像帧")
	for _frame in 50:
		await get_tree().physics_frame
	var health_after_tracking := 0.0
	for target in targets:
		health_after_tracking += target.health
	check(target_health - health_after_tracking == 45.0, "三根追踪棒分别造成15点伤害")

	var ghost := find_enemy("游魂")
	ghost.ghost_solid = false
	var ghost_health := ghost.health
	ghost.take_damage(15.0, player.global_position)
	check(ghost.health == ghost_health, "游魂虚化时不可受击")
	var ox := find_enemy("牛头")
	var horse := find_enemy("马面")
	ox.set_physics_process(false)
	horse.set_physics_process(false)
	ox.invulnerable_until = 0
	ox.take_damage(ox.health, player.global_position)
	await get_tree().process_frame
	check(horse.phase_two and horse.current_phase == 2, "牛头死亡后马面进入狂暴")
	var yanluo := find_enemy("阎罗王")
	yanluo.set_physics_process(false)
	yanluo.invulnerable_until = 0
	yanluo.take_damage(400.0, player.global_position)
	check(yanluo.current_phase == 2, "阎罗王半血进入鬼王阶段")
	yanluo.invulnerable_until = 0
	yanluo.take_damage(400.0, player.global_position)
	await get_tree().process_frame
	check(level3.completed and level3.shop.visible, "击败阎罗王完成第三关并打开商店")
	level3.shop.close_shop()
	level3.queue_free()
	for _frame in 3:
		await get_tree().process_frame

	GameState.has_staff = false
	check(GameState.load_game() and GameState.has_staff, "金箍棒解锁状态可从存档恢复")
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	if failures.is_empty():
		print("PHASE 03 CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("PHASE 03 CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func find_enemy(display_name: String) -> Enemy:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.stats.display_name == display_name:
			return enemy
	return null


func check_enemy_animation_coverage(enemies: Array[Node], expected_visuals: int, label: String) -> void:
	var atlas_paths: Dictionary[String, bool] = {}
	var covered := true
	for enemy_node in enemies:
		var enemy := enemy_node as Enemy
		atlas_paths[enemy.animation_atlas.resource_path] = true
		for animation in [&"idle", &"walk", &"attack", &"hurt", &"death"]:
			if enemy.sprite.sprite_frames.get_frame_count(animation) < 2:
				covered = false
	check(atlas_paths.size() == expected_visuals, "%s所有角色使用独立逐帧图集" % label)
	check(covered, "%s所有角色核心状态至少包含2帧" % label)
