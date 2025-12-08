extends Control
## 物品视图，控制物品的绘制
class_name ItemView

## 堆叠数字的label
var stack_label: StackAnimLabel
## 堆叠数字的字体
var stack_num_font: Font
## 堆叠数字的字体大小
var stack_num_font_size: int
## 堆叠数字的边距
var stack_num_margin: int = 4
## 堆叠数字的颜色
var stack_num_color: Color = BaseGridView.DEFAULT_STACK_NUM_COLOR
## 堆叠数字的描边大小
var stack_outline_size: int = BaseGridView.DEFAULT_STACK_OUTLINE_SIZE
## 堆叠数字的描边颜色
var stack_outline_color: Color = BaseGridView.DEFAULT_STACK_OUTLINE_SIZE
## 圆角大小
var corner_radius: int = MGIS.CORNER_RADIUS
## 圆角边框大小
var border_width: int = MGIS.BORDER_WIDTH
## 边框颜色
var border_color: Color = MGIS.BORDER_COLOR
## 限制宽度
var limit_width: float
## 限制高度
var limit_height: float

## 物品数据
var data: BaseItemData
## 绘制基础大小（格子大小）
var base_size: int:
	set(value):
		base_size = value
		call_deferred("recalculate_size")
## 物品宽
var width: float
## 物品高
var height: float
## 物品首坐标
var first_grid: Vector2i = Vector2i.ZERO
## 物品的着色器层
var overlay_rect: ColorRect

## 是否正在移动
var _is_moving: bool = false
## 移动偏移量（坐标）
var _moving_offset: Vector2i = Vector2i.ZERO
## 缓存的 AtlasTexture 实例，用于动画贴图
var _cached_atlas_texture: AtlasTexture = null
## 当前格子拥有的数量
var _owner_amount: int = 0

## 构造函数
@warning_ignore("shadowed_variable")
func _init(
	data: BaseItemData,
	base_size: int,
	stack_num_font: Font = null,
	stack_num_font_size: int = 16,
	stack_num_margin: int = 4,
	stack_num_color: Color = BaseGridView.DEFAULT_STACK_NUM_COLOR,
	stack_outline_size: int = BaseGridView.DEFAULT_STACK_OUTLINE_SIZE,
	stack_outline_color: Color = BaseGridView.DEFAULT_STACK_OUTLINE_COLOR,
	border_width: int = MGIS.BORDER_WIDTH,
	corner_radius: int = MGIS.CORNER_RADIUS,
	border_color: Color = MGIS.BORDER_COLOR,
	limit_width: float = 0.0,
	limit_height: float = 0.0,
) -> void:
	self.data = data
	self.base_size = base_size
	self.width = data.get_columns()
	self.height = data.get_rows()
	self.stack_num_font = stack_num_font if stack_num_font else get_theme_font("font")
	self.stack_num_font_size = stack_num_font_size
	self.stack_num_margin = stack_num_margin
	self.stack_num_color = stack_num_color
	self.stack_outline_size = stack_outline_size
	self.stack_outline_color = stack_outline_color
	self.border_width = border_width
	self.corner_radius = corner_radius
	self.border_color = border_color
	self.limit_width = limit_width
	self.limit_height = limit_height
	# 记录当前拥有的数量
	if data is StackableData:
		_owner_amount = data.current_amount
	else:
		_owner_amount = 0
	recalculate_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# 可以堆叠则显示文本（使用独立的 Label 节点，解决旋转和兼容性问题）
	if data is StackableData:
		stack_label = StackAnimLabel.new()
		# 配置 Label 位置和对齐方式 (左上角)
		stack_label.position = Vector2(stack_num_margin, stack_num_margin)
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stack_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		# 使用label_settings设置字体
		var label_set: LabelSettings = LabelSettings.new()
		label_set.font = stack_num_font
		label_set.font_color = stack_num_color
		label_set.font_size = stack_num_font_size
		label_set.outline_size = stack_outline_size
		label_set.outline_color = stack_outline_color
		stack_label.label_settings = label_set
		# 确保尺寸更新，这样 Label 才能计算正确的尺寸
		stack_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stack_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		stack_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		add_child(stack_label)
		# 更新数量
		if data.current_amount > 1:
			stack_label.text = str(data.current_amount)
			stack_label.visible = true
		else:
			stack_label.visible = false
	# 动态创建一个全屏的 ColorRect 覆盖在自己身上
	overlay_rect = ColorRect.new()
	# 设置为全屏填充
	overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 鼠标事件穿透（不要挡住下面的交互）
	overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 透明色
	overlay_rect.color = Color(0, 0, 0, 0)
	add_child(overlay_rect)


## 更新堆叠 Label 的文本和可见性
func update_stack_label(update_data: BaseItemData = null) -> void:
	if is_instance_valid(update_data):
		data = update_data
	if stack_label and data is StackableData:
		var stackable_data: StackableData = data
		if not stackable_data.current_amount == _owner_amount:
			# 记录当前格子拥有的数量
			_owner_amount = data.current_amount
			# 堆叠文本动效
			if stackable_data.current_amount > 1:
				stack_label.animated_text = str(stackable_data.current_amount)
				stack_label.visible = true
			else:
				stack_label.visible = false
	elif stack_label:
		stack_label.queue_free()
		stack_label = null


