class_name AudioService
extends RefCounted

const ATTACK := preload("res://assets/audio/generated/attack_v2.wav")
const HIT := preload("res://assets/audio/generated/hit_v2.wav")
const JUMP := preload("res://assets/audio/generated/jump_v2.wav")
const THROW := preload("res://assets/audio/generated/throw_v2.wav")
const PLAYER_HURT := preload("res://assets/audio/generated/player_hurt.wav")
const ENEMY_ATTACK := preload("res://assets/audio/generated/enemy_attack.wav")
const ENEMY_THROW := preload("res://assets/audio/generated/enemy_throw.wav")
const ENEMY_HURT := preload("res://assets/audio/generated/enemy_hurt.wav")
const ENEMY_DEATH := preload("res://assets/audio/generated/enemy_death.wav")
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
