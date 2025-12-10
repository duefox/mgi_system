@tool
extends BaseContainerView
class_name SparseMapView

## 稀疏地图视图
## 特点：不生成格子节点，仅渲染存在的物品，背景和高亮通过 _draw 绘制

## 允许存放的物品类型
@export var avilable_types: Array[String] = ["ANY"]

# --- 视觉配置 ---
@export_group("Sparse Grid Settings")
## 是否绘制网格线
@export var show_grid_lines: bool = true:
	set(value):
		show_grid_lines = value
		queue_redraw()

## 网格线颜色
@export var grid_line_color: Color = Color(1, 1, 1, 0.1):
	set(value):
		grid_line_color = value
		queue_redraw()

## 地图总宽（格子数）
@export var map_width: int = 100:
	set(value):
		map_width = value
		call_deferred("_update_min_size")
		queue_redraw()

## 地图总高（格子数）
@export var map_height: int = 100:
	set(value):
		map_height = value
		call_deferred("_update_min_size")
		queue_redraw()

# --- 模式控制 ---
## 是否为建造模式
@export var is_build_mode: bool = false:
	set(value):
		is_build_mode = value
		# 切换模式时清理交互状态
		_stop_interaction()
		_clear_highlight()

# --- 内部变量 ---
## 当前高亮的格子列表
var _highlight_grids: Array[Vector2i] = []
## 当前高亮的状态
var _highlight_state: BaseGridView.State = BaseGridView.State.EMPTY

## 缓存：当前鼠标所在的网格坐标
var _current_mouse_grid: Vector2i = -Vector2i.ONE
## 缓存：当前鼠标悬停的 ItemView (用于范围显示)
var _current_hover_view: ItemView = null

# [交互相关变量]
const INTERACT_INTERVAL: float = 0.2
# 交互状态标志位：0=无, 1=左键交互(采集/铺设), 2=右键交互(回收)
var _interacting_state: int = 0
var _target_interact_view: ItemView = null
var _has_triggered_interaction: bool = false  # 本次按压是否已经触发过交互
var _last_grid_pos: Vector2i = -Vector2i.ONE  # 记录拖拽轨迹(铺设/回收)，防止单帧重复


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not container_name:
		push_error("SparseMap must have a name.")
		return

	is_slot = false
	# 建议在 MGIS.ContainerType 中增加 MAP 类型
	container_type = MGIS.ContainerType.INVENTORY

	MGIS.container_dict.set(container_name, self)

	# 注册容器
	var service = MGIS.inventory_service
	var ret = service.regist(container_name, map_width, map_height, map_height, avilable_types)

	# 同步数据
	container_columns = ret.columns
	container_rows = ret.rows

	_update_min_size()

	# 初始化物品容器
	_init_item_container()

	# 连接信号
	MGIS.sig_inv_item_added.connect(_on_item_added)
	MGIS.sig_inv_item_removed.connect(_on_item_removed)
	MGIS.sig_inv_item_updated.connect(_on_inv_item_updated)
	MGIS.sig_inv_refresh.connect(refresh)

	# 鼠标移出地图区域时清理状态
	mouse_exited.connect(_on_mouse_exited_control)

	mouse_filter = Control.MOUSE_FILTER_PASS

	call_deferred("refresh")


# --- 物理帧处理：持续触发交互 ---
func _physics_process(_delta: float) -> void:
	if _interacting_state == 0:
		return

	# 普通模式：长按采集
	if not is_build_mode and _interacting_state == 1 and is_instance_valid(_target_interact_view):
		MGIS.throttle("sparse_map_interact", INTERACT_INTERVAL, _on_interact_tick)

	# 建造模式：右键持续回收 (原地按住)
	elif is_build_mode and _interacting_state == 2:
		var current_grid = get_target_grid_from_mouse()
		# 节流执行回收
		MGIS.throttle("sparse_map_reclaim", 0.15, func(): _try_reclaim_continuous(current_grid))


## 普通模式的采集回调
func _on_interact_tick() -> void:
	if is_instance_valid(_target_interact_view):
		_has_triggered_interaction = true
		MGIS.sig_grid_interact_pressed.emit(container_name, _target_interact_view.first_grid, _target_interact_view)


