class_name ItemDefinition
extends Resource

enum Category {
	HEALING,
	LIFE,
	ARTIFACT,
}

@export var id: StringName
@export var display_name: String
@export var category: Category
@export_range(0, 1000, 1) var price: int
@export_range(0.0, 200.0, 1.0) var power: float
@export_range(0.0, 20.0, 0.1) var duration: float
@export var color: Color = Color.WHITE
