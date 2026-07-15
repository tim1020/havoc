extends CampaignLevel

const SOUL := preload("res://resources/stats/enemies/wandering_soul.tres")
const SKELETON := preload("res://resources/stats/enemies/skeleton_guard.tres")
const REAPER := preload("res://resources/stats/enemies/soul_reaper.tres")
const ATTENDANT := preload("res://resources/stats/enemies/mengpo_attendant.tres")
const OX := preload("res://resources/stats/enemies/ox_guard.tres")
const HORSE := preload("res://resources/stats/enemies/horse_guard.tres")
const YANLUO := preload("res://resources/stats/enemies/yanluo_king.tres")
const SOUL_FRAMES := preload("res://assets/vector/characters/campaign/wandering_soul_frames.svg")
const SKELETON_FRAMES := preload("res://assets/vector/characters/campaign/skeleton_guard_frames.svg")
const REAPER_FRAMES := preload("res://assets/vector/characters/campaign/soul_reaper_frames.svg")
const ATTENDANT_FRAMES := preload("res://assets/vector/characters/campaign/mengpo_attendant_frames.svg")
const OX_FRAMES := preload("res://assets/vector/characters/campaign/ox_guard_frames.svg")
const HORSE_FRAMES := preload("res://assets/vector/characters/campaign/horse_guard_frames.svg")
const YANLUO_FRAMES := preload("res://assets/vector/characters/campaign/yanluo_king_frames.svg")
const GHOST_FIRE := preload("res://resources/stats/hazards/ghost_fire.tres")
const VORTEX := preload("res://resources/stats/hazards/reincarnation_vortex.tres")


func _ready() -> void:
	super()
	var ox: Enemy
	var horse: Enemy
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.stats == OX:
			ox = enemy
		elif enemy.stats == HORSE:
			horse = enemy
	if ox != null and horse != null:
		ox.defeated.connect(enrage_partner.bind(horse))
		horse.defeated.connect(enrage_partner.bind(ox))


func enrage_partner(_reward: int, partner: Enemy) -> void:
	if is_instance_valid(partner) and not partner.dead:
		partner.phase_two = true
		partner.current_phase = 2


func next_level_path() -> String:
	return GameState.FOURTH_LEVEL


func ground_rects() -> Array[Rect2]:
	return [Rect2(0, 650, 520, 120), Rect2(610, 650, 430, 120), Rect2(1140, 650, 280, 120), Rect2(2420, 650, 1140, 120), Rect2(3680, 650, 1440, 120)]


func platform_rects() -> Array[Rect2]:
	return [Rect2(380, 515, 230, 24), Rect2(1450, 540, 210, 24), Rect2(1740, 470, 190, 24), Rect2(2020, 535, 210, 24), Rect2(2710, 500, 300, 24), Rect2(3160, 455, 260, 24), Rect2(4080, 500, 280, 24), Rect2(4580, 445, 320, 24)]


func enemy_specs() -> Array:
	return [
		spec(Vector2(350, 520), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(670, 580), SKELETON, SKELETON_FRAMES), spec(Vector2(910, 500), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(1190, 580), SKELETON, SKELETON_FRAMES), spec(Vector2(1390, 500), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(1570, 490), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING),
		spec(Vector2(1800, 420), REAPER, REAPER_FRAMES), spec(Vector2(2080, 485), ATTENDANT, ATTENDANT_FRAMES), spec(Vector2(2320, 500), REAPER, REAPER_FRAMES),
		spec(Vector2(2520, 580), SKELETON, SKELETON_FRAMES), spec(Vector2(2700, 450), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(2890, 580), SKELETON, SKELETON_FRAMES), spec(Vector2(3070, 410), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(3260, 580), SKELETON, SKELETON_FRAMES), spec(Vector2(3460, 580), SKELETON, SKELETON_FRAMES),
		spec(Vector2(3850, 580), REAPER, REAPER_FRAMES), spec(Vector2(4140, 450), ATTENDANT, ATTENDANT_FRAMES), spec(Vector2(4470, 580), ATTENDANT, ATTENDANT_FRAMES),
		spec(Vector2(3260, 520), OX, OX_FRAMES, Enemy.Behavior.BOSS, Vector2(1.25, 1.25)), spec(Vector2(3450, 520), HORSE, HORSE_FRAMES, Enemy.Behavior.BOSS, Vector2(1.25, 1.25)),
		spec(Vector2(4880, 500), YANLUO, YANLUO_FRAMES, Enemy.Behavior.BOSS, Vector2(1.5, 1.5), true),
	]


func item_specs() -> Array:
	return [
		{"position": Vector2(440, 470), "id": &"peach"}, {"position": Vector2(1250, 590), "id": &"fire_spear"},
		{"position": Vector2(1800, 425), "id": &"peach"}, {"position": Vector2(2260, 490), "id": &"purple_bell"},
		{"position": Vector2(3820, 590), "id": &"elixir"}, {"position": Vector2(4680, 400), "id": &"cosmic_ring"},
	]


func hazard_specs() -> Array:
	return [
		{"position": Vector2(565, 585), "stats": GHOST_FIRE, "kind": LineHazard.Kind.FIRE, "size": Vector2(65, 65)},
		{"position": Vector2(1090, 585), "stats": GHOST_FIRE, "kind": LineHazard.Kind.FIRE, "size": Vector2(65, 65)},
		{"position": Vector2(1685, 590), "stats": VORTEX, "kind": LineHazard.Kind.VORTEX, "size": Vector2(100, 80), "slow_seconds": 1.0},
		{"position": Vector2(2335, 590), "stats": VORTEX, "kind": LineHazard.Kind.VORTEX, "size": Vector2(100, 80), "slow_seconds": 1.0},
	]


func spec(position_value: Vector2, stats_value: EnemyStats, atlas_value: Texture2D, behavior_value: Enemy.Behavior = Enemy.Behavior.MELEE, scale_value: Vector2 = Vector2.ONE, final_value: bool = false) -> Dictionary:
	return {"position": position_value, "stats": stats_value, "atlas": atlas_value, "behavior": behavior_value, "scale": scale_value, "final_boss": final_value}
