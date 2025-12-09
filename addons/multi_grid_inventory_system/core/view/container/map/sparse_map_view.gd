@tool
extends BaseContainerView
class_name SparseMapView

## 稀疏地图视图
## 特点：不生成格子节点，仅渲染存在的物品，背景和高亮通过 _draw 绘制

## 允许存放的物品类型，如果背包名字重复，可存放的物品类型需要一样
@export var avilable_types: Array[String] = ["ANY"]
## --- 视觉配置 ---
@export_group("Sparse Grid Settings")
## 是否绘制网格线
@export var show_grid_lines: bool = true:
	set(value):
		show_grid_lines = value
		queue_redraw()

## 网格线颜色 (建议这也加上 setter，方便在编辑器里实时调色)
@export var grid_line_color: Color = Color(1, 1, 1, 0.1):
	set(value):
		grid_line_color = value
		queue_redraw()

## 地图总宽（格子数）
@export var map_width: int = 100:
	set(value):
		map_width = value
		# 尺寸变了通常需要重算最小尺寸并重绘
		call_deferred("_update_min_size")
		queue_redraw()

## 地图总高（格子数）
@export var map_height: int = 100:
	set(value):
		map_height = value
		call_deferred("_update_min_size")
		queue_redraw()

## 当前高亮的格子列表 (用于绘制绿色/红色框)
var _highlight_grids: Array[Vector2i] = []
## 当前高亮的状态 (可用/冲突)
var _highlight_state: BaseGridView.State = BaseGridView.State.EMPTY
## 缓存：当前鼠标所在的网格坐标
var _current_mouse_grid: Vector2i = -Vector2i.ONE
## 缓存类型改为 ItemView(用于判断进入/离开物品以显示范围)
var _current_hover_view: ItemView = null
## 交互相关变量
const INTERACT_INTERVAL: float = 0.4  # 交互间隔 (例如每0.4秒挥动一次稿子)
var _is_interacting: bool = false  # 是否正在按住交互键
var _target_interact_view: ItemView = null  # 当前交互的目标 View
var _has_triggered_interaction: bool = false  # 本次按压是否已经触发过交互(用于区分短按详情)


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not container_name:
		push_error("SparseMap must have a name.")
		return

	is_slot = false
	# 使用自定义的容器类型，或者复用 INVENTORY，取决于你的 MGIS 枚举定义
	# 建议在 MGIS.ContainerType 中增加 MAP 类型，或者暂用 INVENTORY
	container_type = MGIS.ContainerType.INVENTORY
	# 容器存入字典
	MGIS.container_dict.set(container_name, self)
	# 注册容器 (注意：activated_rows 在这里通常等于 map_height)
	var service = MGIS.inventory_service
	var ret = service.regist(container_name, map_width, map_height, map_height, avilable_types)

	# 同步数据
	container_columns = ret.columns
	container_rows = ret.rows

	# 设置最小尺寸，撑开 ScrollContainer
	custom_minimum_size = Vector2(container_columns, container_rows) * base_size

	# 初始化物品容器
	_init_item_container()

	# 连接信号
	MGIS.sig_inv_item_added.connect(_on_item_added)
	MGIS.sig_inv_item_removed.connect(_on_item_removed)
	MGIS.sig_inv_item_updated.connect(_on_inv_item_updated)
	MGIS.sig_inv_refresh.connect(refresh)
	# 连接鼠标离开控件的信号，确保鼠标移出地图区域时隐藏范围提示
	mouse_exited.connect(_on_mouse_exited_control)

	# 启用鼠标输入
	mouse_filter = Control.MOUSE_FILTER_PASS

	call_deferred("refresh")


