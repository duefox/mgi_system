extends Control
## 格子视图，用于绘制格子
class_name BaseGridView

## 格子的绘制状态：空、占用、冲突、可用
enum State { EMPTY, TAKEN, CONFLICT, AVILABLE }

## 默认边框颜色
const DEFAULT_BORDER_COLOR: Color = Color.GRAY
## 默认空置颜色
const DEFAULT_EMPTY_COLOR: Color = Color.AZURE
## 默认禁用颜色
const DEFAULT_DISABLED_COLOR: Color = Color.DARK_GRAY
## 默认占用颜色
const DEFAULT_TAKEN_COLOR: Color = Color("989f9a64")
## 默认冲突颜色
const DEFAULT_CONFLICT_COLOR: Color = Color("ff000064")
## 默认可用颜色
const DEFAULT_AVILABLE_COLOR: Color = Color("00be0b64")
## 默认堆叠文本颜色stack_num_color
const DEFAULT_STACK_NUM_COLOR: Color = Color("ed870e")
## 默认堆叠文本描边颜色stack_outline_color
const DEFAULT_STACK_OUTLINE_COLOR: Color = Color.BLACK
## 默认堆叠文本描边大小stack_outline_size
const DEFAULT_STACK_OUTLINE_SIZE: int = 4
## 每隔多久扣除一个
const SUB_INTERVAL: float = 0.15

## 当前绘制状态
var state: State = State.EMPTY:
	set(value):
		state = value
		queue_redraw()

## 格子ID（格子在当前背包的坐标）
var grid_id: Vector2i = Vector2i.ZERO
## 偏移（格子存储物品时的偏移坐标，如：一个2*2的物品，这个格子是它右下角的格子，则 offset = [1,1]）
var offset: Vector2i = Vector2i.ZERO
## 是否被占用
var has_taken: bool = false
## 是否按下使用键(input_use)
var input_use_pressed: bool = false
## 边框大小
var grid_border_size: int = 1:
	set(value):
		grid_border_size = value

## 格子大小
var _size: int = 32
## 边框颜色
var _border_color: Color = DEFAULT_BORDER_COLOR
## 空置颜色
var _empty_color: Color = DEFAULT_EMPTY_COLOR
## 禁用颜色
var _disabled_color: Color = DEFAULT_DISABLED_COLOR
## 占用颜色
var _taken_color: Color = DEFAULT_TAKEN_COLOR
## 冲突颜色
var _conflict_color: Color = DEFAULT_CONFLICT_COLOR
## 可用颜色
var _avilable_color: Color = DEFAULT_AVILABLE_COLOR
## 格子贴图
var _background_texture: Texture2D = null
## 格子禁用贴图
var _background_disabled_texture: Texture2D = null
## 格子style box样式
var _grid_style_box: StyleBox = null
## 是否激活
var _activated: bool = true

## 所属的背包View
var _container_view: BaseContainerView
## 定义 Shader 材质
var _shader_material: ShaderMaterial

## 占用格子
@warning_ignore("shadowed_variable")
## 是否被激活
func is_activated() -> bool:
	return _activated


## 是否占用
func taken(offset: Vector2i) -> void:
	has_taken = true
	self.offset = offset
	state = State.TAKEN


## 释放格子
func release() -> void:
	has_taken = false
	self.offset = Vector2i.ZERO
	state = State.EMPTY


## 更新tooltip
func update_tooltip(bbcode_text: String = "") -> void:
	tooltip_text = bbcode_text


## 构造函数
@warning_ignore("shadowed_variable")
@warning_ignore("shadowed_variable_base_class")
func _init(
	inventoryView: BaseContainerView,
	grid_id: Vector2i,
	size: int,
	border_size: int,
	border_color: Color,
	empty_color: Color,
	disabled_color: Color,
	taken_color: Color,
	conflict_color: Color,
	avilable_color: Color,
	background_texture: Texture2D = null,
	background_disabled_texture: Texture2D = null,
	grid_style_box: StyleBox = null,
	activated: bool = true,
):
	_avilable_color = avilable_color
	_background_texture = background_texture
	_background_disabled_texture = background_disabled_texture
	_grid_style_box = grid_style_box
	_container_view = inventoryView
	self.grid_id = grid_id
	_size = size
	grid_border_size = border_size
	_border_color = border_color
	_empty_color = empty_color
	_disabled_color = disabled_color
	_taken_color = taken_color
	_conflict_color = conflict_color
	_activated = activated
	custom_minimum_size = Vector2(_size, _size)


## 初始化
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
func _on_mouse_entered() -> void:
	_container_view.grid_hover(grid_id)
	MGIS.mouse_cell_id = grid_id


func _on_mouse_exited() -> void:
	_container_view.grid_lose_hover(grid_id)


## 返回网格的大小
func get_cell_size() -> int:
	return _size


## 绘制逻辑
func _draw() -> void:

	# 1. 绘制背景贴图 (原逻辑保持不变)
	if _activated:
		if is_instance_valid(_background_texture):
			draw_texture(_background_texture, Vector2.ZERO)
	else:
		if is_instance_valid(_background_disabled_texture):
			draw_texture(_background_disabled_texture, Vector2.ZERO)

	# 2. 计算内部区域 (原逻辑保持不变)
	var inner_size = _size - grid_border_size * 2
	var background_color: Color

	# 3. 确定背景色 (原逻辑保持不变)
	match state:
		State.EMPTY:
			if _activated:
				background_color = _empty_color
				# 如果有贴图，背景透明
				if is_instance_valid(_background_texture):
					background_color.a = 0
			else:
				background_color = _disabled_color  #
				if is_instance_valid(_background_disabled_texture):
					background_color.a = 0
		State.TAKEN:
			background_color = _taken_color
		State.CONFLICT:
			background_color = _conflict_color
		State.AVILABLE:
			background_color = _avilable_color

	# 4. 绘制内部填充 / StyleBox
	if is_instance_valid(_grid_style_box):
		var temp_style: StyleBoxFlat = _grid_style_box.duplicate()
		temp_style.bg_color = background_color
		var draw_rect_area: Rect2 = Rect2(Vector2(grid_border_size, grid_border_size), Vector2(inner_size, inner_size))
		draw_style_box(temp_style, draw_rect_area)
	else:
		# 常规实心矩形 (填充色)
		draw_rect(Rect2(grid_border_size, grid_border_size, inner_size, inner_size), background_color, true)


## 重写tootip显示函数
## ===============重要=========================
## 自定义tooltips窗口，注意一定在代理中封装create函数
## ===============重要=========================
func _make_custom_tooltip(for_text: String) -> Control:
	if is_instance_valid(MGIS.proxy_tooltip):
		return MGIS.proxy_tooltip.create(for_text)
	return null
