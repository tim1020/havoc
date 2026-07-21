class_name SectionEnemyTracker
extends RefCounted

var enemies_by_section: Dictionary = {}


func track(enemy: Enemy, section: int) -> void:
	var enemies: Dictionary = enemies_by_section.get(section, {})
	enemies[enemy.get_instance_id()] = enemy
	enemies_by_section[section] = enemies


func remove(enemy: Enemy, section: int) -> void:
	if not enemies_by_section.has(section):
		return
	var enemies: Dictionary = enemies_by_section[section]
	enemies.erase(enemy.get_instance_id())


func count(section: int) -> int:
	prune(section)
	return (enemies_by_section.get(section, {}) as Dictionary).size()


func alive_enemies(section: int) -> Array[Enemy]:
	prune(section)
	var result: Array[Enemy] = []
	for enemy in (enemies_by_section.get(section, {}) as Dictionary).values():
		result.append(enemy as Enemy)
	return result


func snapshot(section: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy in alive_enemies(section):
		result.append({
			"id": enemy.get_instance_id(),
			"type": enemy.stats.display_name,
			"behavior": Enemy.Behavior.keys()[enemy.behavior],
			"position": enemy.global_position,
		})
	return result


func prune(section: int) -> void:
	if not enemies_by_section.has(section):
		return
	var enemies: Dictionary = enemies_by_section[section]
	for id in enemies.keys():
		var enemy := enemies[id] as Enemy
		if not is_instance_valid(enemy) or enemy.dead:
			enemies.erase(id)
