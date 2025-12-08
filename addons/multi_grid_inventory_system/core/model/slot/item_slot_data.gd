extends Resource
## 物品插槽数据类，管理穿脱物品
class_name ItemSlotData

## 已装备的物品，未装备时null，可用于检测是否有装备物品
@export_storage var equipped_item: BaseItemData
## 允许装备的物品类型，对应BaseItemData.type
@export_storage var avilable_types: Array[String]
## 物品插槽的名字
@export_storage var slot_name: String


### 装备物品
## 注意：本函数在堆叠成功时，会修改传入 item_data 的 current_amount 属性，
## 调用者需检查该属性来处理剩余数量（即查找下一个插槽或返回背包）。
## @param item_data: 要装备的物品数据
## @return bool: 返回是否成功进行了“装备”或“堆叠”操作。
func equip(item_data: BaseItemData) -> bool:
	if not is_item_avilable(item_data):
		return false
	# A: 堆叠物品 (消耗品/药水)
	if item_data is StackableData:
		var stackable_new_item: StackableData = item_data
		# A.1. 如果插槽已被占用
		if equipped_item:
			# A.1.a. 检查是否为同类型的堆叠物品 (进行堆叠操作)
			if equipped_item is StackableData and equipped_item.item_id == stackable_new_item.item_id and equipped_item.item_level == stackable_new_item.item_level:
				equipped_item = equipped_item as StackableData
				# 尝试将新物品的数量添加到已装备的物品上
				var amount_left: int = equipped_item.add_amount(stackable_new_item.current_amount)
				# 更新数量文本
				MGIS.sig_slot_item_equipped.emit(slot_name, equipped_item)
				# 通过修改输入资源的数量来通知剩余数量
				stackable_new_item.current_amount = amount_left
				# 堆叠操作成功，返回 true
				return true
			# 此时需要交换，强制上层服务先 unequip，故返回 false
			return false
		# A.2. 插槽为空
		else:
			# 检查堆叠上限，只装备符合上限的部分
			var amount_to_equip: int = mini(stackable_new_item.current_amount, stackable_new_item.stack_size)
			# 创建一个副本，只包含要装备到本插槽的数量
			var item_to_slot: StackableData = stackable_new_item.duplicate(true)
			item_to_slot.current_amount = amount_to_equip
			# 尝试装备
			if equip_item(item_to_slot):
				# 更新传入物品的剩余数量，通知 try_equip 继续查找
				stackable_new_item.current_amount -= amount_to_equip
				return true
			return false

	# B: 非堆叠物品 (装备)
	else:
		if not equipped_item:
			return equip_item(item_data)
		return false

	return false  # 默认安全返回


## 立刻直接装备物品
func equip_item(item_data: BaseItemData) -> bool:
	if is_item_avilable(item_data):
		equipped_item = item_data
		equipped_item.equipped(slot_name)
		# 更新数量文本
		MGIS.sig_slot_item_equipped.emit(slot_name, equipped_item)
		return true
	return false


## 脱掉物品，返回被脱掉的物品
func unequip() -> BaseItemData:
	if not equipped_item:
		return null
	var ret = equipped_item
	ret.unequipped(slot_name)
	equipped_item = null
	return ret


## 检查是否可装备这个物品
func is_item_avilable(item_data: BaseItemData) -> bool:
	if avilable_types.has("ANY") or avilable_types.has(item_data.type):
		return item_data.test_need(slot_name)
	return false


## 构造函数
@warning_ignore("shadowed_variable")


func _init(slot_name: String = MGIS.DEFAULT_SLOT_NAME, avilable_types: Array[String] = []) -> void:
	self.slot_name = slot_name
	self.avilable_types = avilable_types