# 确保在 data 发生变化或创建后调用此函数来更新 Label
func _notification(what: int) -> void:
	if what == NOTIFICATION_POSTINITIALIZE:
		# 在构造函数 _init 后确保调用 _ready() 中需要的更新
		# 实际使用中，通常在 ItemView 被添加到父节点时调用 _ready()
		pass


## 重写计算大小
func recalculate_size() -> void:
	# 大小计算
	if limit_width == 0.0 and limit_height == 0.0:
		if data.orientation == BaseItemData.ORI.VER:
			width = data.get_columns()
			height = data.get_rows()
		elif data.orientation == BaseItemData.ORI.HOR:
			width = data.get_rows()
			height = data.get_columns()
	# 限定宽和高
	else:
		width = limit_width
		height = limit_height

	var new_size = Vector2(width, height) * base_size
	self.custom_minimum_size = new_size
	self.size = new_size
	#渲染树不可见直接返回
	if not is_visible_in_tree():
		return
	queue_redraw()
	# 更新文本
	if data is StackableData:
		update_stack_label()


## 移动
func move(offset: Vector2i = Vector2i.ZERO) -> void:
	_is_moving = true
	_moving_offset = offset


## 绘制物品
func _draw() -> void:
	# 绘制物品级别底图（颜色区分不同品级的物品）
	var item_color: Color = MGIS.LEVEL_COLOR[data.item_level]
	if data.show_style_box:
		# 创建 StyleBoxFlat
		var temp_style: StyleBoxFlat = StyleBoxFlat.new()
		temp_style.bg_color = item_color
		temp_style.set_corner_radius_all(corner_radius)
		temp_style.set_border_width_all(border_width)
		temp_style.border_color = border_color
		temp_style.border_blend = true
		var draw_style_rect: Rect2 = Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
		draw_style_box(temp_style, draw_style_rect)
	# 获取物品图标
	var texture_icon: Texture2D = _get_texture()
	# 绘制图标
	if texture_icon:
		# 判断是否需要等比缩放 (如果设置了 limit_width 或 limit_height，则视为需要缩放)
		var need_scale: bool = limit_width != 0.0 or limit_height != 0.0
		# 正常绘制 (竖直方向)
		if data.orientation == BaseItemData.ORI.VER:
			if not need_scale:
				draw_texture_rect(texture_icon, Rect2(Vector2.ZERO, size), false)
			else:
				# 等比缩放绘制
				_draw_scale_texture(texture_icon)

		# 旋转90度绘制 (水平方向)
		elif data.orientation == BaseItemData.ORI.HOR:
			if not need_scale:
				_draw_rotate(texture_icon)
			else:
				# 旋转并等比缩放绘制
				_draw_rotate_scale(texture_icon)

	# 绘制额外图片
	_draw_extra_texture()
	# 更新文本
	if data is StackableData:
		update_stack_label()


## 绘制额外贴图（不支持旋转，不支持缩放）
func _draw_extra_texture() -> void:
	if data.orientation == BaseItemData.ORI.HOR:
		return
	var extra_texture: Texture2D = data.get_extra_texture()
	if not is_instance_valid(extra_texture):
		return
	# 获取原始纹理尺寸
	var texture_size: Vector2 = extra_texture.get_size()
	# 获得居中绘制点
	var center_offset: Vector2 = (size - texture_size) / 2.0 - data.extra_offset
	draw_texture_rect(extra_texture, Rect2(center_offset, texture_size), false)


## 等比缩放贴图
func _draw_scale_texture(texture: Texture2D, center_offset: Vector2 = Vector2.ZERO) -> void:
	# 目标绘制区域，即ItemView的尺寸
	var target_rect: Rect2 = Rect2(Vector2.ZERO, size)
	# 1. 获取原始纹理尺寸
	var texture_size: Vector2 = texture.get_size()
	# 2. 计算宽高缩放比例
	var scale_x: float = target_rect.size.x / texture_size.x
	var scale_y: float = target_rect.size.y / texture_size.y
	# 3. 确定统一的等比缩放系数 (取较小值，以保证图片完全可见)
	var uniform_scale: float = min(scale_x, scale_y)
	# 4. 计算缩放后的实际绘制尺寸
	var scaled_size: Vector2 = texture_size * uniform_scale
	# 5. 计算居中偏移量
	var offset: Vector2 = (target_rect.size - scaled_size) / 2.0 + center_offset
	# 6. 创建最终的绘制矩形
	var final_draw_rect: Rect2 = Rect2(offset, scaled_size)
	# 7. 使用最终矩形进行等比缩放绘制
	draw_texture_rect(texture, final_draw_rect, false)


