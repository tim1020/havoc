extends Node

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")


func _ready() -> void:
	var level := LEVEL_SCENE.instantiate()
	add_child(level)
	for _frame in 5:
		await get_tree().physics_frame

	var player := level.player as Player
	var enemy := get_tree().get_nodes_in_group("enemies")[0] as Enemy
	player.global_position = Vector2(360, 580)
	player.velocity = Vector2.ZERO
	enemy.global_position = Vector2(520, 580)
	enemy.velocity = Vector2.ZERO
	enemy.invulnerable_until = 0
	enemy.take_damage(1.0, player.global_position)

	for _frame in 2:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://artifacts/phase_01/enemy_hit_feedback_actual.png")
	if error != OK:
		push_error("Failed to save enemy feedback screenshot: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("ENEMY FEEDBACK SCREENSHOT SAVED")
	get_tree().quit(0)
