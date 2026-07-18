extends CampaignLevel

const ENEMY_TEMPLATE := preload("res://src/actors/enemies/enemy.tscn")
const ITEM_TEMPLATE := preload("res://src/world/item_pickup.tscn")
const TIMED_PLATFORM := preload("res://src/world/timed_platform.gd")
const GATE_SCRIPT := preload("res://src/world/heaven_gate.gd")
const GOLD_GUARD := preload("res://resources/stats/enemies/gold_guard.tres")
const ARCHER := preload("res://resources/stats/enemies/heaven_archer.tres")
const CLOUD := preload("res://resources/stats/enemies/cloud_immortal.tres")
const GUARDIAN := preload("res://resources/stats/enemies/gate_guardian.tres")
const GIANT := preload("res://resources/stats/enemies/giant_spirit.tres")
const PHANTOM := preload("res://resources/stats/enemies/growth_phantom.tres")
const ILLUSION := preload("res://resources/stats/enemies/heaven_illusion.tres")
const GUARD_FRAMES := preload("res://assets/generated/characters/campaign/gold_guard_frames.png")
const ARCHER_FRAMES := preload("res://assets/generated/characters/campaign/heaven_archer_frames.png")
const CLOUD_FRAMES := preload("res://assets/generated/characters/campaign/cloud_immortal_frames.png")
const GUARDIAN_FRAMES := preload("res://assets/generated/characters/campaign/gate_guardian_frames.png")
const GIANT_FRAMES := preload("res://assets/generated/characters/campaign/giant_spirit_frames.png")
const PHANTOM_FRAMES := preload("res://assets/generated/characters/campaign/growth_phantom_frames.png")
const KING_STATS := [
	preload("res://resources/stats/enemies/dhritarashtra.tres"), preload("res://resources/stats/enemies/virudhaka.tres"),
	preload("res://resources/stats/enemies/virupaksha.tres"), preload("res://resources/stats/enemies/vaishravana.tres"),
]
const KING_FRAMES := [
	preload("res://assets/generated/characters/campaign/dhritarashtra_frames.png"), preload("res://assets/generated/characters/campaign/virudhaka_frames.png"),
	preload("res://assets/generated/characters/campaign/virupaksha_frames.png"), preload("res://assets/generated/characters/campaign/vaishravana_frames.png"),
]
const LIGHTNING := preload("res://resources/stats/hazards/heaven_lightning.tres")
const WIND := preload("res://resources/stats/hazards/gale_wind.tres")
const LASER := preload("res://resources/stats/hazards/statue_laser.tres")

var gate
var phantom_clones_spawned := false
var current_king_index := -1
var reinforcement_timer: Timer
var reinforcement_index := 0


func _ready() -> void:
	super()


func on_section_loaded(section: int) -> void:
	if section not in [3, 4]:
		return
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if floori(enemy.global_position.x / SECTION_WIDTH) != section:
			continue
		if enemy.stats == PHANTOM:
			enemy.health_changed.connect(check_phantom_phase)


func create_world() -> void:
	for rect in ground_rects():
		create_surface(rect, rect.size.y)
	for index in platform_rects().size():
		var rect := platform_rects()[index]
		if index in [1, 3, 5]:
			var cloud = TIMED_PLATFORM.new()
			cloud.position = rect.position + rect.size * 0.5
			cloud.visual_size = rect.size
			cloud.collapse_delay = 2.0
			cloud.surface_color = Color("aebbc7")
			add_child(cloud)
		else:
			create_surface(rect, 72.0)


func ground_rects() -> Array[Rect2]:
	return campaign_ground_rects()


func platform_rects() -> Array[Rect2]:
	return campaign_platform_rects()


func enemy_specs() -> Array:
	return [
		spec(Vector2(420, 580), GOLD_GUARD, GUARD_FRAMES), spec(Vector2(980, 580), GOLD_GUARD, GUARD_FRAMES), spec(Vector2(1580, 580), GOLD_GUARD, GUARD_FRAMES), spec(Vector2(2200, 580), GOLD_GUARD, GUARD_FRAMES),
		spec(Vector2(2920, 450), ARCHER, ARCHER_FRAMES), spec(Vector2(3540, 400), ARCHER, ARCHER_FRAMES), spec(Vector2(4160, 470), ARCHER, ARCHER_FRAMES), spec(Vector2(4780, 390), ARCHER, ARCHER_FRAMES),
		spec(Vector2(5480, 430), CLOUD, CLOUD_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(6120, 380), CLOUD, CLOUD_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(6760, 450), CLOUD, CLOUD_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(7380, 400), CLOUD, CLOUD_FRAMES, Enemy.Behavior.FLYING),
		spec(Vector2(7900, 580), GOLD_GUARD, GUARD_FRAMES), spec(Vector2(8320, 440), ARCHER, ARCHER_FRAMES), spec(Vector2(8750, 430), CLOUD, CLOUD_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(9180, 580), GUARDIAN, GUARDIAN_FRAMES), spec(Vector2(9600, 510), GIANT, GIANT_FRAMES, Enemy.Behavior.BOSS, Vector2(1.7, 1.7)),
		spec(Vector2(10480, 580), GOLD_GUARD, GUARD_FRAMES), spec(Vector2(10920, 440), ARCHER, ARCHER_FRAMES), spec(Vector2(11350, 430), CLOUD, CLOUD_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(11780, 580), GUARDIAN, GUARDIAN_FRAMES), spec(Vector2(11820, 510), KING_STATS[0], KING_FRAMES[0], Enemy.Behavior.BOSS, Vector2(1.35, 1.35), true), spec(Vector2(12100, 510), KING_STATS[1], KING_FRAMES[1], Enemy.Behavior.BOSS, Vector2(1.35, 1.35), true), spec(Vector2(12380, 510), KING_STATS[2], KING_FRAMES[2], Enemy.Behavior.BOSS, Vector2(1.35, 1.35), true), spec(Vector2(12600, 510), KING_STATS[3], KING_FRAMES[3], Enemy.Behavior.BOSS, Vector2(1.35, 1.35), true),
	]


