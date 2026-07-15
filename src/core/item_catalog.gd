class_name ItemCatalog
extends RefCounted

const DEFINITIONS := {
	&"peach": preload("res://resources/items/peach.tres"),
	&"wine": preload("res://resources/items/wine.tres"),
	&"elixir": preload("res://resources/items/elixir.tres"),
	&"life_hair": preload("res://resources/items/life_hair.tres"),
	&"fire_spear": preload("res://resources/items/fire_spear.tres"),
	&"cosmic_ring": preload("res://resources/items/cosmic_ring.tres"),
	&"fire_wheels": preload("res://resources/items/fire_wheels.tres"),
	&"purple_bell": preload("res://resources/items/purple_bell.tres"),
	&"monkey_hair": preload("res://resources/items/monkey_hair.tres"),
	&"binding_rope": preload("res://resources/items/binding_rope.tres"),
	&"heaven_seal": preload("res://resources/items/heaven_seal.tres"),
}


static func get_definition(item_id: StringName) -> ItemDefinition:
	return DEFINITIONS.get(item_id) as ItemDefinition


static func shop_items() -> Array[ItemDefinition]:
	var items: Array[ItemDefinition] = []
	for item_id in [&"peach", &"wine", &"elixir", &"life_hair", &"fire_spear", &"cosmic_ring", &"fire_wheels", &"purple_bell", &"monkey_hair", &"binding_rope", &"heaven_seal"]:
		items.append(get_definition(item_id))
	return items
