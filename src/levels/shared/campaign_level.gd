class_name CampaignLevel
extends Node2D

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemies/enemy.tscn")
const HUD_SCENE := preload("res://src/ui/hud/hud.tscn")
const ITEM_PICKUP_SCENE := preload("res://src/world/item_pickup.tscn")
const SHOP_SCENE := preload("res://src/ui/shop/shop_panel.tscn")
const LINE_HAZARD_SCENE := preload("res://src/world/line_hazard.tscn")
const AUDIO_DIRECTOR := preload("res://src/audio/audio_director.gd")
const SECTION_ENEMY_TRACKER := preload("res://src/levels/shared/section_enemy_tracker.gd")
const SCREEN_WIDTH := 1280.0
const SECTION_WIDTH := SCREEN_WIDTH * 2.0
const SECTION_COUNT := 5
const LEVEL_WIDTH := SECTION_WIDTH * SECTION_COUNT
const BOSS_REINFORCEMENT_COUNT := 2
const FINAL_BOSS_MAX_WAVES := 5
const INITIAL_ENEMY_MIN_X := 760.0
const LEVEL_TITLES := {
	2: "第二关 东海龙宫",
	3: "第三关 地府",
	4: "第四关 蟠桃园",
	5: "第五关 南天门",
	6: "第六关 凌霄宝殿",
}
const LEVEL_STORIES := {
	2: "悟空从混世魔王口中得知\n龙宫里有很多奇珍异宝\n于是前往东海龙宫索要宝物\n龙王不允\n悟空一怒之下\n將龙宫搅了个天翻地覆",
	3: "悟空强抢定海神针铁\n龙王上天告状\n天庭派阎王索命\n悟空大闹地府\n撕毁生死簿",
	4: "悟空得知是天庭要灭自己\n决定上天讨个说法\n误入蟠桃园\n被当成偷桃猴\n一怒之下\n在蟠桃园大肆破坏",
	5: "破坏蟠桃园后\n悟空还不解气\n一路打砸\n直奔南天门",
	6: "打败四大天王后\n悟空硬闯凌霄宝殿\n要向玉帝问个究竟",
}

@export_range(2, 6, 1) var level_number: int = 2
@export var section_names: PackedStringArray

var player: Player
var hud: GameHud
var shop: ShopPanel
var earned_stones: int = 0
var current_section: int = -1
var completed: bool = false
var section_gates: Dictionary = {}
var back_wall: StaticBody2D
var end_wall: StaticBody2D
var loaded_sections: Dictionary = {}
var pending_camera_section: int = -1
var camera_left_tween: Tween
var camera_right_tween: Tween
var enemy_tracker = SECTION_ENEMY_TRACKER.new()
var current_section_enemy_count: int = 0
var section_wave_specs: Dictionary = {}
var section_boss_reinforcement_index: Dictionary = {}
var section_boss_reinforcement_waves: Dictionary = {}
var section_final_boss_specs: Dictionary = {}
var section_final_boss_spawned: Dictionary = {}


func _ready() -> void:
	GameState.begin_level(level_number, get_tree().current_scene.scene_file_path)
	if level_number >= 3 and not GameState.has_staff:
		GameState.unlock_staff()
	if should_play_background_music():
		var audio = AUDIO_DIRECTOR.new()
		audio.track_number = level_number
		add_child(audio)
	add_child(CampaignBackdrop.new(level_number))
	create_world()
	spawn_player()
	create_section_barriers()
	load_section_content(0)
	spawn_hud()
	shop = SHOP_SCENE.instantiate() as ShopPanel
	add_child(shop)
	update_section(true)
	await play_level_intro()


func play_level_intro() -> void:
	var title: String = LEVEL_TITLES.get(level_number, "")
	var story: String = LEVEL_STORIES.get(level_number, "")
	if title.is_empty() or story.is_empty():
		return
	player.controls_enabled = false
	get_tree().paused = true
	await hud.play_level_intro(title, story)
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
	if current_section < SECTION_COUNT - 1 and section_gates.has(current_section):
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


