@tool
extends Control
## 装备槽视图
class_name ItemSlotView

## 装备槽的绘制状态：正常、可用、不可用
enum State { NORMAL, AVILABLE, INVILABLE }

## 物品所在容器的类型
@export var container_type: MGIS.ContainerType = MGIS.ContainerType.SLOT
## 容器名称，如果重复，则显示同一来源的数据
var container_name: String = MGIS.DEFAULT_SLOT_NAME
## 装备槽名称，如果重复则展示同意来源的数据
@export var slot_name: String = MGIS.DEFAULT_SLOT_NAME:
	set(value):
		slot_name = value
		container_name = value
## 基础大小（格子大小）
@export var base_size: int = 32:
	set(value):
		base_size = value
		_recalculate_size()
## 列数（仅显示，与物品大小无关）
@export var columns: int = 1:
	set(value):
		columns = value
		_recalculate_size()
## 行数（仅显示，与物品大小无关）
@export var rows: int = 1:
	set(value):
		rows = value
		_recalculate_size()
## 背景图片
@export var background: Texture2D:
	set(value):
		background = value
		queue_redraw()
## 视图边距
@export var item_margin: int = 0:
	set(value):
		item_margin = value
		queue_redraw()
## 可用时的颜色（推荐半透明）
@export var avilable_color: Color = BaseGridView.DEFAULT_AVILABLE_COLOR:
	set(value):
		avilable_color = value
		queue_redraw()
## 不可用时的颜色（推荐半透明）
@export var invilable_color: Color = BaseGridView.DEFAULT_CONFLICT_COLOR:
	set(value):
		invilable_color = value
		queue_redraw()
## 可以装备的物品类型，对应 BaseItemData.type
@export var avilable_types: Array[String] = ["ANY"]
@export_group("Stack Settings")
## 堆叠数量的字体
@export var stack_num_font: Font:
	set(value):
		stack_num_font = value
		queue_redraw()
## 堆叠数量的字体大小
@export var stack_num_font_size: int = 12:
	set(value):
		stack_num_font_size = value
		queue_redraw()
## 堆叠数量的边距（右下角）
@export var stack_num_margin: int = 2:
	set(value):
		stack_num_margin = value
		queue_redraw()
## 堆叠数量的颜色
@export var stack_num_color: Color = BaseGridView.DEFAULT_STACK_NUM_COLOR:
	set(value):
		stack_num_color = value
		queue_redraw()
## 堆叠数量的描边大小
@export var stack_outline_size: int = 0:
	set(value):
		stack_outline_size = value
		queue_redraw()
## 堆叠数量的描边颜色
@export var stack_outline_color: Color = Color.BLACK:
	set(value):
		stack_outline_color = value
		queue_redraw()

## 物品容器
var _item_container: Control
## 物品视图
var _item_view: ItemView
## 当前绘制状态
var _state: State = State.NORMAL


## 是否为空
func is_empty() -> bool:
	return _item_view == null


## 当前容器是否打开
func is_open() -> bool:
	return is_visible_in_tree()


## 更新tooltip
func update_tooltip(slot_name: String, bbcode_text: String = "") -> void:
	# 查找插槽
	var slot_view: ItemSlotView = MGIS.get_container_view(slot_name)
	if is_instance_valid(slot_view):
		slot_view.tooltip_text = bbcode_text


## 更新_item_view视图
func update_item_view(update_data: BaseItemData = null) -> void:
	_item_view.update_stack_label(update_data)


## 删除插槽物品
func remove_item_view() -> void:
	_clear_slot()


## 刷新装备槽显示
func refresh() -> void:
	_clear_slot()
	var slot_data: ItemSlotData = MGIS.item_slot_service.get_slot(slot_name)
	if slot_data:
		var item_data: BaseItemData = slot_data.equipped_item
		if item_data:
			_on_item_equipped(slot_name, item_data)


## 初始化
func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_recalculate_size")
		return

	if not slot_name:
		push_error("Slot must have a name.")
		return

	var ret = MGIS.item_slot_service.regist_slot(slot_name, avilable_types)
	if not ret:
		return

	# 把自己保存到全局字典
	if not MGIS.container_dict.has(container_name):
		MGIS.container_dict.set(container_name, self)

	mouse_filter = Control.MOUSE_FILTER_PASS
	_init_item_container()
	MGIS.sig_slot_item_equipped.connect(_on_item_equipped)
	MGIS.sig_slot_item_unequipped.connect(_on_item_unequipped)
	MGIS.sig_slot_refresh.connect(refresh)
	mouse_entered.connect(_on_slot_hover)
	mouse_exited.connect(_on_slot_lose_hover)

	call_deferred("refresh")


## 高亮
func _on_slot_hover() -> void:
	if not MGIS.moving_item_service.moving_item:
		return
		
	var moving_view = MGIS.moving_item_service.moving_item_view
	
	# 1. 同步样式
	MGIS.moving_item_service.sync_style_with_container(self) # 假设 ItemSlotView 也有 base_size 等属性
	
	# 2. 限制大小 (适配插槽的行列数)
	# 装备槽有自己的 columns 和 rows，物品必须缩放进去
	moving_view.limit_width = float(columns)
	moving_view.limit_height = float(rows)
	moving_view.recalculate_size()
	
	# 3. 网格高亮
	var slot_data = MGIS.item_slot_service.get_slot(slot_name)
	var is_avilable = slot_data.is_item_avilable(MGIS.moving_item_service.moving_item)
	
	_state = State.AVILABLE if is_avilable and is_empty() else State.INVILABLE
	queue_redraw()


