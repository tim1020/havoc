extends Node

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemies/enemy.tscn")
const ENEMY_ATLAS := preload("res://assets/generated/characters/level_01_enemy_frames.png")
const REBEL_STATS := preload("res://resources/stats/enemies/rebel_monkey.tres")

var failures: Array[String] = []


func _ready() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	player.global_position = Vector2.ZERO
	add_child(player)
	var sentry := create_enemy(Vector2(900.0, 500.0), 0)
	var attacked := create_enemy(Vector2(1600.0, 500.0), 0)
	var nearby_ally := create_enemy(Vector2(2020.0, 500.0), 0)
	var far_ally := create_enemy(Vector2(2250.0, 500.0), 0)
	var other_section_ally := create_enemy(Vector2(1900.0, 500.0), 1)
	await get_tree().process_frame
	for enemy in [sentry, attacked, nearby_ally, far_ally, other_section_ally]:
		enemy.set_physics_process(false)

	var sentry_start_x := sentry.global_position.x
	sentry._physics_process(0.016)
	check(not sentry.engaged and is_equal_approx(sentry.global_position.x, sentry_start_x), "远离悟空时敌兵固定驻守")
	player.global_position = Vector2(550.0, 500.0)
	sentry._physics_process(0.016)
	check(sentry.engaged, "悟空进入警戒距离后敌兵开始追踪")

	attacked.invulnerable_until = 0
	attacked.take_damage(1.0, player.global_position)
	check(attacked.engaged, "受到攻击的敌兵立即进入追踪")
	check(nearby_ally.engaged, "520像素内的同小节同伙被攻击警报唤醒")
	check(not far_ally.engaged, "警报范围外的同伙保持驻守")
	check(not other_section_ally.engaged, "攻击警报不会跨小节传播")

	if failures.is_empty():
		print("ENEMY ALERT BEHAVIOR CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("ENEMY ALERT BEHAVIOR CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func create_enemy(position_value: Vector2, section: int) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.stats = REBEL_STATS
	enemy.animation_atlas = ENEMY_ATLAS
	enemy.global_position = position_value
	enemy.set_meta(&"section_index", section)
	add_child(enemy)
	return enemy


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
