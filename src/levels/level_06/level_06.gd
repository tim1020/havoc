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
const LI_JING := preload("res://resources/stats/enemies/li_jing.tres")
const THUNDER := preload("res://resources/stats/enemies/thunder_lord.tres")
const LIGHTNING_MOTHER := preload("res://resources/stats/enemies/lightning_mother.tres")
const KING_STATS := [
	preload("res://resources/stats/enemies/dhritarashtra.tres"), preload("res://resources/stats/enemies/virudhaka.tres"),
	preload("res://resources/stats/enemies/virupaksha.tres"), preload("res://resources/stats/enemies/vaishravana.tres"),
]
const YELLOW_FRAMES := preload("res://assets/generated/characters/campaign/yellow_turban_frames_v2.png")
const CURTAIN_FRAMES := preload("res://assets/generated/characters/campaign/curtain_general_frames.png")
const THUNDER_FRAMES := preload("res://assets/generated/characters/campaign/thunder_lord_frames_v2.png")
const LIGHTNING_MOTHER_FRAMES := preload("res://assets/generated/characters/campaign/lightning_mother_frames_v2.png")
const ROYAL_FRAMES := preload("res://assets/generated/characters/campaign/royal_guard_frames.png")
const HOUND_FRAMES := preload("res://assets/generated/characters/campaign/heaven_hound_frames.png")
const NEZHA_FRAMES := preload("res://assets/generated/characters/campaign/nezha_frames.png")
const ERLANG_FRAMES := preload("res://assets/generated/characters/campaign/erlang_frames.png")
const LI_JING_FRAMES := preload("res://assets/generated/characters/campaign/li_jing_frames_v2.png")
const EMPEROR_FRAMES := preload("res://assets/generated/characters/campaign/jade_emperor_frames.png")
const KING_FRAMES := [
	preload("res://assets/generated/characters/campaign/dhritarashtra_frames.png"), preload("res://assets/generated/characters/campaign/virudhaka_frames.png"),
	preload("res://assets/generated/characters/campaign/virupaksha_frames.png"), preload("res://assets/generated/characters/campaign/vaishravana_frames.png"),
]
const GOLD_ARRAY := preload("res://resources/stats/hazards/golden_array.tres")
const DRAGON_FIRE := preload("res://resources/stats/hazards/dragon_fire.tres")

var hounds_summoned := false
var emperor_shield_breaks := 0
var emperor_shield_reset := false
var emperor_reinforcement_timer: Timer
var emperor: Enemy
var final_guardians_spawned := false
var final_guardians: Dictionary = {}
var final_soldiers: Array[WeakRef] = []


func _ready() -> void:
	super()
	emperor_reinforcement_timer = Timer.new()
	emperor_reinforcement_timer.wait_time = 6.0
	emperor_reinforcement_timer.timeout.connect(spawn_emperor_reinforcement)
	add_child(emperor_reinforcement_timer)


func on_section_loaded(section: int) -> void:
	var pillar = PILLAR_SCRIPT.new()
	pillar.position = Vector2([520.0, 3080.0, 5640.0, 8200.0, 10760.0][section], 650)
	add_child(pillar)
	if section == 0:
		var seal = SEAL_SCRIPT.new()
		seal.position = Vector2(-120, 360)
		seal.visible = false
		add_child(seal)
	if section != 4:
		return
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if floori(enemy.global_position.x / SECTION_WIDTH) != section:
			continue


func ground_rects() -> Array[Rect2]:
	return campaign_ground_rects()


func platform_rects() -> Array[Rect2]:
	return campaign_platform_rects()


