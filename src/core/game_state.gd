extends Node

signal lives_changed(current_lives: int)
signal level_requested(level_path: String)

const FIRST_LEVEL := "res://src/levels/level_01/level_01.tscn"

var current_level_path: String = FIRST_LEVEL
var lives: int = 3


func start_new_game() -> void:
	lives = 3
	current_level_path = FIRST_LEVEL
	lives_changed.emit(lives)
	level_requested.emit(current_level_path)
	get_tree().change_scene_to_file(current_level_path)


func consume_life() -> bool:
	if lives <= 0:
		return false
	lives -= 1
	lives_changed.emit(lives)
	return true


func restart_current_level() -> void:
	get_tree().change_scene_to_file(current_level_path)


func return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/main_menu/main_menu.tscn")
