extends CampaignLevel

const ENEMY_TEMPLATE := preload("res://src/actors/enemies/enemy.tscn")
const HAZARD_TEMPLATE := preload("res://src/world/line_hazard.tscn")
const PILLAR_SCRIPT := preload("res://src/world/dragon_pillar.gd")
const SEAL_SCRIPT := preload("res://src/world/pursuit_seal.gd")
const YELLOW := preload("res://resources/stats/enemies/yellow_turban.tres")
const CURTAIN := preload("res://resources/stats/enemies/curtain_general.tres")
const ROYAL := preload("res://resources/stats/enemies/royal_guard.tres")
const HOUND := preload("res://resources/stats/enemies/heaven_hound.tres")
const NEZHA := preload("res://resources/stats/enemies/nezha.tres")
const ERLANG := preload("res://resources/stats/enemies/erlang.tres")
const EMPEROR := preload("res://resources/stats/enemies/jade_emperor.tres")
const YELLOW_FRAMES := preload("res://assets/vector/characters/campaign/yellow_turban_frames.svg")
const CURTAIN_FRAMES := preload("res://assets/vector/characters/campaign/curtain_general_frames.svg")
const ROYAL_FRAMES := preload("res://assets/vector/characters/campaign/royal_guard_frames.svg")
const HOUND_FRAMES := preload("res://assets/vector/characters/campaign/heaven_hound_frames.svg")
const NEZHA_FRAMES := preload("res://assets/vector/characters/campaign/nezha_frames.svg")
const ERLANG_FRAMES := preload("res://assets/vector/characters/campaign/erlang_frames.svg")
const EMPEROR_FRAMES := preload("res://assets/vector/characters/campaign/jade_emperor_frames.svg")
const GOLD_ARRAY := preload("res://resources/stats/hazards/golden_array.tres")
const DRAGON_FIRE := preload("res://resources/stats/hazards/dragon_fire.tres")

var hounds_summoned := false
var emperor_shield_breaks := 0
var emperor_shield_reset := false
var emperor_reinforcement_timer: Timer


func _ready() -> void:
	super()
	for x in [520.0, 1080.0, 1760.0, 2290.0]:
		var pillar = PILLAR_SCRIPT.new()
		pillar.position = Vector2(x, 650)
		add_child(pillar)
	var seal = SEAL_SCRIPT.new()
	seal.position = Vector2(-120, 360)
	seal.visible = false
	add_child(seal)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy.stats == NEZHA:
			enemy.defeated.connect(spawn_erlang, CONNECT_ONE_SHOT)
	emperor_reinforcement_timer = Timer.new()
	emperor_reinforcement_timer.wait_time = 6.0
	emperor_reinforcement_timer.timeout.connect(spawn_emperor_reinforcement)
	add_child(emperor_reinforcement_timer)


func ground_rects() -> Array[Rect2]:
	return [Rect2(0, 650, 1160, 120), Rect2(1280, 650, 1120, 120), Rect2(2500, 650, 1060, 120), Rect2(3680, 650, 1440, 120)]


func platform_rects() -> Array[Rect2]:
	return [Rect2(300, 540, 220, 24), Rect2(680, 470, 230, 24), Rect2(1020, 405, 210, 24), Rect2(1450, 520, 250, 24), Rect2(1840, 460, 240, 24), Rect2(2180, 520, 220, 24), Rect2(2700, 510, 260, 24), Rect2(3160, 450, 260, 24), Rect2(4080, 500, 300, 24), Rect2(4600, 430, 320, 24)]


func enemy_specs() -> Array:
	return [
		spec(Vector2(350, 580), YELLOW, YELLOW_FRAMES), spec(Vector2(650, 580), YELLOW, YELLOW_FRAMES), spec(Vector2(930, 580), CURTAIN, CURTAIN_FRAMES), spec(Vector2(1180, 580), ROYAL, ROYAL_FRAMES),
		spec(Vector2(1430, 580), YELLOW, YELLOW_FRAMES), spec(Vector2(1680, 580), CURTAIN, CURTAIN_FRAMES), spec(Vector2(1940, 580), ROYAL, ROYAL_FRAMES), spec(Vector2(2200, 580), YELLOW, YELLOW_FRAMES),
		spec(Vector2(2520, 580), HOUND, HOUND_FRAMES, Enemy.Behavior.CHARGE), spec(Vector2(2780, 580), ROYAL, ROYAL_FRAMES), spec(Vector2(3030, 580), CURTAIN, CURTAIN_FRAMES), spec(Vector2(3300, 580), HOUND, HOUND_FRAMES, Enemy.Behavior.CHARGE), spec(Vector2(3500, 580), HOUND, HOUND_FRAMES, Enemy.Behavior.CHARGE),
		spec(Vector2(3380, 510), NEZHA, NEZHA_FRAMES, Enemy.Behavior.BOSS, Vector2(1.4, 1.4)),
	]


func item_specs() -> Array:
	return [
		{"position": Vector2(720, 425), "id": &"peach"}, {"position": Vector2(1120, 360), "id": &"fire_spear"},
		{"position": Vector2(1500, 475), "id": &"wine"}, {"position": Vector2(3500, 540), "id": &"elixir"},
		{"position": Vector2(4100, 455), "id": &"heaven_seal"}, {"position": Vector2(4700, 385), "id": &"binding_rope"},
	]