func enemy_specs() -> Array:
	return [
		spec(Vector2(520, 580), YELLOW, YELLOW_FRAMES, Enemy.Behavior.MELEE, Vector2(1.5, 1.5)), spec(Vector2(1120, 580), YELLOW, YELLOW_FRAMES, Enemy.Behavior.MELEE, Vector2(1.5, 1.5)), spec(Vector2(1760, 580), YELLOW, YELLOW_FRAMES, Enemy.Behavior.MELEE, Vector2(1.5, 1.5)), spec(Vector2(2120, 510), THUNDER, THUNDER_FRAMES, Enemy.Behavior.BOSS, Vector2(1.5, 1.5)), spec(Vector2(2360, 510), LIGHTNING_MOTHER, LIGHTNING_MOTHER_FRAMES, Enemy.Behavior.BOSS, Vector2(1.1, 1.1)),
		spec(Vector2(3060, 580), CURTAIN, CURTAIN_FRAMES), spec(Vector2(3700, 580), CURTAIN, CURTAIN_FRAMES), spec(Vector2(4320, 580), CURTAIN, CURTAIN_FRAMES), spec(Vector2(4820, 510), ERLANG, ERLANG_FRAMES, Enemy.Behavior.BOSS, Vector2(1.5, 1.5)),
		spec(Vector2(5620, 580), HOUND, HOUND_FRAMES, Enemy.Behavior.CHARGE), spec(Vector2(6260, 580), HOUND, HOUND_FRAMES, Enemy.Behavior.CHARGE), spec(Vector2(6880, 580), HOUND, HOUND_FRAMES, Enemy.Behavior.CHARGE), spec(Vector2(7380, 510), NEZHA, NEZHA_FRAMES, Enemy.Behavior.BOSS, Vector2(1.5, 1.5)),
		spec(Vector2(8180, 580), ROYAL, ROYAL_FRAMES, Enemy.Behavior.MELEE, Vector2(1.35, 1.35)), spec(Vector2(8820, 580), ROYAL, ROYAL_FRAMES, Enemy.Behavior.MELEE, Vector2(1.35, 1.35)), spec(Vector2(9440, 580), ROYAL, ROYAL_FRAMES, Enemy.Behavior.MELEE, Vector2(1.35, 1.35)), spec(Vector2(9940, 510), LI_JING, LI_JING_FRAMES, Enemy.Behavior.BOSS, Vector2(0.75, 0.75)),
		spec(Vector2(10380, 580), YELLOW, YELLOW_FRAMES, Enemy.Behavior.MELEE, Vector2(1.5, 1.5)), spec(Vector2(10680, 580), CURTAIN, CURTAIN_FRAMES), spec(Vector2(10980, 580), ROYAL, ROYAL_FRAMES, Enemy.Behavior.MELEE, Vector2(1.35, 1.35)), spec(Vector2(11280, 580), HOUND, HOUND_FRAMES, Enemy.Behavior.CHARGE),
		spec(Vector2(11450, 510), THUNDER, THUNDER_FRAMES, Enemy.Behavior.BOSS, Vector2(1.5, 1.5), true), spec(Vector2(11700, 510), LIGHTNING_MOTHER, LIGHTNING_MOTHER_FRAMES, Enemy.Behavior.BOSS, Vector2(1.1, 1.1), true), spec(Vector2(12000, 510), ERLANG, ERLANG_FRAMES, Enemy.Behavior.BOSS, Vector2(1.3, 1.3), true), spec(Vector2(12220, 510), NEZHA, NEZHA_FRAMES, Enemy.Behavior.BOSS, Vector2(1.3, 1.3), true), spec(Vector2(12400, 510), LI_JING, LI_JING_FRAMES, Enemy.Behavior.BOSS, Vector2(0.75, 0.75), true), spec(Vector2(12600, 500), EMPEROR, EMPEROR_FRAMES, Enemy.Behavior.EVADE, Vector2(1.3, 1.3), true),
	]


func spawn_final_boss(section: int) -> void:
	if section != SECTION_COUNT - 1:
		super(section)
		return
	if section_final_boss_spawned.get(section, false):
		return
	section_final_boss_spawned[section] = true
	emperor = spawn_final_character(Vector2(12600, 500), EMPEROR, EMPEROR_FRAMES, Enemy.Behavior.EVADE, Vector2(1.3, 1.3), &"jade_emperor")
	emperor.protected_by_group = &"emperor_protectors"
	emperor.hit_received.connect(start_emperor_guard_battle, CONNECT_ONE_SHOT)


func start_emperor_guard_battle(_enemy: Enemy, _current: float, _maximum: float) -> void:
	if final_guardians_spawned:
		return
	final_guardians_spawned = true
	register_final_guardian(THUNDER, spawn_final_character(Vector2(11450, 510), THUNDER, THUNDER_FRAMES, Enemy.Behavior.BOSS, Vector2(1.5, 1.5), &"emperor_attackers"))
	register_final_guardian(LIGHTNING_MOTHER, spawn_final_character(Vector2(11700, 510), LIGHTNING_MOTHER, LIGHTNING_MOTHER_FRAMES, Enemy.Behavior.BOSS, Vector2(1.1, 1.1), &"emperor_attackers"))
	register_final_guardian(NEZHA, spawn_final_protector(Vector2(12150, 510), NEZHA, NEZHA_FRAMES, Vector2(1.3, 1.3), 370.0))
	register_final_guardian(LI_JING, spawn_final_protector(Vector2(12320, 510), LI_JING, LI_JING_FRAMES, Vector2(0.75, 0.75), 260.0))
	register_final_guardian(ERLANG, spawn_final_protector(Vector2(12470, 510), ERLANG, ERLANG_FRAMES, Vector2(1.3, 1.3), 150.0))
	for soldier_index in 4:
		final_soldiers.append(weakref(spawn_final_soldier(Vector2(11920.0 + soldier_index * 115.0, 580.0), 480.0 + soldier_index * 70.0)))


func register_final_guardian(stats_value: EnemyStats, guardian: Enemy) -> void:
	final_guardians[stats_value] = weakref(guardian)
	guardian.defeated.connect(update_emperor_guard_phase)


func get_final_guardian(stats_value: EnemyStats) -> Enemy:
	var reference := final_guardians.get(stats_value) as WeakRef
	if reference == null:
		return null
	return reference.get_ref() as Enemy