func create_world() -> void:
	for rect in ground_rects():
		create_surface(rect, rect.size.y)
	for rect in platform_rects():
		create_surface(rect, 72.0)


func create_surface(rect: Rect2, visual_height: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	var surface := Polygon2D.new()
	surface.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + visual_height), Vector2(rect.position.x, rect.position.y + visual_height)])
	surface.color = surface_color(rect.position.x)
	surface.z_index = -2
	add_child(surface)
	var line := Line2D.new()
	line.points = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)])
	line.width = 5.0
	line.default_color = Color("f2ce4e")
	line.z_index = 4
	line.add_to_group("standable_surfaces")
	add_child(line)


func surface_color(x: float) -> Color:
	var section := clampi(floori(x / SECTION_WIDTH), 0, SECTION_COUNT - 1)
	var sea := [Color("8c8065"), Color("4d93a5"), Color("4d8292"), Color("6e806d"), Color("8f743d")]
	var hell := [Color("5f5865"), Color("4d4656"), Color("554958"), Color("453b4d"), Color("332f3a")]
	var garden := [Color("719357"), Color("7b5d45"), Color("c2b5ca"), Color("907d59"), Color("765b3e")]
	var heaven := [Color("d8e9ee"), Color("c7d6e5"), Color("b9c9dd"), Color("d3d9e2"), Color("e4dfd2")]
	var palace := [Color("b29451"), Color("9d6948"), Color("76526a"), Color("994d48"), Color("8d3438")]
	return sea[section] if level_number == 2 else (hell[section] if level_number == 3 else (garden[section] if level_number == 4 else (heaven[section] if level_number == 5 else palace[section])))


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


func spawn_enemies(section_filter: int = -1) -> void:
	var section_specs: Array = []
	for spec in enemy_specs():
		var section := clampi(floori(spec.position.x / SECTION_WIDTH), 0, SECTION_COUNT - 1)
		if section_filter >= 0 and section != section_filter:
			continue
		section_specs.append(spec)
		if section == SECTION_COUNT - 1 and bool(spec.final_boss):
			var final_specs: Array = section_final_boss_specs.get(section, [])
			final_specs.append(spec.duplicate())
			section_final_boss_specs[section] = final_specs
		else:
			spawn_enemy_spec(spec, section)
	if section_filter >= 0:
		var normal_specs: Array = []
		for spec in section_specs:
			if spec.behavior != Enemy.Behavior.BOSS and not bool(spec.final_boss):
				normal_specs.append(spec.duplicate())
		if not normal_specs.is_empty():
			for index in 2:
				var reinforcement: Dictionary = normal_specs[index % normal_specs.size()].duplicate()
				var offset := -120.0 if index == 0 else 120.0
				reinforcement.position.x = clampf(reinforcement.position.x + offset, section_filter * SECTION_WIDTH + 120.0, (section_filter + 1) * SECTION_WIDTH - 120.0)
				normal_specs.append(reinforcement)
				spawn_enemy_spec(reinforcement, section_filter)
		section_wave_specs[section_filter] = normal_specs
		section_boss_reinforcement_index[section_filter] = 0
		if section_filter == SECTION_COUNT - 1 and section_final_boss_specs.has(section_filter):
			section_boss_reinforcement_waves[section_filter] = 1
		for index in normal_specs.size():
			var duplicate_spec: Dictionary = normal_specs[index].duplicate()
			var offset := -90.0 if index % 2 == 0 else 90.0
			duplicate_spec.position.x = clampf(duplicate_spec.position.x + offset, section_filter * SECTION_WIDTH + 120.0, (section_filter + 1) * SECTION_WIDTH - 120.0)
			spawn_enemy_spec(duplicate_spec, section_filter)


