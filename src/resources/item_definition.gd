class_name ItemDefinition
extends Resource

enum Category {
	## 血量未满时拾取立即使用，满血拾取或商店购买时进入物品栏。
	HEALING,
	## 救命毫毛，不占用五格物品栏。
	LIFE,
	## 投掷、控制等普通法宝，占用五格物品栏。
	ARTIFACT,
}

@export var id: StringName
@export var display_name: String
## 决定购买与拾取后的处理方式。
@export var category: Category
@export_range(0, 1000, 1) var price: int
## 补血量或法宝基础效果数值，具体解释由使用该资源的行为决定。
@export_range(0.0, 200.0, 1.0) var power: float
@export_range(0.0, 20.0, 0.1) var duration: float
@export var color: Color = Color.WHITE
