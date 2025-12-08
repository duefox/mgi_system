extends RefCounted
## 物品插槽业务类
class_name ItemSlotService

## 物品插槽数据库引用
var _item_slot_repository: ItemSlotRepository = ItemSlotRepository.instance


## 保存所有物品插槽数据
func save() -> void:
	_item_slot_repository.save()


## 读取所有物品插槽数据
func load() -> void:
	_item_slot_repository.load()


## 代理载入所有物品插槽数据
func proxy_load(proxy_data: Resource) -> void:
	_item_slot_repository.proxy_load(proxy_data)


## 获取指定名称的物品插槽
func get_slot(slot_name: String) -> ItemSlotData:
	return _item_slot_repository.get_slot(slot_name)


## 注册物品插槽，如果重名，则检测是否和已有的数据相符
## 注意：如果物品插槽不显示，大概率是注册返回失败了，请检查配置
func regist_slot(slot_name: String, avilable_types: Array[String]) -> bool:
	var slot_data = _item_slot_repository.get_slot(slot_name)
	if slot_data:
		var is_same_avilable_types = avilable_types.size() == slot_data.avilable_types.size()
		if is_same_avilable_types:
			for i in range(avilable_types.size()):
				is_same_avilable_types = avilable_types[i] == slot_data.avilable_types[i]
				if not is_same_avilable_types:
					break
		return is_same_avilable_types
	else:
		return _item_slot_repository.add_slot(slot_name, avilable_types)


## 尝试穿戴装备，如果成功，发射信号 sig_slot_item_equipped
func try_equip(item_data: BaseItemData) -> bool:
	if not item_data:
		return false
	var slot: ItemSlotData = _item_slot_repository.try_equip(item_data)
	if slot:
		return true
	return false


## 尝试装备正在移动的物品，返回是否成功
func equip_moving_item(slot_name: String) -> bool:
	if equip_to(slot_name, MGIS.moving_item_service.moving_item):
		MGIS.moving_item_service.clear_moving_item()
		return true
	return false


## 装备物品到指定的物品插槽，成功后发射信号 sig_slot_item_equipped
func equip_to(slot_name, item_data: BaseItemData) -> bool:
	return _item_slot_repository.get_slot(slot_name).equip(item_data)


## 脱掉装备，需要先配置 MGIS.current_inventories，用于存放脱下来的装备，成功后发射信号 sig_slot_item_unequipped
func unequip(slot_name: String) -> BaseItemData:
	for current_inventory in MGIS.current_inventories:
		if not MGIS.inventory_service.is_container_existed(current_inventory):
			push_error("Cannot find inventory name [%s]. " % current_inventory)
			return null
		# 背包必须是打开的
		var current_inventory_view: BaseContainerView = MGIS.get_container_view(current_inventory)
		if not current_inventory_view.is_open():
			continue
		var item_data: BaseItemData = get_slot(slot_name).equipped_item
		if item_data and MGIS.inventory_service.add_item(current_inventory, item_data):
			_item_slot_repository.get_slot(slot_name).unequip()
			MGIS.sig_slot_item_unequipped.emit(slot_name, item_data)
			return item_data
	return null


## 堆叠物品脱掉一半的数量
func half_unequip(slot_name: String, item_data: StackableData) -> StackableData:
	for current_inventory in MGIS.current_inventories:
		if not MGIS.inventory_service.is_container_existed(current_inventory):
			push_error("Cannot find inventory name [%s]. " % current_inventory)
			return null
		# 背包必须是打开的
		var current_inventory_view: BaseContainerView = MGIS.get_container_view(current_inventory)
		if not current_inventory_view.is_open():
			continue
		#移动一半的数量
		var item_to_move: StackableData = item_data.duplicate(true)
		var origin_count: int = item_data.current_amount
		var move_count: int = ceili(origin_count / 2.0)
		var keep_count: int = origin_count - move_count
		item_to_move.current_amount = move_count
		if MGIS.inventory_service.add_item(current_inventory, item_to_move):
			var slot_view: ItemSlotView = MGIS.get_container_view(slot_name) as ItemSlotView
			item_data.current_amount = keep_count
			if keep_count <= 0:
				# 更新插槽
				_item_slot_repository.get_slot(slot_name).unequip()
				MGIS.sig_slot_item_unequipped.emit(slot_name, item_data)
				# 删除物品
				slot_view.remove_item_view()
			else:
				slot_view.update_item_view()
			return item_data
	return null


## 使用插槽的物品
func use_item(slot_name: String) -> bool:
	var item_data: BaseItemData = get_slot(slot_name).equipped_item
	# 检查插槽的视图是否打开
	var slot_view: ItemSlotView = MGIS.get_container_view(slot_name)
	if not slot_view.is_open():
		push_warning("can't use item in the background.")
		return false
	# 非消耗品则脱掉
	if not item_data is ConsumableData:
		unequip(slot_name)
		return false
	item_data = item_data as ConsumableData
	# 消耗完了
	if item_data.use():
		# 更新插槽
		_item_slot_repository.get_slot(slot_name).unequip()
		MGIS.sig_slot_item_unequipped.emit(slot_name, item_data)
		# 删除物品
		slot_view.remove_item_view()
	# 消耗一个物品
	else:
		slot_view.update_item_view()

	return true


## 移动正在装备的物品，成功后发射信号 sig_slot_item_unequipped
func move_item(slot_name: String, base_size: int) -> void:
	if MGIS.moving_item_service.moving_item:
		push_error("Already had moving item.")
		return
	var item_data = get_slot(slot_name).equipped_item
	if item_data:
		if _item_slot_repository.get_slot(slot_name).unequip():
			MGIS.moving_item_service.move_item_by_data(item_data, Vector2i.ZERO, base_size)
			MGIS.sig_slot_item_unequipped.emit(slot_name, item_data)


## 更新网格的tooltip文本
func _update_tootip(inv_name: String, item_data: BaseItemData) -> void:
	if item_data.tooltips.is_empty():
		return
