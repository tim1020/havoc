class_name LineHazard
extends Hazard

enum Kind { SPIKES, ELECTRIC, FIRE, VORTEX, ROOT, PEACH_BOMB, WATER, POLLEN, LIGHTNING, WIND, LASER, GOLD_ARRAY }

@export var kind: Kind = Kind.SPIKES
@export var visual_size: Vector2 = Vector2(90, 50)
@export_range(0.0, 10.0, 0.1) var slow_seconds: float = 0.0
@export_range(0.0, 10.0, 0.1) var confusion_seconds: float = 0.0
@export_range(-1000.0, 1000.0, 1.0) var push_force: float = 0.0

var elapsed: float = 0.0


func _ready() -> void:
	super()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if not is_zero_approx(push_force):
		for body in get_overlapping_bodies():
			if body is Player:
				(body as Player).velocity.x += push_force * delta
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.SPIKES:
			for index in 7:
				var x := -visual_size.x * 0.5 + index * visual_size.x / 6.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 8, visual_size.y * 0.5), Vector2(x, -visual_size.y * 0.5), Vector2(x + 8, visual_size.y * 0.5)]), Color("b75a79"))
		Kind.ELECTRIC:
			var pulse := 0.65 + sin(elapsed * 9.0) * 0.25
			draw_rect(Rect2(-visual_size * 0.5, visual_size), Color(0.3, 0.8, 1.0, pulse), false, 5)
			for index in 4:
				var x := -visual_size.x * 0.4 + index * visual_size.x * 0.26
				draw_polyline(PackedVector2Array([Vector2(x, 18), Vector2(x + 12, -5), Vector2(x - 2, -20)]), Color("d8f8ff"), 4, true)
		Kind.FIRE:
			var flame_y := sin(elapsed * 7.0) * 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(-24, 22), Vector2(-8, -24 + flame_y), Vector2(2, -5), Vector2(18, -30 - flame_y), Vector2(26, 22)]), Color("61d8ef"))
		Kind.VORTEX:
			for ring in 3:
				draw_arc(Vector2.ZERO, 16.0 + ring * 12.0, elapsed * (ring + 1), elapsed * (ring + 1) + PI * 1.4, 24, Color("a767cc"), 6, true)
		Kind.ROOT:
			draw_polyline(PackedVector2Array([Vector2(-visual_size.x * 0.5, 12), Vector2(-18, -8), Vector2(8, 10), Vector2(visual_size.x * 0.5, -5)]), Color("795032"), 9, true)
		Kind.PEACH_BOMB:
			draw_circle(Vector2.ZERO, 18.0 + sin(elapsed * 8.0) * 3.0, Color("e9859d"))
			draw_line(Vector2(0, -18), Vector2(10, -30), Color("547947"), 6, true)
		Kind.WATER:
			draw_rect(Rect2(-visual_size * 0.5, visual_size), Color(0.34, 0.72, 0.82, 0.62), true)
			for index in 4:
				draw_arc(Vector2(-visual_size.x * 0.35 + index * visual_size.x * 0.23, 0), 13, 0, PI, 12, Color("c5f4f1"), 4, true)
		Kind.POLLEN:
			for index in 7:
				var angle := elapsed + index * TAU / 7.0
				draw_circle(Vector2(cos(angle) * 30.0, sin(angle * 1.4) * 24.0), 7, Color(1.0, 0.55, 0.75, 0.62))
		Kind.LIGHTNING:
			var pulse := 0.6 + sin(elapsed * 12.0) * 0.35
			draw_polyline(PackedVector2Array([Vector2(-12, -visual_size.y * 0.5), Vector2(15, -35), Vector2(-8, 5), Vector2(18, visual_size.y * 0.5)]), Color(1.0, 0.95, 0.55, pulse), 10, true)
		Kind.WIND:
			for index in 4:
				var y := -45.0 + index * 30.0
				draw_line(Vector2(-visual_size.x * 0.45, y), Vector2(visual_size.x * 0.45, y), Color(0.8, 0.95, 1.0, 0.55), 5, true)
		Kind.LASER:
			draw_rect(Rect2(-visual_size * 0.5, visual_size), Color(1.0, 0.32, 0.35, 0.35 + sin(elapsed * 8.0) * 0.2), true)
		Kind.GOLD_ARRAY:
			for ring in 3:
				draw_arc(Vector2.ZERO, 18.0 + ring * 14.0, elapsed + ring, elapsed + ring + PI * 1.55, 24, Color("f4cf52"), 6, true)


func on_body_entered(body: Node2D) -> void:
	var can_apply := body is Player and Time.get_ticks_msec() >= next_hit_at
	super(body)
	if can_apply and slow_seconds > 0.0:
		(body as Player).apply_slow(slow_seconds)
	if can_apply and confusion_seconds > 0.0:
		(body as Player).apply_confusion(confusion_seconds)
