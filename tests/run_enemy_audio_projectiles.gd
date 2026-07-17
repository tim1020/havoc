extends Node

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemies/enemy.tscn")
const ENEMY_ATLAS := preload("res://assets/generated/characters/level_01_enemy_frames.png")
const RANGED_STATS := preload("res://resources/stats/enemies/turtle_chancellor.tres")
const GROUND_STATS := preload("res://resources/stats/enemies/rebel_monkey.tres")
const SNAKE_STATS := preload("res://resources/stats/enemies/snake.tres")
const THORN_STATS := preload("res://resources/stats/hazards/thorn_spikes.tres")

var failures: Array[String] = []


func _ready() -> void:
	GameState.settings.reduced_motion = true
	var player := PLAYER_SCENE.instantiate() as Player
	player.global_position = Vector2(500.0, 300.0)
	add_child(player)
	await get_tree().process_frame

	player.invulnerable_until = 0
	player.take_damage(1.0, Vector2.ZERO)
	check(has_playing_stream(player, AudioService.PLAYER_HURT), "悟空受击播放独立且增强的受击音效")
	clear_audio_players(player)
	player.invulnerable_until = 0
	var hazard := Hazard.new()
	hazard.stats = THORN_STATS
	add_child(hazard)
	var health_before_hazard := player.health
	hazard.on_body_entered(player)
	check(player.health < health_before_hazard and has_playing_stream(player, AudioService.PLAYER_HURT), "悟空踩中陷阱扣血时同步播放受击音效")

	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.stats = RANGED_STATS
	enemy.animation_atlas = ENEMY_ATLAS
	enemy.global_position = Vector2(0.0, 300.0)
	enemy.target_player = player
	add_child(enemy)
	await get_tree().process_frame

	enemy.next_attack_at = 0
	enemy.try_attack(player)
	check(has_playing_stream(enemy, AudioService.ENEMY_ATTACK), "敌兵近战攻击播放独立音效")
	enemy.next_projectile_at = 0
	check(enemy.try_ranged_attack(player), "远程敌兵成功发射弹体")
	check(has_playing_stream(enemy, AudioService.ENEMY_THROW), "敌兵远程发射播放独立音效")
	enemy.invulnerable_until = 0
	enemy.take_damage(1.0, player.global_position)
	check(has_playing_stream(enemy, AudioService.ENEMY_HURT), "敌兵受击播放独立音效")

	player.invulnerable_until = 0
	var health_before_projectile := player.health
	var projectiles := get_tree().get_nodes_in_group("enemy_projectiles")
	check(not projectiles.is_empty(), "敌兵远程攻击生成弹体")
	if not projectiles.is_empty():
		var projectile := projectiles.back() as EnemyProjectile
		var projectile_start := projectile.global_position
		var projectile_end := projectile_start + projectile.direction * projectile.speed * 2.0
		var player_center := player.global_position + Vector2(0.0, -42.0)
		check(projectile.segment_distance_to_point(projectile_start, projectile_end, player_center) <= 38.0, "远程弹体轨迹穿过悟空碰撞范围")
		projectile._process(2.0)
		check(player.health < health_before_projectile, "高速敌方弹体扫过悟空时能够命中并造成伤害")

	var ground_enemy := ENEMY_SCENE.instantiate() as Enemy
	ground_enemy.stats = GROUND_STATS
	ground_enemy.animation_atlas = ENEMY_ATLAS
	ground_enemy.global_position = Vector2(0.0, 300.0)
	ground_enemy.target_player = player
	add_child(ground_enemy)
	create_floor(Rect2(-200.0, 360.0, 260.0, 80.0))
	await get_tree().process_frame
	ground_enemy.patrol_direction = 1.0
	ground_enemy.next_projectile_at = 0
	check(not ground_enemy.can_throw_ground_projectile_at(player, Vector2(500.0, 0.0)), "地面兵有路接近悟空时不会投掷")
	ground_enemy.global_position.x = 20.0
	check(ground_enemy.can_throw_ground_projectile_at(player, Vector2(480.0, 0.0)) and ground_enemy.try_ranged_attack(player, true), "地面兵到缺口前无法接近时才投掷")
	var stone_projectiles := get_tree().get_nodes_in_group("enemy_projectiles")
	var stone := stone_projectiles.back() as EnemyProjectile
	check(stone.style == "stone" and stone.direction.x > 0.99 and is_zero_approx(stone.direction.y), "地面兵石头仅沿正前方飞行")
	check(not ground_enemy.can_throw_ground_projectile_at(player, Vector2(-480.0, 0.0)), "地面兵不会向身后投掷")
	check(GROUND_STATS.ground_projectile_style == "stone" and SNAKE_STATS.ground_projectile_style == "fang", "不同兵种配置不同投掷物")
	ground_enemy.die()

	enemy.die()
	check(has_playing_stream(enemy, AudioService.ENEMY_DEATH), "敌兵死亡播放独立音效")

	if failures.is_empty():
		print("ENEMY AUDIO AND PROJECTILE CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("ENEMY AUDIO AND PROJECTILE CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func has_playing_stream(parent: Node, stream: AudioStream) -> bool:
	for child in parent.get_children():
		if child is AudioStreamPlayer and child.stream == stream and child.playing:
			return true
	return false


func clear_audio_players(parent: Node) -> void:
	for child in parent.get_children():
		if child is AudioStreamPlayer:
			child.free()


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


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