func item_specs() -> Array:
	return [
		{"position": Vector2(400, 455), "id": &"peach"}, {"position": Vector2(900, 475), "id": &"wine"},
		{"position": Vector2(1450, 505), "id": &"peach"}, {"position": Vector2(3450, 395), "id": &"elixir"},
		{"position": Vector2(4700, 395), "id": &"binding_rope"},
	]


func hazard_specs() -> Array:
	return [
		{"position": Vector2(800, 530), "stats": LIGHTNING, "kind": LineHazard.Kind.LIGHTNING, "size": Vector2(70, 250)},
		{"position": Vector2(2050, 500), "stats": LIGHTNING, "kind": LineHazard.Kind.LIGHTNING, "size": Vector2(70, 280)},
		{"position": Vector2(1700, 420), "stats": WIND, "kind": LineHazard.Kind.WIND, "size": Vector2(900, 260), "push_force": 380.0},
		{"position": Vector2(3000, 430), "stats": WIND, "kind": LineHazard.Kind.WIND, "size": Vector2(850, 260), "push_force": 420.0},
		{"position": Vector2(4100, 500), "stats": LASER, "kind": LineHazard.Kind.LASER, "size": Vector2(35, 250)},
		{"position": Vector2(4950, 500), "stats": LASER, "kind": LineHazard.Kind.LASER, "size": Vector2(35, 250)},
	]


func check_phantom_phase(current: float, maximum: float) -> void:
	if phantom_clones_spawned or current > maximum * 0.5:
		return
	phantom_clones_spawned = true
	for offset in [-130.0, 130.0]:
		spawn_enemy(Vector2(3380 + offset, 520), ILLUSION, PHANTOM_FRAMES, &"heaven_illusions")


func start_king_battle() -> void:
	reinforcement_timer.stop()
	spawn_king(0)


func spawn_gate_reinforcement() -> void:
	if gate.broken:
		return
	var use_archer := reinforcement_index % 2 == 1
	spawn_enemy(Vector2(3980 + reinforcement_index % 3 * 80, 580), ARCHER if use_archer else GOLD_GUARD, ARCHER_FRAMES if use_archer else GUARD_FRAMES, &"gate_reinforcements")
	reinforcement_index += 1


func spawn_king(index: int) -> void:
	current_king_index = index
	var king := spawn_enemy(Vector2(4610, 510), KING_STATS[index], KING_FRAMES[index], &"active_king")
	king.behavior = Enemy.Behavior.BOSS
	king.visual_scale = Vector2(1.5, 1.5)
	king.sprite.scale = king.visual_scale
	king.defeated.connect(king_defeated.bind(index), CONNECT_ONE_SHOT)


func king_defeated(_reward: int, index: int) -> void:
	drop_peach(Vector2(4550, 580))
	if index < KING_STATS.size() - 1:
		spawn_king(index + 1)
	else:
		complete_level(0)


func spawn_enemy(position_value: Vector2, stats_value: EnemyStats, atlas: Texture2D, group_name: StringName) -> Enemy:
	var enemy := ENEMY_TEMPLATE.instantiate() as Enemy
	enemy.position = position_value
	enemy.stats = stats_value
	enemy.animation_atlas = atlas
	enemy.target_player = player
	enemy.defeated.connect(add_stones)
	enemy.hit_received.connect(show_enemy_status)
	enemy.add_to_group(group_name)
	add_child(enemy)
	return enemy


func drop_peach(position_value: Vector2) -> void:
	var pickup := ITEM_TEMPLATE.instantiate() as ItemPickup
	pickup.position = position_value
	pickup.item = ItemCatalog.get_definition(&"peach")
	pickup.add_to_group("king_rewards")
	add_child(pickup)


func next_level_path() -> String:
	return GameState.SIXTH_LEVEL


func spec(position_value: Vector2, stats_value: EnemyStats, atlas_value: Texture2D, behavior_value: Enemy.Behavior = Enemy.Behavior.MELEE, scale_value: Vector2 = Vector2.ONE, final_value: bool = false) -> Dictionary:
	return {"position": position_value, "stats": stats_value, "atlas": atlas_value, "behavior": behavior_value, "scale": scale_value, "final_boss": final_value}
