extends BaseGridView
## 格子视图，用于绘制格子
class_name InventoryGridView


## input事件处理一直按下使用键（物品数量一直减一直到数量为零或者松开按键）
func _physics_process(_delta: float) -> void:
	# 只在鼠标所在的格子实例上执行逻辑
	if not grid_id == MGIS.mouse_cell_id:
		return

	# 检查是否按下使用键，并且在有效格子内（有物品占用）
	if has_taken and input_use_pressed:
		var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(MGIS.current_container.container_name, grid_id)
		# 确保格子有堆叠物品
		if is_instance_valid(item_data) and item_data is StackableData:
			item_data = item_data as StackableData
			# 且物品数量大于0
			if item_data.current_amount > 0:
				# 节流发送分割物品的信号
				MGIS.throttle("inventory_sub_item", SUB_INTERVAL, _on_sub_item, [MGIS.current_container, grid_id, 1])
			else:
				# 先清除物品信息
				MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))
				# 如果鼠标仍在按下使用键，但物品数量已为0，则停止循环
				input_use_pressed = false
		else:
			input_use_pressed = false


## 开始分割物品，每隔一段分割一个
func _on_sub_item(container_view: BaseContainerView, grid_id: Vector2i, sub_count: int) -> void:
	MGIS.inventory_service.quick_move_item(container_view, grid_id, sub_count)


## 输入控制
func _gui_input(event: InputEvent) -> void:
	# 1. 点击物品 (左键)
	if event.is_action_pressed(MGIS.input_click):
		# A. 放置物品
		if not has_taken and MGIS.moving_item_service.moving_item:
			# 获取精确的目标格子 (像素吸附)
			var target_grid = _container_view.get_target_grid_from_mouse()
			# 使用 target_grid 进行放置
			if MGIS.inventory_service.place_moving_item(_container_view, target_grid):
				return

		# B. 格子有物品
		elif has_taken:
			# 手上没有拖动物品 -> 尝试拾取
			if not MGIS.moving_item_service.moving_item:
				var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(_container_view.container_name, grid_id)

				# [修改] 如果不可拖动，直接返回 (不再触发长按/详情信号)
				if is_instance_valid(item_data) and not item_data.can_drag:
					return

				# 正常的拖动物品逻辑
				MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))
				# Offset 传 0 (中心对齐)
				MGIS.moving_item_service.move_item_by_grid(_container_view.container_name, grid_id, Vector2i.ZERO, get_cell_size())

			# 手上有物品 -> 堆叠
			elif MGIS.moving_item_service.moving_item is StackableData:
				MGIS.inventory_service.stack_moving_item(_container_view, grid_id)

			# 点击时手动刷新高亮
			_container_view.grid_hover(grid_id)

	# 2. 快速移动物品 (Shift + RightClick)
	elif event.is_action_pressed(MGIS.input_quick_move):
		if has_taken:
			var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(_container_view.container_name, grid_id)
			if is_instance_valid(item_data) and not item_data.can_drag:
				return
			MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))
			MGIS.inventory_service.quick_move(_container_view, grid_id)

	# 3. 快速移动一半物品 (Ctrl + RightClick)
	elif event.is_action_pressed(MGIS.input_move_half):
		if has_taken:
			var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(_container_view.container_name, grid_id)
			if is_instance_valid(item_data) and not item_data.can_drag:
				return
			MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))
			MGIS.inventory_service.quick_move_half(_container_view, grid_id)

	# 4. 使用物品 (RightClick)
	elif event.is_action_pressed(MGIS.input_use):
		if has_taken:
			var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(_container_view.container_name, grid_id)
			if is_instance_valid(item_data) and not item_data.can_drag:
				return
			if MGIS.inventory_service.use_item(_container_view, grid_id):
				MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))
			# 标记按下，用于 _physics_process 中的连续购买/分割
			input_use_pressed = true

	# 5. 分割物品
	elif event.is_action_pressed(MGIS.input_split):
		if has_taken:
			var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(_container_view.container_name, grid_id)
			if is_instance_valid(item_data) and not item_data.can_drag:
				return
		if has_taken and not MGIS.moving_item_service.moving_item:
			# offset 传 0
			var split_item_data: BaseItemData = MGIS.inventory_service.split_item(_container_view, grid_id, Vector2i.ZERO, get_cell_size())
			if is_instance_valid(split_item_data):
				MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))

	# 6. 释放按下的使用键
	elif event.is_action_released(MGIS.input_use):
		input_use_pressed = false


# 处理未被 UI 消耗的事件 (旋转)
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed(MGIS.input_rotate):
		if not event.is_echo():
			if MGIS.moving_item_service.moving_item:
				MGIS.current_container.grid_lose_hover(MGIS.mouse_cell_id)
				MGIS.moving_item_service.rotate_item(_container_view.container_name, MGIS.current_container.base_size)
				MGIS.current_container.grid_hover(MGIS.mouse_cell_id)
				accept_event()
				return
