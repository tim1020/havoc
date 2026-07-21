class_name ArtifactCastEffect
extends Node2D

var color := Color.WHITE
var style: StringName = &"ring"
var elapsed := 0.0


func _ready() -> void:
	z_index = 8


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= 0.65:
		queue_free()


func _draw() -> void:
	var alpha := maxf(0.0, 1.0 - elapsed / 0.65)
	var tint := Color(color, alpha)
	if style == &"fan":
		for index in 3:
			draw_arc(Vector2.ZERO, 56.0 + index * 42.0 + elapsed * 90.0, -0.7, 0.7, 20, tint, 4.0, true)
	elif style == &"fire":
		draw_circle(Vector2.ZERO, 42.0 + elapsed * 45.0, Color(color, alpha * 0.18))
		draw_arc(Vector2.ZERO, 32.0 + elapsed * 40.0, 0.0, TAU, 28, tint, 4.0, true)
	else:
		draw_arc(Vector2.ZERO, 30.0 + elapsed * 60.0, 0.0, TAU, 28, tint, 5.0, true)
		draw_circle(Vector2.ZERO, 13.0, Color.WHITE)
