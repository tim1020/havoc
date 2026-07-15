extends Node

const MENU := preload("res://src/ui/main_menu/main_menu.tscn")
const LEVEL := preload("res://src/levels/level_01/level_01.tscn")
const OUTPUT_DIR := "res://artifacts/phase_07"


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_phase_07_capture.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var menu := MENU.instantiate()
	add_child(menu)
	await settle(5)
	if save_view("%s/main_menu_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	menu.queue_free()
	await settle(3)
	var level = LEVEL.instantiate()
	add_child(level)
	await settle(8)
	level.hud.toggle_pause()
	await settle(3)
	if save_view("%s/audio_settings_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	print("PHASE 07 SCREENSHOTS SAVED")
	get_tree().quit(0)


func settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().physics_frame
		await get_tree().process_frame


func save_view(path: String) -> Error:
	return get_viewport().get_texture().get_image().save_png(path)
