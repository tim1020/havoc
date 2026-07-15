extends Node

signal lives_changed(current_lives: int)
signal stones_changed(current_stones: int)
signal artifacts_changed(current_artifacts: Array[StringName])
signal level_requested(level_path: String)

const FIRST_LEVEL := "res://src/levels/level_01/level_01.tscn"
const SECOND_LEVEL := "res://src/levels/level_02/level_02.tscn"
const THIRD_LEVEL := "res://src/levels/level_03/level_03.tscn"
const FOURTH_LEVEL := "res://src/levels/level_04/level_04.tscn"
const FIFTH_LEVEL := "res://src/levels/level_05/level_05.tscn"
const SIXTH_LEVEL := "res://src/levels/level_06/level_06.tscn"
const SAVE_PATH := "user://havoc_save.json"
const MAX_LIVES := 3
const MAX_ARTIFACTS := 3

var current_level_path: String = FIRST_LEVEL
var lives: int = 3
var stones: int = 0
var artifacts: Array[StringName] = []
var unlocked_level: int = 1
var current_level: int = 1
var life_bought_this_level: bool = false
var has_staff: bool = false
var game_completed: bool = false
var save_path: String = SAVE_PATH
var settings := {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"effects_volume": 0.9,
	"reduced_motion": false,
}


func _ready() -> void:
	if not load_game():
		apply_audio_settings()


func set_setting(key: String, value: Variant) -> void:
	if not settings.has(key):
		return
	settings[key] = bool(value) if key == "reduced_motion" else clampf(float(value), 0.0, 1.0)
	apply_audio_settings()
	save_game()


func apply_audio_settings() -> void:
	ensure_audio_bus(&"Music")
	ensure_audio_bus(&"SFX")
	set_bus_volume(&"Master", float(settings.master_volume))
	set_bus_volume(&"Music", float(settings.music_volume))
	set_bus_volume(&"SFX", float(settings.effects_volume))


func ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func set_bus_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, is_zero_approx(value))
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


func start_new_game() -> void:
	lives = 3
	stones = 0
	artifacts.clear()
	unlocked_level = 1
	current_level = 1
	life_bought_this_level = false
	has_staff = false
	game_completed = false
	current_level_path = FIRST_LEVEL
	emit_resource_signals()
	save_game()
	level_requested.emit(current_level_path)
	get_tree().change_scene_to_file(current_level_path)


func consume_life() -> bool:
	if lives <= 0:
		return false
	lives -= 1
	lives_changed.emit(lives)
	save_game()
	return true


func add_life() -> bool:
	if lives >= MAX_LIVES:
		return false
	lives += 1
	lives_changed.emit(lives)
	save_game()
	return true


func add_stones(amount: int) -> void:
	stones = maxi(0, stones + amount)
	stones_changed.emit(stones)
	save_game()


func spend_stones(amount: int) -> bool:
	if amount < 0 or stones < amount:
		return false
	stones -= amount
	stones_changed.emit(stones)
	save_game()
	return true


func pickup_artifact(item_id: StringName) -> void:
	if artifacts.size() >= MAX_ARTIFACTS:
		artifacts.pop_front()
	artifacts.append(item_id)
	artifacts_changed.emit(artifacts.duplicate())
	save_game()


func purchase_artifact(item_id: StringName, price: int) -> bool:
	if artifacts.size() >= MAX_ARTIFACTS or not spend_stones(price):
		return false
	artifacts.append(item_id)
	artifacts_changed.emit(artifacts.duplicate())
	save_game()
	return true


func discard_artifact(index: int) -> bool:
	if index < 0 or index >= artifacts.size():
		return false
	artifacts.remove_at(index)
	artifacts_changed.emit(artifacts.duplicate())
	save_game()
	return true


func pop_artifact() -> StringName:
	if artifacts.is_empty():
		return &""
	var item_id: StringName = artifacts.pop_front()
	artifacts_changed.emit(artifacts.duplicate())
	save_game()
	return item_id


func purchase_life(price: int) -> bool:
	if life_bought_this_level or lives >= MAX_LIVES or stones < price:
		return false
	stones -= price
	lives += 1
	life_bought_this_level = true
	stones_changed.emit(stones)
	lives_changed.emit(lives)
	save_game()
	return true


func begin_level(level_number: int, level_path: String) -> void:
	current_level = level_number
	current_level_path = level_path
	life_bought_this_level = false
	save_game()


func unlock_level(level_number: int) -> void:
	unlocked_level = maxi(unlocked_level, level_number)
	save_game()


func save_game(path: String = "") -> Error:
	var target_path := save_path if path.is_empty() else path
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var artifact_strings: Array[String] = []
	for item_id in artifacts:
		artifact_strings.append(String(item_id))
	file.store_string(JSON.stringify({
		"lives": lives,
		"stones": stones,
		"artifacts": artifact_strings,
		"unlocked_level": unlocked_level,
		"current_level": current_level,
		"current_level_path": current_level_path,
		"life_bought_this_level": life_bought_this_level,
		"has_staff": has_staff,
		"game_completed": game_completed,
		"settings": settings,
	}))
	return OK


func load_game(path: String = "") -> bool:
	var target_path := save_path if path.is_empty() else path
	if not FileAccess.file_exists(target_path):
		return false
	var file := FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	lives = clampi(int(parsed.get("lives", 3)), 0, MAX_LIVES)
	stones = maxi(0, int(parsed.get("stones", 0)))
	artifacts.clear()
	for item_id in parsed.get("artifacts", []):
		if artifacts.size() < MAX_ARTIFACTS and ItemCatalog.get_definition(StringName(item_id)) != null:
			artifacts.append(StringName(item_id))
	unlocked_level = maxi(1, int(parsed.get("unlocked_level", 1)))
	current_level = clampi(int(parsed.get("current_level", 1)), 1, unlocked_level)
	current_level_path = String(parsed.get("current_level_path", FIRST_LEVEL))
	life_bought_this_level = bool(parsed.get("life_bought_this_level", false))
	has_staff = bool(parsed.get("has_staff", false))
	game_completed = bool(parsed.get("game_completed", false))
	var loaded_settings = parsed.get("settings", {})
	if loaded_settings is Dictionary:
		for key in ["master_volume", "music_volume", "effects_volume"]:
			settings[key] = clampf(float(loaded_settings.get(key, settings[key])), 0.0, 1.0)
		settings.reduced_motion = bool(loaded_settings.get("reduced_motion", settings.reduced_motion))
	apply_audio_settings()
	emit_resource_signals()
	return true


func continue_game() -> void:
	if load_game():
		get_tree().change_scene_to_file(current_level_path)


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func emit_resource_signals() -> void:
	lives_changed.emit(lives)
	stones_changed.emit(stones)
	artifacts_changed.emit(artifacts.duplicate())


func unlock_staff() -> void:
	has_staff = true
	save_game()


func complete_game() -> void:
	game_completed = true
	unlocked_level = maxi(unlocked_level, 6)
	current_level = 6
	save_game()


func advance_to_level(level_number: int, level_path: String) -> void:
	unlocked_level = maxi(unlocked_level, level_number)
	current_level = level_number
	current_level_path = level_path
	life_bought_this_level = false
	save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file(level_path)


func restart_current_level() -> void:
	get_tree().change_scene_to_file(current_level_path)


func return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/main_menu/main_menu.tscn")
