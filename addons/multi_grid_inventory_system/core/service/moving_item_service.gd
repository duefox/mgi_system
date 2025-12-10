extends RefCounted
## 移动物品业务类
class_name MovingItemService

## 正在移动的物品
var moving_item: BaseItemData
## 正在移动的物品View
var moving_item_view: ItemView
## 正在移动的物品的偏移
var moving_item_offset: Vector2i = Vector2i.ZERO
## 丢弃物品检测区域
var drop_area_view: DropAreaView

## 顶层，用于展示移动物品的View
var _moving_item_layer: CanvasLayer


## 获取顶层，没有则新建
func get_moving_item_layer() -> CanvasLayer:
	if not _moving_item_layer:
		_moving_item_layer = CanvasLayer.new()
		_moving_item_layer.layer = 128
		MGIS.get_root().add_child(_moving_item_layer)
	return _moving_item_layer


## 清除正在移动的物品
func clear_moving_item() -> void:
	for o in _moving_item_layer.get_children():
		o.queue_free()
	moving_item = null
	moving_item_view = null
	if drop_area_view:
		drop_area_view.hide()


## 纯粹的数据移动 (底层函数，不发送 Pickup 信号，防止与旋转混淆)
func move_item_by_data(item_data: BaseItemData, offset: Vector2i, base_size: int) -> void:
	# 强制中心对齐逻辑
	offset = Vector2i.ZERO
	self.moving_item = item_data
	self.moving_item_offset = offset
	self.moving_item_view = ItemView.new(item_data, base_size)
	get_moving_item_layer().add_child(moving_item_view)
	moving_item_view.move(offset)
	if drop_area_view:
		drop_area_view.show()


## [修改] 从网格拿起物品
func move_item_by_grid(inv_name: String, grid_id: Vector2i, offset: Vector2i, base_size: int) -> void:
	if moving_item:
		push_error("Already had moving item.")
		return
	var item_data = MGIS.inventory_service.find_item_data_by_grid(inv_name, grid_id)
	if item_data:
		move_item_by_data(item_data, offset, base_size)
		MGIS.inventory_service.remove_item_by_data(inv_name, item_data)
		if drop_area_view:
			drop_area_view.show()

		# [新增] 发送拿起信号
		MGIS.sig_item_picked_up.emit(item_data)


## [修改] 旋转拖拽物品
func rotate_item(inv_name: String, base_size: int) -> void:
	if not is_instance_valid(moving_item):
		return
	# 1. 改变数据朝向
	if moving_item.orientation == BaseItemData.ORI.VER:
		moving_item.orientation = BaseItemData.ORI.HOR
	elif moving_item.orientation == BaseItemData.ORI.HOR:
		moving_item.orientation = BaseItemData.ORI.VER

	# 2. 重建 View
	moving_item_view.queue_free()
	# offset 传 0 即可
	move_item_by_data(moving_item, Vector2i.ZERO, base_size)

	# [新增] 发送旋转信号
	MGIS.sig_item_rotated.emit(moving_item)


## 同步拖拽物品的样式（大小、字体等）以匹配目标容器
func sync_style_with_container(container_view: Control) -> void:
	if not is_instance_valid(moving_item_view):
		return

	if "base_size" in container_view:
		if moving_item_view.base_size == container_view.base_size and moving_item_view.scale == container_view.scale:
			pass  # 属性一致，跳过

	if "base_size" in container_view:
		moving_item_view.base_size = container_view.base_size

	moving_item_view.scale = container_view.scale

	if "stack_num_color" in container_view:
		moving_item_view.stack_num_color = container_view.stack_num_color
		moving_item_view.stack_num_font = container_view.stack_num_font
		moving_item_view.stack_num_font_size = container_view.stack_num_font_size
		moving_item_view.stack_num_margin = container_view.stack_num_margin
		moving_item_view.stack_outline_size = container_view.stack_outline_size
		moving_item_view.stack_outline_color = container_view.stack_outline_color

	moving_item_view.border_width = MGIS.BORDER_WIDTH
	moving_item_view.corner_radius = MGIS.CORNER_RADIUS
	moving_item_view.border_color = MGIS.BORDER_COLOR

	moving_item_view.queue_redraw()
