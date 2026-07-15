extends Control

const AUDIO_DIRECTOR := preload("res://src/audio/audio_director.gd")

@onready var start_button: Button = %StartButton
@onready var continue_button: Button = %ContinueButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	var audio = AUDIO_DIRECTOR.new()
	audio.track_number = 0
	add_child(audio)
	start_button.grab_focus()
	start_button.pressed.connect(GameState.start_new_game)
	continue_button.disabled = not GameState.has_save()
	continue_button.pressed.connect(GameState.continue_game)
	quit_button.pressed.connect(get_tree().quit)
