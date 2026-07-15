extends CampaignLevel

const SHRIMP := preload("res://resources/stats/enemies/shrimp_soldier.tres")
const CRAB := preload("res://resources/stats/enemies/crab_general.tres")
const JELLY := preload("res://resources/stats/enemies/electric_jellyfish.tres")
const MAIDEN := preload("res://resources/stats/enemies/dragon_maiden.tres")
const TURTLE := preload("res://resources/stats/enemies/turtle_chancellor.tres")
const DRAGON_KING := preload("res://resources/stats/enemies/dragon_king.tres")
const SHRIMP_FRAMES := preload("res://assets/vector/characters/campaign/shrimp_soldier_frames.svg")
const CRAB_FRAMES := preload("res://assets/vector/characters/campaign/crab_general_frames.svg")
const JELLY_FRAMES := preload("res://assets/vector/characters/campaign/electric_jellyfish_frames.svg")
const MAIDEN_FRAMES := preload("res://assets/vector/characters/campaign/dragon_maiden_frames.svg")
const TURTLE_FRAMES := preload("res://assets/vector/characters/campaign/turtle_chancellor_frames.svg")
const DRAGON_KING_FRAMES := preload("res://assets/vector/characters/campaign/dragon_king_frames.svg")
const URCHIN := preload("res://resources/stats/hazards/sea_urchin.tres")
const ELECTRIC := preload("res://resources/stats/hazards/electric_field.tres")
const CHECKPOINT := preload("res://src/world/checkpoint.gd")


func _ready() -> void:
	super()
	var checkpoint = CHECKPOINT.new()
	checkpoint.position = Vector2(4520, 650)
	checkpoint.checkpoint_position = Vector2(4520, 580)
	add_child(checkpoint)


func on_level_victory() -> void:
	GameState.unlock_staff()


func next_level_path() -> String:
	return GameState.THIRD_LEVEL


func ground_rects() -> Array[Rect2]:
	return [Rect2(0, 650, 1080, 120), Rect2(1180, 650, 1120, 120), Rect2(2420, 650, 1140, 120), Rect2(3680, 650, 1440, 120)]


func platform_rects() -> Array[Rect2]:
	return [Rect2(420, 520, 240, 24), Rect2(780, 455, 220, 24), Rect2(1480, 510, 260, 24), Rect2(1980, 465, 220, 24), Rect2(2730, 500, 300, 24), Rect2(4100, 500, 300, 24), Rect2(4590, 440, 320, 24)]


func enemy_specs() -> Array:
	return [
		spec(Vector2(430, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(690, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(970, 580), CRAB, CRAB_FRAMES, Enemy.Behavior.CHARGE, Vector2(1.12, 1.12)),
		spec(Vector2(1320, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(1570, 440), JELLY, JELLY_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(1850, 550), MAIDEN, MAIDEN_FRAMES), spec(Vector2(2110, 410), JELLY, JELLY_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(2260, 580), CRAB, CRAB_FRAMES, Enemy.Behavior.CHARGE, Vector2(1.12, 1.12)),
		spec(Vector2(2510, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(2770, 440), JELLY, JELLY_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(3050, 580), MAIDEN, MAIDEN_FRAMES), spec(Vector2(3310, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(3500, 580), CRAB, CRAB_FRAMES, Enemy.Behavior.CHARGE, Vector2(1.12, 1.12)),
		spec(Vector2(3770, 580), SHRIMP, SHRIMP_FRAMES), spec(Vector2(3990, 580), CRAB, CRAB_FRAMES, Enemy.Behavior.CHARGE, Vector2(1.12, 1.12)), spec(Vector2(4220, 440), JELLY, JELLY_FRAMES, Enemy.Behavior.FLYING), spec(Vector2(4460, 580), MAIDEN, MAIDEN_FRAMES),
		spec(Vector2(3360, 535), TURTLE, TURTLE_FRAMES, Enemy.Behavior.BOSS, Vector2(1.3, 1.3)),
		spec(Vector2(4860, 510), DRAGON_KING, DRAGON_KING_FRAMES, Enemy.Behavior.BOSS, Vector2(1.5, 1.5), true),
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
