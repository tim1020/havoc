class_name ItemPickup
extends Area2D

signal collected(item: ItemDefinition)

@export var item: ItemDefinition

var base_y: float
var elapsed: float = 0.0


func _ready() -> void:
	assert(item != null, "ItemDefinition is required")
	base_y = position.y
	$Name.text = item.display_name
	body_entered.connect(on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	position.y = base_y + sin(elapsed * 3.0) * 5.0
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 24.0, Color(item.color, 0.2))
	draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 32, item.color, 4.0, true)
	if item.category == ItemDefinition.Category.HEALING:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -15), Vector2(14, -2), Vector2(8, 15), Vector2(-8, 15), Vector2(-14, -2)]), item.color)
		draw_line(Vector2(0, -13), Vector2(8, -22), Color("6a8f4e"), 4.0, true)
	elif item.category == ItemDefinition.Category.ARTIFACT:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(15, 0), Vector2(0, 16), Vector2(-15, 0)]), item.color)
		draw_circle(Vector2.ZERO, 5.0, Color("fff0b0"))
	else:
		draw_line(Vector2(-8, 15), Vector2(7, -15), item.color, 5.0, true)


func on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var player := body as Player
	if item.category == ItemDefinition.Category.HEALING:
		if player.health < player.stats.max_health:
			player.apply_healing_item(item)
		else:
			GameState.pickup_artifact(item.id)
	elif item.category == ItemDefinition.Category.LIFE:
		if not GameState.add_life():
			return
	else:
		GameState.pickup_artifact(item.id)
	AudioService.play_sfx(get_tree().current_scene, AudioService.PICKUP, -3.0)
	collected.emit(item)
	queue_free()
