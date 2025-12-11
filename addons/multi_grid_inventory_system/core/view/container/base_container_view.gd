@tool
extends Control
## 背包视图，控制背包的绘制
class_name BaseContainerView

## 物品所在容器的类型
@export var container_type: MGIS.ContainerType = MGIS.ContainerType.INVENTORY
@export_group("Container Settings")
## 背包名字，如果重复，则显示同一来源的数据
@export var container_name: String = MGIS.DEFAULT_INVENTORY_NAME
## 背包列数，如果背包名字重复，列数需要一样
@export var container_columns: int = 2:
	set(value):
		container_columns = value
		_recalculate_size()
## 背包行数，如果背包名字重复，行数需要一样
@export var container_rows: int = 2:
	set(value):
		container_rows = value
		_recalculate_size()
## 激活的背包行数（激活的才能摆放物品，主要用于预占位，不想动态改变背包行数的情况）
@export var activated_rows: int = 2:
	set(value):
		activated_rows = value
		_recalculate_size()

@export_group("Grid Settings")
## 格子大小
@export var base_size: int = 32:
	set(value):
		base_size = value
		_recalculate_size()
## 格子边框大小
@export var grid_border_size: int = 1:
	set(value):
		grid_border_size = value
		queue_redraw()
## 格子偏移（应对有边框边距的网格）
@export var grid_offset: Vector2i = Vector2i.ZERO
## 格子边框颜色
@export var grid_border_color: Color = BaseGridView.DEFAULT_BORDER_COLOR:
	set(value):
		grid_border_color = value
		queue_redraw()
## 格子空置颜色
@export var gird_background_color_empty: Color = BaseGridView.DEFAULT_EMPTY_COLOR:
	set(value):
		gird_background_color_empty = value
		queue_redraw()
## 格子禁用的颜色
@export var gird_background_color_disabled: Color = BaseGridView.DEFAULT_DISABLED_COLOR:
	set(value):
		gird_background_color_disabled = value
		queue_redraw()
## 格子占用颜色
@export var gird_background_color_taken: Color = BaseGridView.DEFAULT_TAKEN_COLOR:
	set(value):
		gird_background_color_taken = value
		queue_redraw()
## 格子冲突颜色
@export var gird_background_color_conflict: Color = BaseGridView.DEFAULT_CONFLICT_COLOR:
	set(value):
		gird_background_color_conflict = value
		queue_redraw()
## 格子可用颜色
@export var grid_background_color_avilable: Color = BaseGridView.DEFAULT_AVILABLE_COLOR:
	set(value):
		grid_background_color_avilable = value
		queue_redraw()

## 格子贴图
@export var grid_background_texture: Texture2D = null:
	set(value):
		grid_background_texture = value
		queue_redraw()

## 格子禁用贴图
@export var grid_background_disabled_texture: Texture2D = null:
	set(value):
		grid_background_disabled_texture = value
		queue_redraw()
## 格子的StyleBox样式
@export var grid_style_box: StyleBox = null

@export_group("Stack Settings")
## 堆叠数量的字体
@export var stack_num_font: Font:
	set(value):
		stack_num_font = value
		queue_redraw()
## 堆叠数量的字体大小
@export var stack_num_font_size: int = 16:
	set(value):
		stack_num_font_size = value
		queue_redraw()
## 堆叠数量的边距（右下角）
@export var stack_num_margin: int = 4:
	set(value):
		stack_num_margin = value
		queue_redraw()
## 堆叠数量的颜色
@export var stack_num_color: Color = BaseGridView.DEFAULT_STACK_NUM_COLOR:
	set(value):
		stack_num_color = value
		queue_redraw()
## 堆叠数量的描边大小
@export var stack_outline_size: int = BaseGridView.DEFAULT_STACK_OUTLINE_SIZE:
	set(value):
		stack_outline_size = value
		queue_redraw()
## 堆叠数量的描边颜色
@export var stack_outline_color: Color = BaseGridView.DEFAULT_STACK_OUTLINE_COLOR:
	set(value):
		stack_outline_color = value
		queue_redraw()

## 格子是否激活
var activated: bool = true
## 当前选中高亮的网格
var selected_grids: Array = []
## 是否单格背包
var is_slot: bool = false
## 格子容器
var _grid_container: GridContainer
## 物品容器
var _item_container: Control

## 所有物品的View
var _items: Array[ItemView]
## 物品到格子的映射（Array[Vector2i]）
var _item_grids_map: Dictionary[ItemView, Array]
## 格子到格子View的映射
var _grid_map: Dictionary[Vector2i, BaseGridView]
## 格子到物品的映射
var _grid_item_map: Dictionary[Vector2i, ItemView]


## 子类实现具体功能
func grid_hover(grid_id: Vector2i) -> void:
	MGIS.current_container = self


## 子类实现具体功能
func grid_lose_hover(grid_id: Vector2i) -> void:
	pass


## 消除鼠标经过时候的高亮
func unselected_item() -> void:
	for grid: Vector2i in selected_grids:
		var grid_view: BaseGridView = _grid_map[grid]
		grid_view.state = BaseGridView.State.EMPTY


## 当前容器是否打开
func is_open() -> bool:
	return is_visible_in_tree()


## 返回格子到格子的映射
func get_grid_map() -> Dictionary[Vector2i, BaseGridView]:
	return _grid_map


