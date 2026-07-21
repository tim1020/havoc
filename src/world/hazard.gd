class_name Hazard
extends Area2D

@export var stats: HazardStats

var next_hit_at: int = 0


func _ready() -> void:
	assert(stats != null, "HazardStats is required")
	body_entered.connect(on_body_entered)


func on_body_entered(body: Node2D) -> void:
	if not body is Player or Time.get_ticks_msec() < next_hit_at:
		return
	next_hit_at = Time.get_ticks_msec() + int(stats.hit_cooldown_seconds * 1000.0)
	body.take_damage(stats.damage, global_position)
