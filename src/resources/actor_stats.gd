class_name ActorStats
extends Resource

@export_group("Identity")
@export var display_name: String

@export_group("Combat")
@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0
@export_range(0.0, 1000.0, 1.0) var contact_damage: float = 0.0
@export_range(0.0, 10.0, 0.05) var invulnerability_seconds: float = 0.5
@export_range(0.0, 2000.0, 1.0) var knockback_force: float = 220.0