## 物理帧处理：持续触发交互
func _physics_process(_delta: float) -> void:
	# 只有在按住状态，且目标有效时才执行
	if _is_interacting and is_instance_valid(_target_interact_view):
		# 使用节流函数，每隔 INTERACT_INTERVAL 秒执行一次 _on_interact_tick
		# "sparse_map_interact" 是节流器的唯一 Key
		MGIS.throttle("sparse_map_interact", INTERACT_INTERVAL, _on_interact_tick)
	else:
		# 保护措施：如果对象丢失或标记错误，重置状态
		if _is_interacting and not is_instance_valid(_target_interact_view):
			_stop_interaction()


## 交互的回调函数 (由 throttle 触发)
func _on_interact_tick() -> void:
	if is_instance_valid(_target_interact_view):
		# 标记：已经触发过交互了 (这样松开鼠标时就不会弹出详情窗口)
		_has_triggered_interaction = true

		# 发送交互信号 (外部逻辑连接此信号来扣除耐久、播放特效等)
		MGIS.sig_grid_interact_pressed.emit(container_name, _target_interact_view.first_grid, _target_interact_view)
		#print("SparseMap: Mining... ", _target_interact_view)


## 停止交互并重置变量
func _stop_interaction() -> void:
	_is_interacting = false
	_target_interact_view = null
	# 注意：这里不重置 _has_triggered_interaction，因为它在 Release 中还有用


# --- 核心：坐标转换 ---


## 根据鼠标像素位置计算最佳的左上角网格坐标 (像素吸附)
func get_target_grid_from_mouse() -> Vector2i:
	var moving_item = MGIS.moving_item_service.moving_item
	if not moving_item:
		return get_grid_under_mouse()

	var local_mouse_pos = get_local_mouse_position()
	var item_shape = moving_item.get_shape(is_slot)
	var item_pixel_size = Vector2(item_shape) * float(base_size)

	# 居中对齐公式
	var raw_top_left_px = local_mouse_pos - (item_pixel_size / 2.0)

	var target_x = round(raw_top_left_px.x / base_size)
	var target_y = round(raw_top_left_px.y / base_size)

	return Vector2i(int(target_x), int(target_y))


## 获取鼠标当前正下方的格子 (不考虑物品偏移)
func get_grid_under_mouse() -> Vector2i:
	var local_pos = get_local_mouse_position()
	var x = floor(local_pos.x / base_size)
	var y = floor(local_pos.y / base_size)
	return Vector2i(int(x), int(y))


# --- 核心：绘制逻辑 ---


func _draw() -> void:
	# 1. 绘制网格线 (优化性能：只画视野内的？但 Draw Line 性能很高，全画通常也行)
	if show_grid_lines:
		var total_w = custom_minimum_size.x
		var total_h = custom_minimum_size.y

		# 垂直线
		for i in range(container_columns + 1):
			var x = i * base_size
			draw_line(Vector2(x, 0), Vector2(x, total_h), grid_line_color)

		# 水平线
		for i in range(container_rows + 1):
			var y = i * base_size
			draw_line(Vector2(0, y), Vector2(total_w, y), grid_line_color)

	# 2. 绘制交互高亮 (替代了 GridView 的 State 切换)
	if not _highlight_grids.is_empty():
		var color = gird_background_color_taken  # 默认
		match _highlight_state:
			BaseGridView.State.AVILABLE:
				color = grid_background_color_avilable
			BaseGridView.State.CONFLICT:
				color = gird_background_color_conflict
			BaseGridView.State.TAKEN:
				color = gird_background_color_taken

		for grid in _highlight_grids:
			# 计算每个格子的 Rect
			var rect = Rect2(Vector2(grid) * base_size, Vector2(base_size, base_size))
			# 绘制半透明填充
			draw_rect(rect, color, true)
			# 可选：绘制边框
			draw_rect(rect, color.lightened(0.2), false, 2.0)


# --- 核心交互逻辑 ---


