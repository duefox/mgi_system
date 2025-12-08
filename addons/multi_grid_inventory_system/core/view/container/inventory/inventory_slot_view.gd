@tool
extends BaseContainerView
## 单格背包视图，控制背包的绘制
class_name InventorySlotView

## 允许存放的物品类型，如果背包名字重复，可存放的物品类型需要一样
@export var avilable_types: Array[String] = ["ANY"]

# inventory_slot_view.gd

## [新增] 像素吸附 (对于单格，其实就是鼠标所在的格子，但为了统一接口)
func get_target_grid_from_mouse() -> Vector2i:
	var moving_item = MGIS.moving_item_service.moving_item
	if not moving_item: return Vector2i.ZERO
	
	var local_mouse_pos = get_local_mouse_position()
	# 单格背包强制 1x1
	var item_pixel_size = Vector2(base_size, base_size) 
	var raw_top_left_px = local_mouse_pos - (item_pixel_size / 2.0)
	
	var target_x = round(raw_top_left_px.x / base_size)
	var target_y = round(raw_top_left_px.y / base_size)
	return Vector2i(int(target_x), int(target_y))


## 格子高亮
func grid_hover(grid_id: Vector2i) -> void:
	# 1. 调用父类逻辑
	super(grid_id)
	
	# 2. 如果没有拖拽物品，执行普通选中高亮
	if not MGIS.moving_item_service.moving_item:
		selected_item(container_name, grid_id)
		return

	# 3. [样式同步] 同步基础样式 (字体、颜色等)
	MGIS.moving_item_service.sync_style_with_container(self)
	
	# 4. [特殊逻辑] 强制限制拖拽物品显示为 1x1
	# 无论物品原本是 2x2 还是 3x3，在单格容器上方悬停时，必须缩放进格子里
	var moving_view = MGIS.moving_item_service.moving_item_view
	if moving_view:
		moving_view.limit_width = 1.0
		moving_view.limit_height = 1.0
		# 强制立即重算尺寸，保证视觉瞬间变小
		moving_view.recalculate_size()

	# 5. 计算高亮区域
	# 对于单格背包，形状强制为 1x1，且不需要计算偏移，目标就是当前 grid_id
	var moving_item = MGIS.moving_item_service.moving_item
	var item_shape = Vector2i.ONE 
	
	# 获取覆盖的格子 (其实就是 grid_id 本身)
	var grids = _get_grids_by_shape(grid_id, item_shape)
	
	# 记录高亮格子 (供 grid_lose_hover 使用)
	selected_grids = grids 

	# 6. 冲突检测逻辑
	# 检查容器类型限制 (例如快捷栏可能不限制，但特定单格可能有类型限制)
	var has_conflict = not MGIS.inventory_service.get_container(container_name).is_item_avilable(moving_item)
	
	for grid in grids:
		if has_conflict:
			break
			
		# 检查格子占用情况
		var is_taken = _grid_map[grid].has_taken
		
		# 堆叠检测
		if is_taken:
			var item_view = _grid_item_map.get(grid)
			if item_view:
				var item_data: BaseItemData = item_view.data
				if item_data is StackableData:
					# ID 相同且未满 -> 允许堆叠 (无冲突)
					if item_data.item_id == moving_item.item_id and not item_data.is_full():
						is_taken = false
		
		if is_taken:
			has_conflict = true

	# 7. 渲染状态
	for grid in grids:
		if _grid_map.has(grid):
			var grid_view = _grid_map[grid]
			grid_view.state = BaseGridView.State.CONFLICT if has_conflict else BaseGridView.State.AVILABLE