## 失去高亮
func _on_slot_lose_hover() -> void:
	if MGIS.moving_item_service.moving_item:
		# 恢复大小
		var moving_view = MGIS.moving_item_service.moving_item_view
		if moving_view:
			moving_view.limit_width = 0.0
			moving_view.limit_height = 0.0
			moving_view.recalculate_size()
			
	_state = State.NORMAL
	queue_redraw()


## 监听穿装备
@warning_ignore("shadowed_variable")
func _on_item_equipped(slot_name: String, item_data: BaseItemData):
	if slot_name != self.slot_name:
		return
	# 为空则添加物品视图
	if is_empty():
		_item_view = _draw_item(item_data)
		_item_container.add_child(_item_view)
		_state = State.NORMAL
		# 堆叠物品则更新堆叠数据
		if item_data is StackableData:
			print("before->current_amount:",item_data.current_amount)
			_item_view.update_stack_label(item_data)
	# 非空
	else:
		# 堆叠物品则更新堆叠数据
		if item_data is StackableData:
			print("after->current_amount:",item_data.current_amount)
			_item_view.update_stack_label(item_data)
	## 更新提示文本
	update_tooltip(slot_name, item_data.tooltips)


## 监听脱装备
@warning_ignore("shadowed_variable")
func _on_item_unequipped(slot_name: String, _item_data: BaseItemData):
	if slot_name != self.slot_name:
		return
	## 更新提示文本
	update_tooltip(slot_name, "")
	_clear_slot()


## 绘制装备
func _draw_item(item_data: BaseItemData) -> ItemView:
	item_data.orientation = BaseItemData.ORI.VER
	var item = (
		ItemView
		. new(
			item_data,
			base_size - item_margin,
			stack_num_font,
			stack_num_font_size,
			stack_num_margin,
			stack_num_color,
			stack_outline_size,
			stack_outline_color,
			0,
			MGIS.CORNER_RADIUS,
			MGIS.BORDER_COLOR,
			float(columns),
			float(rows),
		)
	)
	var center = size / 2 - item.size / 2
	item.position = center
	return item


## 清空装备槽显示（仅清空显示，与数据无关）
func _clear_slot() -> void:
	if _item_view:
		_item_view.queue_free()
		_item_view = null


## 初始化物品容器
func _init_item_container() -> void:
	_item_container = Control.new()
	add_child(_item_container)


## 绘制装备槽背景
func _draw() -> void:
	if background:
		draw_texture_rect(background, Rect2(0, 0, columns * base_size, rows * base_size), false)
		var margin_size: Vector2 = Vector2(item_margin, item_margin)
		var inner_size: Vector2 = Vector2(columns * base_size, rows * base_size) - margin_size * 2
		match _state:
			State.AVILABLE:
				draw_rect(Rect2(margin_size, inner_size), avilable_color, true)
			State.INVILABLE:
				draw_rect(Rect2(margin_size, inner_size), invilable_color, true)
	else:
		draw_rect(Rect2(0, 0, columns * base_size, rows * base_size), invilable_color)


## 重新计算大小
func _recalculate_size() -> void:
	var new_size = Vector2(columns, rows) * base_size
	self.custom_minimum_size = new_size
	self.size = new_size
	queue_redraw()


## 输入控制
func _gui_input(event: InputEvent) -> void:
	# 点击物品
	if event.is_action_pressed(MGIS.input_click):
		if MGIS.moving_item_service.moving_item and is_empty():
			MGIS.item_slot_service.equip_moving_item(slot_name)
		elif not MGIS.moving_item_service.moving_item and not is_empty():
			# 先清除物品信息
			MGIS.item_focus_service.item_lose_focus(_item_view)
			MGIS.item_slot_service.move_item(slot_name, base_size)
			_on_slot_hover()
	# 快速移动物品
	elif event.is_action_pressed(MGIS.input_quick_move):
		if is_empty():
			return
		# 先清除物品信息
		MGIS.item_focus_service.item_lose_focus(_item_view)
		MGIS.item_slot_service.unequip(slot_name)
	# 快速移动一半的物品
	elif event.is_action_pressed(MGIS.input_move_half):
		if is_empty():
			return
		var item_data: BaseItemData = MGIS.item_slot_service.get_slot(slot_name).equipped_item
		if item_data is StackableData:
			MGIS.item_slot_service.half_unequip(slot_name, item_data)
		else:
			# 先清除物品信息
			MGIS.item_focus_service.item_lose_focus(_item_view)
			MGIS.item_slot_service.unequip(slot_name)
	# 使用物品
	elif event.is_action_pressed(MGIS.input_use):
		if is_empty():
			return
		var item_data: BaseItemData = MGIS.item_slot_service.get_slot(slot_name).equipped_item
		# 插槽容器的物品是消耗品则直接使用
		if item_data is ConsumableData:
			MGIS.item_slot_service.use_item(slot_name)
		# 脱掉装备
		else:
			# 先清除物品信息
			MGIS.item_focus_service.item_lose_focus(_item_view)
			MGIS.item_slot_service.unequip(slot_name)


## 重写tootip显示函数
## ===============重要=========================
## 自定义tooltips窗口，注意一定在代理中封装create函数
## ===============重要=========================
func _make_custom_tooltip(for_text: String) -> Control:
	if is_instance_valid(MGIS.proxy_tooltip):
		return MGIS.proxy_tooltip.create(for_text)
	return null
