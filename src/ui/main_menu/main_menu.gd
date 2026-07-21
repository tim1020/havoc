extends Control

const AUDIO_DIRECTOR := preload("res://src/audio/audio_director.gd")
# 隐藏入口使用角色移动动作，而不是固定物理方向键。
const MOCK_SEQUENCE: Array[StringName] = [&"move_left", &"move_right", &"move_left", &"move_right"]

@onready var start_button: Button = %StartButton
@onready var continue_button: Button = %ContinueButton
@onready var quit_button: Button = %QuitButton
@onready var mock_panel: PanelContainer = %MockPanel
@onready var mock_lives: SpinBox = %MockLives
@onready var mock_level: SpinBox = %MockLevel
@onready var mock_start_button: Button = %MockStartButton

var mock_sequence_index: int = 0


func _ready() -> void:
	var audio = AUDIO_DIRECTOR.new()
	audio.track_number = 0
	add_child(audio)
	mock_panel.visible = false
	start_button.grab_focus()
	start_button.pressed.connect(GameState.start_new_game)
	continue_button.disabled = not GameState.has_save()
	continue_button.pressed.connect(GameState.continue_game)
	quit_button.pressed.connect(get_tree().quit)
	mock_start_button.pressed.connect(start_mock_game)


func _unhandled_input(event: InputEvent) -> void:
	if mock_panel.visible or not event.is_pressed() or event.is_echo():
		return
	var action: StringName
	if event.is_action_pressed(&"move_left"):
		action = &"move_left"
	elif event.is_action_pressed(&"move_right"):
		action = &"move_right"
	else:
		mock_sequence_index = 0
		return
	if action == MOCK_SEQUENCE[mock_sequence_index]:
		mock_sequence_index += 1
	else:
		mock_sequence_index = 1 if action == MOCK_SEQUENCE[0] else 0
	if mock_sequence_index == MOCK_SEQUENCE.size():
		show_mock_panel()
	get_viewport().set_input_as_handled()


func show_mock_panel() -> void:
	mock_sequence_index = 0
	mock_lives.value = 3
	mock_level.value = 1
	mock_panel.visible = true
	mock_lives.get_line_edit().grab_focus()


func start_mock_game() -> void:
	GameState.start_mock_game(roundi(mock_lives.value), roundi(mock_level.value))
