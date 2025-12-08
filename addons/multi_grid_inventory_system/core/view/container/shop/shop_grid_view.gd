extends BaseGridView
## 格子视图，用于绘制格子
class_name ShopGridView


## input事件处理一直按下使用键（物品数量一直减一直到数量为零或者松开按键）
func _physics_process(_delta: float) -> void:
	# 只在鼠标所在的格子实例上执行逻辑
	if not grid_id == MGIS.mouse_cell_id:
		return
	# 检查是否按下使用键，并且在有效格子内（有物品占用）
	if has_taken and input_use_pressed:
		var item_data: BaseItemData = MGIS.shop_service.find_item_data_by_grid(MGIS.current_container.container_name, grid_id)
		# 确保格子有堆叠物品
		if is_instance_valid(item_data):
			# 堆叠物品一个一个购买
			if item_data is StackableData:
				item_data = item_data as StackableData
				# 且物品数量大于0
				if item_data.current_amount > 0:
					# 节流发送分割物品的信号
					MGIS.throttle("shop_buy_item", SUB_INTERVAL, _on_sub_item, [MGIS.current_container, grid_id, 1])
				else:
					# 先清除物品信息
					MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))
					# 如果鼠标仍在按下使用键，但物品数量已为0，则停止循环
					input_use_pressed = false
			# 非堆叠物品购买全部
			else:
				MGIS.shop_service.buy_all_amount(MGIS.current_container, grid_id)
				input_use_pressed = false


## 每隔一段购买一个物品
func _on_sub_item(container_view: BaseContainerView, grid_id: Vector2i, sub_count: int) -> void:
	MGIS.shop_service.buy(_container_view, grid_id, sub_count)


## 输入控制
func _gui_input(event: InputEvent) -> void:
	# 点击购买1个
	if event.is_action_pressed(MGIS.input_click):
		if has_taken:
			if not MGIS.moving_item_service.moving_item:
				MGIS.shop_service.buy(_container_view, grid_id, 1)
	# shfit+右键 购买物品的全部数量
	elif event.is_action_pressed(MGIS.input_quick_move):
		if has_taken:
			if not MGIS.moving_item_service.moving_item:
				MGIS.shop_service.buy_all_amount(_container_view, grid_id)
	# ctrl+右键 购买物品的一半数量
	elif event.is_action_pressed(MGIS.input_move_half):
		if has_taken:
			if not MGIS.moving_item_service.moving_item:
				MGIS.shop_service.buy_half_amount(_container_view, grid_id)
	# 持续购买物品（购买1个，按住不松可以持续购买直到松开或者数量为零）
	elif event.is_action_pressed(MGIS.input_use):
		if has_taken:
			if not MGIS.moving_item_service.moving_item:
				# 按下使用键
				input_use_pressed = true
	# 拖拽出售物品
	elif MGIS.has_moving_item():
		MGIS.shop_service.sell(_container_view, MGIS.moving_item_service.moving_item)
	# 释放按下的使用键
	elif event.is_action_released(MGIS.input_use):
		# 松开使用键
		input_use_pressed = false
