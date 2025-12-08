extends BaseContainerService
class_name SparseMapService

## 稀疏地图业务类
## 这里目前复用 BaseContainerService 的逻辑
## 未来可以添加：地形检测、建造限制、多层覆盖检测等逻辑

# 比如：判断某个坐标是否是水域，不能放物品
# func can_place_at(container_name: String, item: BaseItemData, grid: Vector2i) -> bool:
#     return true
