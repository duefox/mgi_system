@tool
extends BaseContainerView
## 背包视图，控制背包的绘制
class_name InventoryView

## 允许存放的物品类型，如果背包名字重复，可存放的物品类型需要一样
@export var avilable_types: Array[String] = ["ANY"]


## 整理排序
func sort_inventory(sort_attri: String, reverse: bool = false) -> void:
	if MGIS.inventory_service.sort_items(container_name, sort_attri, reverse):
		# 刷新数据
		refresh()


## 格子高亮
func grid_hover(grid_id: Vector2i) -> void:
	super(grid_id)
	if not MGIS.moving_item_service.moving_item:
		selected_item(container_name, grid_id)
		return
	var moving_item_view = MGIS.moving_item_service.moving_item_view
	moving_item_view.base_size = base_size
	moving_item_view.stack_num_color = stack_num_color
	moving_item_view.stack_num_font = stack_num_font
	moving_item_view.stack_num_font_size = stack_num_font_size
	moving_item_view.stack_num_margin = stack_num_margin
	moving_item_view.stack_num_color = stack_num_color
	moving_item_view.stack_outline_size = stack_outline_size
	moving_item_view.stack_outline_color = stack_outline_color
	moving_item_view.border_width = MGIS.BORDER_WIDTH
	moving_item_view.corner_radius = MGIS.CORNER_RADIUS
	moving_item_view.border_color = MGIS.BORDER_COLOR
	moving_item_view.limit_width = 0.0
	moving_item_view.limit_height = 0.0
	# 拖拽的物品同步缩放
	moving_item_view.scale = self.scale

	var moving_item_offset = MGIS.moving_item_service.moving_item_offset
	var moving_item = MGIS.moving_item_service.moving_item
	var item_shape = moving_item.get_shape(is_slot)
	var grids = _get_grids_by_shape(grid_id - moving_item_offset, item_shape)
	var has_conflict = item_shape.x * item_shape.y != grids.size() or not MGIS.inventory_service.get_container(container_name).is_item_avilable(moving_item)
	for grid in grids:
		if has_conflict:
			break
		has_conflict = _grid_map[grid].has_taken
		var item_view = _grid_item_map.get(grid_id)
		if has_conflict and item_view:
			var item_data: BaseItemData = item_view.data
			if item_data is StackableData:
				if item_data.item_id == MGIS.moving_item_service.moving_item.item_id and not item_data.is_full():
					has_conflict = false
	for grid in grids:
		var grid_view = _grid_map[grid]
		grid_view.state = BaseGridView.State.CONFLICT if has_conflict else BaseGridView.State.AVILABLE


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


## 格子失去高亮
func grid_lose_hover(grid_id: Vector2i) -> void:
	super(grid_id)
	if not MGIS.moving_item_service.moving_item:
		unselected_item()
		return
	var moving_item_offset = MGIS.moving_item_service.moving_item_offset
	var moving_item = MGIS.moving_item_service.moving_item
	var item_shape = moving_item.get_shape()
	var grids = _get_grids_by_shape(grid_id - moving_item_offset, item_shape)
	for grid in grids:
		var grid_view = _grid_map[grid]
		grid_view.state = BaseGridView.State.TAKEN if grid_view.has_taken else BaseGridView.State.EMPTY


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
	is_slot = false
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
		)
	)
	_item_container.add_child(item)
	item.global_position = _grid_map[first_grid].global_position + Vector2(grid_offset)
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
