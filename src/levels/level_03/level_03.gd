extends CampaignLevel

const SOUL := preload("res://resources/stats/enemies/wandering_soul.tres")
const SKELETON := preload("res://resources/stats/enemies/skeleton_guard.tres")
const REAPER := preload("res://resources/stats/enemies/soul_reaper.tres")
const ATTENDANT := preload("res://resources/stats/enemies/mengpo_attendant.tres")
const OX := preload("res://resources/stats/enemies/ox_guard.tres")
const HORSE := preload("res://resources/stats/enemies/horse_guard.tres")
const YANLUO := preload("res://resources/stats/enemies/yanluo_king.tres")
const SOUL_FRAMES := preload("res://assets/generated/characters/campaign/wandering_soul_frames.png")
const SKELETON_FRAMES := preload("res://assets/generated/characters/campaign/skeleton_guard_frames.png")
const REAPER_FRAMES := preload("res://assets/generated/characters/campaign/soul_reaper_frames.png")
const ATTENDANT_FRAMES := preload("res://assets/generated/characters/campaign/mengpo_attendant_frames.png")
const OX_FRAMES := preload("res://assets/generated/characters/campaign/ox_guard_frames.png")
const HORSE_FRAMES := preload("res://assets/generated/characters/campaign/horse_guard_frames.png")
const YANLUO_FRAMES := preload("res://assets/generated/characters/campaign/yanluo_king_frames.png")
const GHOST_FIRE := preload("res://resources/stats/hazards/ghost_fire.tres")
const VORTEX := preload("res://resources/stats/hazards/reincarnation_vortex.tres")


func _ready() -> void:
	super()


func on_section_loaded(section: int) -> void:
	if section != 3:
		return
	var ox: Enemy
	var horse: Enemy
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if floori(enemy.global_position.x / SECTION_WIDTH) != section:
			continue
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
	return campaign_ground_rects()


func platform_rects() -> Array[Rect2]:
	return campaign_platform_rects()


func enemy_specs() -> Array:
	return [
		spec(Vector2(420, 490), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(980, 440), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(1580, 500), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(2200, 450), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING),
		spec(Vector2(2920, 580), SKELETON, SKELETON_FRAMES), spec(Vector2(3540, 580), SKELETON, SKELETON_FRAMES), spec(Vector2(4160, 580), SKELETON, SKELETON_FRAMES), spec(Vector2(4780, 580), SKELETON, SKELETON_FRAMES),
		spec(Vector2(5480, 500), REAPER, REAPER_FRAMES), spec(Vector2(6120, 500), REAPER, REAPER_FRAMES), spec(Vector2(6760, 500), REAPER, REAPER_FRAMES), spec(Vector2(7380, 500), REAPER, REAPER_FRAMES),
		spec(Vector2(7900, 490), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(8300, 580), SKELETON, SKELETON_FRAMES), spec(Vector2(8740, 500), REAPER, REAPER_FRAMES), spec(Vector2(9140, 500), ATTENDANT, ATTENDANT_FRAMES), spec(Vector2(9480, 520), OX, OX_FRAMES, Enemy.Behavior.BOSS, Vector2(1.25, 1.25)), spec(Vector2(9760, 520), HORSE, HORSE_FRAMES, Enemy.Behavior.BOSS, Vector2(1.25, 1.25)),
		spec(Vector2(10450, 490), SOUL, SOUL_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(10880, 580), SKELETON, SKELETON_FRAMES), spec(Vector2(11320, 500), REAPER, REAPER_FRAMES), spec(Vector2(11740, 500), ATTENDANT, ATTENDANT_FRAMES), spec(Vector2(12320, 500), YANLUO, YANLUO_FRAMES, Enemy.Behavior.BOSS, Vector2(1.5, 1.5), true),
	]


func item_specs() -> Array:
	return [
		{"position": Vector2(440, 470), "id": &"peach"}, {"position": Vector2(1250, 590), "id": &"samadhi_fire"},
		{"position": Vector2(1800, 425), "id": &"peach"}, {"position": Vector2(2260, 490), "id": &"purple_bell"},
		{"position": Vector2(3820, 590), "id": &"elixir"}, {"position": Vector2(4680, 400), "id": &"invisibility_talisman"},
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
