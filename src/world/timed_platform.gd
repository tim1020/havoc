class_name TimedPlatform
extends AnimatableBody2D

var visual_size: Vector2 = Vector2(220, 24)
var collapse_delay: float = 3.0
var surface_color: Color = Color("7b5d45")
var collapsed: bool = false
var generation: int = 0

var collision: CollisionShape2D
var trigger: Area2D
var visuals: Node2D


func _ready() -> void:
	add_to_group("timed_platforms")
	collision_layer = 1
	collision_mask = 0
	build_collision()
	build_visuals()
	build_trigger()


func build_collision() -> void:
	collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = visual_size
	collision.shape = shape
	add_child(collision)


func build_visuals() -> void:
	visuals = Node2D.new()
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([
		-visual_size * 0.5,
		Vector2(visual_size.x * 0.5, -visual_size.y * 0.5),
		visual_size * 0.5,
		Vector2(-visual_size.x * 0.5, visual_size.y * 0.5),
	])
	fill.color = surface_color
	visuals.add_child(fill)
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(-visual_size.x * 0.5, -visual_size.y * 0.5), Vector2(visual_size.x * 0.5, -visual_size.y * 0.5)])
	line.width = 5.0
	line.default_color = Color("f2ce4e")
	line.add_to_group("standable_surfaces")
	visuals.add_child(line)
	add_child(visuals)


func build_trigger() -> void:
	trigger = Area2D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	var trigger_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(visual_size.x, 70.0)
	trigger_shape.position.y = -visual_size.y * 0.5 - 35.0
	trigger_shape.shape = shape
	trigger.add_child(trigger_shape)
	trigger.body_entered.connect(start_collapse)
	add_child(trigger)


func start_collapse(body: Node2D) -> void:
	if collapsed or not body is Player:
		return
	generation += 1
	var current_generation := generation
	await get_tree().create_timer(collapse_delay).timeout
	if current_generation != generation or collapsed:
		return
	collapsed = true
	collision.set_deferred("disabled", true)
	trigger.set_deferred("monitoring", false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visuals, "position:y", 120.0, 0.45)
	tween.tween_property(visuals, "modulate:a", 0.15, 0.45)
	await get_tree().create_timer(2.0).timeout
	visuals.position.y = 0.0
	visuals.modulate = Color.WHITE
	collision.set_deferred("disabled", false)
	trigger.set_deferred("monitoring", true)
	collapsed = false
