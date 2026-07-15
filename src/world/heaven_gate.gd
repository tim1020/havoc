class_name HeavenGate
extends StaticBody2D

signal destroyed

const MAX_HEALTH := 500.0

var health: float = MAX_HEALTH
var broken: bool = false
var body_shape: CollisionShape2D


func _ready() -> void:
	add_to_group("heaven_gate")
	collision_layer = 1
	collision_mask = 0
	body_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(90, 430)
	body_shape.shape = shape
	body_shape.position.y = -215
	add_child(body_shape)
	queue_redraw()


func take_damage(damage: float, _source_position: Vector2) -> void:
	if broken:
		return
	health = maxf(0.0, health - damage)
	queue_redraw()
	if is_zero_approx(health):
		break_gate()


func break_gate() -> void:
	broken = true
	body_shape.set_deferred("disabled", true)
	destroyed.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)


func _draw() -> void:
	if broken:
		return
	draw_rect(Rect2(-45, -430, 90, 430), Color("b94038"), true)
	draw_rect(Rect2(-45, -430, 90, 430), Color("f2cd63"), false, 9)
	for y in range(-370, -40, 75):
		draw_line(Vector2(-32, y), Vector2(32, y + 35), Color("7b2e2b"), 6, true)
	draw_rect(Rect2(-90, -475, 180, 16), Color("17191d"), true)
	draw_rect(Rect2(-86, -471, 172 * health / MAX_HEALTH, 8), Color("e8b84e"), true)