func spawn_enemy_spec(spec: Dictionary, section: int) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	var spawn_position: Vector2 = spec.position
	if section == 0:
		spawn_position.x = maxf(spawn_position.x, INITIAL_ENEMY_MIN_X)
	if spec.behavior != Enemy.Behavior.FLYING:
		spawn_position.x = safe_ground_spawn_x(section, spawn_position.x)
	enemy.position = spawn_position
	enemy.stats = spec.stats
	enemy.animation_atlas = spec.atlas
	enemy.atlas_row = 0
	enemy.behavior = spec.behavior
	enemy.visual_scale = spec.scale
	enemy.can_reposition = bool(spec.final_boss)
	enemy.set_meta(&"final_boss", bool(spec.final_boss))
	enemy.target_player = player
	enemy.set_meta(&"section_index", section)
	enemy.set_meta(&"level_number", level_number)
	enemy.defeated.connect(add_stones)
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
	for rect in ground_rects():
		if clampi(floori(rect.get_center().x / SECTION_WIDTH), 0, SECTION_COUNT - 1) != section:
			continue
		var candidate := clampf(desired_x, rect.position.x + 70.0, rect.end.x - 70.0)
		var distance := absf(candidate - desired_x)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and candidate > best_x):
			best_x = candidate
			best_distance = distance
	return best_x


func activate_section_waves(section: int) -> void:
	pass


func update_section_waves(section: int) -> void:
	if not section_wave_specs.has(section):
		return
	if not section_final_boss_spawned.get(section, false) or not section_has_alive_final_boss(section):
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
		var enemy := spawn_enemy_spec(spec, section)
		enemy.add_to_group("boss_reinforcements")
	section_boss_reinforcement_index[section] = start_index + BOSS_REINFORCEMENT_COUNT
	section_boss_reinforcement_waves[section] = int(section_boss_reinforcement_waves.get(section, 1)) + 1


func spawn_final_boss(section: int) -> void:
	if section_final_boss_spawned.get(section, false) or not section_final_boss_specs.has(section):
		return
	for spec: Dictionary in section_final_boss_specs[section]:
		spawn_enemy_spec(spec, section)
	section_final_boss_spawned[section] = true
	spawn_boss_reinforcement_wave(section)


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
	return clampi(floori(enemy.spawn_position.x / SECTION_WIDTH), 0, SECTION_COUNT - 1)


func spawn_items(section_filter: int = -1) -> void:
	for spec in item_specs():
		if section_filter >= 0 and clampi(floori(spec.position.x / SECTION_WIDTH), 0, SECTION_COUNT - 1) != section_filter:
			continue
		var pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
		pickup.position = spec.position
		pickup.item = ItemCatalog.get_definition(spec.id)
		add_child(pickup)


func spawn_hazards(section_filter: int = -1) -> void:
	for spec in hazard_specs():
		if section_filter >= 0 and clampi(floori(spec.position.x / SECTION_WIDTH), 0, SECTION_COUNT - 1) != section_filter:
			continue
		var hazard := LINE_HAZARD_SCENE.instantiate() as LineHazard
		hazard.position = spec.position
		hazard.stats = spec.stats
		hazard.kind = spec.kind
		hazard.visual_size = spec.size
		hazard.slow_seconds = spec.get("slow_seconds", 0.0)
		hazard.confusion_seconds = spec.get("confusion_seconds", 0.0)
		hazard.push_force = spec.get("push_force", 0.0)
		var shape := hazard.get_node("Shape").shape as RectangleShape2D
		shape = shape.duplicate() as RectangleShape2D
		shape.size = spec.size
		hazard.get_node("Shape").shape = shape
		add_child(hazard)


func load_section_content(section: int) -> void:
	if loaded_sections.has(section):
		return
	loaded_sections[section] = true
	spawn_enemies(section)
	spawn_items(section)
	spawn_hazards(section)
	on_section_loaded(section)


func on_section_loaded(_section: int) -> void:
	pass


func show_enemy_status(enemy: Enemy, current: float, maximum: float) -> void:
	hud.show_enemy_status(enemy, current, maximum)


func add_stones(amount: int) -> void:
	earned_stones += amount
	GameState.add_stones(amount)


