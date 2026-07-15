extends Node

const LEVEL_02 := preload("res://src/levels/level_02/level_02.tscn")
const LEVEL_03 := preload("res://src/levels/level_03/level_03.tscn")
const OUTPUT_DIR := "res://artifacts/phase_03"


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_phase_03_capture.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if not await capture_level_02():
		get_tree().quit(1)
		return
	if not await capture_level_03():
		get_tree().quit(1)
		return
	print("PHASE 03 SCREENSHOTS SAVED")
	get_tree().quit(0)


func capture_level_02() -> bool:
	GameState.has_staff = false
	var level := LEVEL_02.instantiate() as CampaignLevel
	add_child(level)
	await settle(8)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		enemy.set_physics_process(false)
		enemy.visible = false
	level.player.set_physics_process(false)
	level.player.global_position = Vector2(4440, 580)
	level.player.velocity = Vector2.ZERO
	var camera := level.player.get_node("Camera") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	var checkpoint := get_tree().get_first_node_in_group("checkpoints") as Checkpoint
	checkpoint.activate(level.player)
	await settle(8)
	var saved := save_view("%s/level_02_actual.png" % OUTPUT_DIR) == OK
	level.queue_free()
	await get_tree().process_frame
	return saved


func capture_level_03() -> bool:
	GameState.has_staff = true
	var level := LEVEL_03.instantiate() as CampaignLevel
	add_child(level)
	await settle(8)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		enemy.set_physics_process(false)
		enemy.visible = false
	level.player.set_physics_process(false)
	level.player.global_position = Vector2(3060, 650)
	level.player.velocity = Vector2.ZERO
	level.player.facing = 1.0
	level.player.sprite.play(&"idle")
	var camera := level.player.get_node("Camera") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	level.player.begin_attack_charge()
	level.player.attack_started_on_floor = true
	level.player.attack_pressed_at = Time.get_ticks_msec() - int(level.player.stats.charge_seconds * 1000.0)
	level.player.update_charge_feedback()
	await settle(6)
	return save_view("%s/level_03_staff_actual.png" % OUTPUT_DIR) == OK


func settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().physics_frame
		await get_tree().process_frame


func save_view(path: String) -> Error:
	var image := get_viewport().get_texture().get_image()
	return image.save_png(path)
