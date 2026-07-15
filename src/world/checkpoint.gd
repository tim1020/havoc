class_name Checkpoint
extends Area2D

@export var checkpoint_position: Vector2
var activated := false


func _ready() -> void:
	add_to_group("checkpoints")
	collision_layer = 0
	collision_mask = 2
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 180)
	shape_node.shape = shape
	shape_node.position.y = -70
	add_child(shape_node)
	body_entered.connect(activate)
	queue_redraw()


func activate(body: Node2D) -> void:
	if activated or not body is Player:
		return
	activated = true
	(body as Player).set_checkpoint(checkpoint_position)
	queue_redraw()


func _draw() -> void:
	var color := Color("ffd34f") if activated else Color("7f9167")
	draw_line(Vector2(0, 0), Vector2(0, -105), color, 7.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -105), Vector2(58, -88), Vector2(0, -68)]), color)
	draw_circle(Vector2.ZERO, 15.0, color)
