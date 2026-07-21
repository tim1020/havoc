extends Node

const TEST_SAVE := "/tmp/havoc_phase_07_save.json"
const AUDIO_PATHS := [
	"res://assets/audio/generated/menu.wav",
	"res://assets/audio/generated/level_01.wav",
	"res://assets/audio/generated/level_02.wav",
	"res://assets/audio/generated/level_03.wav",
	"res://assets/audio/generated/level_04.wav",
	"res://assets/audio/generated/level_05.wav",
	"res://assets/audio/generated/level_06.wav",
	"res://assets/audio/generated/attack.wav",
	"res://assets/audio/generated/hit.wav",
	"res://assets/audio/generated/pickup.wav",
	"res://assets/audio/generated/victory.wav",
]
const LEVEL_PATHS := [
	"res://src/levels/level_01/level_01.tscn",
	"res://src/levels/level_02/level_02.tscn",
	"res://src/levels/level_03/level_03.tscn",
	"res://src/levels/level_04/level_04.tscn",
	"res://src/levels/level_05/level_05.tscn",
	"res://src/levels/level_06/level_06.tscn",
]

var failures: Array[String] = []


func _ready() -> void:
	GameState.save_path = TEST_SAVE
	await run_checks()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func run_checks() -> void:
	var audio_loaded := true
	var audio_has_data := true
	for path in AUDIO_PATHS:
		var stream := load(path) as AudioStreamWAV
		audio_loaded = audio_loaded and stream != null
		audio_has_data = audio_has_data and stream != null and stream.data.size() > 1000 and stream.get_length() > 0.05
	check(audio_loaded, "菜单、六关音乐和四类音效均可加载")
	check(audio_has_data, "11个音频资源均包含实际PCM采样而非占位")
	check(AudioDirector.TRACKS.size() == 7, "音乐控制器覆盖菜单和六关独立曲目")

	var director := AudioDirector.new()
	director.track_number = 6
	add_child(director)
	await get_tree().process_frame
	check(director.player.playing and director.player.bus == &"Music", "关卡音乐通过Music总线自动播放")
	var sfx := AudioService.play_sfx(self, AudioService.ATTACK)
	check(sfx.playing and sfx.bus == &"SFX", "战斗音效通过SFX总线播放")

	GameState.set_setting("master_volume", 0.65)
	GameState.set_setting("music_volume", 0.45)
	GameState.set_setting("effects_volume", 0.35)
	GameState.set_setting("reduced_motion", true)
	check(AudioServer.get_bus_index(&"Music") >= 0 and AudioServer.get_bus_index(&"SFX") >= 0, "Music和SFX混音总线已建立")
	GameState.settings.master_volume = 1.0
	GameState.settings.music_volume = 1.0
	GameState.settings.effects_volume = 1.0
	GameState.settings.reduced_motion = false
	check(GameState.load_game(), "设置存档可重新读取")
	check(is_equal_approx(GameState.settings.master_volume, 0.65) and is_equal_approx(GameState.settings.music_volume, 0.45) and is_equal_approx(GameState.settings.effects_volume, 0.35), "三路音量设置持久化")
	check(GameState.settings.reduced_motion, "减少界面动画设置持久化")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))), 0.45), "读取存档后立即恢复Music总线音量")

	var hud_scene := load("res://src/ui/hud/hud.tscn") as PackedScene
	var hud := hud_scene.instantiate() as GameHud
	add_child(hud)
	await get_tree().process_frame
	check(hud.master_slider != null and hud.music_slider != null and hud.effects_slider != null, "暂停菜单提供总音量、音乐和音效调节")
	check(hud.reduced_motion_button.button_pressed, "暂停菜单同步减少界面动画设置")
	hud.set_section("最终验收")
	check(is_equal_approx(hud.section_label.modulate.a, 1.0), "减少动画模式不执行章节标题淡出")

	var levels_loaded := true
	for path in LEVEL_PATHS:
		levels_loaded = levels_loaded and load(path) is PackedScene
	check(levels_loaded, "第一至第六关场景入口均可加载")
	check(FileAccess.file_exists("res://export_presets.cfg"), "macOS导出预设已纳入项目")
	var menu_scene := load("res://src/ui/main_menu/main_menu.tscn") as PackedScene
	var menu = menu_scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu.find_children("*", "AudioDirector", true, false).size() == 1, "主菜单使用独立循环音乐")
	check(menu.get_node("Panel/Margin/Content/Subtitle").text.contains("六关完整版"), "主菜单明确标识完整六关版本")

	if is_instance_valid(sfx):
		sfx.stop()
		sfx.queue_free()
	director.queue_free()
	hud.queue_free()
	menu.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	if failures.is_empty():
		print("PHASE 07 CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("PHASE 07 CHECKS FAILED: ", failures.size())
		get_tree().quit(1)
