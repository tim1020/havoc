class_name PursuitSeal
extends Area2D

var active := false
var start_position := Vector2.ZERO


func _ready() -> void:
	add_to_group("pursuit_seal")
	collision_layer = 0
	collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(90, 620)
	collision.shape = shape
	add_child(collision)
	body_entered.connect(func(body: Node2D) -> void:
		if active and body is Player:
			(body as Player).take_damage(999.0, global_position)
	)
	start_position = position
	var timer := Timer.new()
	timer.wait_time = 10.0
	timer.timeout.connect(begin_sweep)
	add_child(timer)
	timer.start()
	queue_redraw()


func _process(delta: float) -> void:
	if active:
		position.x += 430.0 * delta
		if position.x > start_position.x + 1500.0:
			active = false
			position = start_position
			visible = false


func begin_sweep() -> void:
	position = start_position
	active = true
	visible = true


func _draw() -> void:
	draw_rect(Rect2(-45, -310, 90, 620), Color(1.0, 0.78, 0.22, 0.72), true)
	for y in range(-260, 280, 70):
		draw_circle(Vector2.ZERO + Vector2(0, y), 20, Color("fff0a0"), false, 6)
