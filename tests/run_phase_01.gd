extends Node

var failures: Array[String] = []


func _ready() -> void:
	run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var player_stats := load("res://resources/stats/player_empty_hand.tres") as PlayerStats
	var thorn_stats := load("res://resources/stats/hazards/thorn_spikes.tres") as HazardStats
	check(player_stats != null and player_stats.max_health == 100.0, "玩家数值资源可加载")
	check(player_stats.combo_damage == PackedFloat32Array([10.0, 10.0, 10.0]), "空手三连击数值正确")
	check(thorn_stats != null and thorn_stats.damage == 15.0, "陷阱数值资源可加载")

	var menu_scene := load("res://src/ui/main_menu/main_menu.tscn") as PackedScene
	var level_scene := load("res://src/levels/level_01/level_01.tscn") as PackedScene
	check(menu_scene != null, "主菜单场景可加载")
	check(level_scene != null, "第一关场景可加载")

	var level := level_scene.instantiate()
	add_child(level)
	await get_tree().process_frame
	for _frame in 5:
		await get_tree().physics_frame

	var player := level.player as Player
	check(player != null and player.health == player_stats.max_health, "玩家已生成且生命正确")
	check(get_tree().get_nodes_in_group("enemies").size() == 8, "第一关生成8名敌人")
	check(get_tree().get_nodes_in_group("bosses").size() == 2, "第一关生成中Boss与关底Boss")
	check(level.find_children("*", "Hazard", true, false).size() == 3, "第一关生成3组资源化陷阱")
	check(get_tree().get_nodes_in_group("standable_surfaces").size() == 8, "第一关8段可站立顶边均有提示线")

	player.jumps_left = 2
	player.try_jump()
	check(player.velocity.y < 0.0 and player.jumps_left == 1, "玩家跳跃消耗一次跳跃次数")
	player.try_jump()
	check(player.jumps_left == 0, "玩家支持二段跳")

	var health_before_spell := player.health
	player.cast_freeze_spell()
	check(player.health == health_before_spell - player_stats.freeze_health_cost, "定身术消耗20点生命")
	var first_enemy := get_tree().get_nodes_in_group("enemies")[0] as Enemy
	check(first_enemy.frozen_until > Time.get_ticks_msec(), "定身术冻结普通敌人")
	var hud := level.hud as GameHud
	player.global_position = Vector2(360, 580)
	player.velocity = Vector2.ZERO
	first_enemy.global_position = Vector2(430, 580)
	first_enemy.velocity = Vector2.ZERO
	first_enemy.invulnerable_until = 0
	for _frame in 2:
		await get_tree().physics_frame
	var enemy_health_before_attack := first_enemy.health
	var attack_press := InputEventAction.new()
	attack_press.action = "attack"
	attack_press.pressed = true
	player._unhandled_input(attack_press)
	await get_tree().physics_frame
	check(first_enemy.health == enemy_health_before_attack, "按下攻击键不会立即攻击")
	var attack_release := InputEventAction.new()
	attack_release.action = "attack"
	attack_release.pressed = false
	player._unhandled_input(attack_release)
	for _frame in 2:
		await get_tree().physics_frame
	check(first_enemy.health == enemy_health_before_attack - player.stats.combo_damage[0], "短按松开触发普通攻击")
	check(first_enemy.hit_reaction_until > Time.get_ticks_msec(), "敌兵受击进入可见反馈状态")
	check(hud.enemy_panel.visible, "敌兵受击显示右上状态面板")
	check(hud.enemy_name_label.text == first_enemy.stats.display_name, "右上状态面板显示敌兵名称")
	check(hud.enemy_health_bar.value == first_enemy.health, "右上敌兵血条实时更新")
	var boar: Enemy
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.stats.display_name == "山猪妖":
			boar = enemy
			break
	check(boar != null, "山猪妖已生成用于蓄力攻击检查")
	if boar != null:
		player.global_position = Vector2(2600, 580)
		boar.global_position = Vector2(2670, 580)
		boar.velocity = Vector2.ZERO
		boar.invulnerable_until = 0
		for _frame in 2:
			await get_tree().physics_frame
		var boar_health_before_charge := boar.health
		player.begin_attack_charge()
		player.attack_pressed_at = Time.get_ticks_msec() - int(player.stats.charge_seconds * 1000.0) - 10
		player.update_charge_feedback()
		check(player.sprite.scale.x > player.base_sprite_scale.x, "长按攻击显示蓄力视觉反馈")
		await get_tree().physics_frame
		check(boar.health == boar_health_before_charge, "长按期间不会连续攻击")
		player.release_attack_charge()
		for _frame in 2:
			await get_tree().physics_frame
		check(boar.health == boar_health_before_charge - player.stats.charged_attack_damage, "蓄力松开触发30点攻击")
	check(player.attack_area.monitoring, "攻击检测区保持常驻监测")
	first_enemy.hit_reaction_until = 0
	first_enemy.frozen_until = 0
	first_enemy.velocity.x = 100.0
	first_enemy.visual_time = 0.0
	first_enemy.update_visual_animation()
	var first_motion_position := first_enemy.sprite.position
	first_enemy.visual_time = 0.2
	first_enemy.update_visual_animation()
	check(first_enemy.sprite.position != first_motion_position, "敌兵移动动画持续改变视觉帧")

	player.invulnerable_until = 0
	var health_before_hit := player.health
	player.take_damage(5.0, player.global_position + Vector2.LEFT)
	check(player.health == health_before_hit - 5.0, "玩家受伤扣血")
	var health_after_first_hit := player.health
	player.take_damage(5.0, player.global_position + Vector2.LEFT)
	check(player.health == health_after_first_hit, "玩家无敌帧阻止连续伤害")

	hud.toggle_pause()
	check(get_tree().paused and hud.pause_panel.visible, "暂停菜单可暂停场景")
	hud.toggle_pause()
	check(not get_tree().paused and not hud.pause_panel.visible, "暂停菜单可恢复场景")

	var bosses := get_tree().get_nodes_in_group("bosses")
	var demon_king: Enemy
	for enemy_node in bosses:
		var enemy := enemy_node as Enemy
		if enemy.stats.display_name == "混世魔王":
			demon_king = enemy
			break
	check(demon_king != null, "混世魔王已生成")
	if demon_king != null:
		demon_king.take_damage(demon_king.stats.max_health * 0.5, player.global_position)
		check(demon_king.phase_two, "混世魔王半血进入第二阶段")
		demon_king.invulnerable_until = 0
		demon_king.take_damage(demon_king.stats.max_health, player.global_position)
		await get_tree().process_frame
		check(level.completed and hud.result_panel.visible, "击败混世魔王触发过关结算")

	await get_tree().create_timer(0.5).timeout
	level.queue_free()
	for _frame in 3:
		await get_tree().process_frame
	if failures.is_empty():
		print("PHASE 01 CORE CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("PHASE 01 CORE CHECKS FAILED: ", failures.size())
		get_tree().quit(1)
