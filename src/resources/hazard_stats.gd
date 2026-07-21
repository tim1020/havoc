class_name HazardStats
extends Resource

@export var display_name: String = "陷阱"
@export_range(0.0, 999.0, 1.0) var damage: float = 15.0
@export_range(0.0, 10.0, 0.05) var hit_cooldown_seconds: float = 0.8
