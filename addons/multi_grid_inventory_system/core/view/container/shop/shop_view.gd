@tool
extends BaseContainerView
## 背包视图，控制背包的绘制
class_name ShopView
## 商店的物品资源
@export var goods: Array[BaseItemData]


## 格子高亮
func grid_hover(grid_id: Vector2i) -> void:
	super(grid_id)
	if not MGIS.moving_item_service.moving_item:
		selected_item(container_name, grid_id)
		return


## 格子失去高亮
func grid_lose_hover(grid_id: Vector2i) -> void:
	super(grid_id)
	unselected_item()


## 高亮经过的物品
func selected_item(shop_name: String, grid_id: Vector2i) -> void:
	var selected_item_view: ItemView = find_item_view_by_grid(grid_id)
	if not is_instance_valid(selected_item_view):
		return
	var head_pos: Vector2i = selected_item_view.first_grid
	# 高亮点击的物品
	var item_data: BaseItemData = MGIS.shop_service.find_item_data_by_grid(shop_name, grid_id)
	var item_shape = item_data.get_shape(is_slot)
	selected_grids = _get_grids_by_shape(head_pos, item_shape)

	for grid: Vector2i in selected_grids:
		var grid_view: BaseGridView = _grid_map[grid]
		grid_view.state = BaseGridView.State.AVILABLE


## 通过格子ID获取物品视图
func find_item_view_by_grid(grid_id: Vector2i) -> ItemView:
	return _grid_item_map.get(grid_id)


## 更新货物
func update_goods() -> void:
	MGIS.shop_service.get_container(container_name).clear()
	MGIS.shop_service.load_goods(container_name, goods)
	# 刷新
	MGIS.sig_shop_refresh.emit()


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
	## 物品所在容器的类型
	container_type = MGIS.ContainerType.SHOP
	# 存入字典
	if not MGIS.container_dict.has(container_name):
		MGIS.container_dict.set(container_name, self)

	var ret = MGIS.shop_service.regist(container_name, container_columns, activated_rows, container_rows)

	# 使用已注册的信息覆盖View设置
	container_columns = ret.columns
	container_rows = ret.rows
	activated_rows = ret.activated_rows

	# 加载货物
	MGIS.shop_service.get_container(container_name).clear()
	MGIS.shop_service.load_goods(container_name, goods)

	mouse_filter = Control.MOUSE_FILTER_PASS
	_init_grid_container()
	_init_item_container()
	_init_grids()
	MGIS.sig_shop_refresh.connect(refresh)
	MGIS.sig_inv_item_added.connect(_on_item_added)
	MGIS.sig_inv_item_removed.connect(_on_item_removed)
	MGIS.sig_inv_item_updated.connect(_on_inv_item_updated)

	visibility_changed.connect(_on_visible_changed)

	if not stack_num_font:
		stack_num_font = get_theme_font("font")

	call_deferred("refresh")


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
				ShopGridView
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