## 格子失去高亮
func grid_lose_hover(grid_id: Vector2i) -> void:
	super(grid_id)
	
	# [恢复] 如果有拖拽物品，恢复其尺寸限制
	if MGIS.moving_item_service.moving_item:
		var moving_view = MGIS.moving_item_service.moving_item_view
		if moving_view:
			moving_view.limit_width = 0.0  # 0.0 表示无限制
			moving_view.limit_height = 0.0
			moving_view.recalculate_size()
			
	if not MGIS.moving_item_service.moving_item:
		unselected_item()
		return
		
	# 清除高亮
	for grid in selected_grids:
		if _grid_map.has(grid):
			var grid_view = _grid_map[grid]
			grid_view.state = BaseGridView.State.TAKEN if grid_view.has_taken else BaseGridView.State.EMPTY
	selected_grids.clear()


## 高亮经过的物品
func selected_item(shop_name: String, grid_id: Vector2i) -> void:
	var selected_item_view: ItemView = find_item_view_by_grid(grid_id)
	if not is_instance_valid(selected_item_view):
		return
	var head_pos: Vector2i = selected_item_view.first_grid
	# 高亮点击的物品
	var item_data: BaseItemData = MGIS.inventory_service.find_item_data_by_grid(shop_name, grid_id)
	var item_shape = item_data.get_shape(is_slot)
	selected_grids = _get_grids_by_shape(head_pos, item_shape)

	for grid: Vector2i in selected_grids:
		var grid_view: BaseGridView = _grid_map[grid]
		grid_view.state = BaseGridView.State.AVILABLE



## 通过格子ID获取物品视图
func find_item_view_by_grid(grid_id: Vector2i) -> ItemView:
	return _grid_item_map.get(grid_id)


## 初始化
func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		call_deferred("_recalculate_size")
		return

	if not container_name:
		push_error("Inventory must have a name.")
		return
	is_slot = true
	# 物品所在容器的类型
	container_type = MGIS.ContainerType.INVENTORY
	# 存入字典
	if not MGIS.container_dict.has(container_name):
		MGIS.container_dict.set(container_name, self)
	# 注冊背包
	var ret = MGIS.inventory_service.regist(container_name, container_columns, container_rows, activated_rows, avilable_types)

	# 使用已注册的信息覆盖View设置
	avilable_types = ret.avilable_types
	container_columns = ret.columns
	container_rows = ret.rows
	activated_rows = ret.activated_rows

	mouse_filter = Control.MOUSE_FILTER_PASS
	_init_grid_container()
	_init_item_container()
	_init_grids()
	MGIS.sig_inv_item_added.connect(_on_item_added)
	MGIS.sig_inv_item_removed.connect(_on_item_removed)
	MGIS.sig_inv_item_updated.connect(_on_inv_item_updated)
	MGIS.sig_inv_refresh.connect(refresh)

	visibility_changed.connect(_on_visible_changed)

	if not stack_num_font:
		stack_num_font = get_theme_font("font")

	call_deferred("refresh")


## 绘制物品
func _draw_item(item_data: BaseItemData, first_grid: Vector2i) -> ItemView:
	var item = (
		ItemView
		. new(
			item_data,
			base_size,
			stack_num_font,
			stack_num_font_size,
			stack_num_margin,
			stack_num_color,
			stack_outline_size,
			stack_outline_color,
			MGIS.BORDER_WIDTH,
			MGIS.CORNER_RADIUS,
			MGIS.BORDER_COLOR,
			1,
			1,
		)
	)
	_item_container.add_child(item)
	item.global_position = _grid_map[first_grid].global_position
	item.first_grid = first_grid
	return item


## 初始化格子View
func _init_grids() -> void:
	for row in container_rows:
		# 设置格子是否激活
		if row >= activated_rows:
			activated = false
		else:
			activated = true
		# 渲染格子
		for col in container_columns:
			var grid_id = Vector2i(col, row)
			var grid = (
				InventoryGridView
				. new(
					self,
					grid_id,
					base_size,
					grid_border_size,
					grid_border_color,
					gird_background_color_empty,
					gird_background_color_disabled,
					gird_background_color_taken,
					gird_background_color_conflict,
					grid_background_color_avilable,
					grid_background_texture,
					grid_background_disabled_texture,
					grid_style_box,
					activated,
				)
			)
			_grid_container.add_child(grid)
			_grid_map[grid_id] = grid
