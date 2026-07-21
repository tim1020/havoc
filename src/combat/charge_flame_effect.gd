class_name ChargeFlameEffect
extends Node2D

enum Mode { AURA, BURST }

var mode: Mode = Mode.AURA
var direction: float = 1.0
var elapsed: float = 0.0
var lifetime: float = 0.48


func _ready() -> void:
	z_index = 7
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if mode == Mode.BURST:
		position.x += direction * 620.0 * delta
		modulate.a = maxf(0.0, 1.0 - elapsed / lifetime)
		if elapsed >= lifetime:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	if mode == Mode.AURA:
		for index in 8:
			var angle := TAU * index / 8.0 + elapsed * 1.8
			var radius := Vector2(48.0, 68.0)
			var flame_position := Vector2(cos(angle) * radius.x, sin(angle) * radius.y - 48.0)
			draw_flame(flame_position, 0.72 + sin(elapsed * 8.0 + index) * 0.12)
	else:
		for index in 14:
			var progress := float(index) / 13.0
			var x := direction * (progress * 260.0 - 70.0)
			var y := -48.0 + sin(index * 2.4 + elapsed * 18.0) * (18.0 + progress * 42.0)
			draw_flame(Vector2(x, y), 0.65 + progress * 0.85)


func draw_flame(center: Vector2, flame_scale: float) -> void:
	var width := 15.0 * flame_scale
	var height := 34.0 * flame_scale
	var flicker := sin(elapsed * 14.0 + center.x * 0.03) * 5.0
	var outer := PackedVector2Array([
		center + Vector2(-width, height * 0.45),
		center + Vector2(-width * 0.7, -height * 0.15),
		center + Vector2(flicker, -height),
		center + Vector2(width * 0.75, -height * 0.05),
		center + Vector2(width, height * 0.45),
	])
	draw_colored_polygon(outer, Color("ff5426"))
	var inner := PackedVector2Array([
		center + Vector2(-width * 0.45, height * 0.35),
		center + Vector2(0, -height * 0.48),
		center + Vector2(width * 0.48, height * 0.35),
	])
	draw_colored_polygon(inner, Color("ffd23f"))
