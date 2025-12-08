extends RefCounted
## 容器业务类
class_name BaseContainerService

## 容器数据库引用
var _container_repository: ContainerRepository = ContainerRepository.instance


## 保存所有容器
func save(inv_name: String) -> void:
	_container_repository.save(inv_name)


## 载入容器数据
func load(inv_name: String) -> void:
	_container_repository.load(inv_name)


## 代理载入容器数据
func proxy_load(inv_name: String, proxy_data: Resource) -> void:
	_container_repository.proxy_load(inv_name, proxy_data)


## 注册容器，如果重名，则返回已存在的容器
func regist(container_name: String, columns: int, rows: int, activated_rows: int, avilable_types: Array[String] = ["ANY"]) -> ContainerData:
	return _container_repository.add_container(container_name, columns, rows, activated_rows, avilable_types)


## 获取容器数据
func get_container(container_name: String) -> ContainerData:
	return _container_repository.get_container(container_name)


## 通过物品名称找所有物品（同名物品可能有多个实例）
func find_item_data_by_item_id(container_name: String, item_id: String) -> Array[BaseItemData]:
	var inv = _container_repository.get_container(container_name)
	if inv:
		return inv.find_item_data_by_item_id(item_id)
	return []


## 通过格子找物品
func find_item_data_by_grid(container_name: String, grid_id: Vector2i) -> BaseItemData:
	return _container_repository.get_container(container_name).find_item_data_by_grid(grid_id)


## 判断容器是否存在
func is_container_existed(container_name: String) -> bool:
	return _container_repository.get_container(container_name) != null


## 尝试把物品放置到指定格子
func place_to(container_name: String, item_data: BaseItemData, grid_id: Vector2i, is_slot: bool = false) -> bool:
	if item_data:
		var inv = _container_repository.get_container(container_name)
		if inv:
			var grids = inv.try_add_to_grid(item_data, grid_id - MGIS.moving_item_service.moving_item_offset, is_slot)
			if grids:
				MGIS.sig_inv_item_added.emit(container_name, item_data, grids)
				return true
	return false


## 向背包添加物品 (已修正超额堆叠数量丢失的逻辑)
## @param inv_name：背包名称
## @param item_data：资源数据
## @param need_duplicate：是否需要副本
## @param is_slot：是否单格背包
## @param head_pos：是否添加到背包的指定位置（只处理非堆叠物品，堆叠物品自动）
func add_item(inv_name: String, item_data: BaseItemData, need_duplicate: bool = true, is_slot: bool = false, head_pos: Vector2i = -Vector2i.ONE) -> bool:
	# 保存资源数据
	var container_data: ContainerData = _container_repository.get_container(inv_name)
	if not is_instance_valid(container_data):
		return false
	if not is_instance_valid(item_data):
		return false
	# item_to_process 是函数内部操作所基于的资源副本
	var item_to_process: BaseItemData = item_data
	if need_duplicate:
		# 确保所有处理都基于一个独立的副本，防止污染原始数据
		item_to_process = item_data.duplicate(true)
	var overall_success: bool = false
	# 堆叠物品处理
	if item_to_process is StackableData:
		var stackable_item: StackableData = item_to_process as StackableData
		var remaining_amount: int = stackable_item.current_amount
		var stack_size: int = stackable_item.stack_size

		# 1.1 尝试堆叠到现有物品
		var items: Array = find_item_data_by_item_id(inv_name, stackable_item.item_id)
		for item: StackableData in items:
			if not item.is_full():
				# item.add_amount 会修改 item.current_amount 并返回剩余数量
				remaining_amount = item.add_amount(remaining_amount)
				# 发射信号更新堆叠格子 UI
				var new_item_grids = container_data.find_grids_by_item_data(item)
				assert(not new_item_grids.is_empty())
				MGIS.sig_inv_item_updated.emit(inv_name, new_item_grids[0])
				if remaining_amount <= 0:
					return true  # 全部数量堆叠成功

		# 1.2 处理剩余数量 (> 0) - 放置到新格子
		while remaining_amount > 0:
			var amount_for_new_slot: int = min(remaining_amount, stack_size)
			# 创建一个全新的资源副本用于放置，并设置其数量
			var item_to_add_new: StackableData = item_data.duplicate(true)
			item_to_add_new.current_amount = amount_for_new_slot
			# 尝试放置到新格子
			var grids = container_data.add_item(item_to_add_new, is_slot)
			if not grids.is_empty():
				overall_success = true
				MGIS.sig_inv_item_added.emit(inv_name, item_to_add_new, grids)
				remaining_amount -= amount_for_new_slot  # 减少剩余数量
			else:
				# 背包已满，跳出循环
				break
		return overall_success

	# 非堆叠物品处理
	else:
		var grids = container_data.add_item(item_to_process, is_slot, head_pos)
		if not grids.is_empty():
			MGIS.sig_inv_item_added.emit(inv_name, item_to_process, grids)
			return true
		return false


## 增加背包间的快速移动关系
func add_relation(inv_name: String, target_inv_name: String) -> void:
	_container_repository.add_relation(inv_name, target_inv_name)


## 删除背包间的快速移动关系
func remove_relation(inv_name: String, target_inv_name: String) -> void:
	_container_repository.remove_relation(inv_name, target_inv_name)


## 删除背包中的物品，成功后触发 sig_inv_item_removed
func remove_item_by_data(inv_name: String, item_data: BaseItemData) -> void:
	#print("remove_item_by_data->inv_name:", inv_name, ",item_id:", item_data.item_id)
	# 获取保存的资源数据
	var container_data: ContainerData = _container_repository.get_container(inv_name)
	if not is_instance_valid(container_data):
		return
	var grids: Array[Vector2i] = container_data.item_grids_map[item_data]
	if container_data.remove_item(item_data):
		MGIS.sig_inv_item_removed.emit(inv_name, item_data)
