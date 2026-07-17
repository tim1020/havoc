extends Node

const TEST_SAVE := "/tmp/havoc_phase_02_save.json"

var failures: Array[String] = []


func _ready() -> void:
	GameState.save_path = TEST_SAVE
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	await run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var item_is_c := false
	for event in InputMap.action_get_events("item"):
		if event is InputEventKey and event.physical_keycode == KEY_C:
			item_is_c = true
	check(item_is_c, "法宝输入动作集中映射为C键")
	check(ItemCatalog.DEFINITIONS.size() == 11, "11种商店道具资源可加载")
	check(ItemCatalog.get_definition(&"peach").power == 33.0, "蟠桃回复数值来自资源")
	check(ItemCatalog.get_definition(&"heaven_seal").power == 80.0, "翻天印伤害数值来自资源")
	var menu_scene := load("res://src/ui/main_menu/main_menu.tscn") as PackedScene
	var menu = menu_scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu.continue_button.disabled, "无存档时主菜单禁用继续游戏")
	var mock_actions: Array[StringName] = [&"move_left", &"move_right", &"move_left", &"move_right"]
	for action in mock_actions:
		var mock_event := InputEventAction.new()
		mock_event.action = action
		mock_event.pressed = true
		menu._unhandled_input(mock_event)
	check(menu.mock_panel.visible, "主菜单顺序按左右左右显示测试Mock界面")
	GameState.configure_mock_game(100, 4)
	check(GameState.lives == 100 and GameState.current_level == 4 and GameState.current_level_path == GameState.FOURTH_LEVEL, "Mock可设置任意非负毫毛数量和起始关卡")
	check(GameState.has_staff, "Mock从第三关以后开始时自动解锁金箍棒")
	menu.queue_free()
	await get_tree().process_frame

	GameState.lives = 2
	GameState.stones = 700
	GameState.artifacts.clear()
	GameState.life_bought_this_level = false
	GameState.pickup_artifact(&"fire_spear")
	GameState.pickup_artifact(&"cosmic_ring")
	GameState.pickup_artifact(&"fire_wheels")
	GameState.pickup_artifact(&"purple_bell")
	GameState.pickup_artifact(&"monkey_hair")
	check(not GameState.pickup_artifact(&"binding_rope"), "五格满栏时拒绝拾取新法宝")
	check(GameState.artifacts == [&"fire_spear", &"cosmic_ring", &"fire_wheels", &"purple_bell", &"monkey_hair"], "五格满栏拾取法宝不会顶掉已有物品")
	check(GameState.purchase_artifact_fifo(&"heaven_seal", 150), "满栏购买法宝丢弃队首并整体前移")
	check(GameState.artifacts == [&"cosmic_ring", &"fire_wheels", &"purple_bell", &"monkey_hair", &"heaven_seal"], "新法宝追加到五格物品栏队尾")
	check(GameState.stones == 550, "购买法宝正确扣除灵石")
	check(GameState.pop_artifact() == &"cosmic_ring", "使用法宝按FIFO取出队首")
	check(GameState.purchase_life(500), "本关首次购买救命毫毛成功")
	check(GameState.lives == 3 and GameState.stones == 50, "毫毛购买更新上限与余额")
	check(not GameState.purchase_life(500), "同关不能重复购买救命毫毛")

	GameState.unlocked_level = 3
	GameState.current_level = 2
	GameState.settings.master_volume = 0.42
	check(GameState.save_game() == OK and FileAccess.file_exists(TEST_SAVE), "存档写入成功")
	GameState.lives = 0
	GameState.stones = 0
	GameState.artifacts.clear()
	GameState.unlocked_level = 1
	GameState.settings.master_volume = 1.0
	check(GameState.load_game(), "存档读取成功")
	check(GameState.lives == 3 and GameState.stones == 50, "生命与灵石可恢复")
	check(GameState.artifacts == [&"fire_wheels", &"purple_bell", &"monkey_hair", &"heaven_seal"], "五格物品队列可恢复")
	check(GameState.unlocked_level == 3 and GameState.current_level == 2, "关卡进度可恢复")
	check(is_equal_approx(GameState.settings.master_volume, 0.42), "设置可恢复")
	menu = menu_scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(not menu.continue_button.disabled, "有效存档存在时主菜单启用继续游戏")
	menu.queue_free()
	await get_tree().process_frame

	GameState.lives = 3
	GameState.stones = 0
	GameState.artifacts.clear()
	var level_scene := load("res://src/levels/level_01/level_01.tscn") as PackedScene
	var level = level_scene.instantiate()
	add_child(level)
	for _frame in 5:
		await get_tree().physics_frame
	while get_tree().paused:
		await get_tree().create_timer(0.1, true).timeout
	var pickups := level.find_children("*", "ItemPickup", true, false)
	check(pickups.size() == 6, "第一关生成6个固定拾取物")
	var player := level.player as Player
	player.health = 40.0
	var peach: ItemPickup
	var fire_spear: ItemPickup
	for pickup_node in pickups:
		var pickup := pickup_node as ItemPickup
		if pickup.item.id == &"peach" and peach == null:
			peach = pickup
		elif pickup.item.id == &"fire_spear":
			fire_spear = pickup
	peach.on_body_entered(player)
	check(player.health == 73.0, "拾取蟠桃立即回复33点生命")
	player.health = player.stats.max_health
	var stored_peach := (load("res://src/world/item_pickup.tscn") as PackedScene).instantiate() as ItemPickup
	stored_peach.item = ItemCatalog.get_definition(&"peach")
	level.add_child(stored_peach)
	stored_peach.on_body_entered(player)
	check(GameState.artifacts == [&"peach"], "满血拾取补血物品进入五格物品栏")
	GameState.pop_artifact()
	fire_spear.on_body_entered(player)
	check(GameState.artifacts == [&"fire_spear"], "拾取法宝进入队列")
	check(level.hud.artifact_labels[0].text == "火尖枪", "HUD未选中时不标记法宝")
	player.select_next_artifact()
	check(level.hud.artifact_labels[0].text == "▶ 火尖枪", "按C后HUD标记当前法宝")
	var enemy: Enemy
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var candidate := enemy_node as Enemy
		if candidate.stats.display_name == "山猪妖":
			enemy = candidate
			break
	check(enemy != null, "山猪妖可用于法宝伤害测试")
	var reward_target: Enemy
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var candidate := enemy_node as Enemy
		if candidate.stats.display_name == "叛猴喽啰":
			reward_target = candidate
			break
	player.global_position = Vector2(360, 580)
	player.facing = 1.0
	enemy.global_position = Vector2(500, 580)
	enemy.invulnerable_until = 0
	reward_target.set_physics_process(false)
	reward_target.global_position = Vector2(680, 580)
	reward_target.health = 30.0
	reward_target.invulnerable_until = 0
	var enemy_health := enemy.health
	player.use_current_artifact()
	check(GameState.artifacts.is_empty(), "使用法宝消费队首")
	for _frame in 24:
		await get_tree().physics_frame
	check(enemy.health == enemy_health - 30.0, "火尖枪按资源数值造成30点伤害")
	check(GameState.stones == reward_target.stats.spirit_stones, "火尖枪贯穿击杀路径敌人并自动累计奖励")
	var stones_before_reward := GameState.stones
	level.add_spirit_stones(10)
	check(GameState.stones == stones_before_reward + 10 and level.hud.stones_label.text == "灵石  0020", "敌人奖励累计到全局灵石并更新HUD")

	GameState.stones = 1000
	GameState.artifacts = [&"fire_spear", &"cosmic_ring"]
	GameState.lives = 2
	GameState.life_bought_this_level = false
	player.health = 40.0
	var shop := level.shop as ShopPanel
	shop.open_shop(player, "测试商店")
	var right_event := InputEventAction.new()
	right_event.action = &"move_right"
	right_event.pressed = true
	shop._unhandled_input(right_event)
	check(shop.selected_index == 1, "商店使用角色右移绑定键框选商品")
	shop.selected_index = 3
	shop.move_selection(1)
	check(shop.selected_index == 4, "商店右移到行尾后自动进入下一行")
	shop.move_selection(-1)
	check(shop.selected_index == 3, "商店左移到行首后自动回到上一行")
	var item_event := InputEventAction.new()
	item_event.action = &"item"
	item_event.pressed = true
	shop._unhandled_input(item_event)
	check(GameState.artifacts == [&"cosmic_ring", &"fire_spear"], "商店按C将队首物品移到队尾")
	shop._unhandled_input(item_event)
	shop.request_purchase(ItemCatalog.get_definition(&"peach"))
	check(GameState.stones == 1000 and player.health == 40.0, "商品选择后未确认不会扣款或生效")
	var attack_event := InputEventAction.new()
	attack_event.action = &"attack"
	attack_event.pressed = true
	shop._unhandled_input(attack_event)
	check(GameState.stones == 950 and player.health == 40.0 and GameState.artifacts == [&"fire_spear", &"cosmic_ring", &"peach"], "确认购买蟠桃后进入法宝栏且不立即回复")
	GameState.pickup_artifact(&"fire_wheels")
	GameState.pickup_artifact(&"purple_bell")
	shop.request_purchase(ItemCatalog.get_definition(&"heaven_seal"))
	shop.confirm_pending()
	check(GameState.stones == 950 and GameState.artifacts == [&"fire_spear", &"cosmic_ring", &"peach", &"fire_wheels", &"purple_bell"], "五格满栏第一次确认只提示前移且不扣款")
	shop.confirm_pending()
	check(GameState.stones == 800 and GameState.artifacts == [&"cosmic_ring", &"peach", &"fire_wheels", &"purple_bell", &"heaven_seal"], "五格满栏再次确认丢弃队首、整体前移并把新法宝放到队尾")
	GameState.rotate_artifacts()
	check(GameState.artifacts == [&"peach", &"fire_wheels", &"purple_bell", &"heaven_seal", &"cosmic_ring"], "商店C键对应的五格FIFO轮转保持物品顺序")
	shop.request_purchase(ItemCatalog.get_definition(&"life_hair"))
	shop.confirm_pending()
	check(GameState.lives == 3 and GameState.life_bought_this_level, "商店可购买本关唯一一根救命毫毛")
	var stones_after_life := GameState.stones
	GameState.lives = 2
	shop.request_purchase(ItemCatalog.get_definition(&"life_hair"))
	shop.confirm_pending()
	check(GameState.lives == 2 and GameState.stones == stones_after_life, "隐藏与过关商店共享毫毛限购状态")
	shop.pending_action = ShopPanel.PendingAction.NONE
	var jump_event := InputEventAction.new()
	jump_event.action = &"jump"
	jump_event.pressed = true
	shop._unhandled_input(jump_event)
	check(shop.visible and shop.pending_action == ShopPanel.PendingAction.LEAVE, "跳跃键第一次只询问是否离开")
	shop._unhandled_input(jump_event)
	check(not shop.visible and not get_tree().paused, "跳跃键第二次确认离开商店")
	var wall := level.find_children("*", "BreakableWall", true, false)[0] as BreakableWall
	wall.take_damage(30.0, player.global_position)
	check(shop.visible and get_tree().paused, "击破支路石壁打开隐藏商店并暂停战斗")
	shop.close_shop()
	check(not get_tree().paused, "离开隐藏商店恢复战斗")
	level.queue_free()
	for _frame in 2:
		await get_tree().process_frame

	DirAccess.remove_absolute(TEST_SAVE)
	if failures.is_empty():
		print("PHASE 02 STATE CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("PHASE 02 STATE CHECKS FAILED: ", failures.size())
		get_tree().quit(1)
