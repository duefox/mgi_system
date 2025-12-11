extends Control
class_name GameMap

# --- 子节点引用 ---
# 地面层
@export var ground_layer: MapView
# 家具层
@export var interact_layer: MapView

# --- 模式缓存 ---
var _is_build_mode: bool = false


func _ready() -> void:
	# 确保自己能接收输入
	mouse_filter = Control.MOUSE_FILTER_PASS

	# 连接进入/离开信号 (可选，用于处理边界)
	mouse_exited.connect(_on_mouse_exited_map)


# --- 输入分发逻辑 (核心) ---
func _gui_input(event: InputEvent) -> void:
	# 1. 获取当前手持物品 (如果需要根据物品类型分发)
	var moving_item = MGIS.moving_item_service.moving_item

	# --- 情况 A: 建造/铺设 (手上有物品) ---
	if moving_item:
		# 判断物品属于哪一层
		# 假设 BaseItemData 有个枚举 type: "TERRAIN" (地板) 或 "BUILD" (家具)
		# 你可以根据自己的 ItemType 来判断
		if _is_ground_item(moving_item):
			# 操作地面层
			ground_layer.proxy_input(event)
			# 确保家具层不高亮/不响应
			interact_layer.clear_hover_state()

		else:
			# 操作家具层 (默认)
			interact_layer.proxy_input(event)
			ground_layer.clear_hover_state()

	# --- 情况 B: 选择/交互 (手上没物品) ---
	else:
		# 获取鼠标位置对应的逻辑格子 (用于判断层级优先级)
		# 这里需要转换坐标，假设 GameMap 和 Layer 是对齐的
		# 如果不对齐，需要用 layer.get_local_mouse_position()

		# 策略：优先检查家具层是否有物品
		# 由于我们不能直接调用 layer.get_item_at_mouse() (因为那是内部逻辑)，
		# 我们只能按优先级顺序尝试分发。

		# 这里的简单做法：
		# 1. 总是让家具层先处理 (高亮/选中)
		# 2. 只有当家具层“没东西”时，是否需要地面层响应？
		# 实际上，在双层显示中，通常高亮是最上层的。

		# 改进策略：
		# 我们把输入同时发给两层？不行，会双重高亮。
		# 我们需要查询一下家具层：鼠标下有东西吗？

		var mouse_pos = interact_layer.get_local_mouse_position()  # 假设对齐
		var grid_pos = Vector2i(floor(mouse_pos.x / interact_layer.base_size), floor(mouse_pos.y / interact_layer.base_size))

		var has_furniture = MGIS.inventory_service.find_item_data_by_grid(interact_layer.container_name, grid_pos) != null

		if has_furniture:
			# 鼠标下有家具 -> 家具层响应
			interact_layer.proxy_input(event)
			ground_layer.clear_hover_state()
		else:
			# 鼠标下没家具 -> 地面层响应 (比如高亮地板详情)
			ground_layer.proxy_input(event)
			interact_layer.clear_hover_state()


# --- 辅助函数 ---


# 判断是否为地面层物品
func _is_ground_item(item: BaseItemData) -> bool:
	# 根据你的 Enum 定义修改
	return item.layer_type == BaseItemData.LayerType.GROUND


# 鼠标移出整个大地图区域
func _on_mouse_exited_map() -> void:
	ground_layer.clear_hover_state()
	interact_layer.clear_hover_state()


# 切换模式 (由外部 UI 调用)
func set_build_mode(enabled: bool) -> void:
	_is_build_mode = enabled
	ground_layer.is_build_mode = enabled
	interact_layer.is_build_mode = enabled
