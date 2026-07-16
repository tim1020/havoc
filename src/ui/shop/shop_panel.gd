class_name ShopPanel
extends CanvasLayer

signal closed

# 需要二次确认的操作共用一个状态，切换商品或调整物品栏时会取消确认。
enum PendingAction { NONE, FIFO_SHIFT, LEAVE }

@onready var title_label: Label = %TitleLabel
@onready var balance_label: Label = %BalanceLabel
@onready var status_label: Label = %StatusLabel
@onready var products: GridContainer = %Products
@onready var inventory_row: HBoxContainer = %InventoryRow

var player: Player
var product_buttons: Array[Button] = []
var shop_items: Array[ItemDefinition] = []
var selected_index: int = 0
var pending_action: PendingAction = PendingAction.NONE
var pending_item: ItemDefinition


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	shop_items = ItemCatalog.shop_items()
	for index in shop_items.size():
		var item := shop_items[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 104)
		button.text = "%s\n%d 灵石" % [item.display_name, item.price]
		button.icon = ItemIconFactory.create(item)
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_entered.connect(select_product.bind(index))
		button.pressed.connect(select_and_purchase.bind(index))
		products.add_child(button)
		product_buttons.append(button)
	GameState.stones_changed.connect(update_balance)
	GameState.artifacts_changed.connect(update_inventory)


func open_shop(target_player: Player, shop_title: String) -> void:
	player = target_player
	title_label.text = shop_title
	selected_index = 0
	clear_pending()
	update_balance(GameState.stones)
	update_inventory(GameState.artifacts)
	visible = true
	get_tree().paused = true
	update_selection()
	status_label.text = "左右移动键选择商品，攻击键购买"


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	# 商店沿用角色移动动作，玩家修改移动键绑定后无需单独配置商店按键。
	if event.is_action_pressed(&"move_left"):
		move_selection(-1)
	elif event.is_action_pressed(&"move_right"):
		move_selection(1)
	elif event.is_action_pressed(&"attack"):
		purchase_selected()
	elif event.is_action_pressed(&"item"):
		clear_pending()
		GameState.rotate_artifacts()
		status_label.text = "物品栏顺序已调整"
	elif event.is_action_pressed(&"jump"):
		request_leave()
	else:
		return
	get_viewport().set_input_as_handled()


func move_selection(direction: int) -> void:
	clear_pending()
	# 商品按 GridContainer 的实际子节点顺序一维移动，因此跨过行尾时会自然换行。
	selected_index = clampi(selected_index + direction, 0, shop_items.size() - 1)
	update_selection()
	status_label.text = "%s · %d 灵石" % [shop_items[selected_index].display_name, shop_items[selected_index].price]


func select_product(index: int) -> void:
	selected_index = clampi(index, 0, shop_items.size() - 1)
	clear_pending()
	update_selection()


func select_and_purchase(index: int) -> void:
	select_product(index)
	purchase_selected()


func update_selection() -> void:
	for index in product_buttons.size():
		var button := product_buttons[index]
		button.modulate = Color.WHITE if index == selected_index else Color(0.58, 0.58, 0.58, 1)
		button.add_theme_color_override("font_color", Color("ffd86a") if index == selected_index else Color("d8cfba"))
		button.add_theme_color_override("font_hover_color", Color("ffd86a"))
		button.add_theme_constant_override("outline_size", 5 if index == selected_index else 0)
		button.add_theme_color_override("font_outline_color", Color("9b5a18"))


func request_purchase(item: ItemDefinition) -> void:
	var index := shop_items.find(item)
	if index >= 0:
		selected_index = index
		clear_pending()
		update_selection()


func purchase_selected() -> void:
	if shop_items.is_empty():
		return
	var item := shop_items[selected_index]
	if item.category == ItemDefinition.Category.LIFE:
		clear_pending()
		status_label.text = "购买成功：%s" % item.display_name if GameState.purchase_life(item.price) else "无法购买：限购、持有上限或灵石不足"
		return
	if GameState.artifacts.size() >= GameState.MAX_ARTIFACTS:
		# 满栏购买必须二次确认；确认后销毁队首、整体前移，并把新物品追加到队尾。
		if pending_action != PendingAction.FIFO_SHIFT or pending_item != item:
			pending_action = PendingAction.FIFO_SHIFT
			pending_item = item
			var front := ItemCatalog.get_definition(GameState.artifacts.front())
			status_label.text = "物品栏已满，再按攻击键确认：丢弃队首 %s，其余前移" % front.display_name
			return
		var replaced := GameState.purchase_artifact_fifo(item.id, item.price)
		clear_pending()
		status_label.text = "购买成功，已放到队尾" if replaced else "无法购买：灵石不足"
		return
	clear_pending()
	status_label.text = "购买成功，已放到队尾" if GameState.purchase_artifact(item.id, item.price) else "无法购买：灵石不足"


func confirm_pending() -> void:
	if pending_action == PendingAction.LEAVE:
		close_shop()
	else:
		purchase_selected()


func request_leave() -> void:
	if pending_action == PendingAction.LEAVE:
		close_shop()
		return
	pending_action = PendingAction.LEAVE
	pending_item = null
	status_label.text = "结束购买？再按一次跳跃键确认离开"


func clear_pending() -> void:
	pending_action = PendingAction.NONE
	pending_item = null


func update_inventory(artifacts: Array[StringName]) -> void:
	for child in inventory_row.get_children():
		child.queue_free()
	for index in GameState.MAX_ARTIFACTS:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(142, 62)
		slot.focus_mode = Control.FOCUS_NONE
		slot.disabled = true
		if index < artifacts.size():
			var item := ItemCatalog.get_definition(artifacts[index])
			slot.text = "%d  %s%s" % [index + 1, item.display_name, "  ▶ 最前" if index == 0 else ""]
			slot.icon = ItemIconFactory.create(item)
			slot.expand_icon = true
			slot.modulate = item.color.lightened(0.18)
		else:
			slot.text = "%d  空" % (index + 1)
		inventory_row.add_child(slot)


func update_balance(stones: int) -> void:
	balance_label.text = "灵石  %d" % stones


func update_status_balance(stones: int) -> void:
	update_balance(stones)


func close_shop() -> void:
	clear_pending()
	visible = false
	get_tree().paused = false
	closed.emit()
