extends Node

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemies/enemy.tscn")
const ENEMY_STATS := preload("res://resources/stats/enemies/rebel_monkey.tres")
const BOSS_STATS := preload("res://resources/stats/enemies/demon_king.tres")
const ENEMY_ATLAS := preload("res://assets/generated/characters/level_01_enemy_frames.png")
const PICKUP_SCENE := preload("res://src/world/item_pickup.tscn")

var failures: Array[String] = []


func _ready() -> void:
	GameState.save_path = "/tmp/havoc_artifact_system_save.json"
	GameState.artifacts.clear()
	GameState.artifact_counts.clear()
	GameState.stones = 0
	var player := PLAYER_SCENE.instantiate() as Player
	player.global_position = Vector2(300.0, 300.0)
	add_child(player)
	var enemy_a := create_enemy(Vector2(420.0, 300.0))
	var enemy_b := create_enemy(Vector2(520.0, 300.0))
	await get_tree().process_frame
	check(player.artifact_cast_sprite.sprite_frames.get_frame_count(&"cast") == 8, "法宝使用动作加载八帧抽符施法动画")
	player.set_physics_process(false)
	enemy_a.set_physics_process(false)
	enemy_b.set_physics_process(false)

	check(GameState.pickup_artifact(&"freeze_talisman") and GameState.pickup_artifact(&"freeze_talisman"), "重复拾取同类法宝成功")
	check(GameState.artifacts == [&"freeze_talisman"] and GameState.artifact_count(&"freeze_talisman") == 2, "同类法宝只占一个栏位且数量累加")

	var peach := PICKUP_SCENE.instantiate() as ItemPickup
	peach.item = ItemCatalog.get_definition(&"peach")
	add_child(peach)
	player.health = 40.0
	peach.on_body_entered(player)
	check(player.health == 73.0, "未满血拾取补给立即回血")
	var full_peach := PICKUP_SCENE.instantiate() as ItemPickup
	full_peach.item = ItemCatalog.get_definition(&"peach")
	add_child(full_peach)
	player.health = player.stats.max_health
	var stones_before := GameState.stones
	full_peach.on_body_entered(player)
	check(GameState.stones == stones_before + full_peach.item.price and not GameState.artifacts.has(&"peach"), "满血拾取补给转为灵石而不进入栏位")

	player.use_current_artifact()
	check(enemy_a.frozen_until - Time.get_ticks_msec() >= 9500 and GameState.artifact_count(&"freeze_talisman") == 1, "定身符冻结所有敌兵10秒并消耗一层")
	GameState.artifacts = [&"invisibility_talisman"]
	GameState.artifact_counts = {&"invisibility_talisman": 1}
	player.use_current_artifact()
	check(player.is_physically_invisible() and player.sprite.modulate.a < 0.5 and not enemy_a.has_clear_line_to_player(player), "隐身符使悟空半透明且敌兵失去视野")

	GameState.artifacts = [&"samadhi_fire"]
	GameState.artifact_counts = {&"samadhi_fire": 1}
	player.use_current_artifact()
	var fires := get_tree().get_nodes_in_group("artifact_fire_patches")
	var fire_health_before := enemy_a.health
	if not fires.is_empty():
		var fire = fires[0]
		fire.elapsed = 0.34
		fire._process(0.01)
	check(fires.size() == 2 and enemy_a.health < fire_health_before and fires[0].fire_sprite.sprite_frames.get_frame_count(&"burn") == 6, "三味真火对屏幕内每名敌兵降下火焰并按普通攻击结算")

	GameState.artifacts = [&"banana_fan"]
	GameState.artifact_counts = {&"banana_fan": 1}
	enemy_a.launched_until = 0
	player.use_current_artifact()
	check(enemy_a.launched_until > Time.get_ticks_msec() and enemy_b.launched_until > Time.get_ticks_msec(), "芭蕉扇清退屏幕内小兵")

	GameState.artifacts = [&"purple_bell"]
	GameState.artifact_counts = {&"purple_bell": 1}
	enemy_a.frozen_until = 0
	enemy_b.frozen_until = 0
	enemy_a.launched_until = 0
	enemy_b.launched_until = 0
	enemy_a.invulnerable_until = 0
	enemy_b.invulnerable_until = 0
	enemy_b.global_position = enemy_a.global_position + Vector2(40.0, 0.0)
	var ally_health_before := enemy_b.health
	player.use_current_artifact()
	enemy_a.next_attack_at = 0
	enemy_a._physics_process(0.1)
	check(enemy_a.hallucinated_until - Time.get_ticks_msec() >= 9500 and enemy_b.hallucinated_until - Time.get_ticks_msec() >= 9500 and enemy_b.health < ally_health_before, "紫金铃使敌兵幻觉10秒并攻击同伙")

	var boss := create_enemy(Vector2(760.0, 300.0), BOSS_STATS)
	await get_tree().process_frame
	boss.set_physics_process(false)
	var boss_health := boss.health
	boss.global_position.y = Enemy.PIT_DEATH_Y + 1.0
	boss._physics_process(0.0)
	check(not boss.dead and boss.global_position == boss.spawn_position and boss.health < boss_health, "中Boss和大Boss掉坑只受伤并返回战场")

	var frozen_enemy := create_enemy(Vector2(900.0, 300.0))
	await get_tree().process_frame
	frozen_enemy.freeze_for(10.0)
	frozen_enemy.die()
	await get_tree().create_timer(1.0).timeout
	check(not is_instance_valid(frozen_enemy), "被定身后击败的Boss角色仍会播放死亡动画并消失")

	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(GameState.save_path)
	if failures.is_empty():
		print("ARTIFACT SYSTEM CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("ARTIFACT SYSTEM CHECKS FAILED: ", failures.size())
		get_tree().quit(1)


func create_enemy(position_value: Vector2, stats: EnemyStats = ENEMY_STATS) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.stats = stats
	enemy.animation_atlas = ENEMY_ATLAS
	enemy.global_position = position_value
	add_child(enemy)
	return enemy


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