## 获取贴图
func _get_texture() -> Texture2D:
	# 1. 配置了物品图片的直接返回（icon是固定图标，不随节气和成长等外部因素变化）
	if data.icon:
		# 清除缓存，确保下次使用图集时重新创建
		if _cached_atlas_texture:
			_cached_atlas_texture = null
		return data.icon
	# 2. 处理动画贴图
	else:
		# 2a. 检查缓存，如果不存在则创建
		if not is_instance_valid(_cached_atlas_texture):
			_cached_atlas_texture = AtlasTexture.new()
			var texture: CompressedTexture2D = data.get_texture()
			if not texture:
				return null  # 纹理不存在，提前返回
			_cached_atlas_texture.atlas = texture
			# 计算并存储显示帧的大小（只需要计算一次）
			var atlas_size: Vector2 = texture.get_size()
			var atlas_cell_size: Vector2 = Vector2(atlas_size.x / data.hframes, atlas_size.y / data.vframes)
		# 2b. 每次调用时，只需要更新 Region (帧的位置)
		var atlas_texture: AtlasTexture = _cached_atlas_texture
		var atlas_cell_size: Vector2 = Vector2(atlas_texture.atlas.get_width() / data.hframes, atlas_texture.atlas.get_height() / data.vframes)
		# 纹理裁剪位置
		var region_x: int = data.frame % data.hframes
		var region_y: int = floori(float(data.frame) / float(data.hframes))
		var region_coords: Vector2 = Vector2(region_x, region_y) * atlas_cell_size
		var region: Rect2 = Rect2(region_coords, atlas_cell_size)
		atlas_texture.region = region
		return atlas_texture

	# 3. 确保返回 Texture2D 类型 (虽然在逻辑上不应该到达这里)
	return null


## 旋转90度绘制
func _draw_rotate(texture: Texture2D) -> void:
	var original_transform: Transform2D = get_transform()
	var center: Vector2 = size / 2.0
	var rotation_angle: float = PI / 2.0  # 90度 (顺时针)
	# 1. 设置新的变换：平移到中心，然后旋转 90 度
	var rotated_transform: Transform2D = Transform2D(rotation_angle, center)
	draw_set_transform_matrix(rotated_transform)
	# 2. 绘制图标
	# *** 关键修正点：交换绘制矩形的 W 和 H ***
	# 屏幕尺寸是 (W, H)，旋转后，绘制尺寸必须是 (H, W)
	var rect_w_rotated: float = size.y
	var rect_h_rotated: float = size.x
	# 绘制矩形：起点 (-W_rotated/2, -H_rotated/2)，尺寸 (W_rotated, H_rotated)
	var draw_rect: Rect2 = Rect2(Vector2(-rect_w_rotated, -rect_h_rotated) / 2.0, Vector2(rect_w_rotated, rect_h_rotated))
	draw_texture_rect(texture, draw_rect, false)
	# 3. 恢复变换：非常重要！
	draw_set_transform_matrix(original_transform)


## 旋转90度并等比缩放绘制
func _draw_rotate_scale(texture: Texture2D) -> void:
	var original_transform: Transform2D = get_transform()
	var center: Vector2 = size / 2.0
	var rotation_angle: float = PI / 2.0  # 90度 (顺时针)
	# 1. 设置变换
	var rotated_transform: Transform2D = Transform2D(rotation_angle, center)
	draw_set_transform_matrix(rotated_transform)
	# 2. 计算缩放逻辑
	# 注意：在旋转坐标系下，绘制区域的宽变成了 size.y，高变成了 size.x
	var target_width: float = size.y
	var target_height: float = size.x
	var target_size_rotated: Vector2 = Vector2(target_width, target_height)
	var texture_size: Vector2 = texture.get_size()
	# 计算宽高缩放比例
	var scale_x: float = target_width / texture_size.x
	var scale_y: float = target_height / texture_size.y
	# 确定统一的等比缩放系数
	var uniform_scale: float = min(scale_x, scale_y)
	# 计算缩放后的实际绘制尺寸
	var scaled_size: Vector2 = texture_size * uniform_scale
	# 绘制矩形：起点 (-scaled_w/2, -scaled_h/2)
	var draw_rect: Rect2 = Rect2(-scaled_size / 2.0, scaled_size)
	# 3. 绘制
	draw_texture_rect(texture, draw_rect, false)
	# 4. 恢复变换
	draw_set_transform_matrix(original_transform)


## 跟随鼠标
func _process(_delta: float) -> void:
	if _is_moving:
		# 获取当前缩放后的像素大小
		var current_scale_size = Vector2(width, height) * base_size * self.scale.x
		# 强制居中对齐
		# 直接减去物品像素宽高的一半，使鼠标位于物品正中心
		global_position = get_global_mouse_position() - (current_scale_size / 2.0)


## 处理事件
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not get_global_rect().has_point(get_global_mouse_position()):
		if data:
			MGIS.item_focus_service.item_lose_focus(self)
	if event is InputEventMouseMotion and get_global_rect().has_point(get_global_mouse_position()):
		if data:
			MGIS.item_focus_service.focus_item(self)
