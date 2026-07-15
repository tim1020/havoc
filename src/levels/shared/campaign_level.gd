class_name CampaignLevel
extends Node2D

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemies/enemy.tscn")
const HUD_SCENE := preload("res://src/ui/hud/hud.tscn")
const ITEM_PICKUP_SCENE := preload("res://src/world/item_pickup.tscn")
const SHOP_SCENE := preload("res://src/ui/shop/shop_panel.tscn")
const LINE_HAZARD_SCENE := preload("res://src/world/line_hazard.tscn")
const SECTION_WIDTH := 1280.0
const LEVEL_WIDTH := SECTION_WIDTH * 4.0

@export_range(2, 6, 1) var level_number: int = 2
@export var section_names: PackedStringArray

var player: Player
var hud: GameHud
var shop: ShopPanel
var earned_stones: int = 0
var current_section: int = -1
var completed: bool = false


func _ready() -> void:
	add_child(CampaignBackdrop.new(level_number))
	create_world()
	spawn_player()
	spawn_enemies()
	spawn_items()
	spawn_hazards()
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
	update_section(false)


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
	var section := clampi(floori(x / SECTION_WIDTH), 0, 3)
	var sea := [Color("8c8065"), Color("4d93a5"), Color("4d8292"), Color("8f743d")]
	var hell := [Color("5f5865"), Color("4d4656"), Color("554958"), Color("332f3a")]
	return sea[section] if level_number == 2 else hell[section]


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


func spawn_enemies() -> void:
	for spec in enemy_specs():
		var enemy := ENEMY_SCENE.instantiate() as Enemy
		enemy.position = spec.position
		enemy.stats = spec.stats
		enemy.animation_atlas = spec.atlas
		enemy.atlas_row = 0
		enemy.behavior = spec.behavior
		enemy.visual_scale = spec.scale
		enemy.defeated.connect(add_stones)
		enemy.hit_received.connect(show_enemy_status)
		add_child(enemy)
		if spec.final_boss:
			enemy.defeated.connect(complete_level)


func spawn_items() -> void:
	for spec in item_specs():
		var pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
		pickup.position = spec.position
		pickup.item = ItemCatalog.get_definition(spec.id)
		add_child(pickup)


func spawn_hazards() -> void:
	for spec in hazard_specs():
		var hazard := LINE_HAZARD_SCENE.instantiate() as LineHazard
		hazard.position = spec.position
		hazard.stats = spec.stats
		hazard.kind = spec.kind
		hazard.visual_size = spec.size
		hazard.slow_seconds = spec.get("slow_seconds", 0.0)
		var shape := hazard.get_node("Shape").shape as RectangleShape2D
		shape = shape.duplicate() as RectangleShape2D
		shape.size = spec.size
		hazard.get_node("Shape").shape = shape
		add_child(hazard)


func show_enemy_status(enemy: Enemy, current: float, maximum: float) -> void:
	hud.show_enemy_status(enemy, current, maximum)


func add_stones(amount: int) -> void:
	earned_stones += amount
	GameState.add_stones(amount)


func update_section(force: bool) -> void:
	var next_section := clampi(floori(player.global_position.x / SECTION_WIDTH), 0, 3)
	if not force and next_section == current_section:
		return
	current_section = next_section
	player.set_checkpoint(Vector2(current_section * SECTION_WIDTH + 120.0, 580.0))
	hud.set_section(section_names[current_section]) if hud != null else null


func complete_level(_reward: int) -> void:
	completed = true
	player.controls_enabled = false
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
	return []


func platform_rects() -> Array[Rect2]:
	return []


func enemy_specs() -> Array:
	return []


func item_specs() -> Array:
	return []


func hazard_specs() -> Array:
	return []