func _gui_input(event: InputEvent) -> void:
	# 1. 处理鼠标移动
	if event is InputEventMouseMotion:
		# A. 处理网格高亮 (之前的逻辑)
		var current_grid = get_grid_under_mouse()
		if current_grid != _current_mouse_grid:
			grid_lose_hover(_current_mouse_grid)
			_current_mouse_grid = current_grid
			MGIS.mouse_cell_id = current_grid
			if _is_valid_grid(current_grid):
				grid_hover(current_grid)
			else:
				_clear_highlight()

		# B. 处理物品范围显示 (Show/Hide Range)
		if current_grid != _current_mouse_grid:
			_current_mouse_grid = current_grid
		# 处理物品范围显示
		_handle_item_hover(current_grid)

	# 2. 鼠标点击
	if event is InputEventMouseButton:
		# 左键按下
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click_pressed()

		# 左键释放
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			_handle_left_click_released()

		# 右键按下
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click()


# --- 逻辑处理函数 ---


## 处理物品悬停 (显示/隐藏范围)
func _handle_item_hover(grid_pos: Vector2i) -> void:
	var item_view = find_item_view_by_grid(grid_pos)

	if item_view != _current_hover_view:
		# 隐藏旧的
		if _current_hover_view:
			MGIS.sig_hide_item_range.emit(container_name, _current_hover_view)

		_current_hover_view = item_view

		# 显示新的
		if _current_hover_view:
			MGIS.sig_show_item_range.emit(container_name, _current_hover_view)


## 左键按下
func _handle_left_click_pressed() -> void:
	# 场景 A: 放置物品 (保持不变)
	if MGIS.moving_item_service.moving_item:
		var target_grid = get_target_grid_from_mouse()
		if MGIS.inventory_service.place_moving_item(self, target_grid):
			_clear_highlight()
		return

	# 场景 B: 拾取 或 交互
	var click_grid = get_grid_under_mouse()
	var item_view = find_item_view_by_grid(click_grid)

	if item_view and item_view.data:
		var item_data = item_view.data

		if item_data.can_drag:
			# 可拖拽 -> 直接拾取 (逻辑不变)
			MGIS.item_focus_service.item_lose_focus(item_view)
			MGIS.moving_item_service.move_item_by_grid(container_name, click_grid, Vector2i.ZERO, base_size)
			grid_hover(click_grid)
			if _current_hover_view == item_view:
				MGIS.sig_hide_item_range.emit(container_name, item_view)
				_current_hover_view = null
		else:
			# [核心修改] 不可拖拽 -> 启动持续交互
			_is_interacting = true
			_target_interact_view = item_view
			_has_triggered_interaction = false

			# 可选：按下瞬间是否立即触发一次？
			# 如果想立即触发，可以在这里调用一次 _on_interact_tick()
			# 如果想有前摇（按住一会儿才开始），则交给 _physics_process
			# 建议：为了手感，通常第一下是立即触发的，或者稍微延迟。MGIS.throttle 默认行为取决于实现。
			# 这里我们让 physics process 接管，通常会有几十毫秒的自然延迟，手感较好。


## 左键释放
func _handle_left_click_released() -> void:
	if not _is_interacting:
		return

	# 停止交互
	_stop_interaction()

	# [逻辑判断] 短按 vs 长按
	# 如果 _has_triggered_interaction 为 false，说明按下的时间很短，throttle 一次都没触发
	# 此时视为玩家只是想“点击查看详情”
	if not _has_triggered_interaction:
		# 这里需要再次确认目标是否有效（虽然 _stop_interaction 清空了变量，但在清空前应该缓存一下，或者利用之前的状态）
		# 由于 _stop_interaction 已经清空了 _target_interact_view，我们需要在 _handle_left_click_released 开头获取它
		# 但更简单的做法是：不用 _target_interact_view，而是重新获取鼠标下的格子，或者修改流程。

		# 修正后的逻辑：重新获取鼠标下的物品来显示详情
		var click_grid = get_grid_under_mouse()
		var item_view = find_item_view_by_grid(click_grid)
		if item_view and not item_view.data.can_drag:
			MGIS.sig_show_item_detail.emit(container_name, item_view.first_grid, item_view)
			# print("SparseMap: Short Press (Detail)")


