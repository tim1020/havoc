class_name AudioDirector
extends Node

const TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/generated/menu.wav"),
	preload("res://assets/audio/generated/level_01.wav"),
	preload("res://assets/audio/generated/level_02.wav"),
	preload("res://assets/audio/generated/level_03.wav"),
	preload("res://assets/audio/generated/level_04.wav"),
	preload("res://assets/audio/generated/level_05.wav"),
	preload("res://assets/audio/generated/level_06.wav"),
]

var track_number: int = 0
var player: AudioStreamPlayer


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.stream = TRACKS[clampi(track_number, 0, TRACKS.size() - 1)]
	player.bus = &"Music"
	player.finished.connect(player.play)
	add_child(player)
	player.play()
