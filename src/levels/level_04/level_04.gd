extends CampaignLevel

const ENEMY_TEMPLATE := preload("res://src/actors/enemies/enemy.tscn")
const HAZARD_TEMPLATE := preload("res://src/world/line_hazard.tscn")
const TIMED_PLATFORM := preload("res://src/world/timed_platform.gd")
const GUARDIAN := preload("res://resources/stats/enemies/garden_guardian.tres")
const FLOWER_FAIRY := preload("res://resources/stats/enemies/flower_fairy.tres")
const PEACH_DEMON := preload("res://resources/stats/enemies/peach_demon.tres")
const PEACH_CHILD := preload("res://resources/stats/enemies/peach_child.tres")
const FAIRY_LEADER := preload("res://resources/stats/enemies/fairy_leader.tres")
const FAIRY_ILLUSION := preload("res://resources/stats/enemies/fairy_illusion.tres")
const LAND_GOD := preload("res://resources/stats/enemies/peach_land_god.tres")
const GUARDIAN_FRAMES := preload("res://assets/vector/characters/campaign/garden_guardian_frames.svg")
const FLOWER_FAIRY_FRAMES := preload("res://assets/vector/characters/campaign/flower_fairy_frames.svg")
const PEACH_DEMON_FRAMES := preload("res://assets/vector/characters/campaign/peach_demon_frames.svg")
const PEACH_CHILD_FRAMES := preload("res://assets/vector/characters/campaign/peach_child_frames.svg")
const FAIRY_LEADER_FRAMES := preload("res://assets/vector/characters/campaign/fairy_leader_frames.svg")
const LAND_GOD_FRAMES := preload("res://assets/vector/characters/campaign/peach_land_god_frames.svg")
const TRIP_ROOT := preload("res://resources/stats/hazards/trip_root.tres")
const PEACH_BOMB := preload("res://resources/stats/hazards/peach_bomb.tres")
const POOL_WATER := preload("res://resources/stats/hazards/jade_pool_water.tres")
const POLLEN := preload("res://resources/stats/hazards/pollen_mist.tres")

var fairy_clones_spawned := false
var land_phase_spawned := false


func _ready() -> void:
	super()
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.stats == FAIRY_LEADER:
			enemy.health_changed.connect(check_fairy_phase)
		elif enemy.stats == LAND_GOD:
			enemy.health_changed.connect(check_land_phase)


func create_world() -> void:
	for rect in ground_rects():
		create_surface(rect, rect.size.y)
	var platforms := platform_rects()
	for index in platforms.size():
		var rect := platforms[index]
		if index >= 2 and index <= 5:
			create_timed_surface(rect, 2.0 if index == 3 else 3.0)
		else:
			create_surface(rect, 72.0)


func create_timed_surface(rect: Rect2, delay: float) -> void:
	var platform = TIMED_PLATFORM.new()
	platform.position = rect.position + rect.size * 0.5
	platform.visual_size = rect.size
	platform.collapse_delay = delay
	platform.surface_color = surface_color(rect.position.x)
	add_child(platform)


func next_level_path() -> String:
	return GameState.FIFTH_LEVEL


func ground_rects() -> Array[Rect2]:
	return [Rect2(0, 650, 1180, 120), Rect2(1280, 690, 1280, 80), Rect2(2560, 650, 1000, 120), Rect2(3680, 650, 1440, 120)]


func platform_rects() -> Array[Rect2]:
	return [Rect2(360, 520, 220, 24), Rect2(760, 465, 250, 24), Rect2(1350, 535, 240, 24), Rect2(1660, 490, 210, 24), Rect2(1960, 530, 220, 24), Rect2(2250, 470, 230, 24), Rect2(2730, 520, 560, 24), Rect2(3990, 515, 260, 24), Rect2(4380, 450, 280, 24), Rect2(4750, 520, 250, 24)]


func enemy_specs() -> Array:
	return [
		spec(Vector2(350, 580), PEACH_DEMON, PEACH_DEMON_FRAMES), spec(Vector2(650, 580), GUARDIAN, GUARDIAN_FRAMES), spec(Vector2(920, 580), PEACH_DEMON, PEACH_DEMON_FRAMES), spec(Vector2(1150, 580), FLOWER_FAIRY, FLOWER_FAIRY_FRAMES),
		spec(Vector2(1380, 480), PEACH_CHILD, PEACH_CHILD_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(1630, 580), FLOWER_FAIRY, FLOWER_FAIRY_FRAMES), spec(Vector2(1900, 420), PEACH_CHILD, PEACH_CHILD_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(2190, 580), FLOWER_FAIRY, FLOWER_FAIRY_FRAMES), spec(Vector2(2470, 430), PEACH_CHILD, PEACH_CHILD_FRAMES, Enemy.Behavior.FLYING),
		spec(Vector2(2710, 580), FLOWER_FAIRY, FLOWER_FAIRY_FRAMES), spec(Vector2(3450, 580), PEACH_DEMON, PEACH_DEMON_FRAMES),
		spec(Vector2(3820, 580), GUARDIAN, GUARDIAN_FRAMES), spec(Vector2(4250, 580), PEACH_DEMON, PEACH_DEMON_FRAMES), spec(Vector2(4560, 580), GUARDIAN, GUARDIAN_FRAMES),
		spec(Vector2(3180, 520), FAIRY_LEADER, FAIRY_LEADER_FRAMES, Enemy.Behavior.BOSS, Vector2(1.3, 1.3)),
		spec(Vector2(4900, 510), LAND_GOD, LAND_GOD_FRAMES, Enemy.Behavior.BOSS, Vector2(1.5, 1.5), true),
	]