func spawn_final_protector(position_value: Vector2, stats_value: EnemyStats, atlas: Texture2D, scale_value: Vector2, guard_distance: float) -> Enemy:
	var protector := spawn_final_character(position_value, stats_value, atlas, Enemy.Behavior.BOSS, scale_value, &"emperor_protectors")
	protector.protects_group = &"jade_emperor"
	protector.bodyguard_attacks = true
	protector.bodyguard_distance = guard_distance
	protector.engaged = true
	return protector


func spawn_final_soldier(position_value: Vector2, guard_distance: float) -> Enemy:
	var soldier := spawn_enemy_spec(spec(position_value, ROYAL, ROYAL_FRAMES, Enemy.Behavior.MELEE, Vector2(1.35, 1.35)), SECTION_COUNT - 1)
	soldier.add_to_group(&"emperor_protectors")
	soldier.add_to_group(&"emperor_soldiers")
	soldier.protects_group = &"jade_emperor"
	soldier.bodyguard_attacks = true
	soldier.bodyguard_distance = guard_distance
	soldier.engaged = true
	return soldier


func spawn_final_character(position_value: Vector2, stats_value: EnemyStats, atlas: Texture2D, behavior_value: Enemy.Behavior, scale_value: Vector2, group_name: StringName) -> Enemy:
	var character := spawn_enemy_spec(spec(position_value, stats_value, atlas, behavior_value, scale_value, true), SECTION_COUNT - 1)
	character.add_to_group(group_name)
	return character


func update_emperor_guard_phase(_reward: int) -> void:
	for stats_value in final_guardians:
		var guardian := get_final_guardian(stats_value)
		if guardian != null and guardian.dead:
			guardian.remove_from_group(&"emperor_protectors")
	if guardians_defeated([THUNDER, LIGHTNING_MOTHER]):
		activate_final_attackers([NEZHA, LI_JING])
	if guardians_defeated([NEZHA, LI_JING]):
		activate_final_attackers([ERLANG])
		retreat_final_soldiers()


func guardians_defeated(stats_list: Array) -> bool:
	for stats_value in stats_list:
		var guardian := get_final_guardian(stats_value as EnemyStats)
		if guardian != null and not guardian.dead:
			return false
	return true


func activate_final_attackers(stats_list: Array) -> void:
	for stats_value in stats_list:
		var guardian := get_final_guardian(stats_value as EnemyStats)
		if guardian == null or guardian.dead:
			continue
		guardian.remove_from_group(&"emperor_protectors")
		guardian.add_to_group(&"emperor_attackers")
		guardian.protects_group = &""
		guardian.bodyguard_attacks = true


func retreat_final_soldiers() -> void:
	for reference in final_soldiers:
		var soldier := reference.get_ref() as Enemy
		if soldier == null:
			continue
		soldier.remove_from_group(&"emperor_protectors")
		soldier.remove_from_group(&"emperor_soldiers")
		enemy_tracker.remove(soldier, SECTION_COUNT - 1)
		soldier.queue_free()
	final_soldiers.clear()


func update_section_waves(section: int) -> void:
	if section != SECTION_COUNT - 1:
		super(section)


func item_specs() -> Array:
	return [
		{"position": Vector2(720, 425), "id": &"peach"}, {"position": Vector2(1120, 360), "id": &"samadhi_fire"},
		{"position": Vector2(1500, 475), "id": &"wine"}, {"position": Vector2(3500, 540), "id": &"elixir"},
		{"position": Vector2(4100, 455), "id": &"banana_fan"}, {"position": Vector2(4700, 385), "id": &"freeze_talisman"},
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
	player.play_victory()
	hud.play_victory_animation("大闹天宫 · 通关")
	AudioService.play_sfx(self, AudioService.VICTORY)
	GameState.complete_game()
	await get_tree().create_timer(0.9).timeout
	hud.show_result(earned_stones, "主线通关")


func complete_final_encounter() -> void:
	complete_main_story(0)


func spawn_enemy(position_value: Vector2, stats_value: EnemyStats, atlas: Texture2D, group_name: StringName, behavior_value: Enemy.Behavior = Enemy.Behavior.BOSS) -> Enemy:
	var enemy := ENEMY_TEMPLATE.instantiate() as Enemy
	enemy.position = position_value
	enemy.stats = stats_value
	enemy.animation_atlas = atlas
	enemy.behavior = behavior_value
	enemy.visual_scale = Vector2(1.5, 1.5) if behavior_value == Enemy.Behavior.BOSS else Vector2.ONE
	enemy.target_player = player
	enemy.defeated.connect(add_stones)
	enemy.hit_received.connect(show_enemy_status)
	enemy.add_to_group(group_name)
	add_child(enemy)
	return enemy


func spec(position_value: Vector2, stats_value: EnemyStats, atlas_value: Texture2D, behavior_value: Enemy.Behavior = Enemy.Behavior.MELEE, scale_value: Vector2 = Vector2.ONE, final_value: bool = false) -> Dictionary:
	return {"position": position_value, "stats": stats_value, "atlas": atlas_value, "behavior": behavior_value, "scale": scale_value, "final_boss": final_value}
