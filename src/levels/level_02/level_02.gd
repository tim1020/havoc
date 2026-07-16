extends CampaignLevel

const SHRIMP := preload("res://resources/stats/enemies/shrimp_soldier.tres")
const CRAB := preload("res://resources/stats/enemies/crab_general.tres")
const JELLY := preload("res://resources/stats/enemies/electric_jellyfish.tres")
const MAIDEN := preload("res://resources/stats/enemies/dragon_maiden.tres")
const TURTLE := preload("res://resources/stats/enemies/turtle_chancellor.tres")
const DRAGON_KING := preload("res://resources/stats/enemies/dragon_king.tres")
const SHRIMP_FRAMES := preload("res://assets/generated/characters/campaign/shrimp_soldier_frames.png")
const CRAB_FRAMES := preload("res://assets/generated/characters/campaign/crab_general_frames.png")
const JELLY_FRAMES := preload("res://assets/generated/characters/campaign/electric_jellyfish_frames.png")
const MAIDEN_FRAMES := preload("res://assets/generated/characters/campaign/dragon_maiden_frames.png")
const TURTLE_FRAMES := preload("res://assets/generated/characters/campaign/turtle_chancellor_frames.png")
const DRAGON_KING_FRAMES := preload("res://assets/generated/characters/campaign/dragon_king_frames.png")
const URCHIN := preload("res://resources/stats/hazards/sea_urchin.tres")
const ELECTRIC := preload("res://resources/stats/hazards/electric_field.tres")
const CHECKPOINT := preload("res://src/world/checkpoint.gd")


func _ready() -> void:
	super()


func on_section_loaded(section: int) -> void:
	if section != 4:
		return
	var checkpoint = CHECKPOINT.new()
	checkpoint.position = Vector2(12000, 650)
	checkpoint.checkpoint_position = Vector2(12000, 580)
	add_child(checkpoint)


func on_level_victory() -> void:
	GameState.unlock_staff()


func next_level_path() -> String:
	return GameState.THIRD_LEVEL


func ground_rects() -> Array[Rect2]:
	return campaign_ground_rects()


func platform_rects() -> Array[Rect2]:
	return campaign_platform_rects()


func enemy_specs() -> Array:
	return [
		spec(Vector2(430, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(980, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(1540, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(2200, 580), SHRIMP, SHRIMP_FRAMES),
		spec(Vector2(2910, 580), CRAB, CRAB_FRAMES, Enemy.Behavior.CHARGE), spec(Vector2(3520, 580), CRAB, CRAB_FRAMES, Enemy.Behavior.CHARGE), spec(Vector2(4180, 580), CRAB, CRAB_FRAMES, Enemy.Behavior.CHARGE), spec(Vector2(4780, 580), CRAB, CRAB_FRAMES, Enemy.Behavior.CHARGE),
		spec(Vector2(5480, 430), JELLY, JELLY_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(6120, 390), JELLY, JELLY_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(6760, 450), JELLY, JELLY_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(7380, 400), JELLY, JELLY_FRAMES, Enemy.Behavior.FLYING),
		spec(Vector2(7920, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(8320, 580), CRAB, CRAB_FRAMES, Enemy.Behavior.CHARGE), spec(Vector2(8750, 430), JELLY, JELLY_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(9160, 550), MAIDEN, MAIDEN_FRAMES), spec(Vector2(9650, 535), TURTLE, TURTLE_FRAMES, Enemy.Behavior.BOSS, Vector2(1.3, 1.3)),
		spec(Vector2(10500, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(10920, 580), CRAB, CRAB_FRAMES, Enemy.Behavior.CHARGE), spec(Vector2(11350, 430), JELLY, JELLY_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(11780, 550), MAIDEN, MAIDEN_FRAMES), spec(Vector2(12350, 510), DRAGON_KING, DRAGON_KING_FRAMES, Enemy.Behavior.BOSS, Vector2(1.5, 1.5), true),
	]


func item_specs() -> Array:
	return [
		{"position": Vector2(540, 475), "id": &"peach"}, {"position": Vector2(1060, 590), "id": &"wine"},
		{"position": Vector2(1600, 465), "id": &"fire_wheels"}, {"position": Vector2(2150, 420), "id": &"heaven_seal"},
		{"position": Vector2(3900, 590), "id": &"peach"}, {"position": Vector2(4600, 395), "id": &"monkey_hair"},
	]


func hazard_specs() -> Array:
	return [
		{"position": Vector2(1090, 620), "stats": URCHIN, "kind": LineHazard.Kind.SPIKES, "size": Vector2(90, 50)},
		{"position": Vector2(1760, 620), "stats": ELECTRIC, "kind": LineHazard.Kind.ELECTRIC, "size": Vector2(130, 45), "slow_seconds": 2.0},
		{"position": Vector2(2310, 620), "stats": URCHIN, "kind": LineHazard.Kind.SPIKES, "size": Vector2(100, 50)},
		{"position": Vector2(3950, 620), "stats": ELECTRIC, "kind": LineHazard.Kind.ELECTRIC, "size": Vector2(140, 45), "slow_seconds": 2.0},
	]


func spec(position_value: Vector2, stats_value: EnemyStats, atlas_value: Texture2D, behavior_value: Enemy.Behavior = Enemy.Behavior.MELEE, scale_value: Vector2 = Vector2.ONE, final_value: bool = false) -> Dictionary:
	return {"position": position_value, "stats": stats_value, "atlas": atlas_value, "behavior": behavior_value, "scale": scale_value, "final_boss": final_value}