func _stop_interaction() -> void:
	_interacting_state = 0
	_target_interact_view = null
	_last_grid_pos = -Vector2i.ONE


# --- 核心：交互逻辑分发 ---


func _gui_input(event: InputEvent) -> void:
	# 1. 鼠标移动
	if event is InputEventMouseMotion:
		_handle_mouse_motion()

	# 2. 鼠标点击
	# 使用本地映射配置的 inv_click (左键) 和 inv_use (右键)
	if event.is_action_pressed("inv_click"):
		_handle_left_press()
	elif event.is_action_released("inv_click"):
		_handle_left_release()
	elif event.is_action_pressed("inv_use"):
		_handle_right_press()
	elif event.is_action_released("inv_use"):
		_handle_right_release()


# --- 逻辑分支实现 ---


## 处理鼠标移动
func _handle_mouse_motion() -> void:
	var current_grid = get_grid_under_mouse()

	# A. 基础高亮与范围显示 (通用)
	if current_grid != _current_mouse_grid:
		grid_lose_hover(_current_mouse_grid)
		_current_mouse_grid = current_grid
		MGIS.mouse_cell_id = current_grid

		if _is_valid_grid(current_grid):
			grid_hover(current_grid)
		else:
			_clear_highlight()

	_handle_item_hover(current_grid)

	# B. [建造模式] 拖拽连续操作
	if is_build_mode:
		var target_grid = get_target_grid_from_mouse()

		# 只有格子变了才触发，防止单帧重复
		if target_grid != _last_grid_pos:
			# 左键拖拽铺设
			if _interacting_state == 1 and MGIS.moving_item_service.moving_item:
				_try_place_continuous(target_grid)

			# 右键拖拽回收
			elif _interacting_state == 2:
				_try_reclaim_continuous(target_grid)


## 左键按下
func _handle_left_press() -> void:
	if is_build_mode:
		_handle_build_mode_left_press()
	else:
		_handle_normal_mode_left_press()


## 左键释放
func _handle_left_release() -> void:
	if is_build_mode:
		_interacting_state = 0
		_last_grid_pos = -Vector2i.ONE
	else:
		_handle_normal_mode_left_release()


## 右键按下
func _handle_right_press() -> void:
	if is_build_mode:
		# [建造模式] 启动连续回收
		_interacting_state = 2  # 标记为右键交互
		_last_grid_pos = -Vector2i.ONE
		_try_reclaim_continuous(get_target_grid_from_mouse())
	else:
		# [普通模式] 发送进入信号
		var item_view = find_item_view_by_grid(get_grid_under_mouse())
		if item_view:
			MGIS.sig_enter_item.emit(container_name, item_view)


## 右键释放
func _handle_right_release() -> void:
	if is_build_mode:
		_interacting_state = 0
		_last_grid_pos = -Vector2i.ONE


# --- 详细逻辑实现 ---


# [建造模式] 左键按下：放置 / 拾取
func _handle_build_mode_left_press() -> void:
	# 场景 A: 手上有东西 -> 启动铺设
	if MGIS.moving_item_service.moving_item:
		_interacting_state = 1
		var target_grid = get_target_grid_from_mouse()
		_try_place_continuous(target_grid)
		return

	# 场景 B: 手上没东西 -> 拾取 (移动)
	var click_grid = get_grid_under_mouse()
	var item_view = find_item_view_by_grid(click_grid)
	if item_view and item_view.data:
		if item_view.data.can_drag:
			MGIS.item_focus_service.item_lose_focus(item_view)
			MGIS.moving_item_service.move_item_by_grid(container_name, click_grid, Vector2i.ZERO, base_size)
			grid_hover(click_grid)
			_clear_hover_status(item_view)


# [普通模式] 左键按下：长按交互
func _handle_normal_mode_left_press() -> void:
	var click_grid = get_grid_under_mouse()
	var item_view = find_item_view_by_grid(click_grid)

	if item_view:
		# 启动交互 (采集)
		_interacting_state = 1
		_target_interact_view = item_view
		_has_triggered_interaction = false


