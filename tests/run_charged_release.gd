extends Node


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_charged_release_save.json"
	GameState.has_staff = false
	var level := (load("res://src/levels/level_01/level_01.tscn") as PackedScene).instantiate()
	add_child(level)
	for _frame in 6:
		await get_tree().physics_frame
	var player := level.player as Player
	player.set_physics_process(false)
	player.global_position = Vector2(300, 580)
	player.facing = 1.0
	var enemies := get_tree().get_nodes_in_group("enemies")
	var target := get_tree().get_nodes_in_group("bosses")[0] as Enemy
	for index in enemies.size():
		var enemy := enemies[index] as Enemy
		enemy.set_physics_process(false)
		enemy.global_position = Vector2(5000 + index * 120, 580)
	target.global_position = Vector2(620, 580)
	target.invulnerable_until = 0
	var health_before := target.health
	player.begin_attack_charge()
	player.attack_pressed_at = Time.get_ticks_msec() - 2100
	player.update_charge_feedback()
	player.release_attack_charge()
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group("charged_flame_projectiles").size() == 1, "满蓄力应生成火焰投射物")
	for _frame in 90:
		await get_tree().physics_frame
	assert(is_equal_approx(health_before - target.health, player.stats.charged_attack_damage), "火焰三连击总伤害错误")
	print("PASS: charged flame projectile dealt three-hit total damage")
	get_tree().quit()
