extends Node

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemies/enemy.tscn")
const ENEMY_STATS := preload("res://resources/stats/enemies/rebel_monkey.tres")
const ENEMY_ATLAS := preload("res://assets/generated/characters/level_01_enemy_frames.png")

var failures: Array[String] = []


func _ready() -> void:
	GameState.lives = 3
	var player := PLAYER_SCENE.instantiate() as Player
	player.global_position = Vector2(420.0, 320.0)
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	var nearby_enemy := ENEMY_SCENE.instantiate() as Enemy
	nearby_enemy.stats = ENEMY_STATS
	nearby_enemy.animation_atlas = ENEMY_ATLAS
	nearby_enemy.global_position = player.global_position + Vector2(120.0, 0.0)
	add_child(nearby_enemy)
	await get_tree().process_frame
	nearby_enemy.set_physics_process(false)

	var death_position := player.global_position
	player.die_and_respawn(death_position)
	await get_tree().create_timer(0.9).timeout
	check(player.global_position == death_position, "被敌兵击败后原地复活")
	check(player.invulnerable_until - Time.get_ticks_msec() >= 2400, "原地复活后获得3秒无敌")
	check(player.invulnerability_aura.visible and player.invulnerability_aura.get_child_count() == 3, "重生无敌显示真气护身效果")
	check(nearby_enemy.launched_until > Time.get_ticks_msec() and nearby_enemy.velocity.x > 0.0, "重生会震飞附近敌兵")
	await get_tree().create_timer(0.4).timeout

	GameState.lives = 3
	create_floor(Rect2(100.0, 650.0, 180.0, 120.0))
	player.respawn_position = Vector2(180.0, 580.0)
	player.last_safe_platform_position = Vector2(279.0, 580.0)
	check(player.safe_respawn_position() == player.respawn_position, "坑边落脚点不会被用作复活点")
	player.last_safe_platform_position = Vector2(180.0, 580.0)
	player.global_position = Vector2(640.0, 850.0)
	player.fall_into_pit()
	await get_tree().create_timer(1.2).timeout
	check(player.global_position == Vector2(180.0, 580.0), "掉沟后回到掉落前最近平台")
	check(player.invulnerable_until - Time.get_ticks_msec() >= 2400, "掉沟复活后获得3秒无敌")
	player.apply_confusion(1.0)
	player.update_status_visual()
	check(player.confusion_stars.visible, "方向错乱时悟空头顶持续冒金星")

	if failures.is_empty():
		print("PLAYER RESPAWN CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("PLAYER RESPAWN CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func create_floor(rect: Rect2) -> void:
	var floor := StaticBody2D.new()
	floor.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	floor.position = rect.get_center()
	floor.add_child(collision)
	add_child(floor)