# [普通模式] 左键释放：短按详情
func _handle_normal_mode_left_release() -> void:
	if _interacting_state != 1:
		return

	# 缓存目标
	var target = _target_interact_view
	_stop_interaction()

	# 如果没触发过采集，则是短按 -> 详情
	if not _has_triggered_interaction and is_instance_valid(target):
		MGIS.sig_show_item_detail.emit(container_name, target.first_grid, target)


# --- 连续操作辅助函数 ---


## 连续放置
func _try_place_continuous(grid: Vector2i) -> void:
	if MGIS.inventory_service.place_single_from_moving(self, grid):
		_last_grid_pos = grid
		_clear_highlight()
		grid_hover(grid)


## 连续回收
func _try_reclaim_continuous(grid: Vector2i) -> void:
	if MGIS.inventory_service.pickup_single_to_moving(self, grid):
		_last_grid_pos = grid
		_clear_highlight()
		grid_hover(grid)


# --- 其他辅助 ---


func _clear_hover_status(item_view: ItemView) -> void:
	if _current_hover_view == item_view:
		MGIS.sig_hide_item_range.emit(container_name, item_view)
		_current_hover_view = null


func _handle_item_hover(grid_pos: Vector2i) -> void:
	var item_view = find_item_view_by_grid(grid_pos)
	if item_view != _current_hover_view:
		if _current_hover_view:
			MGIS.sig_hide_item_range.emit(container_name, _current_hover_view)
		_current_hover_view = item_view
		if _current_hover_view:
			MGIS.sig_show_item_range.emit(container_name, _current_hover_view)


func _on_mouse_exited_control() -> void:
	grid_lose_hover(_current_mouse_grid)
	_current_mouse_grid = -Vector2i.ONE
	_last_grid_pos = -Vector2i.ONE

	if _current_hover_view:
		MGIS.sig_hide_item_range.emit(container_name, _current_hover_view)
		_current_hover_view = null

	if _interacting_state != 0:
		_stop_interaction()


# --- 核心：坐标转换 ---


func get_target_grid_from_mouse() -> Vector2i:
	var moving_item = MGIS.moving_item_service.moving_item
	if not moving_item:
		return get_grid_under_mouse()

	var local_mouse_pos = get_local_mouse_position()
	var item_shape = moving_item.get_shape(is_slot)
	var item_pixel_size = Vector2(item_shape) * float(base_size)
	var raw_top_left_px = local_mouse_pos - (item_pixel_size / 2.0)

	var target_x = round(raw_top_left_px.x / base_size)
	var target_y = round(raw_top_left_px.y / base_size)
	return Vector2i(int(target_x), int(target_y))


func get_grid_under_mouse() -> Vector2i:
	var local_pos = get_local_mouse_position()
	var x = floor(local_pos.x / base_size)
	var y = floor(local_pos.y / base_size)
	return Vector2i(int(x), int(y))


# --- 核心：绘制逻辑 ---


func _draw() -> void:
	# 1. 绘制网格线
	if show_grid_lines:
		var total_w = custom_minimum_size.x
		var total_h = custom_minimum_size.y
		for i in range(container_columns + 1):
			var x = i * base_size
			draw_line(Vector2(x, 0), Vector2(x, total_h), grid_line_color)
		for i in range(container_rows + 1):
			var y = i * base_size
			draw_line(Vector2(0, y), Vector2(total_w, y), grid_line_color)

	# 2. 绘制交互高亮
	if not _highlight_grids.is_empty():
		var color = gird_background_color_taken
		match _highlight_state:
			BaseGridView.State.AVILABLE:
				color = grid_background_color_avilable
			BaseGridView.State.CONFLICT:
				color = gird_background_color_conflict
			BaseGridView.State.TAKEN:
				color = gird_background_color_taken

		for grid in _highlight_grids:
			var rect = Rect2(Vector2(grid) * base_size, Vector2(base_size, base_size))
			draw_rect(rect, color, true)
			draw_rect(rect, color.lightened(0.2), false, 2.0)


