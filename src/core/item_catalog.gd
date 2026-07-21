class_name ItemCatalog
extends RefCounted

const DEFINITIONS := {
	&"peach": preload("res://resources/items/peach.tres"),
	&"wine": preload("res://resources/items/wine.tres"),
	&"elixir": preload("res://resources/items/elixir.tres"),
	&"life_hair": preload("res://resources/items/life_hair.tres"),
	&"freeze_talisman": preload("res://resources/items/freeze_talisman.tres"),
	&"invisibility_talisman": preload("res://resources/items/invisibility_talisman.tres"),
	&"samadhi_fire": preload("res://resources/items/samadhi_fire.tres"),
	&"banana_fan": preload("res://resources/items/banana_fan.tres"),
	&"purple_bell": preload("res://resources/items/purple_bell.tres"),
}


static func get_definition(item_id: StringName) -> ItemDefinition:
	return DEFINITIONS.get(item_id) as ItemDefinition


static func shop_items() -> Array[ItemDefinition]:
	var items: Array[ItemDefinition] = []
	for item_id in [&"life_hair", &"freeze_talisman", &"invisibility_talisman", &"samadhi_fire", &"banana_fan", &"purple_bell"]:
		items.append(get_definition(item_id))
	return items
