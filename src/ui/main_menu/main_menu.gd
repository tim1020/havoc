extends Control

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	start_button.grab_focus()
	start_button.pressed.connect(GameState.start_new_game)
	quit_button.pressed.connect(get_tree().quit)