func item_specs() -> Array:
	return [
		{"position": Vector2(430, 475), "id": &"peach"}, {"position": Vector2(810, 420), "id": &"peach"}, {"position": Vector2(1110, 590), "id": &"fire_spear"},
		{"position": Vector2(1460, 490), "id": &"cosmic_ring"}, {"position": Vector2(2050, 485), "id": &"peach"},
		{"position": Vector2(4460, 405), "id": &"elixir"}, {"position": Vector2(4800, 475), "id": &"heaven_seal"},
	]


func hazard_specs() -> Array:
	return [
		{"position": Vector2(1040, 625), "stats": TRIP_ROOT, "kind": LineHazard.Kind.ROOT, "size": Vector2(95, 35)},
		{"position": Vector2(720, 600), "stats": PEACH_BOMB, "kind": LineHazard.Kind.PEACH_BOMB, "size": Vector2(60, 60)},
		{"position": Vector2(1920, 650), "stats": POOL_WATER, "kind": LineHazard.Kind.WATER, "size": Vector2(1180, 75), "slow_seconds": 3.0},
		{"position": Vector2(1560, 555), "stats": POLLEN, "kind": LineHazard.Kind.POLLEN, "size": Vector2(110, 100), "confusion_seconds": 3.0},
		{"position": Vector2(2310, 555), "stats": POLLEN, "kind": LineHazard.Kind.POLLEN, "size": Vector2(110, 100), "confusion_seconds": 3.0},
	]


func check_fairy_phase(current: float, maximum: float) -> void:
	if not fairy_clones_spawned and current <= maximum * 0.5:
		fairy_clones_spawned = true
		for offset in [-150.0, 0.0, 150.0]:
			spawn_extra_enemy(Vector2(3180 + offset, 520), FAIRY_ILLUSION, FAIRY_LEADER_FRAMES, &"fairy_illusions")


func check_land_phase(current: float, maximum: float) -> void:
	if land_phase_spawned or current > maximum * 0.5:
		return
	land_phase_spawned = true
	spawn_extra_enemy(Vector2(4620, 580), PEACH_DEMON, PEACH_DEMON_FRAMES)
	spawn_extra_enemy(Vector2(4780, 580), PEACH_DEMON, PEACH_DEMON_FRAMES)
	for x in [4520.0, 4750.0, 4990.0]:
		spawn_vine(Vector2(x, 600))


func spawn_extra_enemy(position_value: Vector2, stats_value: EnemyStats, atlas: Texture2D, group_name: StringName = &"") -> Enemy:
	var enemy := ENEMY_TEMPLATE.instantiate() as Enemy
	enemy.position = position_value
	enemy.stats = stats_value
	enemy.animation_atlas = atlas
	enemy.behavior = Enemy.Behavior.MELEE
	enemy.defeated.connect(add_stones)
	enemy.hit_received.connect(show_enemy_status)
	if not group_name.is_empty():
		enemy.add_to_group(group_name)
	add_child(enemy)
	return enemy


func spawn_vine(position_value: Vector2) -> void:
	var hazard := HAZARD_TEMPLATE.instantiate() as LineHazard
	hazard.position = position_value
	hazard.stats = TRIP_ROOT
	hazard.kind = LineHazard.Kind.ROOT
	hazard.visual_size = Vector2(70, 80)
	var shape := hazard.get_node("Shape").shape.duplicate() as RectangleShape2D
	shape.size = Vector2(70, 80)
	hazard.get_node("Shape").shape = shape
	hazard.add_to_group("land_vines")
	add_child(hazard)


func spec(position_value: Vector2, stats_value: EnemyStats, atlas_value: Texture2D, behavior_value: Enemy.Behavior = Enemy.Behavior.MELEE, scale_value: Vector2 = Vector2.ONE, final_value: bool = false) -> Dictionary:
	return {"position": position_value, "stats": stats_value, "atlas": atlas_value, "behavior": behavior_value, "scale": scale_value, "final_boss": final_value}
