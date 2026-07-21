class_name PlayerThrowProjectile
extends Node2D

enum Kind { BANANA, STAFF }

const BANANA_TEXTURE := preload("res://assets/generated/effects/player_banana_throw.png")
const STAFF_TEXTURE := preload("res://assets/generated/effects/player_staff_throw_generated.png")
const BANANA_DISPLAY_WIDTH := 42.0
const STAFF_DISPLAY_WIDTH := 88.0
const STAFF_STRIKE_RANGE := 64.0
const STAFF_STRIKE_COUNT := 3
const STAFF_STRIKE_INTERVAL := 0.16

var kind: Kind = Kind.BANANA
var direction: float = 1.0
var damage: float = 10.0
var speed: float = 720.0
var source_position: Vector2
var target: Node2D
var elapsed: float = 0.0
var staff_hits: int = 0
var next_staff_strike_at: float = 0.0
var staff_damage_applied: bool = false


func _ready() -> void:
	add_to_group(&"player_throw_projectiles")
	z_index = 7
	var projectile_sprite := Sprite2D.new()
	projectile_sprite.texture = STAFF_TEXTURE if kind == Kind.STAFF else BANANA_TEXTURE
	var display_width := STAFF_DISPLAY_WIDTH if kind == Kind.STAFF else BANANA_DISPLAY_WIDTH
	var texture_scale := display_width / projectile_sprite.texture.get_width()
	projectile_sprite.scale = Vector2(texture_scale, texture_scale)
	add_child(projectile_sprite)
	queue_redraw()


func _physics_process(delta: float) -> void:
	elapsed += delta
	if not is_instance_valid(target):
		target = null
	if kind == Kind.STAFF and target is Enemy and update_staff_attack(delta):
		return
	var travel := Vector2(direction, 0.0)
	if is_target_available():
		travel = navigation_direction(target_position())
	global_position += travel * speed * delta
	rotation = travel.angle() if kind == Kind.STAFF else rotation + delta * 12.0 * direction
	for enemy_projectile_node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		var enemy_projectile := enemy_projectile_node as Node2D
		if enemy_projectile == null or enemy_projectile.is_queued_for_deletion() or global_position.distance_to(enemy_projectile.global_position) > 42.0:
			continue
		enemy_projectile.queue_free()
		queue_free()
		return
	for enemy_node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := enemy_node as Enemy
		if enemy.dead or global_position.distance_to(enemy.global_position + Vector2(0.0, -42.0)) > 48.0:
			continue
		enemy.take_projectile_damage(damage, source_position)
		queue_free()
		return
	if elapsed >= 1.8:
		queue_free()


func update_staff_attack(delta: float) -> bool:
	if not is_target_available():
		target = null
		return false
	var enemy := target as Enemy
	var target_position := target.global_position + Vector2(0.0, -42.0)
	var travel := navigation_direction(target_position)
	if global_position.distance_to(target_position) > STAFF_STRIKE_RANGE:
		rotation = travel.angle()
		global_position += travel * speed * delta
		return true
	if elapsed >= next_staff_strike_at:
		var swing := -0.5 if staff_hits % 2 == 0 else 0.5
		rotation = travel.angle() + swing
		global_position = target_position - travel * 46.0 + Vector2(0.0, swing * 22.0)
		if not staff_damage_applied:
			enemy.take_projectile_damage(damage, source_position)
			staff_damage_applied = true
		staff_hits += 1
		next_staff_strike_at = elapsed + STAFF_STRIKE_INTERVAL
		if staff_hits >= STAFF_STRIKE_COUNT:
			queue_free()
	return true


func is_target_available() -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if target is Enemy:
		return not (target as Enemy).dead
	return true


func target_position() -> Vector2:
	var offset := Vector2(0.0, -42.0) if target is Enemy else Vector2.ZERO
	return target.global_position + offset


func navigation_direction(target_position: Vector2) -> Vector2:
	var direct := global_position.direction_to(target_position)
	var query := PhysicsRayQueryParameters2D.create(global_position, target_position, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return direct
	var turn := -1.0 if target_position.y <= global_position.y else 1.0
	return direct.rotated(turn * 0.9)
