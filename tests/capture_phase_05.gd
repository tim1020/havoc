extends Node

const LEVEL_05 := preload("res://src/levels/level_05/level_05.tscn")
const OUTPUT_DIR := "res://artifacts/phase_05"


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_phase_05_capture.json"
	GameState.has_staff = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var level = LEVEL_05.instantiate()
	add_child(level)
	await settle(8)
	var camera := level.player.get_node("Camera") as Camera2D
	camera.position_smoothing_enabled = false
	level.player.global_position = Vector2(720, 570)
	camera.reset_smoothing()
	await settle(5)
	if save_view("%s/cloud_route_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	level.player.global_position = Vector2(3510, 570)
	camera.reset_smoothing()
	await settle(5)
	if save_view("%s/heaven_gate_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	level.gate.take_damage(500.0, level.player.global_position)
	level.player.global_position = Vector2(4300, 570)
	camera.reset_smoothing()
	await settle(5)
	if save_view("%s/king_battle_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	print("PHASE 05 SCREENSHOTS SAVED")
	get_tree().quit(0)


func settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().physics_frame
		await get_tree().process_frame


func save_view(path: String) -> Error:
	return get_viewport().get_texture().get_image().save_png(path)
