class_name GameHud
extends CanvasLayer

signal game_over_continue

const INTRO_CHARACTER_SECONDS := 0.09

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var lives_label: Label = %LivesLabel
@onready var stones_label: Label = %StonesLabel
@onready var artifact_labels: Array[Label] = [%Artifact1, %Artifact2, %Artifact3, %Artifact4, %Artifact5]
@onready var section_label: Label = %SectionLabel
@onready var go_label: Label = %GoLabel
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
var go_tween: Tween
var artifact_selected: bool = false
var game_over_active: bool = false
var game_over_ready: bool = false
var game_over_overlay: Control


func bind_player(player: Player) -> void:
	health_bar.max_value = player.stats.max_health
	player.health_changed.connect(update_health)
	GameState.lives_changed.connect(update_lives)
	GameState.stones_changed.connect(update_stones)
	GameState.artifacts_changed.connect(update_artifacts)
	player.artifact_selection_changed.connect(set_artifact_selected)
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
			artifact_labels[index].text = ("▶ " if artifact_selected and index == 0 else "") + (item.display_name if item != null else "?")
			artifact_labels[index].modulate = item.color if item != null else Color.WHITE
		else:
			artifact_labels[index].text = "空"
			artifact_labels[index].modulate = Color(0.65, 0.65, 0.65)


func set_artifact_selected(selected: bool) -> void:
	artifact_selected = selected and not GameState.artifacts.is_empty()
	update_artifacts(GameState.artifacts)


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


func show_go_prompt() -> void:
	go_label.visible = true
	go_label.modulate.a = 1.0
	if GameState.settings.reduced_motion:
		return
	if go_tween != null:
		go_tween.kill()
	go_tween = create_tween().set_loops()
	go_tween.tween_property(go_label, "modulate:a", 0.35, 0.45)
	go_tween.tween_property(go_label, "modulate:a", 1.0, 0.45)


func hide_go_prompt() -> void:
	if go_tween != null:
		go_tween.kill()
	go_tween = null
	go_label.visible = false


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
	# 结算面板会留在过关商店背后；禁止键盘焦点，避免离店的跳跃键同时触发返回主菜单。
	%ReturnButton.focus_mode = Control.FOCUS_NONE
	%ReturnButton.release_focus()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(result_panel, "modulate:a", 1.0, 0.35)
	tween.tween_property(result_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_hud")
	result_panel.visible = false
	pause_panel.visible = false
	enemy_panel.visible = false
	victory_banner.visible = false
	go_label.visible = false
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


func _input(event: InputEvent) -> void:
	if not game_over_active or not event is InputEventKey or not event.is_pressed() or event.echo:
		return
	get_viewport().set_input_as_handled()
	if game_over_ready:
		game_over_ready = false
		game_over_continue.emit()


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


func play_level_intro(story: String) -> void:
	var overlay := create_fullscreen_overlay(Color(0.035, 0.025, 0.02, 0.94))
	var story_label := Label.new()
	story_label.text = story
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.add_theme_font_size_override("font_size", 30)
	story_label.add_theme_color_override("font_color", Color("f7e7bd"))
	story_label.set_anchors_preset(Control.PRESET_CENTER)
	story_label.position = Vector2(-440.0, -130.0)
	story_label.size = Vector2(880.0, 260.0)
	overlay.add_child(story_label)
	if GameState.settings.reduced_motion:
		story_label.visible_characters = -1
	else:
		story_label.visible_characters = 0
		for count in story.length():
			story_label.visible_characters = count + 1
			await get_tree().create_timer(INTRO_CHARACTER_SECONDS, true).timeout
	await get_tree().create_timer(1.0, true).timeout
	overlay.queue_free()
	get_tree().paused = false


func show_game_over() -> void:
	if game_over_active:
		return
	game_over_active = true
	game_over_ready = false
	get_viewport().gui_release_focus()
	get_tree().paused = true
	game_over_overlay = create_fullscreen_overlay(Color(0.02, 0.01, 0.01, 0.78))
	var title := create_centered_overlay_label("Game Over", 58, -55.0)
	title.add_theme_color_override("font_color", Color("e84b43"))
	game_over_overlay.add_child(title)
	var prompt := create_centered_overlay_label("按任意键继续", 24, 40.0)
	prompt.visible = false
	game_over_overlay.add_child(prompt)
	await get_tree().create_timer(1.0, true).timeout
	if not is_instance_valid(prompt):
		return
	prompt.visible = true
	game_over_ready = true


func create_fullscreen_overlay(color: Color) -> Control:
	var overlay := Control.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = color
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	add_child(overlay)
	return overlay


func create_centered_overlay_label(text_value: String, font_size: int, y_offset: float) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(-320.0, y_offset - 45.0)
	label.size = Vector2(640.0, 90.0)
	return label
