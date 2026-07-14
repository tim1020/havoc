class_name GameHud
extends CanvasLayer

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var lives_label: Label = %LivesLabel
@onready var stones_label: Label = %StonesLabel
@onready var section_label: Label = %SectionLabel
@onready var result_panel: Control = %ResultPanel
@onready var pause_panel: Control = %PausePanel
@onready var enemy_panel: Control = %EnemyPanel
@onready var enemy_name_label: Label = %EnemyNameLabel
@onready var enemy_health_bar: ProgressBar = %EnemyHealthBar
@onready var enemy_health_label: Label = %EnemyHealthLabel

var enemy_status_expires_at: int = 0


func bind_player(player: Player) -> void:
	health_bar.max_value = player.stats.max_health
	player.health_changed.connect(update_health)
	GameState.lives_changed.connect(update_lives)
	update_health(player.health, player.stats.max_health)
	update_lives(GameState.lives)


func update_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func update_lives(current_lives: int) -> void:
	lives_label.text = "毫毛  × %d" % current_lives


func update_stones(stones: int) -> void:
	stones_label.text = "灵石  %04d" % stones


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
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(section_label, "modulate:a", 0.0, 0.6)


func show_result(stones: int) -> void:
	result_panel.visible = true
	%ResultText.text = "花果山重归平静\n本关灵石：%d" % stones
	%ReturnButton.grab_focus()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	result_panel.visible = false
	pause_panel.visible = false
	enemy_panel.visible = false
	%ReturnButton.pressed.connect(GameState.return_to_menu)
	%ResumeButton.pressed.connect(toggle_pause)
	%RestartButton.pressed.connect(restart_level)
	%PauseMenuButton.pressed.connect(GameState.return_to_menu)


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
