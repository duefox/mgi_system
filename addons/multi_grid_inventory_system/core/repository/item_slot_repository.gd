extends Resource
## 物品插槽数据库，管理 ItemSlotRepository 的存取
class_name ItemSlotRepository

## 用于生成唯一的保存请求ID
static var _next_request_id: int = 0

## 系统中所有的物品插槽
@export_storage var _slot_data_map: Dictionary[String, ItemSlotData]

## 单例
static var instance: ItemSlotRepository:
	get:
		if not instance:
			instance = ItemSlotRepository.new()
		return instance


## 保存所有装备槽
func save() -> int:
	# 启用代理保存
	if MGIS.enable_proxy:
		_next_request_id += 1
		var request_id = _next_request_id
		# 确保发送一个副本，防止外部保存系统在异步处理时修改了实时数据
		var data_to_save = self.duplicate(true)
		# MGIS 发出保存请求信号
		MGIS.sig_proxy_save.emit(data_to_save, MGIS.item_slot_prefix, request_id)
		return request_id
	else:
		var error = ResourceSaver.save(self, MGIS.current_save_path + MGIS.item_slot_prefix + MGIS.current_save_name)
		return error


## 读取所有装备槽，会重新穿戴所有装备
func load() -> void:
	# 启用代理加载导入
	if MGIS.enable_proxy:
		_next_request_id += 1
		var request_id = _next_request_id
		# MGIS 发出保存请求信号
		MGIS.sig_proxy_load.emit(MGIS.item_slot_prefix, request_id)
		return
	# 未启用代理正常处理
	_unequipped_all_data()
	var saved_repository: ItemSlotRepository = load(MGIS.current_save_path + MGIS.item_slot_prefix + MGIS.current_save_name)
	if not saved_repository:
		return
	for slot_name in saved_repository._slot_data_map.keys():
		_slot_data_map[slot_name] = saved_repository._slot_data_map[slot_name].duplicate(true)
		var item_data = _slot_data_map[slot_name].equipped_item
		if item_data:
			item_data.equipped(slot_name)


## 代理载入所有装备槽，会重新穿戴所有装备
func proxy_load(proxy_data: Resource) -> void:
	_unequipped_all_data()
	var saved_repository: ItemSlotRepository = proxy_data as ItemSlotRepository
	if not saved_repository:
		return
	for slot_name in saved_repository._slot_data_map.keys():
		_slot_data_map[slot_name] = saved_repository._slot_data_map[slot_name].duplicate(true)
		var item_data = _slot_data_map[slot_name].equipped_item
		if item_data:
			item_data.equipped(slot_name)


## 获取指定装备槽的数据类
func get_slot(slot_name: String) -> ItemSlotData:
	return _slot_data_map.get(slot_name)


## 增加一个装备槽
func add_slot(slot_name: String, avilable_types: Array[String]) -> bool:
	var slot = get_slot(slot_name)
	if not slot:
		_slot_data_map[slot_name] = ItemSlotData.new(slot_name, avilable_types)
		return true
	return false


## 尝试装备一件物品，如果装备成功，返回装备上这个物品的装备槽
func try_equip_bak(item_data: BaseItemData) -> ItemSlotData:
	for slot: ItemSlotData in _slot_data_map.values():
		if slot.equip(item_data):
			return slot
	return null


## 尝试装备一件物品，如果装备成功，返回装备上这个物品的装备槽
func try_equip(item_data: BaseItemData) -> ItemSlotData:
	var last_equipped_slot: ItemSlotData = null
	# 1. 对于非堆叠物品（装备），只需找到第一个能装备的插槽，成功后即返回
	if not item_data is StackableData:
		for slot: ItemSlotData in _slot_data_map.values():
			if slot.equip(item_data):
				return slot
		return null

	# 2. 对于可堆叠物品（消耗品），需要遍历所有插槽，进行堆叠/装备，直到数量为 0
	var stackable_item: StackableData = item_data as StackableData
	for slot: ItemSlotData in _slot_data_map.values():
		# 检查是否还有剩余数量需要处理
		if stackable_item.current_amount <= 0:
			break  # 所有数量都已处理完毕，跳出循环

		# equip() 会尝试在 slot 上进行堆叠或装备
		if slot.equip(stackable_item):
			# 记录最后一次成功的插槽。
			last_equipped_slot = slot
			# 如果数量清零，则全部装备完成
			if stackable_item.current_amount <= 0:
				return last_equipped_slot

	# 3. 循环结束后，如果 last_equipped_slot 不为空，说明至少部分装备成功
	return last_equipped_slot


## 卸载所有装备
func _unequipped_all_data() -> void:
	for slot_name in _slot_data_map.keys():
		var item_data = _slot_data_map[slot_name].equipped_item
		if item_data:
			item_data.unequipped(slot_name)
