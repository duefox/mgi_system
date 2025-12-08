extends BaseItemData
class_name PetData


func can_drop() -> bool:
	push_warning("[Override this function] check if the item [%s] can drop" % item_id)
	return true


## 丢弃物品时调用，需重写
func drop() -> void:
	push_warning("[Override this function] item [%s] dropped" % item_id)


## 物品是否能出售（是否贵重物品等）
func can_sell() -> bool:
	return true


## 物品是否能购买（检查资源是否足够等）
func can_buy(item_to_buy: BaseItemData) -> bool:
	print(item_to_buy, "，检查金币是否足够")
	return true


## 购买后扣除资源
func cost(item_to_buy: BaseItemData) -> void:
	print("[%s] 购买成功，花费了xxx金币。" % item_to_buy.item_id)


## 出售后增加资源
func sold() -> void:
	push_warning("[Override this function] [%s] add resource" % item_id)


## 检测装备是否可用，需重写
func test_need(slot_name: String) -> bool:
	push_warning("[Override this function] [%s]:[%s] Equipment slot test passed." % [MGIS.current_player, slot_name])
	return true


## 装备时调用，需重写；也可以使用 MGIS.sig_slot_item_equipped 信号行处理
func equipped(slot_name: String) -> void:
	push_warning("[Override this function] [%s] equipped item [%s] at slot [%s]" % [MGIS.current_player, item_id, slot_name])


## 脱装备时调用，需重写；也可以用 MGIS.sig_slot_item_unequipped 信号进行处理
func unequipped(slot_name: String) -> void:
	push_warning("[Override this function] [%s] unequipped item [%s] at slot [%s]" % [MGIS.current_player, item_id, slot_name])
