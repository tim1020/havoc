class_name AudioService
extends RefCounted

const ATTACK := preload("res://assets/audio/generated/attack.wav")
const HIT := preload("res://assets/audio/generated/hit.wav")
const PICKUP := preload("res://assets/audio/generated/pickup.wav")
const VICTORY := preload("res://assets/audio/generated/victory.wav")


static func play_sfx(parent: Node, stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
	return player
