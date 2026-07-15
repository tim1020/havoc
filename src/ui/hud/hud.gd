class_name GameHud
extends CanvasLayer

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var lives_label: Label = %LivesLabel
@onready var stones_label: Label = %StonesLabel
@onready var artifact_labels: Array[Label] = [%Artifact1, %Artifact2, %Artifact3]
@onready var section_label: Label = %SectionLabel
@onready var victory_banner: Label = %VictoryBanner
@onready var result_panel: Control = %ResultPanel
@onready var pause_panel: Control = %PausePanel
@onready var enemy_panel: Control = %EnemyPanel
@onready var enemy_name_label: Label = %EnemyNameLabel
@onready var enemy_health_bar: ProgressBar = %EnemyHealthBar
@onready var enemy_health_label: Label = %EnemyHealthLabel
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var effects_slider: HSlider = %EffectsSlider
@onready var reduced_motion_button: CheckButton = %ReducedMotionButton

var enemy_status_expires_at: int = 0


func bind_player(player: Player) -> void:
	health_bar.max_value = player.stats.max_health
	player.health_changed.connect(update_health)
	GameState.lives_changed.connect(update_lives)
	GameState.stones_changed.connect(update_stones)
	GameState.artifacts_changed.connect(update_artifacts)
	update_health(player.health, player.stats.max_health)
	update_lives(GameState.lives)
	update_stones(GameState.stones)
	update_artifacts(GameState.artifacts)


func update_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func update_lives(current_lives: int) -> void:
	lives_label.text = "毫毛  × %d" % current_lives


func update_stones(stones: int) -> void:
	stones_label.text = "灵石  %04d" % stones


func update_artifacts(artifacts: Array[StringName]) -> void:
	for index in artifact_labels.size():
		if index < artifacts.size():
			var item := ItemCatalog.get_definition(artifacts[index])
			artifact_labels[index].text = ("▶ " if index == 0 else "") + (item.display_name if item != null else "?")
			artifact_labels[index].modulate = item.color if item != null else Color.WHITE
		else:
			artifact_labels[index].text = "空"
			artifact_labels[index].modulate = Color(0.65, 0.65, 0.65)


func show_enemy_status(enemy: Enemy, current: float, maximum: float) -> void:
	enemy_panel.visible = true
	enemy_name_label.text = enemy.stats.display_name
	enemy_health_bar.max_value = maximum
	enemy_health_bar.value = current
	enemy_health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]
	enemy_status_expires_at = Time.get_ticks_msec() + 2500


func set_section(section_name: String) -> void:
	section_label.text = section_name
	section_label.modulate.a = 1.0
	if GameState.settings.reduced_motion:
		return
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(section_label, "modulate:a", 0.0, 0.6)


func play_victory_animation(title: String = "关卡通过") -> void:
	victory_banner.text = title
	victory_banner.visible = true
	victory_banner.modulate.a = 0.0
	victory_banner.scale = Vector2(0.65, 0.65)
	victory_banner.pivot_offset = victory_banner.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(victory_banner, "modulate:a", 1.0, 0.22)
	tween.tween_property(victory_banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_interval(0.32)
	tween.chain().tween_property(victory_banner, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(func() -> void: victory_banner.visible = false)


func show_result(stones: int, level_title: String = "第一关") -> void:
	result_panel.visible = true
	result_panel.modulate.a = 0.0
	result_panel.scale = Vector2(0.82, 0.82)
	result_panel.pivot_offset = result_panel.size * 0.5
	%ResultTitle.text = "%s完成" % level_title
	%ResultText.text = "%s挑战完成\n本关灵石：%d　总计：%d" % [level_title, stones, GameState.stones]
	%ReturnButton.grab_focus()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(result_panel, "modulate:a", 1.0, 0.35)
	tween.tween_property(result_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	result_panel.visible = false
	pause_panel.visible = false
	enemy_panel.visible = false
	victory_banner.visible = false
	%ReturnButton.pressed.connect(GameState.return_to_menu)
	%ResumeButton.pressed.connect(toggle_pause)
	%RestartButton.pressed.connect(restart_level)
	%PauseMenuButton.pressed.connect(GameState.return_to_menu)
	master_slider.value = GameState.settings.master_volume
	music_slider.value = GameState.settings.music_volume
	effects_slider.value = GameState.settings.effects_volume
	reduced_motion_button.button_pressed = GameState.settings.reduced_motion
	master_slider.value_changed.connect(func(value: float) -> void: GameState.set_setting("master_volume", value))
	music_slider.value_changed.connect(func(value: float) -> void: GameState.set_setting("music_volume", value))
	effects_slider.value_changed.connect(func(value: float) -> void: GameState.set_setting("effects_volume", value))
	reduced_motion_button.toggled.connect(func(enabled: bool) -> void: GameState.set_setting("reduced_motion", enabled))


func _process(_delta: float) -> void:
	if enemy_panel.visible and Time.get_ticks_msec() >= enemy_status_expires_at:
		enemy_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not result_panel.visible:
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_panel.visible = paused
	if paused:
		%ResumeButton.grab_focus()


func restart_level() -> void:
	get_tree().paused = false
	GameState.restart_current_level()
