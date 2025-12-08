extends RefCounted
## 移动物品业务类
class_name MovingItemService

## 正在移动的物品
var moving_item: BaseItemData
## 正在移动的物品View
var moving_item_view: ItemView
## 正在移动的物品的偏移（例：一个2*2的物品，点击左上角移动时，偏移是[0,0]，点击右下角移动时，偏移是[1,1]）
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


func move_item_by_data(item_data: BaseItemData, offset: Vector2i, base_size: int) -> void:
	offset = Vector2i.ZERO
	self.moving_item = item_data
	self.moving_item_offset = offset
	self.moving_item_view = ItemView.new(item_data, base_size)
	get_moving_item_layer().add_child(moving_item_view)
	moving_item_view.move(offset)
	if drop_area_view:
		drop_area_view.show()


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


## 旋转拖拽物品
func rotate_item(inv_name: String, base_size: int) -> void:
	if not is_instance_valid(moving_item):
		return
	# [核心修改]
	# 1. 改变数据朝向
	if moving_item.orientation == BaseItemData.ORI.VER:
		moving_item.orientation = BaseItemData.ORI.HOR
	elif moving_item.orientation == BaseItemData.ORI.HOR:
		moving_item.orientation = BaseItemData.ORI.VER

	# 2. 重建 View (保持不变)
	moving_item_view.queue_free()
	# offset 传 0 即可
	move_item_by_data(moving_item, Vector2i.ZERO, base_size)
	
	

## 同步拖拽物品的样式（大小、字体等）以匹配目标容器
func sync_style_with_container(container_view: BaseContainerView) -> void:
	if not is_instance_valid(moving_item_view):
		return
		
	# 1. 性能优化：只有当基础大小或缩放不一致时才执行更新
	# 注意：浮点数比较 scale 最好用 is_equal_approx，但这里直接比较通常也够用
	if moving_item_view.base_size == container_view.base_size and moving_item_view.scale == container_view.scale:
		return

	# 2. 同步基础属性
	moving_item_view.base_size = container_view.base_size
	moving_item_view.scale = container_view.scale
	
	# 3. 同步堆叠数字样式 (防止小格子出现巨大的数字)
	moving_item_view.stack_num_color = container_view.stack_num_color
	moving_item_view.stack_num_font = container_view.stack_num_font
	moving_item_view.stack_num_font_size = container_view.stack_num_font_size
	moving_item_view.stack_num_margin = container_view.stack_num_margin
	moving_item_view.stack_outline_size = container_view.stack_outline_size
	moving_item_view.stack_outline_color = container_view.stack_outline_color
	
	# 4. 同步边框样式 (如果有需要)
	# MGIS 的常量通常是全局的，但如果容器有自定义样式，这里也要同步
	moving_item_view.border_width = MGIS.BORDER_WIDTH
	moving_item_view.corner_radius = MGIS.CORNER_RADIUS
	moving_item_view.border_color = MGIS.BORDER_COLOR
	
	# 5. 强制更新
	# base_size 的 setter 只有 call_deferred，为了保证拖拽手感（下一帧 _process 计算位置时用到新尺寸），
	# 这里虽然不需要手动调用 recalculate，但在视觉上确保万无一失
	moving_item_view.queue_redraw()
