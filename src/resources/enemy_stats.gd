class_name EnemyStats
extends ActorStats

@export_group("Movement")
@export_range(0.0, 1000.0, 1.0) var move_speed: float = 180.0
@export_range(0.0, 2000.0, 1.0) var gravity: float = 2400.0
@export_range(0.0, 2000.0, 1.0) var detection_range: float = 420.0
@export_range(0.0, 1000.0, 1.0) var attack_range: float = 90.0

@export_group("Rewards")
@export_range(0, 10000, 1) var spirit_stones: int = 0
@export var is_boss: bool = false
