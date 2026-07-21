extends Node

const LEVEL_06 := preload("res://src/levels/level_06/level_06.tscn")
const OUTPUT_DIR := "res://artifacts/phase_06"


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_phase_06_capture.json"
	GameState.has_staff = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var level = LEVEL_06.instantiate()
	add_child(level)
	await settle(8)
	var camera := level.player.get_node("Camera") as Camera2D
	camera.position_smoothing_enabled = false
	level.player.global_position = Vector2(700, 570)
	camera.reset_smoothing()
	await settle(5)
	if save_view("%s/palace_stairs_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	level.player.global_position = Vector2(3160, 570)
	camera.reset_smoothing()
	await settle(5)
	if save_view("%s/nezha_battle_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	var nezha := find_enemy("哪吒")
	kill(nezha, level.player)
	await get_tree().process_frame
	var erlang := find_enemy("二郎神")
	kill(erlang, level.player)
	await get_tree().process_frame
	var emperor := find_enemy("玉皇大帝")
	emperor.hit_received.emit(emperor, emperor.health + emperor.shield_health, emperor.stats.max_health + emperor.stats.shield_health)
	level.player.global_position = Vector2(4320, 570)
	camera.reset_smoothing()
	await settle(5)
	if save_view("%s/jade_emperor_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	print("PHASE 06 SCREENSHOTS SAVED")
	get_tree().quit(0)


func find_enemy(display_name: String) -> Enemy:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.stats.display_name == display_name and not enemy.dead:
			return enemy
	return null


func kill(enemy: Enemy, player: Player) -> void:
	enemy.set_physics_process(false)
	enemy.invulnerable_until = 0
	enemy.take_damage(enemy.health, player.global_position)


func settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().physics_frame
		await get_tree().process_frame


func save_view(path: String) -> Error:
	return get_viewport().get_texture().get_image().save_png(path)