func update_section(force: bool) -> void:
	var next_section := clampi(floori(player.global_position.x / SECTION_WIDTH), 0, SECTION_COUNT - 1)
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
	hud.set_section(section_names[current_section]) if hud != null else null


func create_section_barriers() -> void:
	back_wall = create_vertical_barrier(-24.0)
	end_wall = create_vertical_barrier(LEVEL_WIDTH + 24.0)
	for section in SECTION_COUNT - 1:
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
	if enemy.has_meta(&"final_boss") and bool(enemy.get_meta(&"final_boss")) and section_final_boss_spawned.get(section, false) and not section_has_alive_final_boss(section):
		complete_final_encounter()
		return
	if section == current_section:
		current_section_enemy_count = enemy_tracker.count(section)
	call_deferred("refresh_section_gate", section)


func refresh_section_gate(section: int) -> void:
	var alive_enemies: Array[Enemy] = enemy_tracker.alive_enemies(section)
	if not alive_enemies.is_empty():
		return_section_stragglers(alive_enemies, section)
		return
	if section == SECTION_COUNT - 1:
		spawn_final_boss(section)
		return
	if not section_gates.has(section):
		return
	if section < SECTION_COUNT - 1:
		load_section_content(section + 1)
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
	hud.play_victory_animation("第%d关通过" % level_number)
	AudioService.play_sfx(self, AudioService.VICTORY)
	await get_tree().create_timer(0.9).timeout
	on_level_victory()
	hud.show_result(earned_stones, "第%d关" % level_number)
	shop.closed.connect(advance_after_shop, CONNECT_ONE_SHOT)
	shop.open_shop(player, "第%d关过关商店" % level_number)


func complete_final_encounter() -> void:
	complete_level(0)


func advance_after_shop() -> void:
	if get_tree().current_scene != self:
		return
	var path := next_level_path()
	if path.is_empty():
		GameState.return_to_menu()
	else:
		GameState.advance_to_level(level_number + 1, path)


func on_level_victory() -> void:
	pass


func next_level_path() -> String:
	return ""


func should_play_background_music() -> bool:
	return true


func ground_rects() -> Array[Rect2]:
	return campaign_ground_rects()


func platform_rects() -> Array[Rect2]:
	return campaign_platform_rects()


func campaign_ground_rects() -> Array[Rect2]:
	var layouts := [
		[[0, 920], [1040, 760], [1920, 640]],
		[[0, 560], [700, 920], [1740, 820]],
		[[0, 780], [940, 480], [1560, 1000]],
		[[0, 1100], [1240, 520], [1880, 680]],
		[[0, 680], [800, 520], [1440, 1120]],
	]
	var rects: Array[Rect2] = []
	for section in SECTION_COUNT:
		for segment in layouts[section]:
			rects.append(Rect2(section * SECTION_WIDTH + segment[0], 650, segment[1], 120))
	return rects


func campaign_platform_rects() -> Array[Rect2]:
	var layouts := [
		[[320, 520, 260], [760, 450, 220], [1280, 530, 320], [1840, 420, 260]],
		[[180, 470, 260], [620, 380, 300], [1160, 510, 220], [1640, 430, 300], [2140, 350, 240]],
		[[260, 540, 300], [740, 440, 220], [1120, 340, 260], [1600, 470, 320], [2110, 390, 260]],
		[[240, 500, 320], [760, 400, 240], [1220, 520, 340], [1760, 410, 260], [2200, 500, 220]],
		[[180, 510, 280], [620, 420, 260], [1080, 330, 300], [1600, 450, 300], [2100, 520, 300]],
	]
	var rects: Array[Rect2] = []
	for section in SECTION_COUNT:
		for platform in layouts[section]:
			rects.append(Rect2(section * SECTION_WIDTH + platform[0], platform[1], platform[2], 24))
	return rects


func enemy_specs() -> Array:
	return []


func item_specs() -> Array:
	return []


func hazard_specs() -> Array:
	return []
