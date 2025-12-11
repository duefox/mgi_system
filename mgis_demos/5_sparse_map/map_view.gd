## 地图多网格容器类，继承自稀疏地图视图
## 主要负责UI显示相关视觉，以及地形 Shader 的特殊处理
@tool
extends SparseMapView
class_name MapView

## 叠加着色器（模拟PS的叠加滤镜）
const OVERLAY_SHADER: Shader = preload("res://shaders/overlay_color.gdshader")


## 重写绘制物品
## 这里我们先调用父类方法生成 ItemView 并定位，然后追加 Shader 逻辑
func _draw_item(item_data: BaseItemData, first_grid: Vector2i) -> ItemView:
	# 1. 调用父类 (SparseMapView) 的方法创建并定位物品
	# 父类会处理 position = grid * base_size 的逻辑
	var item: ItemView = super._draw_item(item_data, first_grid)

	# 2. 叠加 Shader 覆盖颜色逻辑 (保持原有逻辑不变)
	# 只有 TerrainData 且颜色不为白色时才应用，节省性能
	if item_data is TerrainData:
		if not item_data.overlay_color == Color.WHITE:
			# 确保 item.overlay_rect 存在 (在 ItemView._ready 中创建)
			if is_instance_valid(item.overlay_rect):
				# 创建 Shader 材质
				var overlay_material: ShaderMaterial = ShaderMaterial.new()
				overlay_material.shader = OVERLAY_SHADER

				# 设置叠加滤镜
				item.overlay_rect.color = Color.WHITE
				item.overlay_rect.material = overlay_material

				# 设置滤镜参数
				overlay_material.set_shader_parameter("overlay_color", item_data.overlay_color)  # 叠加颜色
				overlay_material.set_shader_parameter("target_color", item_data.target_color)  # 智能抠图色

				if is_instance_valid(item_data.overlay_texture):
					overlay_material.set_shader_parameter("overlay_texture", item_data.overlay_texture)  # 叠加纹理

	return item
