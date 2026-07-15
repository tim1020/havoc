extends Node2D

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemies/enemy.tscn")
const HUD_SCENE := preload("res://src/ui/hud/hud.tscn")
const ITEM_PICKUP_SCENE := preload("res://src/world/item_pickup.tscn")
const SHOP_SCENE := preload("res://src/ui/shop/shop_panel.tscn")
const BREAKABLE_WALL_SCENE := preload("res://src/world/breakable_wall.tscn")
const THORN_TEXTURE := preload("res://assets/generated/environments/level_01/thorn_spikes.png")
const THORN_STATS := preload("res://resources/stats/hazards/thorn_spikes.tres")

const ENEMY_ANIMATION_ATLAS := preload("res://assets/vector/characters/level_01_enemy_frames.svg")

const REBEL_STATS := preload("res://resources/stats/enemies/rebel_monkey.tres")
const SNAKE_STATS := preload("res://resources/stats/enemies/snake.tres")
const BOAR_STATS := preload("res://resources/stats/enemies/boar_demon.tres")
const EAGLE_STATS := preload("res://resources/stats/enemies/eagle_demon.tres")
const AXE_BULL_STATS := preload("res://resources/stats/enemies/axe_bull.tres")
const DEMON_KING_STATS := preload("res://resources/stats/enemies/demon_king.tres")

const SECTION_WIDTH := 1280.0
const LEVEL_WIDTH := SECTION_WIDTH * 4.0

var player: Player
var hud: GameHud
var shop: ShopPanel
var spirit_stones: int = 0
var current_section: int = -1
var completed: bool = false


func _ready() -> void:
	create_backgrounds()
	create_world_collision()
	spawn_player()
	spawn_enemies()
	spawn_items()
	spawn_hud()
	spawn_secret_shop()
	update_section(true)


func _process(_delta: float) -> void:
	if player == null or completed:
		return
	if player.global_position.y > 820.0:
		player.take_damage(20.0, player.global_position + Vector2(0.0, -100.0))
		player.global_position = player.respawn_position
		player.velocity = Vector2.ZERO
	update_section(false)


func create_backgrounds() -> void:
	add_child(Level01Backdrop.new())


func create_world_collision() -> void:
	var ground_segments := [
		Rect2(0, 650, 1180, 120),
		Rect2(1280, 650, 1040, 120),
		Rect2(2440, 650, 1120, 120),
		Rect2(3680, 650, 1440, 120),
	]
	for rect in ground_segments:
		create_static_rect(rect)
		create_ground_visual(rect, rect.size.y)
	var platforms := [
		Rect2(740, 520, 220, 24),
		Rect2(1640, 500, 260, 24),
		Rect2(2860, 470, 260, 24),
		Rect2(4220, 500, 320, 24),
	]
	for rect in platforms:
		create_static_rect(rect)
		create_ground_visual(rect, 92.0)
	create_thorn_hazard(Vector2(1080, 620), Vector2(120, 60))
	create_thorn_hazard(Vector2(2180, 620), Vector2(130, 60))
	create_thorn_hazard(Vector2(3380, 620), Vector2(140, 60))


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
	var section := clampi(floori(rect.position.x / SECTION_WIDTH), 0, 3)
	var colors := [Color("657350"), Color("526f4f"), Color("52656a"), Color("39464d")]
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
	camera.limit_left = 0
	camera.limit_right = int(LEVEL_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = 720


func spawn_hud() -> void:
	hud = HUD_SCENE.instantiate() as GameHud
	add_child(hud)
	hud.bind_player(player)
	hud.update_stones(GameState.stones)


func spawn_enemies() -> void:
	spawn_enemy(Vector2(620, 580), REBEL_STATS, 0, Enemy.Behavior.MELEE, Vector2.ONE)
	spawn_enemy(Vector2(920, 610), SNAKE_STATS, 1, Enemy.Behavior.MELEE, Vector2(0.86, 0.86))
	spawn_enemy(Vector2(1480, 570), REBEL_STATS, 0, Enemy.Behavior.MELEE, Vector2.ONE)
	spawn_enemy(Vector2(1950, 550), EAGLE_STATS, 3, Enemy.Behavior.FLYING, Vector2.ONE)
	spawn_enemy(Vector2(2700, 560), BOAR_STATS, 2, Enemy.Behavior.CHARGE, Vector2(1.08, 1.08))
	spawn_enemy(Vector2(3250, 550), EAGLE_STATS, 3, Enemy.Behavior.FLYING, Vector2.ONE)
	var axe_bull := spawn_enemy(Vector2(3650, 535), AXE_BULL_STATS, 4, Enemy.Behavior.BOSS, Vector2(1.25, 1.25))
	axe_bull.defeated.connect(func(_reward: int) -> void: spawn_pickup(Vector2(3650, 580), &"elixir"))
	var boss := spawn_enemy(Vector2(4650, 515), DEMON_KING_STATS, 5, Enemy.Behavior.BOSS, Vector2(1.4, 1.4))
	boss.defeated.connect(complete_level)


func spawn_enemy(position_value: Vector2, stats_value: EnemyStats, atlas_row_value: int, behavior_value: Enemy.Behavior, scale_value: Vector2) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = position_value
	enemy.stats = stats_value
	enemy.animation_atlas = ENEMY_ANIMATION_ATLAS
	enemy.atlas_row = atlas_row_value
	enemy.visual_scale = scale_value
	enemy.behavior = behavior_value
	enemy.defeated.connect(add_spirit_stones)
	enemy.hit_received.connect(show_enemy_status)
	add_child(enemy)
	return enemy


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
	var next_section := clampi(floori(player.global_position.x / SECTION_WIDTH), 0, 3)
	if not force and next_section == current_section:
		return
	current_section = next_section
	player.set_checkpoint(Vector2(current_section * SECTION_WIDTH + 120.0, 580.0))
	var names := ["花果山脚", "藤蔓区", "水帘洞入口", "水帘洞内部"]
	if hud != null:
		hud.set_section(names[current_section])


func complete_level(_reward: int) -> void:
	completed = true
	player.controls_enabled = false
	hud.show_result(spirit_stones)
	shop.open_shop(player, "第一关过关商店")
