extends Node

const LEVEL_01 := preload("res://src/levels/level_01/level_01.tscn")
const LEVEL_04 := preload("res://src/levels/level_04/level_04.tscn")
const OUTPUT_DIR := "res://artifacts/gameplay_polish"


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_gameplay_polish_capture.json"
	GameState.has_staff = false
	GameState.stones = 1000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var level = LEVEL_01.instantiate()
	add_child(level)
	await settle(8)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		(enemy_node as Enemy).set_physics_process(false)
	level.shop.open_shop(level.player, "水帘洞商品图鉴")
	await settle(3)
	if save_view("%s/shop_item_images_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	level.shop.close_shop()
	level.player.global_position = Vector2(420, 580)
	level.player.facing = 1.0
	var camera := level.player.get_node("Camera") as Camera2D
	camera.position_smoothing_enabled = false
	var demon := find_enemy("混世魔王")
	demon.global_position = Vector2(760, 580)
	GameState.artifacts = [&"fire_spear", &"monkey_hair"]
	level.player.use_current_artifact()
	level.player.use_current_artifact()
	level.player.perform_aerial_throw()
	await settle(4)
	if save_view("%s/artifact_motion_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	for clone in get_tree().get_nodes_in_group("monkey_clones"):
		clone.queue_free()
	for projectile in get_tree().get_nodes_in_group("artifact_projectiles"):
		projectile.queue_free()
	await settle(2)
	demon.phase_two = true
	demon.next_projectile_at = 0
	demon.try_ranged_attack(level.player)
	await settle(9)
	if save_view("%s/boss_ranged_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()
	await settle(2)
	level.player.health = 18.0
	level.complete_level(0)
	await get_tree().create_timer(0.35).timeout
	if save_view("%s/victory_animation_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	level.queue_free()
	await settle(3)
	var level4 = LEVEL_04.instantiate()
	add_child(level4)
	await settle(8)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		enemy.set_physics_process(false)
		enemy.visible = false
	var level4_camera := level4.player.get_node("Camera") as Camera2D
	level4_camera.position_smoothing_enabled = false
	level4.player.global_position = Vector2(2550, 580)
	level4_camera.reset_smoothing()
	var checkpoint := get_tree().get_first_node_in_group("checkpoints") as Checkpoint
	checkpoint.activate(level4.player)
	await settle(4)
	if save_view("%s/peach_checkpoint_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	print("GAMEPLAY POLISH SCREENSHOTS SAVED")
	get_tree().quit(0)


func find_enemy(display_name: String) -> Enemy:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.stats.display_name == display_name:
			return enemy
	return null


func settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().physics_frame
		await get_tree().process_frame


func save_view(path: String) -> Error:
	return get_viewport().get_texture().get_image().save_png(path)
