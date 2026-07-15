class_name ShopPanel
extends CanvasLayer

signal closed

enum PendingAction { NONE, BUY, DISCARD }

@onready var title_label: Label = %TitleLabel
@onready var status_label: Label = %StatusLabel
@onready var products: GridContainer = %Products
@onready var discard_row: HBoxContainer = %DiscardRow

var player: Player
var pending_action: PendingAction = PendingAction.NONE
var pending_item: ItemDefinition
var pending_index: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for item in ItemCatalog.shop_items():
		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 72)
		button.text = "%s  %d" % [item.display_name, item.price]
		button.icon = ItemIconFactory.create(item)
		button.expand_icon = true
		button.modulate = item.color
		button.pressed.connect(request_purchase.bind(item))
		products.add_child(button)
	%ConfirmButton.pressed.connect(confirm_pending)
	%LeaveButton.pressed.connect(close_shop)
	GameState.stones_changed.connect(update_status_balance)
	GameState.artifacts_changed.connect(update_discard_buttons)


func open_shop(target_player: Player, shop_title: String) -> void:
	player = target_player
	title_label.text = shop_title
	pending_action = PendingAction.NONE
	pending_item = null
	status_label.text = "灵石：%d　选择商品后确认" % GameState.stones
	update_discard_buttons(GameState.artifacts)
	visible = true
	get_tree().paused = true
	%LeaveButton.grab_focus()


func request_purchase(item: ItemDefinition) -> void:
	pending_action = PendingAction.BUY
	pending_item = item
	pending_index = -1
	status_label.text = "确认购买 %s（%d 灵石）" % [item.display_name, item.price]


func request_discard(index: int) -> void:
	if index < 0 or index >= GameState.artifacts.size():
		return
	pending_action = PendingAction.DISCARD
	pending_item = null
	pending_index = index
	var item := ItemCatalog.get_definition(GameState.artifacts[index])
	status_label.text = "确认销毁第%d格：%s" % [index + 1, item.display_name]


func confirm_pending() -> void:
	if pending_action == PendingAction.BUY:
		purchase_pending_item()
	elif pending_action == PendingAction.DISCARD:
		if GameState.discard_artifact(pending_index):
			status_label.text = "已销毁，灵石：%d" % GameState.stones
	pending_action = PendingAction.NONE
	pending_item = null
	pending_index = -1


func purchase_pending_item() -> void:
	if pending_item == null:
		return
	if pending_item.category == ItemDefinition.Category.LIFE:
		status_label.text = "购买成功" if GameState.purchase_life(pending_item.price) else "无法购买：每关限购1根、持有上限3根或灵石不足"
	elif pending_item.category in [ItemDefinition.Category.ARTIFACT, ItemDefinition.Category.HEALING]:
		status_label.text = "购买成功" if GameState.purchase_artifact(pending_item.id, pending_item.price) else "无法购买：法宝栏已满或灵石不足"


func update_discard_buttons(artifacts: Array[StringName]) -> void:
	for child in discard_row.get_children():
		child.queue_free()
	for index in 3:
		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 42)
		if index < artifacts.size():
			var item := ItemCatalog.get_definition(artifacts[index])
			button.text = "销毁 %d：%s" % [index + 1, item.display_name]
			button.pressed.connect(request_discard.bind(index))
		else:
			button.text = "第%d格：空" % (index + 1)
			button.disabled = true
		discard_row.add_child(button)


func update_status_balance(stones: int) -> void:
	if visible and pending_action == PendingAction.NONE:
		status_label.text = "灵石：%d" % stones


func close_shop() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()
