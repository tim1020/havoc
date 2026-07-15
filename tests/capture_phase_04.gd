extends Node

const LEVEL_04 := preload("res://src/levels/level_04/level_04.tscn")
const OUTPUT_DIR := "res://artifacts/phase_04"


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_phase_04_capture.json"
	GameState.has_staff = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var level := LEVEL_04.instantiate() as CampaignLevel
	add_child(level)
	await settle(8)
	level.player.global_position = Vector2(520, 580)
	level.player.velocity = Vector2.ZERO
	await settle(8)
	if save_view("%s/peach_path_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	var land_god: Enemy
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.stats.display_name == "蟠桃土地公":
			land_god = enemy
		else:
			enemy.set_physics_process(false)
	land_god.set_physics_process(false)
	land_god.invulnerable_until = 0
	land_god.take_damage(land_god.stats.max_health * 0.5, level.player.global_position)
	level.player.global_position = Vector2(4380, 570)
	level.player.velocity = Vector2.ZERO
	var camera := level.player.get_node("Camera") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	await settle(8)
	if save_view("%s/land_god_phase_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	print("PHASE 04 SCREENSHOTS SAVED")
	get_tree().quit(0)


func settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().physics_frame
		await get_tree().process_frame


func save_view(path: String) -> Error:
	return get_viewport().get_texture().get_image().save_png(path)