# --- 辅助函数 ---


func _update_min_size() -> void:
	custom_minimum_size = Vector2(map_width, map_height) * base_size


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


# --- 重写 BaseContainerView 的高亮逻辑 ---


func grid_hover(grid_id: Vector2i) -> void:
	MGIS.current_container = self

	if not MGIS.moving_item_service.moving_item:
		return

	MGIS.moving_item_service.sync_style_with_container(self)

	var start_grid = get_target_grid_from_mouse()
	var moving_item = MGIS.moving_item_service.moving_item
	var item_shape = moving_item.get_shape(is_slot)

	var grids = _get_grids_by_shape_sparse(start_grid, item_shape)
	_highlight_grids = grids

	var has_conflict = false
	if grids.size() != item_shape.x * item_shape.y:
		has_conflict = true
	else:
		var inv_data = MGIS.inventory_service.get_container(container_name)
		for grid in grids:
			var item_in_grid = inv_data.find_item_data_by_grid(grid)
			if item_in_grid:
				# 堆叠检查：同ID且未满 -> 允许
				if item_in_grid is StackableData and item_in_grid.item_id == moving_item.item_id and not item_in_grid.is_full():
					pass
				else:
					has_conflict = true
					break

	_highlight_state = BaseGridView.State.CONFLICT if has_conflict else BaseGridView.State.AVILABLE
	queue_redraw()


func grid_lose_hover(_grid_id: Vector2i) -> void:
	_clear_highlight()


func _clear_highlight() -> void:
	_highlight_grids.clear()
	_highlight_state = BaseGridView.State.EMPTY
	queue_redraw()


# --- 重写信号处理 (稀疏逻辑) ---


func refresh() -> void:
	_clear_inv()
	var inv_data = MGIS.inventory_service.get_container(container_name)
	if not inv_data:
		return

	var handled_items = {}
	for grid in inv_data.grid_item_map.keys():
		var item_data = inv_data.grid_item_map[grid]
		if item_data and not handled_items.has(item_data):
			handled_items[item_data] = true
			var grids = inv_data.item_grids_map.get(item_data, [])
			if grids.is_empty():
				continue

			var top_left_grid = grids[0]
			var item_view = _draw_item(item_data, top_left_grid)
			_items.append(item_view)

			_item_grids_map[item_view] = grids
			for g in grids:
				_grid_item_map[g] = item_view


func _on_item_added(inv_name: String, item_data: BaseItemData, grids: Array[Vector2i]) -> void:
	if inv_name != container_name:
		return
	if not is_visible_in_tree():
		return

	var item_view = _draw_item(item_data, grids[0])
	_items.append(item_view)
	_item_grids_map[item_view] = grids
	for grid in grids:
		_grid_item_map[grid] = item_view


func _on_item_removed(inv_name: String, item_data: BaseItemData) -> void:
	if inv_name != container_name:
		return
	if not is_visible_in_tree():
		return

	for i in range(_items.size() - 1, -1, -1):
		var item_view = _items[i]
		if item_view.data == item_data:
			var grids = _item_grids_map.get(item_view, [])
			for grid in grids:
				_grid_item_map.erase(grid)
			_item_grids_map.erase(item_view)
			_items.remove_at(i)
			item_view.queue_free()
			break


func _on_inv_item_updated(inv_name: String, grid_id: Vector2i) -> void:
	if inv_name != container_name:
		return
	if not is_visible_in_tree():
		return
	var item_view = _grid_item_map.get(grid_id)
	if is_instance_valid(item_view):
		item_view.update_stack_label()
		item_view.queue_redraw()


func _clear_inv() -> void:
	for item in _items:
		item.queue_free()
	_items.clear()
	_item_grids_map.clear()
	_grid_item_map.clear()
	queue_redraw()


func _draw_item(item_data: BaseItemData, first_grid: Vector2i) -> ItemView:
	var item = ItemView.new(item_data, base_size, stack_num_font, stack_num_font_size, stack_num_margin, stack_num_color)
	_item_container.add_child(item)
	item.position = Vector2(first_grid) * base_size
	item.first_grid = first_grid
	return item
