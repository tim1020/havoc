extends Node2D

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemies/enemy.tscn")
const HUD_SCENE := preload("res://src/ui/hud/hud.tscn")
const ITEM_PICKUP_SCENE := preload("res://src/world/item_pickup.tscn")
const SHOP_SCENE := preload("res://src/ui/shop/shop_panel.tscn")
const BREAKABLE_WALL_SCENE := preload("res://src/world/breakable_wall.tscn")
const SECTION_ENEMY_TRACKER := preload("res://src/levels/shared/section_enemy_tracker.gd")
const THORN_TEXTURE := preload("res://assets/generated/environments/level_01/thorn_spikes.png")
const THORN_STATS := preload("res://resources/stats/hazards/thorn_spikes.tres")

const ENEMY_ANIMATION_ATLAS := preload("res://assets/generated/characters/level_01_enemy_frames.png")

const REBEL_STATS := preload("res://resources/stats/enemies/rebel_monkey.tres")
const SNAKE_STATS := preload("res://resources/stats/enemies/snake.tres")
const BOAR_STATS := preload("res://resources/stats/enemies/boar_demon.tres")
const EAGLE_STATS := preload("res://resources/stats/enemies/eagle_demon.tres")
const AXE_BULL_STATS := preload("res://resources/stats/enemies/axe_bull.tres")
const DEMON_KING_STATS := preload("res://resources/stats/enemies/demon_king.tres")

const SCREEN_WIDTH := 1280.0
const SECTION_WIDTH := SCREEN_WIDTH * 2.0
const LEVEL_WIDTH := SECTION_WIDTH * 5.0
const LEVEL_STORY := "悟空学艺归来，花果山已变成一片废墟，得知是混世魔王所为，于是开始复仇之旅。"
const BOSS_REINFORCEMENT_COUNT := 2
const FINAL_BOSS_MAX_WAVES := 5
const INITIAL_ENEMY_MIN_X := 760.0

var player: Player
var hud: GameHud
var shop: ShopPanel
var spirit_stones: int = 0
var current_section: int = -1
var completed: bool = false
var section_gates: Dictionary = {}
var back_wall: StaticBody2D
var end_wall: StaticBody2D
var pending_camera_section: int = -1
var camera_left_tween: Tween
var camera_right_tween: Tween
var enemy_tracker = SECTION_ENEMY_TRACKER.new()
var current_section_enemy_count: int = 0
var recording_initial_wave: bool = false
var section_wave_specs: Dictionary = {}
var section_boss_reinforcement_index: Dictionary = {}
var section_boss_reinforcement_waves: Dictionary = {}
var final_boss_spawned: bool = false


func _ready() -> void:
	GameState.begin_level(1, get_tree().current_scene.scene_file_path)
	create_backgrounds()
	create_world_collision()
	spawn_player()
	recording_initial_wave = true
	spawn_enemies()
	recording_initial_wave = false
	for section in 5:
		section_boss_reinforcement_index[section] = 0
		var specs: Array = section_wave_specs.get(section, [])
		for index in specs.size():
			var duplicate_spec: Dictionary = specs[index].duplicate()
			var offset := -90.0 if index % 2 == 0 else 90.0
			duplicate_spec.position.x = clampf(duplicate_spec.position.x + offset, section * SECTION_WIDTH + 120.0, (section + 1) * SECTION_WIDTH - 120.0)
			spawn_enemy_from_spec(duplicate_spec)
	section_boss_reinforcement_waves[4] = 1
	create_section_barriers()
	spawn_items()
	spawn_hud()
	spawn_secret_shop()
	update_section(true)
	await play_level_intro()


func play_level_intro() -> void:
	player.controls_enabled = false
	get_tree().paused = true
	await hud.play_level_intro(LEVEL_STORY)
	if get_tree().current_scene != self:
		return
	get_tree().paused = false
	player.controls_enabled = true


func _process(_delta: float) -> void:
	if player == null or completed:
		return
	if player.global_position.y > 820.0:
		player.fall_into_pit()
	if pending_camera_section >= 0 and Input.get_axis("move_left", "move_right") > 0.0:
		unlock_next_section_camera()
	update_section(false)
	current_section_enemy_count = enemy_tracker.count(current_section)
	update_section_waves(current_section)
	if current_section < 4 and section_gates.has(current_section):
		refresh_section_gate(current_section)


