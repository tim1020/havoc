extends Node

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")

var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.settings.reduced_motion = true
	GameState.save_path = "/tmp/havoc_level01_terrain_save.json"
	var level := LEVEL_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame
	check(count_ground_gaps(level.campaign_ground_rects()) == 0, "底图没有明确裂隙的位置不再保留隐形坑位")
	check(has_ground_at(level.campaign_ground_rects(), 2550.0) and has_ground_at(level.campaign_ground_rects(), 2570.0) and has_ground_at(level.campaign_ground_rects(), 5110.0) and has_ground_at(level.campaign_ground_rects(), 5130.0), "小节边界两侧均有连续地面")
	check(level.campaign_platform_rects().size() == 16, "碰撞只保留底图可见的林道石台、森林石台、瀑布台阶和洞内石桥")
	var drop_platforms := get_tree().get_nodes_in_group(&"drop_through_platforms")
	check(drop_platforms.size() == level.campaign_platform_rects().size(), "所有可见石台和台阶均采用单向碰撞")
	var all_platforms_one_way := true
	for platform_node in drop_platforms:
		var platform := platform_node as StaticBody2D
		var shape_node := platform.get_child(0) as CollisionShape2D
		all_platforms_one_way = all_platforms_one_way and shape_node.one_way_collision
	check(all_platforms_one_way, "悟空从台阶正下方跳起不会顶头")
	if not drop_platforms.is_empty():
		var player := level.player as Player
		var platform := drop_platforms[0] as StaticBody2D
		player.one_way_floor = platform
		Input.action_press(&"crouch")
		var dropped := player.drop_through_one_way_floor()
		Input.action_release(&"crouch")
		await get_tree().process_frame
		check(dropped and (platform.get_child(0) as CollisionShape2D).disabled, "台阶上按下键加跳跃会临时穿过当前台阶")
		await get_tree().create_timer(0.2).timeout
		check(not (platform.get_child(0) as CollisionShape2D).disabled, "下跳后台阶碰撞自动恢复")
	check(level.find_children("*", "TileMapLayer", true, false).is_empty(), "第一关地图恢复为线稿绘制，不再加载TileMapLayer")
	check(level.find_children("*", "Level01Backdrop", true, false).size() == 1, "第一关恢复连续分区线稿背景")
	var terrain_fill_polygons := 0
	for polygon_node in level.find_children("*", "Polygon2D", true, false):
		if polygon_node.get_parent() == level:
			terrain_fill_polygons += 1
	check(terrain_fill_polygons == level.campaign_ground_rects().size() + level.campaign_platform_rects().size(), "线稿地面与台阶视觉逐段跟随当前碰撞地图")
	get_tree().paused = false
	level.queue_free()
	await get_tree().process_frame
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(GameState.save_path)
	if failures.is_empty():
		print("LEVEL 01 TERRAIN CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("LEVEL 01 TERRAIN CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func count_ground_gaps(rects: Array[Rect2]) -> int:
	var count := 0
	for section in 5:
		var section_rects: Array[Rect2] = []
		for rect in rects:
			if floori(rect.position.x / 2560.0) == section:
				section_rects.append(rect)
		section_rects.sort_custom(func(left: Rect2, right: Rect2) -> bool: return left.position.x < right.position.x)
		for index in section_rects.size() - 1:
			if section_rects[index].end.x < section_rects[index + 1].position.x:
				count += 1
	return count


func has_ground_at(rects: Array[Rect2], x: float) -> bool:
	for rect in rects:
		if rect.position.x <= x and x <= rect.end.x:
			return true
	return false


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
