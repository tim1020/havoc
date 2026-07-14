extends Node2D

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemies/enemy.tscn")
const HUD_SCENE := preload("res://src/ui/hud/hud.tscn")
const BACKGROUND := preload("res://assets/generated/environments/level_01/flower_fruit_mountain_background.png")
const GROUND_TEXTURE := preload("res://assets/generated/environments/level_01/mossy_stone_platform.png")
const THORN_TEXTURE := preload("res://assets/generated/environments/level_01/thorn_spikes.png")
const THORN_STATS := preload("res://resources/stats/hazards/thorn_spikes.tres")

const REBEL_MONKEY := preload("res://assets/generated/characters/enemies/level_01/rebel_monkey.png")
const SNAKE := preload("res://assets/generated/characters/enemies/level_01/snake.png")
const BOAR := preload("res://assets/generated/characters/enemies/level_01/boar_demon.png")
const EAGLE := preload("res://assets/generated/characters/enemies/level_01/eagle_demon.png")
const AXE_BULL := preload("res://assets/generated/characters/bosses/level_01/axe_bull.png")
const DEMON_KING := preload("res://assets/generated/characters/bosses/level_01/demon_king.png")

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
var spirit_stones: int = 0
var current_section: int = -1
var completed: bool = false


func _ready() -> void:
	create_backgrounds()
	create_world_collision()
	spawn_player()
	spawn_enemies()
	spawn_hud()
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
	for section in 4:
		var backdrop := Sprite2D.new()
		backdrop.texture = BACKGROUND
		backdrop.position = Vector2(SECTION_WIDTH * section + SECTION_WIDTH * 0.5, 360.0)
		backdrop.scale = Vector2(SECTION_WIDTH / BACKGROUND.get_width(), 720.0 / BACKGROUND.get_height())
		backdrop.z_index = -20
		add_child(backdrop)


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
	var sprite := Sprite2D.new()
	sprite.texture = GROUND_TEXTURE
	sprite.position = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + visual_height * 0.5)
	sprite.scale = Vector2(rect.size.x / GROUND_TEXTURE.get_width(), visual_height / GROUND_TEXTURE.get_height())
	sprite.z_index = -2
	add_child(sprite)


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
	hud.update_stones(spirit_stones)


func spawn_enemies() -> void:
	spawn_enemy(Vector2(620, 580), REBEL_STATS, REBEL_MONKEY, Enemy.Behavior.MELEE, Vector2(0.105, 0.105))
	spawn_enemy(Vector2(920, 610), SNAKE_STATS, SNAKE, Enemy.Behavior.MELEE, Vector2(0.075, 0.075))
	spawn_enemy(Vector2(1480, 570), REBEL_STATS, REBEL_MONKEY, Enemy.Behavior.MELEE, Vector2(0.105, 0.105))
	spawn_enemy(Vector2(1950, 550), EAGLE_STATS, EAGLE, Enemy.Behavior.FLYING, Vector2(0.09, 0.09))
	spawn_enemy(Vector2(2700, 560), BOAR_STATS, BOAR, Enemy.Behavior.CHARGE, Vector2(0.105, 0.105))
	spawn_enemy(Vector2(3250, 550), EAGLE_STATS, EAGLE, Enemy.Behavior.FLYING, Vector2(0.09, 0.09))
	spawn_enemy(Vector2(3650, 535), AXE_BULL_STATS, AXE_BULL, Enemy.Behavior.BOSS, Vector2(0.13, 0.13))
	var boss := spawn_enemy(Vector2(4650, 515), DEMON_KING_STATS, DEMON_KING, Enemy.Behavior.BOSS, Vector2(0.145, 0.145))
	boss.defeated.connect(complete_level)


func spawn_enemy(position_value: Vector2, stats_value: EnemyStats, texture_value: Texture2D, behavior_value: Enemy.Behavior, scale_value: Vector2) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = position_value
	enemy.stats = stats_value
	enemy.visual_texture = texture_value
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
	if hud != null:
		hud.update_stones(spirit_stones)


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