## 右键点击 (进入物品)
func _handle_right_click() -> void:
	var click_grid = get_grid_under_mouse()
	var item_view = find_item_view_by_grid(click_grid)

	if item_view:
		MGIS.sig_enter_item.emit(container_name, item_view)


## 鼠标移出整个控件区域时，清理状态
func _on_mouse_exited_control() -> void:
	grid_lose_hover(_current_mouse_grid)
	_current_mouse_grid = -Vector2i.ONE

	# 隐藏范围：发送 View
	if _current_hover_view:
		MGIS.sig_hide_item_range.emit(container_name, _current_hover_view)
		_current_hover_view = null


# --- 重写父类的高亮逻辑 ---


## 格子高亮 (适配稀疏模式)
func grid_hover(grid_id: Vector2i) -> void:
	# 标记当前容器
	MGIS.current_container = self

	if not MGIS.moving_item_service.moving_item:
		# 处理普通选中高亮 (略，或者复用 selected_item 逻辑)
		return

	# 1. 样式同步
	MGIS.moving_item_service.sync_style_with_container(self)

	# 2. 计算覆盖格子 (中心对齐 + 像素吸附)
	var start_grid = get_target_grid_from_mouse()
	var moving_item = MGIS.moving_item_service.moving_item
	var item_shape = moving_item.get_shape(is_slot)

	var grids = _get_grids_by_shape_sparse(start_grid, item_shape)

	# 3. 记录高亮数据
	_highlight_grids = grids

	# 4. 冲突检测
	var has_conflict = false

	# 检查越界
	if grids.size() != item_shape.x * item_shape.y:
		has_conflict = true
	else:
		# 检查占用
		var inv_data = MGIS.inventory_service.get_container(container_name)
		for grid in grids:
			var item_in_grid = inv_data.find_item_data_by_grid(grid)
			if item_in_grid:
				# 堆叠检查
				if item_in_grid is StackableData and item_in_grid.item_id == moving_item.item_id and not item_in_grid.is_full():
					pass  # 允许堆叠
				else:
					has_conflict = true
					break

	# 5. 设置状态并重绘
	_highlight_state = BaseGridView.State.CONFLICT if has_conflict else BaseGridView.State.AVILABLE
	queue_redraw()


## 格子失去高亮
func grid_lose_hover(_grid_id: Vector2i) -> void:
	_clear_highlight()


func _clear_highlight() -> void:
	_highlight_grids.clear()
	_highlight_state = BaseGridView.State.EMPTY
	queue_redraw()


# --- 辅助函数 ---


## 更新容器大小
func _update_min_size() -> void:
	custom_minimum_size = Vector2(map_width, map_height) * base_size


## 稀疏版的获取格子形状 (不依赖 _grid_map)
func _get_grids_by_shape_sparse(start: Vector2i, shape: Vector2i) -> Array[Vector2i]:
	var ret: Array[Vector2i] = []
	for row in shape.y:
		for col in shape.x:
			var grid = Vector2i(start.x + col, start.y + row)
			if _is_valid_grid(grid):
				ret.append(grid)
	return ret


func _is_valid_grid(grid: Vector2i) -> bool:
	return grid.x >= 0 and grid.x < container_columns and grid.y >= 0 and grid.y < container_rows


# --- 重写信号处理逻辑 (覆盖 BaseContainerView 的实现) ---


