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

@export_group("Combat Mechanics")
@export_range(0.0, 1.0, 0.05) var front_damage_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.1) var contact_slow_seconds: float = 0.0
@export_range(0.0, 10.0, 0.1) var contact_root_seconds: float = 0.0
@export_range(0.0, 10.0, 0.1) var contact_confusion_seconds: float = 0.0
@export_range(0.0, 1000.0, 1.0) var pull_distance: float = 0.0
@export_range(0.0, 1000.0, 1.0) var disguise_reveal_distance: float = 0.0
@export_range(0.0, 10.0, 0.1) var ghost_cycle_seconds: float = 0.0
@export_range(0.0, 10.0, 0.1) var ghost_solid_seconds: float = 0.0
@export var phase_thresholds: PackedFloat32Array = PackedFloat32Array([0.5])
@export_range(1.0, 3.0, 0.05) var phase_damage_multiplier: float = 1.5
