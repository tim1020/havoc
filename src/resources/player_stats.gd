class_name PlayerStats
extends ActorStats

@export_group("Movement")
@export_range(0.0, 2000.0, 1.0) var move_speed: float = 360.0
@export_range(0.0, 4000.0, 1.0) var acceleration: float = 1800.0
@export_range(0.0, 4000.0, 1.0) var air_acceleration: float = 1100.0
@export_range(0.0, 4000.0, 1.0) var friction: float = 2200.0
@export_range(0.0, 4000.0, 1.0) var jump_velocity: float = 850.0
@export_range(0.0, 8000.0, 1.0) var gravity: float = 2400.0
@export_range(1, 2, 1) var jump_count: int = 2

@export_group("Actions")
## 三段普通攻击的逐段伤害；空中投掷以第一段伤害为基准。
@export var combo_damage: PackedFloat32Array = PackedFloat32Array([10.0, 10.0, 10.0])
@export_range(0.1, 2.0, 0.05) var combo_reset_seconds: float = 0.65
@export_range(0.0, 100.0, 1.0) var freeze_health_cost: float = 20.0
@export_range(0.0, 10.0, 0.1) var freeze_normal_seconds: float = 3.0
@export_range(0.0, 10.0, 0.1) var freeze_boss_seconds: float = 1.5
@export_range(0.0, 10.0, 0.1) var respawn_invulnerability_seconds: float = 2.0
