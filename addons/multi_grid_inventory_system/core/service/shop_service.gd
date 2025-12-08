extends BaseContainerService
class_name ShopService


## 加载货物
func load_goods(shop_name: String, goods: Array[BaseItemData]) -> void:
	for good: BaseItemData in goods:
		add_item(shop_name, good)


## 售卖物品到商店
func sold_item(shop_name: String, item_data: BaseItemData) -> bool:
	if item_data.can_sell():
		# 尝试添加物品到商店
		var add_suucess: bool = add_item(shop_name, item_data)
		# 出售增加金币
		if add_suucess:
			item_data.sold()
		return add_suucess
	return false


## 购买物品
## @param amount:指定购买数量，0表示一半，其他表示具体数量
## @return bool:返回是否购买成功
func buy(shop_container: BaseContainerView, grid_id: Vector2i, amount: int = 0) -> bool:
	var shop_name: String = shop_container.container_name
	var item: BaseItemData = find_item_data_by_grid(shop_name, grid_id)
	# 1. 购买到背包（注意要配置MGIS.current_inventories）
	if MGIS.current_inventories.is_empty():
		push_warning("MGIS.current_inventories is wrong,U need config MGIS.current_inventories.")
		return false
	for target_container: String in MGIS.current_inventories:
		# 2. 堆叠物品购买
		if item is StackableData:
			var origin_amount: int = item.current_amount
			# 如果只有 1 个(等同于buy_all_amount)
			if origin_amount <= 1:
				return buy_all_amount(shop_container, grid_id)
			# 分割数量
			var amount_to_move: int = amount  # 购买的数量
			# amount为0表示购买一半物品数量
			if amount == 0:
				amount_to_move = ceili(origin_amount / 2.0)  # 购买到目标格子的数量（向上取整）
			var amount_to_keep: int = origin_amount - amount_to_move  # 原始格子保留的数量
			var item_to_buy: BaseItemData = item.duplicate(true)
			item_to_buy.current_amount = amount_to_move
			# 尝试购买（buy函数能处理自动添加到背包的逻辑）
			var buy_success: bool = item.buy(item_to_buy)
			if buy_success:
				item.current_amount = amount_to_keep
				# 如果原始数量减为 0，则从背包中移除
				if item.current_amount <= 0:
					remove_item_by_data(shop_name, item)
				else:
					# 更新商店的数量
					MGIS.sig_inv_item_updated.emit(shop_name, grid_id)

			return buy_success
		# 非堆叠物品购买一个即全部
		else:
			return buy_all_amount(shop_container, grid_id)

	return false


## 购买一半数量
func buy_half_amount(shop_container: BaseContainerView, grid_id: Vector2i) -> bool:
	return buy(shop_container, grid_id)


## 购买全部数量
func buy_all_amount(shop_container: BaseContainerView, grid_id: Vector2i) -> bool:
	var shop_name: String = shop_container.container_name
	var item: BaseItemData = find_item_data_by_grid(shop_name, grid_id)
	var item_to_buy: BaseItemData = item.duplicate(true)
	if item is StackableData:
		item_to_buy.current_amount = item.current_amount
	var buy_success: bool = item.buy(item_to_buy)
	# 购买成删除商店的物品
	if buy_success:
		remove_item_by_data(shop_name, item)
	return buy_success


## 拖拽出售物品
func sell(shop_container: BaseContainerView, item: BaseItemData) -> bool:
	var shop_name: String = shop_container.container_name
	var sold_success: bool = sold_item(shop_name, item.duplicate(true))
	if sold_success:
		MGIS.moving_item_service.clear_moving_item()

	return sold_success
