extends Node

const TEST_SAVE := "/tmp/havoc_gameplay_polish_save.json"
var failures: Array[String] = []


func _ready() -> void:
	GameState.save_path = TEST_SAVE
	GameState.lives = 3
	GameState.stones = 1000
	GameState.artifacts.clear()
	await run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var level_scene := load("res://src/levels/level_01/level_01.tscn") as PackedScene
	var level = level_scene.instantiate()
	add_child(level)
	for _frame in 6:
		await get_tree().physics_frame
	while get_tree().paused:
		await get_tree().create_timer(0.1, true).timeout
	var player := level.player as Player
	GameState.lives = 3
	check(GameState.consume_life() and GameState.lives == 2, "debug测试模式也会消耗救命毫毛")
	level.hud.update_lives(GameState.lives)
	check(level.hud.lives_label.text == "毫毛  × 2", "HUD显示实际救命毫毛数量")
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		(enemy_node as Enemy).set_physics_process(false)

	player.global_position = Vector2(300, 500)
	player.facing = 1.0
	player.perform_aerial_throw()
	check(get_tree().get_nodes_in_group(&"player_throw_projectiles").size() == 1, "空中攻击生成香蕉投掷物")
	player.perform_aerial_throw()
	check(get_tree().get_nodes_in_group(&"player_throw_projectiles").size() == 1, "空中投掷间隔不少于0.2秒")

	GameState.artifacts = [&"fire_spear", &"peach"]
	player.select_next_artifact()
	check(player.artifact_selected and GameState.artifacts == [&"fire_spear", &"peach"], "首次按C选中第一个法宝")
	player.select_next_artifact()
	check(GameState.artifacts == [&"peach", &"fire_spear"], "再次按C循环切换法宝")
	player.health = 20.0
	player.use_current_artifact()
	player.set_artifact_selected(false)
	check(player.health == 53.0 and GameState.artifacts == [&"fire_spear"], "选中后按攻击键消费当前补血物品")

	var target := find_enemy("山猪妖")
	player.global_position = Vector2(360, 580)
	player.facing = 1.0
	target.global_position = Vector2(600, 580)
	target.invulnerable_until = 0
	var target_health := target.health
	player.use_current_artifact()
	var artifact_projectiles := get_tree().get_nodes_in_group("artifact_projectiles")
	check(artifact_projectiles.size() == 1, "投掷法宝生成独立可见运动节点")
	var artifact_sprite := (artifact_projectiles[0] as Node).get("sprite") as AnimatedSprite2D
	check(artifact_sprite != null and artifact_sprite.sprite_frames.get_frame_count(&"fly") == 4, "投掷法宝使用四帧位图动画")
	var projectile_start := (artifact_projectiles[0] as Node2D).global_position
	for _frame in 8:
		await get_tree().physics_frame
	check(is_instance_valid(artifact_projectiles[0]) and (artifact_projectiles[0] as Node2D).global_position.x > projectile_start.x, "投掷法宝从玩家向敌人方向移动")
	for _frame in 18:
		await get_tree().physics_frame
	check(target.health < target_health, "投掷法宝抵达后结算实际伤害")

	GameState.artifacts = [&"monkey_hair"]
	player.use_current_artifact()
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("monkey_clones").size() == 3, "毫毛分身生成3个可见猴子并自主攻击")

	var shop := level.shop as ShopPanel
	var product_icons_ok := true
	for button_node in shop.products.get_children():
		var button := button_node as Button
		product_icons_ok = product_icons_ok and button.icon != null and button.icon.get_size().x >= 48
	check(product_icons_ok and shop.products.get_child_count() == 11, "商店11件商品均显示独立图片")
	check(GameState.MAX_ARTIFACTS == 5 and level.hud.artifact_labels.size() == 5, "HUD与商店使用五格物品栏")
	GameState.artifacts = [&"cosmic_ring"]
	GameState.stones = 1000
	player.health = 25.0
	shop.open_shop(player, "补血商品测试")
	shop.request_purchase(ItemCatalog.get_definition(&"peach"))
	shop.confirm_pending()
	check(player.health == 25.0 and GameState.artifacts == [&"cosmic_ring", &"peach"], "商店补血物品进入法宝栏且不立即生效")
	shop.close_shop()

	var demon := find_enemy("混世魔王")
	demon.global_position = Vector2(800, 580)
	player.global_position = Vector2(300, 580)
	demon.next_projectile_at = 0
	check(demon.try_ranged_attack(player), "Boss可主动释放远程技能")
	var enemy_projectiles := get_tree().get_nodes_in_group("enemy_projectiles")
	check(enemy_projectiles.size() == 1, "Boss远程技能生成可见投射物")
	var enemy_projectile_sprite := (enemy_projectiles[0] as Node).get("sprite") as AnimatedSprite2D
	check(enemy_projectile_sprite != null and enemy_projectile_sprite.sprite_frames.get_frame_count(&"fly") == 4, "Boss远程兵器使用四帧位图动画")
	var demon_idle := demon.sprite.sprite_frames.get_frame_texture(&"idle", 0) as AtlasTexture
	check(demon_idle.atlas.resource_path.ends_with("level_01_enemy_frames.png"), "敌兵与Boss运行时使用PNG角色帧图集")
	demon.phase_two = true
	demon.next_projectile_at = 0
	demon.try_ranged_attack(player)
	check(get_tree().get_nodes_in_group("enemy_projectiles").size() == 4, "Boss半血阶段释放三发扇形弹幕")

	player.health = 12.0
	level.complete_level(0)
	check(player.health == player.stats.max_health and player.sprite.animation == &"victory", "过关立即回满生命并播放角色胜利动画")
	check(level.hud.victory_banner.visible, "过关时播放中央通关动画")
	await get_tree().create_timer(1.0).timeout
	check(level.hud.result_panel.visible, "胜利动画后播放结算面板动画")
	if level.shop.visible:
		level.shop.close_shop()
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	GameState.has_staff = false
	var level3 = (load("res://src/levels/level_03/level_03.tscn") as PackedScene).instantiate()
	add_child(level3)
	while get_tree().paused:
		await get_tree().create_timer(0.1, true).timeout
	for _frame in 5:
		await get_tree().physics_frame
	var staff_player := level3.player as Player
	var idle_texture := staff_player.sprite.sprite_frames.get_frame_texture(&"idle", 0) as AtlasTexture
	check(GameState.has_staff and staff_player.stats == Player.STAFF_STATS, "第三关进入时确保金箍棒已解锁")
	check(idle_texture.atlas.resource_path.ends_with("player_staff_atlas.png"), "第三关及后续使用生成的持棒PNG角色动画")
	level3.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	var level4 = (load("res://src/levels/level_04/level_04.tscn") as PackedScene).instantiate()
	add_child(level4)
	while get_tree().paused:
		await get_tree().create_timer(0.1, true).timeout
	for _frame in 5:
		await get_tree().physics_frame
	var checkpoint := get_tree().get_first_node_in_group("checkpoints") as Checkpoint
	checkpoint.activate(level4.player)
	check(checkpoint.activated and level4.player.respawn_position == Vector2(2680, 580), "蟠桃园中段检查点更新死亡重生位置")
	level4.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	if failures.is_empty():
		print("GAMEPLAY POLISH CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("GAMEPLAY POLISH CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func find_enemy(display_name: String) -> Enemy:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.stats.display_name == display_name and not enemy.dead:
			return enemy
	return null
