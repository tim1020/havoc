class_name BreakableWall
extends StaticBody2D

signal broken

@export_range(1.0, 200.0, 1.0) var health: float = 30.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-34, -55), Vector2(30, -58), Vector2(38, 55), Vector2(-38, 55)]), Color("52666a"))
	for crack in [[Vector2(-8, -50), Vector2(4, -22), Vector2(-12, 5)], [Vector2(27, -8), Vector2(8, 12), Vector2(21, 48)]]:
		draw_polyline(PackedVector2Array(crack), Color("26383d"), 4.0, true)


func take_damage(damage: float, _source_position: Vector2) -> void:
	health -= damage
	modulate = Color(1.0, 0.65, 0.5)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	if health <= 0.0:
		broken.emit()
		queue_free()
