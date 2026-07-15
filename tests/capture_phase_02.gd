extends Node

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")
const OUTPUT_DIR := "res://artifacts/phase_02"


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_phase_02_capture.json"
	GameState.stones = 675
	GameState.artifacts = [&"fire_spear", &"binding_rope", &"heaven_seal"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var level = LEVEL_SCENE.instantiate()
	add_child(level)
	for _frame in 8:
		await get_tree().physics_frame
	level.player.global_position = Vector2(1050, 580)
	level.player.velocity = Vector2.ZERO
	for _frame in 8:
		await get_tree().process_frame
	if save_view("%s/items_hud_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	level.shop.open_shop(level.player, "水帘洞隐藏商店")
	for _frame in 3:
		await get_tree().process_frame
	if save_view("%s/shop_actual.png" % OUTPUT_DIR) != OK:
		get_tree().quit(1)
		return
	print("PHASE 02 SCREENSHOTS SAVED")
	get_tree().quit(0)


func save_view(path: String) -> Error:
	var image := get_viewport().get_texture().get_image()
	return image.save_png(path)