## 刷新背包显示
func refresh() -> void:
	_clear_inv()
	var inv_data = MGIS.inventory_service.get_container(container_name)
	# [安全检查] 确保数据存在
	if not inv_data:
		return
	var handled_item: Dictionary[BaseItemData, ItemView] = {}
	for grid in _grid_map.keys():
		var item_data = inv_data.grid_item_map.get(grid)
		if item_data and not handled_item.has(item_data):
			var grids = inv_data.item_grids_map[item_data]
			var item = _draw_item(item_data, grids[0])
			handled_item[item_data] = item
			_items.append(item)
			_item_grids_map[item] = grids
			for g in grids:
				# 确保格子存在
				if _grid_map.has(g):
					_grid_map[g].taken(g - grids[0])
					_grid_item_map[g] = item
			# 初始化加载物品时，手动更新一次 Tooltip
			update_tooltip(container_name, item_data.tooltips, grids)
			continue
		elif item_data:
			_grid_item_map[grid] = handled_item[item_data]
		else:
			_grid_item_map[grid] = null


## 通过格子ID获取物品视图
func find_item_view_by_grid(grid_id: Vector2i) -> ItemView:
	return _grid_item_map.get(grid_id)


## 更新网格的tooltip文本
func update_tooltip(inv_name: String, item_tooltip: String, grids: Array[Vector2i]) -> void:
	# 查找网格
	var container_view: BaseContainerView = MGIS.get_container_view(inv_name)
	var grid_map: Dictionary[Vector2i, BaseGridView] = container_view.get_grid_map()
	# 遍历grids，对每个格子都更新提示
	for grid: Vector2i in grids:
		if grid_map.has(grid):
			var grid_view: BaseGridView = grid_map.get(grid)
			if is_instance_valid(grid_view):
				grid_view.update_tooltip(item_tooltip)


func _on_visible_changed() -> void:
	if is_visible_in_tree():
		# 需要等待GirdContainer处理完成，否则其下的所有grid没有position信息
		await get_tree().process_frame
		refresh()


## 初始化
func _ready() -> void:
	pass


## 清空背包显示
## 注意，只清空显示，不清空数据库
func _clear_inv() -> void:
	for item in _items:
		item.queue_free()
	_items = []
	_item_grids_map = {}
	for grid in _grid_map.values():
		grid.release()
	_grid_item_map = {}


## 从指定格子开始，获取形状覆盖的格子
func _get_grids_by_shape(start: Vector2i, shape: Vector2i) -> Array[Vector2i]:
	var ret: Array[Vector2i] = []
	for row in shape.y:
		for col in shape.x:
			var grid_id = Vector2i(start.x + col, start.y + row)
			if _grid_map.has(grid_id):
				# 并且是激活的格子
				if _grid_map[grid_id].is_activated():
					ret.append(grid_id)
	return ret


## 绘制物品
func _draw_item(item_data: BaseItemData, first_grid: Vector2i) -> ItemView:
	var item = ItemView.new(item_data, base_size, stack_num_font, stack_num_font_size, stack_num_margin, stack_num_color)
	_item_container.add_child(item)
	item.global_position = _grid_map[first_grid].global_position
	item.first_grid = first_grid
	return item


## 初始化格子容器
func _init_grid_container() -> void:
	_grid_container = GridContainer.new()
	_grid_container.add_theme_constant_override("h_separation", 0)
	_grid_container.add_theme_constant_override("v_separation", 0)
	_grid_container.columns = container_columns
	_grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid_container)


## 初始化物品容器
func _init_item_container() -> void:
	_item_container = Control.new()
	add_child(_item_container)


## 编辑器中绘制示例
func _draw() -> void:
	if Engine.is_editor_hint():
		var inner_size = base_size - grid_border_size * 2
		for row in container_rows:
			for col in container_columns:
				draw_rect(Rect2(col * base_size, row * base_size, base_size, base_size), grid_border_color, true)
				draw_rect(Rect2(col * base_size + grid_border_size, row * base_size + grid_border_size, inner_size, inner_size), gird_background_color_empty, true)


## 重新计算大小
func _recalculate_size() -> void:
	var new_size = Vector2(container_columns * base_size, container_rows * base_size)
	if size != new_size:
		size = new_size
	self.custom_minimum_size = new_size
	self.size = new_size
	queue_redraw()


## 监听添加物品
func _on_item_added(inv_name: String, item_data: BaseItemData, grids: Array[Vector2i]) -> void:
	if not inv_name == container_name:
		return
	if not is_visible_in_tree():
		return
	var item = _draw_item(item_data, grids[0])
	_items.append(item)
	_item_grids_map[item] = grids
	for grid in grids:
		_grid_map[grid].taken(grid - grids[0])
		_grid_item_map[grid] = item
	# 更新网格的tooltip文本
	update_tooltip(inv_name, item_data.tooltips, grids)


## 监听移除物品
func _on_item_removed(inv_name: String, item_data: BaseItemData) -> void:
	if not inv_name == container_name:
		return
	if not is_visible_in_tree():
		return
	#print("_on_item_removed->inv_name:",inv_name,",item_id:",item_data.item_id)
	for i in range(_items.size() - 1, -1, -1):
		var item = _items[i]
		if item.data == item_data:
			var grids = _item_grids_map[item]
			# 更新网格的tooltip文本为空
			update_tooltip(inv_name, "", grids)
			for grid in grids:
				_grid_map[grid].release()
				_grid_item_map[grid] = null
			item.queue_free()
			_items.remove_at(i)
			break


## 监听更新物品
func _on_inv_item_updated(inv_name: String, grid_id: Vector2i) -> void:
	if not inv_name == container_name:
		return
	if not is_visible_in_tree():
		return
	if is_instance_valid(_grid_item_map[grid_id]):
		_grid_item_map[grid_id].queue_redraw()
