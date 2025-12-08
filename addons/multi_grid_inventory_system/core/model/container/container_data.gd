extends Resource
## 库存数据类，管理物品在网格中的存储和操作
class_name ContainerData

## 库存列数
@export_storage var columns: int = 2
## 库存行数
@export_storage var rows: int = 2
## 库存激活行数
@export_storage var activated_rows: int = 2
## 库存名称
@export_storage var container_name: String
## 允许存放的物品类型列表
@export_storage var avilable_types: Array[String]

## 当前存放的物品数据列表
@export_storage var items: Array[BaseItemData] = []
## 物品到占据网格的映射(Array[grid_id: Vector2i])
@export_storage var item_grids_map: Dictionary[BaseItemData, Array]
## 格子到物品的映射
@export_storage var grid_item_map: Dictionary[Vector2i, Variant] = {}

## 构造函数
@warning_ignore("shadowed_variable")
func _init(container_name: String = MGIS.DEFAULT_INVENTORY_NAME, columns: int = 0, rows: int = 0, activated_rows: int = 0, avilable_types: Array[String] = []) -> void:
	self.container_name = container_name
	self.avilable_types = avilable_types
	self.columns = columns
	self.rows = rows
	self.activated_rows = activated_rows
	var activated: bool = true
	for row in rows:
		# 设置格子是否激活
		if row >= activated_rows:
			activated = false
		for col in columns:
			var pos = Vector2i(col, row)
			if activated:
				grid_item_map[pos] = null
			else:
				grid_item_map[pos] = activated


## 清空重启
func clear() -> void:
	items = []
	item_grids_map = {}
	for row in rows:
		for col in columns:
			var pos = Vector2i(col, row)
			grid_item_map[pos] = null


## 深度复制当前库存数据
func deep_duplicate() -> ContainerData:
	var ret = ContainerData.new(container_name, columns, rows, activated_rows, avilable_types)
	for item_data in item_grids_map.keys():
		ret.item_grids_map[item_data.duplicate()] = item_grids_map[item_data].duplicate(true)
	ret.items.append_array(ret.item_grids_map.keys())
	for item in ret.items:
		var grids = ret.item_grids_map[item]
		for grid in grids:
			ret.grid_item_map[grid] = item
	return ret


## 添加物品到库存，返回物品占用的网格坐标列表
## @param item_data:待添加的资源
## @param is_slot:是否是单格背包（多格背包是物品会占用多格空间，单格背包是物品强制只占用一格空间）
## @param head_pos：是否添加到背包的指定位置（只处理非堆叠物品，堆叠物品自动）
## return 返回网格数组
func add_item(item_data: BaseItemData, is_slot: bool = false, head_pos: Vector2i = -Vector2i.ONE) -> Array[Vector2i]:
	if not is_item_avilable(item_data):
		# <<<< 在这里抛出【不允许添加该物品】的信号 >>>>
		MGIS.sig_item_disallowed.emit(container_name, item_data)
		return []
	var grids: Array = _find_first_availble_grids(item_data, is_slot, head_pos)
	if not grids.is_empty():
		_add_item_to_grids(item_data, grids)
		return grids
	# 如果没找到格子，返回 [] (背包已满)
	# <<<< 在这里抛出【背包满了】的信号 >>>>
	MGIS.sig_inventory_full.emit(container_name)
	return []


## 从库存中移除物品，返回是否移除成功
func remove_item(item: BaseItemData) -> bool:
	if items.has(item):
		var grids = item_grids_map[item]
		for grid in grids:
			grid_item_map[grid] = null
		items.erase(item)
		item_grids_map.erase(item)
		return true
	return false


## 检查物品是否可以被放入当前库存
func is_item_avilable(item_data: BaseItemData) -> bool:
	return avilable_types.has("ANY") or avilable_types.has(item_data.type)


## 根据物品数据查找其占用的网格坐标列表
func find_grids_by_item_data(item_data: BaseItemData) -> Array[Vector2i]:
	return item_grids_map.get(item_data, [] as Array[Vector2i])


## 检查库存中是否包含指定物品
func has_item(item: BaseItemData) -> bool:
	return items.has(item)


## 根据网格坐标查找对应的物品数据
func find_item_data_by_grid(grid_id: Vector2i) -> BaseItemData:
	return grid_item_map.get(grid_id)


## 尝试将物品添加到指定网格位置，返回实际占用的网格坐标列表
func try_add_to_grid(item_data: BaseItemData, grid_id: Vector2i, is_slot: bool = false) -> Array[Vector2i]:
	if not is_item_avilable(item_data):
		return []
	var item_shape: Vector2i = item_data.get_shape(is_slot)
	var grids = _try_get_empty_grids_by_shape(grid_id, item_shape)
	_add_item_to_grids(item_data, grids)
	return grids


## 根据物品名称查找所有匹配的物品数据
func find_item_data_by_item_id(item_id: String) -> Array[BaseItemData]:
	var ret: Array[BaseItemData] = []
	for item in items:
		if item.item_id == item_id:
			ret.append(item)
	return ret


## 将物品添加到指定网格位置，返回是否添加成功
func _add_item_to_grids(item_data: BaseItemData, grids: Array[Vector2i]) -> bool:
	if not grids.is_empty():
		items.append(item_data)
		item_grids_map[item_data] = grids
		for grid in grids:
			grid_item_map[grid] = item_data
		return true
	return false


## 查找第一个可用的网格位置来放置物品
## @param item_data:待添加的资源
## @param is_slot:是否是单格背包
## @param head_pos：当head_pos不等于默认-Vector2i.ONE时候添加到指定的head_pos位置，若head_pos位置不合适则自动搜索可用位置
## return 返回网格坐标数组
func _find_first_availble_grids(item: BaseItemData, is_slot: bool = false, head_pos: Vector2i = -Vector2i.ONE) -> Array[Vector2i]:
	var item_shape: Vector2i = item.get_shape(is_slot)
	# 1. 优先尝试指定位置 (head_pos)
	if head_pos != -Vector2i.ONE:
		# 尝试获取指定位置占用的格子
		var target_grids = _try_get_empty_grids_by_shape(head_pos, item_shape)
		# 如果数组不为空，说明该位置可以放下，直接返回
		if not target_grids.is_empty():
			return target_grids
	# 2. 自动搜索可用位置
	for row in rows:
		for col in columns:
			# 如果当前格子中没有东西，则判断能否放下这个物品的形状
			if grid_item_map[Vector2i(col, row)] == null:
				var grids = _try_get_empty_grids_by_shape(Vector2i(col, row), item_shape)
				if not grids.is_empty():
					return grids
	return []


## 尝试根据物品形状获取从指定位置开始的空网格
func _try_get_empty_grids_by_shape(start: Vector2i, shape: Vector2i) -> Array[Vector2i]:
	var ret: Array[Vector2i] = []
	for row in shape.y:
		for col in shape.x:
			var grid_id = Vector2i(start.x + col, start.y + row)
			if grid_item_map.has(grid_id) and grid_item_map[grid_id] == null:
				ret.append(grid_id)
			else:
				return []
	return ret
