class_name CampaignLevel
extends Node2D

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemies/enemy.tscn")
const HUD_SCENE := preload("res://src/ui/hud/hud.tscn")
const ITEM_PICKUP_SCENE := preload("res://src/world/item_pickup.tscn")
const SHOP_SCENE := preload("res://src/ui/shop/shop_panel.tscn")
const LINE_HAZARD_SCENE := preload("res://src/world/line_hazard.tscn")
const AUDIO_DIRECTOR := preload("res://src/audio/audio_director.gd")
const SCREEN_WIDTH := 1280.0
const SECTION_WIDTH := SCREEN_WIDTH * 2.0
const SECTION_COUNT := 5
const LEVEL_WIDTH := SECTION_WIDTH * SECTION_COUNT

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


func _ready() -> void:
	GameState.begin_level(level_number, get_tree().current_scene.scene_file_path)
	if level_number >= 3 and not GameState.has_staff:
		GameState.unlock_staff()
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


func _process(_delta: float) -> void:
	if player == null or completed:
		return
	if player.global_position.y > 820.0:
		player.take_damage(20.0, player.global_position + Vector2.UP * 100.0)
		player.global_position = player.respawn_position
		player.velocity = Vector2.ZERO
	if pending_camera_section >= 0 and Input.get_axis("move_left", "move_right") > 0.0:
		unlock_next_section_camera()
	update_section(false)
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
		spawn_enemy_spec(spec, section)
	if section_filter >= 0:
		spawn_section_reinforcements(section_specs, section_filter)


func spawn_enemy_spec(spec: Dictionary, section: int) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = spec.position
	enemy.stats = spec.stats
	enemy.animation_atlas = spec.atlas
	enemy.atlas_row = 0
	enemy.behavior = spec.behavior
	enemy.visual_scale = spec.scale
	enemy.target_player = player
	enemy.defeated.connect(add_stones)
	enemy.defeated.connect(section_enemy_defeated.bind(section))
	enemy.hit_received.connect(show_enemy_status)
	add_child(enemy)
	if spec.final_boss:
		enemy.defeated.connect(complete_level)


func spawn_section_reinforcements(section_specs: Array, section: int) -> void:
	var candidates := section_specs.filter(func(spec: Dictionary) -> bool: return not spec.final_boss and spec.behavior != Enemy.Behavior.BOSS)
	if candidates.is_empty():
		return
	for index in 2:
		var source: Dictionary = candidates[index % candidates.size()]
		var reinforcement := source.duplicate()
		var offset := -120.0 if index == 0 else 120.0
		reinforcement.position = Vector2(clampf(source.position.x + offset, section * SECTION_WIDTH + 120.0, (section + 1) * SECTION_WIDTH - 120.0), source.position.y)
		spawn_enemy_spec(reinforcement, section)


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


func section_enemy_defeated(_reward: int, section: int) -> void:
	call_deferred("refresh_section_gate", section)


func refresh_section_gate(section: int) -> void:
	if not section_gates.has(section):
		return
	var final_screen_start := (section + 1) * SECTION_WIDTH - SCREEN_WIDTH * 0.5
	if player.global_position.x < final_screen_start:
		return
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.engaged and not enemy.dead and clampi(floori(enemy.spawn_position.x / SECTION_WIDTH), 0, SECTION_COUNT - 1) == section:
			return
	if section < SECTION_COUNT - 1:
		load_section_content(section + 1)
		pending_camera_section = section
		hud.show_go_prompt()
	var gate := section_gates[section] as StaticBody2D
	if is_instance_valid(gate):
		gate.queue_free()
	section_gates.erase(section)


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