##  刷新整个地图显示
func refresh() -> void:
	# 1. 清理现有显示
	_clear_inv()

	# 2. 获取容器数据
	# 注意：这里使用 sparse_map_service 或者 inventory_service (取决于你的架构设计)
	# 假设 ContainerRepository 是通用的，通过 container_name 获取即可
	var inv_data = MGIS.inventory_service.get_container(container_name)
	if not inv_data:
		return

	# 3. 遍历数据并绘制物品
	# grid_item_map 存储了 {格子坐标: ItemData}
	# 为了防止多格物品被重复绘制，我们需要去重
	var handled_items = {}

	for grid in inv_data.grid_item_map.keys():
		var item_data = inv_data.grid_item_map[grid]

		# 如果该物品还没处理过
		if item_data and not handled_items.has(item_data):
			handled_items[item_data] = true

			# 获取该物品占用的所有格子
			var grids = inv_data.item_grids_map.get(item_data, [])
			if grids.is_empty():
				continue

			# 找到左上角 (通常 grids[0] 就是，但在稀疏数据中最好确认一下)
			# 这里假设 add_item 时是按顺序存的，grids[0] 为首格子
			var top_left_grid = grids[0]

			# 绘制物品
			var item_view = _draw_item(item_data, top_left_grid)
			_items.append(item_view)

			# 建立映射 (逻辑映射，而非物理格子映射)
			# 这样当鼠标点击某个坐标时，我们能通过 _grid_item_map 快速找到对应的 ItemView
			_item_grids_map[item_view] = grids
			for g in grids:
				_grid_item_map[g] = item_view


##  监听添加物品
func _on_item_added(inv_name: String, item_data: BaseItemData, grids: Array[Vector2i]) -> void:
	if inv_name != container_name:
		return
	if not is_visible_in_tree():
		return

	# 1. 绘制新物品 (位置完全由 grids[0] 数学计算得出)
	var item_view = _draw_item(item_data, grids[0])
	_items.append(item_view)

	# 2. 更新逻辑映射
	_item_grids_map[item_view] = grids
	for grid in grids:
		# 稀疏模式下没有 _grid_map 节点，所以不需要调用 .taken()
		# 只需要更新 坐标->物品视图 的映射
		_grid_item_map[grid] = item_view

	# 3. (可选) 如果你想显示 Tooltip，可以在这里处理
	# 但由于没有 GridView，通常 Tooltip 逻辑需要移动到 ItemView 或者 _gui_input 中动态生成


##  监听移除物品
func _on_item_removed(inv_name: String, item_data: BaseItemData) -> void:
	if inv_name != container_name:
		return
	# 注意：即使不可见，如果数据变了，也应该清理缓存，或者在下次 Visible 时强制 Refresh
	# 这里为了安全，保持原有逻辑，或者你可以去掉 is_visible_in_tree 检查以保持同步
	if not is_visible_in_tree():
		return

	# 查找对应的 ItemView 并销毁
	for i in range(_items.size() - 1, -1, -1):
		var item_view = _items[i]
		if item_view.data == item_data:
			var grids = _item_grids_map.get(item_view, [])

			# 清除映射
			for grid in grids:
				_grid_item_map.erase(grid)  # 移除字典中的 Key

			_item_grids_map.erase(item_view)
			_items.remove_at(i)
			item_view.queue_free()
			break


##  监听物品更新 (如数量变化)
func _on_inv_item_updated(inv_name: String, grid_id: Vector2i) -> void:
	if inv_name != container_name:
		return
	if not is_visible_in_tree():
		return

	# 通过逻辑映射找到 View
	var item_view = _grid_item_map.get(grid_id)
	if is_instance_valid(item_view):
		item_view.update_stack_label()  # 更新数字
		item_view.queue_redraw()


##  清空显示
func _clear_inv() -> void:
	# 销毁所有物品节点
	for item in _items:
		item.queue_free()

	# 重置数组和字典
	_items.clear()
	_item_grids_map.clear()
	_grid_item_map.clear()  # 关键：清空稀疏映射

	# 触发一次重绘以清除可能残留的高亮框 (在 _draw 中绘制的)
	queue_redraw()


func _draw_item(item_data: BaseItemData, first_grid: Vector2i) -> ItemView:
	var item = ItemView.new(item_data, base_size, stack_num_font, stack_num_font_size, stack_num_margin, stack_num_color)
	_item_container.add_child(item)

	# [稀疏模式核心]：直接计算像素坐标
	item.position = Vector2(first_grid) * base_size
	item.first_grid = first_grid
	return item