func unlock_next_section_camera() -> void:
	var camera := player.get_node("Camera") as Camera2D
	var final_right := int((pending_camera_section + 2) * SECTION_WIDTH)
	var transition_right := mini(final_right, camera.limit_right + int(SCREEN_WIDTH))
	if camera_right_tween != null:
		camera_right_tween.kill()
	camera_right_tween = create_tween()
	camera_right_tween.tween_property(camera, "limit_right", transition_right, 0.9).set_trans(Tween.TRANS_LINEAR)
	camera_right_tween.tween_callback(func() -> void: camera.limit_right = final_right)
	pending_camera_section = -1
	hud.hide_go_prompt()


func create_backgrounds() -> void:
	add_child(Level01Backdrop.new())


func create_world_collision() -> void:
	var ground_segments := campaign_ground_rects()
	for rect in ground_segments:
		create_static_rect(rect)
		create_ground_visual(rect, rect.size.y)
	var platforms := campaign_platform_rects()
	for rect in platforms:
		create_static_rect(rect)
		create_ground_visual(rect, 92.0)
	create_thorn_hazard(Vector2(1080, 620), Vector2(120, 60))
	create_thorn_hazard(Vector2(2180, 620), Vector2(130, 60))
	create_thorn_hazard(Vector2(3380, 620), Vector2(140, 60))


func campaign_ground_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var layouts := [[[0, 920], [1040, 760], [1920, 640]], [[0, 560], [700, 920], [1740, 820]], [[0, 780], [940, 480], [1560, 1000]], [[0, 1100], [1240, 520], [1880, 680]], [[0, 680], [800, 520], [1440, 1120]]]
	for section in 5:
		for segment in layouts[section]:
			rects.append(Rect2(section * SECTION_WIDTH + segment[0], 650, segment[1], 120))
	return rects


func campaign_platform_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var layouts := [[[320, 440, 260], [760, 450, 220], [1280, 530, 320], [1840, 420, 260]], [[180, 470, 260], [620, 380, 300], [1160, 510, 220], [1640, 430, 300], [2140, 350, 240]], [[260, 540, 300], [740, 440, 220], [1120, 340, 260], [1600, 470, 320], [2110, 390, 260]], [[240, 500, 320], [760, 400, 240], [1220, 520, 340], [1760, 410, 260], [2200, 500, 220]], [[180, 510, 280], [620, 420, 260], [1080, 330, 300], [1600, 450, 300], [2100, 520, 300]]]
	for section in 5:
		for platform in layouts[section]:
			rects.append(Rect2(section * SECTION_WIDTH + platform[0], platform[1], platform[2], 24))
	return rects


func create_static_rect(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)


func create_ground_visual(rect: Rect2, visual_height: float) -> void:
	var surface := Polygon2D.new()
	surface.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y + visual_height),
		Vector2(rect.position.x, rect.position.y + visual_height),
	])
	var section := clampi(floori(rect.position.x / SECTION_WIDTH), 0, 4)
	var colors := [Color("657350"), Color("58784f"), Color("526f4f"), Color("52656a"), Color("39464d")]
	surface.color = colors[section]
	surface.z_index = -2
	add_child(surface)
	create_standable_line(rect)


