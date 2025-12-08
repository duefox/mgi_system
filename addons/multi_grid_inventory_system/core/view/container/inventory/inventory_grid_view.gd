extends BaseGridView
## 格子视图，用于绘制格子
class_name InventoryGridView

## 长按相关常量和变量
const LONG_PRESS_TIME: float = 0.5  # 0.5秒视为长按
var _is_click_pressed: bool = false
var _press_time: float = 0.0
var _is_long_pressed_triggered: bool = false  # 确保长按信号只发送一次
var _long_press_item_data: BaseItemData = null  # 存储不可拖动物品的数据，用于短按/长按操作


## input事件处理一直按下使用键（物品数量一直减一直到数量为零或者松开按键）
func _physics_process(_delta: float) -> void:
	# 只在鼠标所在的格子实例上执行逻辑
	if not grid_id == MGIS.mouse_cell_id:
		# 鼠标移出格子时，停止长按计时
		if _is_click_pressed:
			_is_click_pressed = false
			_long_press_item_data = null
		return
	# 长按计时逻辑 (只对不可拖动物品进行计时)
	if _is_click_pressed and is_instance_valid(_long_press_item_data):
		_press_time += _delta
		if _press_time >= LONG_PRESS_TIME and not _is_long_pressed_triggered:
			_is_long_pressed_triggered = true
			# 发送长按信号
			MGIS.sig_grid_long_pressed.emit(_container_view.container_name, grid_id, _long_press_item_data)
			print("sig_grid_long_pressed->container_name:", _container_view.container_name, ",grid_id:", grid_id)
			# 长按动作触发后，结束本次计时
			_is_click_pressed = false
			_long_press_item_data = null
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
	# 点击物品(长按/短按按下逻辑)
	if event.is_action_pressed(MGIS.input_click):
		# 1. 放置物品 (Drag & Drop Logic)
		if not has_taken and MGIS.moving_item_service.moving_item:
			if MGIS.inventory_service.place_moving_item(_container_view, grid_id):
				_is_click_pressed = false  # 确保计时器不启动
				_long_press_item_data = null
				return
		# 2. 格子有物品
		elif has_taken:
			# 未在拖动
			if not MGIS.moving_item_service.moving_item:
				var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(_container_view.container_name, grid_id)
				# 2.1. 不可拖动的物品 (启动长按/短按判断)
				if is_instance_valid(item_data) and not item_data.can_drag:
					# 启动长按计时
					_is_click_pressed = true
					_press_time = 0.0
					_is_long_pressed_triggered = false
					# 储存物品数据，用于后续的短按/长按操作
					_long_press_item_data = item_data
					return
				# 2.2 拖动物品(先清除物品信息)
				MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))
				MGIS.moving_item_service.move_item_by_grid(_container_view.container_name, grid_id, offset, get_cell_size())
			# 拖动中，堆叠物品则尝试堆叠
			elif MGIS.moving_item_service.moving_item is StackableData:
				MGIS.inventory_service.stack_moving_item(_container_view, grid_id)
			# 点击时，手动调用一次高亮
			_container_view.grid_hover(grid_id)
		else:
			# 3. 点击空格子或未能触发任何动作，停止计时
			_is_click_pressed = false
			_long_press_item_data = null
	# 长按/短按释放逻辑 (只对启动了计时的事件有效)
	elif event.is_action_released(MGIS.input_click):
		# 检查是否是在计时状态下释放
		if not _is_click_pressed:
			return
		_is_click_pressed = false  # 停止计时
		# 如果长按已触发 (已经在 _physics_process 中发送信号)，则短按行为被抑制
		if _is_long_pressed_triggered:
			_is_long_pressed_triggered = false  # 重置标志
			_long_press_item_data = null
			return
		# 如果是短按，并且有物品数据 (即短按完成)
		if is_instance_valid(_long_press_item_data):
			# 显示详情面板
			MGIS.sig_show_item_detail.emit(_container_view.container_name, grid_id, _long_press_item_data)
			print("sig_show_item_detail->container_name:", _container_view.container_name, ",grid_id:", grid_id)
			_long_press_item_data = null
		return
	# 快速移动物品
	elif event.is_action_pressed(MGIS.input_quick_move):
		if has_taken:
			var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(_container_view.container_name, grid_id)
			# 不能移动的物品
			if is_instance_valid(item_data) and not item_data.can_drag:
				return
			MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))
			MGIS.inventory_service.quick_move(_container_view, grid_id)
	# 快速移动一半的物品
	elif event.is_action_pressed(MGIS.input_move_half):
		if has_taken:
			var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(_container_view.container_name, grid_id)
			# 不能移动的物品
			if is_instance_valid(item_data) and not item_data.can_drag:
				return
			MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))
			MGIS.inventory_service.quick_move_half(_container_view, grid_id)
	# 使用物品
	elif event.is_action_pressed(MGIS.input_use):
		if has_taken:
			var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(_container_view.container_name, grid_id)
			# 不能移动的物品
			if is_instance_valid(item_data) and not item_data.can_drag:
				# 显示辐射范围
				MGIS.sig_show_item_range.emit(_container_view.container_name, item_data)
				return
			if MGIS.inventory_service.use_item(_container_view, grid_id):
				MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))
			# 按下使用键
			input_use_pressed = true
	# 分割物品
	elif event.is_action_pressed(MGIS.input_split):
		if has_taken:
			var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(_container_view.container_name, grid_id)
			# 不能移动的物品
			if is_instance_valid(item_data) and not item_data.can_drag:
				return
		if has_taken and not MGIS.moving_item_service.moving_item:
			var split_item_data: BaseItemData = MGIS.inventory_service.split_item(_container_view, grid_id, offset, get_cell_size())
			if is_instance_valid(split_item_data):
				MGIS.item_focus_service.item_lose_focus(_container_view.find_item_view_by_grid(grid_id))

	# 释放按下的使用键
	elif event.is_action_released(MGIS.input_use):
		# 松开使用键
		input_use_pressed = false


# 处理未被 UI 消耗的事件
func _unhandled_input(event: InputEvent):
	# 检查 event 是否是映射的动作的按下事件
	if event.is_action_pressed(MGIS.input_rotate):
		# 确保不是按键抬起或重复按键
		if not event.is_echo():
			if MGIS.moving_item_service.moving_item:
				# 旋转时，手动去掉高亮
				MGIS.current_container.grid_lose_hover(MGIS.mouse_cell_id)
				# 旋转处理
				MGIS.moving_item_service.rotate_item(_container_view.container_name, MGIS.current_container.base_size)
				# 旋转后，手动调用一次高亮
				MGIS.current_container.grid_hover(MGIS.mouse_cell_id)
				# 消耗事件，防止它冒泡给更上层的节点
				accept_event()
				return
