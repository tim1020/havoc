extends Node

var failures: Array[String] = []


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_phase_04_save.json"
	GameState.has_staff = true
	await run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var scene := load("res://src/levels/level_04/level_04.tscn") as PackedScene
	check(scene != null, "第四关场景可加载")
	var level := scene.instantiate() as CampaignLevel
	add_child(level)
	for _frame in 8:
		await get_tree().physics_frame
	var enemies := get_tree().get_nodes_in_group("enemies")
	check(enemies.size() == 16, "第四关生成14名普通敌人和2个Boss")
	check(count_enemy("护园力士") == 3 and count_enemy("散花仙女") == 4 and count_enemy("桃妖") == 4 and count_enemy("蟠桃童子") == 3, "第四关普通敌人数量符合数值文档")
	check(get_tree().get_nodes_in_group("bosses").size() == 2, "第四关生成七仙女之首和蟠桃土地公")
	check(level.find_children("*", "LineHazard", true, false).size() == 5, "第四关生成树根、桃核、瑶池水和花粉陷阱")
	var backdrop := level.find_children("*", "CampaignBackdrop", true, false)[0] as CampaignBackdrop
	check(backdrop.level_number == 4, "第四关使用独立蟠桃园四分区线稿背景")
	check(level.find_children("*", "AudioDirector", true, false).is_empty(), "第四关不播放背景音")
	check(get_tree().get_nodes_in_group("standable_surfaces").size() == 14, "第四关14段可站立面均有顶边线")
	var timed_platforms := get_tree().get_nodes_in_group("timed_platforms")
	check(timed_platforms.size() == 4, "瑶池木桥、莲花和荷叶使用计时下沉平台")
	if timed_platforms.size() == 4:
		check(timed_platforms[1].collapse_delay == 2.0, "莲花平台站立2秒后下沉")
		timed_platforms[0].collapse_delay = 0.01
		timed_platforms[0].start_collapse(level.player)
		await get_tree().create_timer(0.05).timeout
		await get_tree().physics_frame
		check(timed_platforms[0].collapsed and timed_platforms[0].collision.disabled, "计时结束后平台关闭碰撞并开始下沉")
		await get_tree().create_timer(2.1).timeout
		await get_tree().physics_frame
		check(not timed_platforms[0].collapsed and not timed_platforms[0].collision.disabled, "下沉平台2秒后自动复位")
	check_enemy_animation_coverage(enemies, 6)
	check(level.player.collision_mask & 4 != 0, "第四关玩家与敌人启用双向实体碰撞")

	var fairy := find_enemy("散花仙女")
	fairy.set_physics_process(false)
	level.player.invulnerable_until = 0
	level.player.confused_until = 0
	fairy.next_attack_at = 0
	fairy.try_attack(level.player)
	check(level.player.confused_until > Time.get_ticks_msec(), "散花仙女命中使玩家方向混乱3秒")
	check(level.player.movement_direction(1.0) == -1.0, "方向混乱期间左右输入反转")
	level.player.update_status_visual()
	check(level.player.sprite.modulate != Color.WHITE, "方向混乱期间玩家显示粉色状态反馈")
	check(level.player.confusion_stars.visible, "方向混乱期间悟空头顶持续冒金星")

	var pollen: LineHazard
	for hazard_node in level.find_children("*", "LineHazard", true, false):
		var hazard := hazard_node as LineHazard
		if hazard.kind == LineHazard.Kind.POLLEN:
			pollen = hazard
			break
	level.player.confused_until = 0
	level.player.invulnerable_until = 0
	pollen.next_hit_at = 0
	pollen.on_body_entered(level.player)
	check(level.player.confused_until > Time.get_ticks_msec(), "花粉迷雾同样触发3秒方向混乱")

	var peach := find_enemy("桃妖")
	peach.set_physics_process(false)
	check(peach.disguised, "桃妖初始伪装为桃树")
	level.player.global_position = peach.global_position + Vector2(80, 0)
	peach.update_disguise(level.player)
	check(not peach.disguised, "玩家靠近后桃妖解除伪装")
	var child := find_enemy("蟠桃童子")
	check(child.behavior == Enemy.Behavior.FLYING and is_zero_approx(child.stats.gravity), "蟠桃童子骑鹤飞行")

	var leader := find_enemy("七仙女之首")
	leader.set_physics_process(false)
	leader.invulnerable_until = 0
	leader.take_damage(leader.stats.max_health * 0.5, level.player.global_position)
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("fairy_illusions").size() == 3, "七仙女之首半血生成3个花瓣分身")

	var land_god := find_enemy("蟠桃土地公")
	land_god.set_physics_process(false)
	land_god.invulnerable_until = 0
	land_god.take_damage(land_god.stats.max_health * 0.5, level.player.global_position)
	await get_tree().process_frame
	check(land_god.current_phase == 2, "蟠桃土地公半血进入第二阶段")
	check(get_tree().get_nodes_in_group("land_vines").size() == 3, "土地公第二阶段生成3处藤蔓地刺")
	check(count_enemy("桃妖") == 6, "土地公第二阶段召唤2只桃妖")
	land_god.invulnerable_until = 0
	land_god.take_damage(land_god.health, level.player.global_position)
	await get_tree().create_timer(1.0).timeout
	check(level.completed and level.shop.visible, "击败蟠桃土地公完成第四关并打开商店")
	check(GameState.FOURTH_LEVEL.ends_with("level_04.tscn"), "第四关路径已纳入全局进度")

	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(GameState.save_path)
	if failures.is_empty():
		print("PHASE 04 CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("PHASE 04 CHECKS FAILED: ", failures.size())
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


func check_enemy_animation_coverage(enemies: Array[Node], expected_visuals: int) -> void:
	var atlas_paths: Dictionary[String, bool] = {}
	var covered := true
	for enemy_node in enemies:
		var enemy := enemy_node as Enemy
		atlas_paths[enemy.animation_atlas.resource_path] = true
		for animation in [&"idle", &"walk", &"attack", &"hurt", &"death"]:
			if enemy.sprite.sprite_frames.get_frame_count(animation) < 2:
				covered = false
	check(atlas_paths.size() == expected_visuals, "第四关所有角色使用独立逐帧图集")
	check(covered, "第四关所有角色核心状态至少包含2帧")