func create_standable_line(rect: Rect2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([
		Vector2(rect.position.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
	])
	line.width = 5.0
	line.default_color = Color(1.0, 0.82, 0.15, 1.0)
	line.z_index = 4
	line.antialiased = true
	line.add_to_group("standable_surfaces")
	add_child(line)


func create_thorn_hazard(position_value: Vector2, size: Vector2) -> void:
	var hazard := Hazard.new()
	hazard.stats = THORN_STATS
	hazard.position = position_value
	hazard.collision_layer = 32
	hazard.collision_mask = 2
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x, size.y * 0.55)
	shape_node.position.y = size.y * 0.18
	shape_node.shape = shape
	hazard.add_child(shape_node)
	var sprite := Sprite2D.new()
	sprite.texture = THORN_TEXTURE
	sprite.position.y = -size.y * 0.5
	sprite.scale = Vector2(size.x / THORN_TEXTURE.get_width(), size.y / THORN_TEXTURE.get_height())
	sprite.z_index = 2
	hazard.add_child(sprite)
	add_child(hazard)


func spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(150, 580)
	add_child(player)
	var camera := player.get_node("Camera") as Camera2D
	camera.limit_smoothed = true
	camera.limit_left = 0
	camera.limit_right = int(SECTION_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = 720


func spawn_hud() -> void:
	hud = HUD_SCENE.instantiate() as GameHud
	add_child(hud)
	hud.bind_player(player)
	hud.update_stones(GameState.stones)


func spawn_enemies() -> void:
	for x in [420.0, 980.0, 1580.0, 2200.0]:
		spawn_enemy(Vector2(x, 580), REBEL_STATS, 0, Enemy.Behavior.MELEE, Vector2.ONE)
	for x in [720.0, 1880.0]:
		spawn_enemy(Vector2(x, 580), REBEL_STATS, 0, Enemy.Behavior.MELEE, Vector2.ONE)
	for x in [2920.0, 3540.0, 4160.0, 4780.0]:
		spawn_enemy(Vector2(x, 610), SNAKE_STATS, 1, Enemy.Behavior.MELEE, Vector2(0.86, 0.86))
	for x in [3260.0, 4460.0]:
		spawn_enemy(Vector2(x, 610), SNAKE_STATS, 1, Enemy.Behavior.MELEE, Vector2(0.86, 0.86))
	for x in [5480.0, 6120.0, 6760.0, 7380.0]:
		spawn_enemy(Vector2(x, 440), EAGLE_STATS, 3, Enemy.Behavior.FLYING, Vector2.ONE)
	for x in [5780.0, 7080.0]:
		spawn_enemy(Vector2(x, 420), EAGLE_STATS, 3, Enemy.Behavior.FLYING, Vector2.ONE)
	spawn_enemy(Vector2(7900, 580), REBEL_STATS, 0, Enemy.Behavior.MELEE, Vector2.ONE)
	spawn_enemy(Vector2(8340, 610), SNAKE_STATS, 1, Enemy.Behavior.MELEE, Vector2(0.86, 0.86))
	spawn_enemy(Vector2(8780, 440), EAGLE_STATS, 3, Enemy.Behavior.FLYING, Vector2.ONE)
	spawn_enemy(Vector2(9180, 560), BOAR_STATS, 2, Enemy.Behavior.CHARGE, Vector2(1.08, 1.08))
	spawn_enemy(Vector2(8120, 580), REBEL_STATS, 0, Enemy.Behavior.MELEE, Vector2.ONE)
	spawn_enemy(Vector2(8960, 440), EAGLE_STATS, 3, Enemy.Behavior.FLYING, Vector2.ONE)
	var axe_bull := spawn_enemy(Vector2(9650, 535), AXE_BULL_STATS, 4, Enemy.Behavior.BOSS, Vector2(1.25, 1.25))
	axe_bull.defeated.connect(func(_reward: int) -> void: spawn_pickup(Vector2(9650, 580), &"elixir"))
	spawn_enemy(Vector2(10480, 580), REBEL_STATS, 0, Enemy.Behavior.MELEE, Vector2.ONE)
	spawn_enemy(Vector2(10920, 610), SNAKE_STATS, 1, Enemy.Behavior.MELEE, Vector2(0.86, 0.86))
	spawn_enemy(Vector2(11350, 440), EAGLE_STATS, 3, Enemy.Behavior.FLYING, Vector2.ONE)
	spawn_enemy(Vector2(11780, 560), BOAR_STATS, 2, Enemy.Behavior.CHARGE, Vector2(1.08, 1.08))
	spawn_enemy(Vector2(10720, 580), REBEL_STATS, 0, Enemy.Behavior.MELEE, Vector2.ONE)
	spawn_enemy(Vector2(11560, 440), EAGLE_STATS, 3, Enemy.Behavior.FLYING, Vector2.ONE)


func spawn_final_boss() -> void:
	if final_boss_spawned:
		return
	var boss := spawn_enemy(Vector2(12350, 515), DEMON_KING_STATS, 5, Enemy.Behavior.BOSS, Vector2(1.4, 1.4))
	boss.can_reposition = true
	boss.set_meta(&"final_boss", true)
	boss.defeated.connect(complete_level)
	final_boss_spawned = true
	spawn_boss_reinforcement_wave(4)


func spawn_enemy(position_value: Vector2, stats_value: EnemyStats, atlas_row_value: int, behavior_value: Enemy.Behavior, scale_value: Vector2) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	var spawn_position := position_value
	var section := clampi(floori(position_value.x / SECTION_WIDTH), 0, 4)
	if section == 0:
		spawn_position.x = maxf(spawn_position.x, INITIAL_ENEMY_MIN_X)
	if behavior_value != Enemy.Behavior.FLYING:
		spawn_position.x = safe_ground_spawn_x(section, spawn_position.x)
	enemy.position = spawn_position
	enemy.stats = stats_value
	enemy.animation_atlas = ENEMY_ANIMATION_ATLAS
	enemy.atlas_row = atlas_row_value
	enemy.visual_scale = scale_value
	enemy.behavior = behavior_value
	enemy.target_player = player
	enemy.defeated.connect(add_spirit_stones)
	enemy.set_meta(&"section_index", section)
	if recording_initial_wave and behavior_value != Enemy.Behavior.BOSS:
		var specs: Array = section_wave_specs.get(section, [])
		specs.append({
			"position": spawn_position,
			"stats": stats_value,
			"atlas_row": atlas_row_value,
			"behavior": behavior_value,
			"scale": scale_value,
		})
		section_wave_specs[section] = specs
	enemy.defeated.connect(section_enemy_defeated.bind(section, enemy))
	enemy.hit_received.connect(show_enemy_status)
	add_child(enemy)
	enemy_tracker.track(enemy, section)
	return enemy


func safe_ground_spawn_x(section: int, desired_x: float) -> float:
	var section_left := section * SECTION_WIDTH
	var section_right := (section + 1) * SECTION_WIDTH
	var best_x := clampf(desired_x, section_left + 70.0, section_right - 70.0)
	var best_distance := INF
	for rect in campaign_ground_rects():
		if clampi(floori(rect.get_center().x / SECTION_WIDTH), 0, 4) != section:
			continue
		var candidate := clampf(desired_x, rect.position.x + 70.0, rect.end.x - 70.0)
		var distance := absf(candidate - desired_x)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and candidate > best_x):
			best_x = candidate
			best_distance = distance
	return best_x


func spawn_enemy_from_spec(spec: Dictionary) -> Enemy:
	return spawn_enemy(spec.position, spec.stats, spec.atlas_row, spec.behavior, spec.scale)


func activate_section_waves(section: int) -> void:
	pass


func update_section_waves(section: int) -> void:
	if not section_wave_specs.has(section):
		return
	if not final_boss_spawned or not section_has_alive_final_boss(section):
		return
	if count_regular_enemies(section) < 2 and int(section_boss_reinforcement_waves.get(section, 1)) < FINAL_BOSS_MAX_WAVES:
		spawn_boss_reinforcement_wave(section)

func spawn_boss_reinforcement_wave(section: int) -> void:
	var specs: Array = section_wave_specs.get(section, [])
	if specs.is_empty():
		return
	var start_index := int(section_boss_reinforcement_index.get(section, 0))
	for index in BOSS_REINFORCEMENT_COUNT:
		var spec: Dictionary = specs[(start_index + index) % specs.size()].duplicate()
		var side := -1.0 if index % 2 == 0 else 1.0
		spec.position.x = clampf(player.global_position.x + side * 520.0, section * SECTION_WIDTH + 120.0, (section + 1) * SECTION_WIDTH - 120.0)
		var enemy := spawn_enemy_from_spec(spec)
		enemy.add_to_group("boss_reinforcements")
	section_boss_reinforcement_index[section] = start_index + BOSS_REINFORCEMENT_COUNT
	section_boss_reinforcement_waves[section] = int(section_boss_reinforcement_waves.get(section, 1)) + 1


func count_regular_enemies(section: int) -> int:
	var count := 0
	for enemy in enemy_tracker.alive_enemies(section):
		if not (enemy.has_meta(&"final_boss") and bool(enemy.get_meta(&"final_boss"))):
			count += 1
	return count


func section_has_alive_final_boss(section: int) -> bool:
	for enemy in enemy_tracker.alive_enemies(section):
		if enemy.has_meta(&"final_boss") and bool(enemy.get_meta(&"final_boss")):
			return true
	return false


func enemy_section(enemy: Enemy) -> int:
	if enemy.has_meta(&"section_index"):
		return int(enemy.get_meta(&"section_index"))
	return clampi(floori(enemy.spawn_position.x / SECTION_WIDTH), 0, 4)


func show_enemy_status(enemy: Enemy, current: float, maximum: float) -> void:
	if hud != null:
		hud.show_enemy_status(enemy, current, maximum)


func add_spirit_stones(amount: int) -> void:
	spirit_stones += amount
	GameState.add_stones(amount)
	if hud != null:
		hud.update_stones(GameState.stones)


func spawn_items() -> void:
	spawn_pickup(Vector2(850, 475), &"peach")
	spawn_pickup(Vector2(1160, 590), &"fire_spear")
	spawn_pickup(Vector2(1770, 455), &"peach")
	spawn_pickup(Vector2(2240, 590), &"cosmic_ring")
	spawn_pickup(Vector2(4100, 590), &"peach")
	spawn_pickup(Vector2(4380, 455), &"fire_wheels")


func spawn_pickup(position_value: Vector2, item_id: StringName) -> ItemPickup:
	var pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
	pickup.position = position_value
	pickup.item = ItemCatalog.get_definition(item_id)
	add_child(pickup)
	return pickup


func spawn_secret_shop() -> void:
	shop = SHOP_SCENE.instantiate() as ShopPanel
	add_child(shop)
	var wall := BREAKABLE_WALL_SCENE.instantiate() as BreakableWall
	wall.position = Vector2(3040, 414)
	wall.broken.connect(func() -> void: shop.open_shop(player, "水帘洞隐藏商店"))
	add_child(wall)


func update_section(force: bool) -> void:
	var next_section := clampi(floori(player.global_position.x / SECTION_WIDTH), 0, 4)
	if not force and next_section == current_section:
		return
	current_section = next_section
	current_section_enemy_count = enemy_tracker.count(current_section)
	activate_section_waves(current_section)
	back_wall.position.x = current_section * SECTION_WIDTH - 24.0
	var camera := player.get_node("Camera") as Camera2D
	var next_limit_left := int(current_section * SECTION_WIDTH)
	if force:
		camera.limit_left = next_limit_left
	else:
		if camera_left_tween != null:
			camera_left_tween.kill()
		camera_left_tween = create_tween()
		camera_left_tween.tween_property(camera, "limit_left", next_limit_left, 0.9).set_trans(Tween.TRANS_LINEAR)
	player.set_checkpoint(Vector2(current_section * SECTION_WIDTH + 120.0, 580.0))
	var names := ["猿兵山道", "蛇窟藤径", "鹰妖断崖", "牛先锋洞门", "混世魔王洞府"]
	if hud != null:
		hud.set_section(names[current_section])


func create_section_barriers() -> void:
	back_wall = create_vertical_barrier(-24.0)
	end_wall = create_vertical_barrier(LEVEL_WIDTH + 24.0)
	for section in 4:
		section_gates[section] = create_vertical_barrier((section + 1) * SECTION_WIDTH)


func create_vertical_barrier(x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(x, 360)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 720)
	collision.shape = shape
	body.add_child(collision)
	if x > 0.0 and x < LEVEL_WIDTH:
		var seal := Polygon2D.new()
		seal.polygon = PackedVector2Array([Vector2(-10, -360), Vector2(10, -360), Vector2(10, 360), Vector2(-10, 360)])
		seal.color = Color(1.0, 0.75, 0.18, 0.55)
		seal.z_index = 8
		body.add_child(seal)
	add_child(body)
	return body


func section_enemy_defeated(_reward: int, section: int, enemy: Enemy) -> void:
	enemy_tracker.remove(enemy, section)
	if section == current_section:
		current_section_enemy_count = enemy_tracker.count(section)
	call_deferred("refresh_section_gate", section)


func refresh_section_gate(section: int) -> void:
	var alive_enemies: Array[Enemy] = enemy_tracker.alive_enemies(section)
	if not alive_enemies.is_empty():
		return_section_stragglers(alive_enemies, section)
		return
	if section == 4:
		spawn_final_boss()
		return
	if not section_gates.has(section):
		return
	pending_camera_section = section
	hud.show_go_prompt()
	var gate := section_gates[section] as StaticBody2D
	if is_instance_valid(gate):
		gate.queue_free()
	section_gates.erase(section)


func get_current_section_enemy_snapshot() -> Array[Dictionary]:
	return enemy_tracker.snapshot(current_section)


func return_section_stragglers(enemies: Array[Enemy], section: int) -> void:
	var section_end := (section + 1) * SECTION_WIDTH
	if player.global_position.x < section_end - SCREEN_WIDTH * 0.35:
		return
	for enemy in enemies:
		if absf(enemy.global_position.x - player.global_position.x) <= SCREEN_WIDTH * 0.5:
			return
	for index in enemies.size():
		var enemy := enemies[index]
		if enemy.has_meta(&"returned_to_gate"):
			continue
		var offset := -520.0 + index * minf(140.0, 900.0 / maxf(enemies.size() - 1, 1))
		enemy.global_position.x = clampf(player.global_position.x + offset, section * SECTION_WIDTH + 120.0, section_end - 120.0)
		enemy.velocity = Vector2.ZERO
		enemy.engaged = true
		enemy.set_meta(&"returned_to_gate", true)


func complete_level(_reward: int) -> void:
	completed = true
	player.play_victory()
	hud.play_victory_animation("第一关通过")
	AudioService.play_sfx(self, AudioService.VICTORY)
	await get_tree().create_timer(0.9).timeout
	hud.show_result(spirit_stones)
	shop.closed.connect(func() -> void:
		if get_tree().current_scene == self:
			GameState.advance_to_level(2, GameState.SECOND_LEVEL)
	, CONNECT_ONE_SHOT)
	shop.open_shop(player, "第一关过关商店")
