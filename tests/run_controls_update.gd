extends Node

const TEST_SAVE := "/tmp/havoc_controls_update_save.json"
var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_path = TEST_SAVE
	GameState.settings.reduced_motion = true
	GameState.has_staff = false
	GameState.artifacts.clear()
	await run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var intro_started_at := Time.get_ticks_msec()
	var level := (load("res://src/levels/level_01/level_01.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	var intro_title := level.hud.find_child("LevelIntroTitle", true, false) as Label
	var intro_story := level.hud.find_child("LevelIntroStory", true, false) as Label
	check(intro_title != null and intro_title.text == "第一关 花果山", "关卡名称使用独立控件固定显示并包含关卡编号")
	check(intro_story != null and intro_story.text.begins_with("悟空学艺归来\n") and not intro_story.text.contains("花果山\n"), "开场正文使用独立控件并保留指定换行")
	while get_tree().paused:
		await get_tree().create_timer(0.05, true).timeout
	await get_tree().process_frame
	check(Time.get_ticks_msec() - intro_started_at >= 900, "关卡简介结束后约等待1秒再开始游戏")
	check(not get_tree().paused, "剧情结束后恢复游戏运行")
	check(is_equal_approx(GameHud.INTRO_CHARACTER_SECONDS, 0.09), "关卡字幕打字速度放慢一半")
	# 测试关卡作为子节点加载，生产场景中的关卡会在自身成为 current_scene 后恢复控制。
	level.player.controls_enabled = true

	var enemies := get_tree().get_nodes_in_group(&"enemies")
	var middle_boss: Enemy
	var final_boss: Enemy
	for enemy_node in enemies:
		var candidate := enemy_node as Enemy
		if candidate.stats.is_boss and candidate.global_position.x < 10000.0:
			middle_boss = candidate
		elif candidate.stats.is_boss:
			final_boss = candidate
	check(middle_boss != null and not middle_boss.can_reposition, "第四小节中Boss禁止瞬移")
	check(final_boss == null, "关底Boss在首波小兵清完前不会提前出场")
	level.spawn_final_boss()
	await get_tree().process_frame
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var candidate := enemy_node as Enemy
		if candidate.has_meta(&"final_boss") and bool(candidate.get_meta(&"final_boss")):
			final_boss = candidate
	check(final_boss != null and final_boss.can_reposition and final_boss.next_boss_reposition_at - Time.get_ticks_msec() > 6000, "最终Boss出场后瞬移间隔为7至10秒")
	check((load("res://resources/stats/enemies/shrimp_soldier.tres") as EnemyStats).faces_right_by_default, "虾兵使用原图朝右标记")
	check((load("res://resources/stats/enemies/soul_reaper.tres") as EnemyStats).faces_right_by_default, "勾魂使者使用原图朝右标记")
	check(not (load("res://resources/stats/enemies/peach_demon.tres") as EnemyStats).faces_right_by_default and not (load("res://resources/stats/enemies/flower_fairy.tres") as EnemyStats).faces_right_by_default and (load("res://resources/stats/enemies/peach_child.tres") as EnemyStats).faces_right_by_default and (load("res://resources/stats/enemies/garden_guardian.tres") as EnemyStats).faces_right_by_default and not (load("res://resources/stats/enemies/fairy_leader.tres") as EnemyStats).faces_right_by_default, "蟠桃园兵种朝向与素材匹配")
	for index in enemies.size():
		var enemy := enemies[index] as Enemy
		enemy.set_physics_process(false)
		enemy.global_position = Vector2(5000.0 + index * 100.0, 500.0)
	var player := level.player as Player
	player.set_physics_process(false)
	player.global_position = Vector2(300.0, 500.0)
	player.facing = 1.0
	player.invulnerable_until = 0
	var health_before_hit := player.health
	player.take_damage(1.0, player.global_position + Vector2.RIGHT)
	player.update_animation(1.0)
	check(player.health == health_before_hit - 1.0 and player.sprite.animation == &"hurt" and player.hurt_animation_until > Time.get_ticks_msec(), "悟空受击动画保持约0.45秒且不会被移动动画立即覆盖")
	check(AudioService.ATTACK != null and AudioService.HIT != null and AudioService.JUMP != null and AudioService.THROW != null, "攻击、受击、跳跃和投掷音效均已加载")
	var target := enemies[0] as Enemy
	target.global_position = Vector2(650.0, 300.0)
	player.next_throw_at = 0
	player.perform_aerial_throw()
	var throws := get_tree().get_nodes_in_group(&"player_throw_projectiles")
	check(throws.size() == 1 and (throws[0] as PlayerThrowProjectile).kind == PlayerThrowProjectile.Kind.BANANA, "无棒时空中攻击投掷香蕉")
	var banana := throws[0] as PlayerThrowProjectile
	check(banana.target != null, "香蕉锁定前方屏幕内敌人")
	var banana_start := banana.global_position
	player.perform_aerial_throw()
	check(get_tree().get_nodes_in_group(&"player_throw_projectiles").size() == 1, "连续投掷间隔不少于0.2秒")
	for _frame in 3:
		await get_tree().physics_frame
	check(banana.global_position.x > banana_start.x and not is_equal_approx(banana.global_position.y, banana_start.y), "香蕉追踪敌兵并修正飞行方向")
	banana.queue_free()
	await get_tree().process_frame

	GameState.has_staff = true
	player.next_throw_at = 0
	player.perform_aerial_throw()
	throws = get_tree().get_nodes_in_group(&"player_throw_projectiles")
	var staff_throw := throws[0] as PlayerThrowProjectile
	check(staff_throw.kind == PlayerThrowProjectile.Kind.STAFF and staff_throw.target == target, "有棒时投棒追踪前方屏幕内敌人")
	var staff_sprite := staff_throw.get_child(0) as Sprite2D
	check(staff_sprite.texture == PlayerThrowProjectile.STAFF_TEXTURE and is_equal_approx(staff_sprite.texture.get_width() * staff_sprite.scale.x, 88.0), "投棍使用独立生成的完整直棍素材")
	var staff_start := staff_throw.global_position
	for _frame in 2:
		await get_tree().physics_frame
	check(staff_throw.global_position.x > staff_start.x and staff_throw.global_position.y < staff_start.y and staff_throw.rotation < 0.0, "投棒棍头朝前追踪目标")
	target.health = 100.0
	target.invulnerable_until = 0
	var staff_health_before := target.health
	var staff_damage := staff_throw.damage
	staff_throw.global_position = target.global_position + Vector2(-40.0, -42.0)
	for _frame in 24:
		await get_tree().physics_frame
	check(target.health == staff_health_before - staff_damage and get_tree().get_nodes_in_group(&"player_throw_projectiles").is_empty(), "投棒连续敲击三次但只结算一次伤害")
	await get_tree().process_frame
	var target_position_before := target.global_position
	target.global_position = Vector2(-500.0, 500.0)
	player.facing = 1.0
	player.next_throw_at = 0
	player.perform_aerial_throw()
	var straight_staff := get_tree().get_nodes_in_group(&"player_throw_projectiles")[0] as PlayerThrowProjectile
	var straight_start := straight_staff.global_position
	straight_staff._physics_process(0.1)
	check(is_instance_valid(straight_staff) and straight_staff.target == null and straight_staff.global_position.x > straight_start.x, "画面内没有目标时投棒仍向前直飞")
	straight_staff.queue_free()
	await get_tree().process_frame
	var hostile_projectile := EnemyProjectile.new()
	hostile_projectile.direction = Vector2.LEFT
	hostile_projectile.global_position = player.global_position + Vector2(260.0, -48.0)
	add_child(hostile_projectile)
	player.next_throw_at = 0
	player.perform_aerial_throw()
	var counter_staff := get_tree().get_nodes_in_group(&"player_throw_projectiles")[0] as PlayerThrowProjectile
	check(counter_staff.target == hostile_projectile, "Boss不在画面时投棒锁定画面内敌方攻击")
	counter_staff.global_position = hostile_projectile.global_position
	counter_staff._physics_process(0.01)
	await get_tree().process_frame
	check(not is_instance_valid(hostile_projectile) and not is_instance_valid(counter_staff), "悟空远程攻击可以击毁敌方投射物")
	target.global_position = target_position_before

	GameState.artifacts = [&"freeze_talisman", &"banana_fan"]
	GameState.artifact_counts = {&"freeze_talisman": 1, &"banana_fan": 1}
	level.hud.update_artifacts(GameState.artifacts)
	player.select_next_artifact()
	check(player.artifact_selected and GameState.artifacts[0] == &"freeze_talisman", "首次按C选中第一个法宝")
	player.select_next_artifact()
	check(GameState.artifacts[0] == &"banana_fan", "再次按C循环切换法宝")
	var direction_event := InputEventAction.new()
	direction_event.action = &"move_right"
	direction_event.pressed = true
	player._unhandled_input(direction_event)
	check(not player.artifact_selected, "方向键取消法宝选择")
	player.select_next_artifact()
	var attack_event := InputEventAction.new()
	attack_event.action = &"attack"
	attack_event.pressed = true
	player._unhandled_input(attack_event)
	check(not player.artifact_selected and GameState.artifacts == [&"freeze_talisman"], "攻击键使用选中法宝后回到普通攻击")

	GameState.artifacts = [&"freeze_talisman", &"invisibility_talisman", &"samadhi_fire", &"banana_fan", &"purple_bell"]
	GameState.artifact_counts = {&"freeze_talisman": 1, &"invisibility_talisman": 1, &"samadhi_fire": 1, &"banana_fan": 1, &"purple_bell": 1}
	var pickup := (load("res://src/world/item_pickup.tscn") as PackedScene).instantiate() as ItemPickup
	pickup.item = ItemCatalog.get_definition(&"freeze_talisman")
	level.add_child(pickup)
	pickup.on_body_entered(player)
	await get_tree().process_frame
	check(not is_instance_valid(pickup) and GameState.artifacts.size() == GameState.MAX_ARTIFACTS and GameState.artifact_count(&"freeze_talisman") == 2, "满栏拾取同类法宝会累加且不占新栏位")

	var continued := [false]
	level.hud.game_over_continue.connect(func() -> void: continued[0] = true)
	level.hud.show_game_over()
	check(get_tree().paused and level.hud.game_over_active and not level.hud.game_over_ready, "失败后冻结当前画面并立即显示Game Over")
	await get_tree().create_timer(1.05, true).timeout
	check(level.hud.game_over_ready, "Game Over显示1秒后开放继续输入")
	var continue_event := InputEventKey.new()
	continue_event.pressed = true
	continue_event.physical_keycode = KEY_SPACE
	level.hud._input(continue_event)
	check(continued[0], "按任意键触发失败界面继续")
	get_tree().paused = false

	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	if failures.is_empty():
		print("CONTROLS UPDATE CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("CONTROLS UPDATE CHECKS FAILED: ", failures.size())
		get_tree().quit(1)