func hazard_specs() -> Array:
	return [
		{"position": Vector2(560, 610), "stats": GOLD_ARRAY, "kind": LineHazard.Kind.GOLD_ARRAY, "size": Vector2(105, 75)},
		{"position": Vector2(1120, 610), "stats": GOLD_ARRAY, "kind": LineHazard.Kind.GOLD_ARRAY, "size": Vector2(105, 75)},
		{"position": Vector2(2050, 610), "stats": GOLD_ARRAY, "kind": LineHazard.Kind.GOLD_ARRAY, "size": Vector2(105, 75)},
		{"position": Vector2(2700, 590), "stats": DRAGON_FIRE, "kind": LineHazard.Kind.FIRE, "size": Vector2(70, 100)},
		{"position": Vector2(3050, 590), "stats": DRAGON_FIRE, "kind": LineHazard.Kind.FIRE, "size": Vector2(70, 100)},
		{"position": Vector2(4100, 590), "stats": DRAGON_FIRE, "kind": LineHazard.Kind.FIRE, "size": Vector2(70, 100)},
		{"position": Vector2(4920, 590), "stats": DRAGON_FIRE, "kind": LineHazard.Kind.FIRE, "size": Vector2(70, 100)},
	]


func spawn_erlang(_reward: int) -> void:
	var erlang := spawn_enemy(Vector2(4400, 510), ERLANG, ERLANG_FRAMES, &"erlang_boss")
	erlang.health_changed.connect(check_erlang_phase)
	erlang.defeated.connect(spawn_emperor, CONNECT_ONE_SHOT)


func check_erlang_phase(current: float, maximum: float) -> void:
	if hounds_summoned or current > maximum * 0.5:
		return
	hounds_summoned = true
	spawn_enemy(Vector2(4240, 580), HOUND, HOUND_FRAMES, &"erlang_hounds", Enemy.Behavior.CHARGE)
	spawn_enemy(Vector2(4560, 580), HOUND, HOUND_FRAMES, &"erlang_hounds", Enemy.Behavior.CHARGE)


func spawn_emperor(_reward: int) -> void:
	var emperor := spawn_enemy(Vector2(4770, 500), EMPEROR, EMPEROR_FRAMES, &"jade_emperor")
	emperor.hit_received.connect(check_emperor_shield)
	emperor.health_changed.connect(check_emperor_phase)
	emperor.defeated.connect(complete_main_story, CONNECT_ONE_SHOT)


func check_emperor_shield(enemy: Enemy, _current: float, _maximum: float) -> void:
	if is_zero_approx(enemy.shield_health) and emperor_shield_breaks == (1 if emperor_shield_reset else 0):
		emperor_shield_breaks += 1
		spawn_burst(enemy.global_position)


func check_emperor_phase(current: float, maximum: float) -> void:
	var emperor := get_tree().get_first_node_in_group("jade_emperor") as Enemy
	if emperor_shield_reset or current > maximum * 0.5 or emperor == null:
		return
	emperor_shield_reset = true
	emperor.shield_health = emperor.stats.shield_health
	emperor_reinforcement_timer.start()


func spawn_emperor_reinforcement() -> void:
	spawn_enemy(Vector2(4050 + randi_range(0, 600), 580), ROYAL, ROYAL_FRAMES, &"emperor_reinforcements")


func spawn_burst(position_value: Vector2) -> void:
	var hazard := HAZARD_TEMPLATE.instantiate() as LineHazard
	hazard.position = position_value
	hazard.stats = GOLD_ARRAY
	hazard.kind = LineHazard.Kind.GOLD_ARRAY
	hazard.visual_size = Vector2(260, 150)
	var shape := hazard.get_node("Shape").shape.duplicate() as RectangleShape2D
	shape.size = Vector2(260, 150)
	hazard.get_node("Shape").shape = shape
	hazard.add_to_group("shield_bursts")
	add_child(hazard)


func complete_main_story(_reward: int) -> void:
	completed = true
	emperor_reinforcement_timer.stop()
	player.controls_enabled = false
	AudioService.play_sfx(self, AudioService.VICTORY)
	GameState.complete_game()
	hud.show_result(earned_stones, "主线通关")


func spawn_enemy(position_value: Vector2, stats_value: EnemyStats, atlas: Texture2D, group_name: StringName, behavior_value: Enemy.Behavior = Enemy.Behavior.BOSS) -> Enemy:
	var enemy := ENEMY_TEMPLATE.instantiate() as Enemy
	enemy.position = position_value
	enemy.stats = stats_value
	enemy.animation_atlas = atlas
	enemy.behavior = behavior_value
	enemy.visual_scale = Vector2(1.5, 1.5) if behavior_value == Enemy.Behavior.BOSS else Vector2.ONE
	enemy.defeated.connect(add_stones)
	enemy.hit_received.connect(show_enemy_status)
	enemy.add_to_group(group_name)
	add_child(enemy)
	return enemy


func spec(position_value: Vector2, stats_value: EnemyStats, atlas_value: Texture2D, behavior_value: Enemy.Behavior = Enemy.Behavior.MELEE, scale_value: Vector2 = Vector2.ONE) -> Dictionary:
	return {"position": position_value, "stats": stats_value, "atlas": atlas_value, "behavior": behavior_value, "scale": scale_value, "final_boss": false}
