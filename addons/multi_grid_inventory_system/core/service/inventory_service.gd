extends BaseContainerService
## 背包业务类
class_name InventoryService


## 整理物品数据
## @param inv_name:背包名称
## @param sort_attri:资源的属性值 (例如 "item_level", "price", "rarity")
## @param reverse:是否倒序排序 (默认 false: 升序/从小到大; true: 降序/从大到小)
## return 返回是否整理成功
func sort_items(inv_name: String, sort_attri: String, reverse: bool = false) -> bool:
	if inv_name.is_empty():
		return false
	# 排序后的数据
	var after_sort_items: Array[BaseItemData] = _container_repository.sort_items_by_attri(inv_name, sort_attri, reverse)
	if after_sort_items.is_empty():
		return false
	var container_view: BaseContainerView = MGIS.get_container_view(inv_name)
	# 重新添加物品
	for item: BaseItemData in after_sort_items:
		add_item(inv_name, item, true, container_view.is_slot)
	return true


## 尝试把正在移动的物品堆叠到这个格子上
func stack_moving_item(container_view: BaseContainerView, grid_id: Vector2i) -> void:
	if not MGIS.moving_item_service.moving_item:
		return
	var inv_name: String = container_view.container_name
	var item_data = find_item_data_by_grid(inv_name, grid_id)
	if not item_data is StackableData:
		return
	if item_data.item_id == MGIS.moving_item_service.moving_item.item_id:
		var amount_left = item_data.add_amount(MGIS.moving_item_service.moving_item.current_amount)
		if amount_left > 0:
			MGIS.moving_item_service.moving_item.current_amount = amount_left
			# 强制重绘正在移动的物品视图，以更新其堆叠数字
			if MGIS.moving_item_service.moving_item_view:
				MGIS.moving_item_service.moving_item_view.queue_redraw()
		else:
			MGIS.moving_item_service.clear_moving_item()
		MGIS.sig_inv_item_updated.emit(inv_name, grid_id)


## [修改] 尝试放置正在移动的物品到这个格子
func place_moving_item(container_view: BaseContainerView, grid_id: Vector2i) -> bool:
	var inv_name: String = container_view.container_name

	# 使用计算好的 grid_id 直接放置
	if place_to(inv_name, MGIS.moving_item_service.moving_item, grid_id, container_view.is_slot):
		MGIS.moving_item_service.clear_moving_item()
		# 成功时，base_container_service 会自动发送 sig_inv_item_added，AudioManager 可以监听那个作为放置音效
		return true

	# [新增] 放置失败，发送信号 (播放错误音效)
	MGIS.sig_transaction_failed.emit({"msg": "Cannot place item here"})
	return false


## 尝试从正在移动的堆叠物品中放置一个到指定格子
## @return bool: 是否放置成功
func place_single_from_moving(container_view: BaseContainerView, grid_id: Vector2i) -> bool:
	var moving_item = MGIS.moving_item_service.moving_item
	if not moving_item:
		return false

	# 1. 检查是否可堆叠
	if not moving_item is StackableData:
		# 非堆叠物品，只能一次性放下全部 (复用原有逻辑)
		return place_moving_item(container_view, grid_id)

	# 2. 创建单个物品的副本
	var single_item = moving_item.duplicate(true)
	single_item.current_amount = 1

	# 3. 尝试放置
	var inv_name = container_view.container_name
	# 使用 place_to 尝试放置这个单体
	# place_to 内部会处理添加逻辑 (如果格子上已有同类物品，它会尝试堆叠；如果是空的，会占坑)
	if place_to(inv_name, single_item, grid_id, container_view.is_slot):
		# 4. 放置成功，扣除手中数量
		moving_item.current_amount -= 1

		# 5. 更新手中物品视图
		if moving_item.current_amount <= 0:
			MGIS.moving_item_service.clear_moving_item()
		else:
			# 强制刷新手中物品的数字显示
			if MGIS.moving_item_service.moving_item_view:
				MGIS.moving_item_service.moving_item_view.update_stack_label()

		return true

	return false


## [修改] 尝试从格子上回收一个堆叠物品到手中
func pickup_single_to_moving(container_view: BaseContainerView, grid_id: Vector2i) -> bool:
	var inv_name = container_view.container_name
	var item_on_grid = find_item_data_by_grid(inv_name, grid_id)
	if not item_on_grid:
		return false
	if not item_on_grid is StackableData:
		return false

	var moving_service = MGIS.moving_item_service

	# 场景 A: 手里是空的 -> 拿起一个
	if not moving_service.moving_item:
		var single_item = item_on_grid.duplicate(true)
		single_item.current_amount = 1
		item_on_grid.current_amount -= 1

		moving_service.move_item_by_data(single_item, Vector2i.ZERO, container_view.base_size)

		if item_on_grid.current_amount <= 0:
			remove_item_by_data(inv_name, item_on_grid)
		else:
			MGIS.sig_inv_item_updated.emit(inv_name, grid_id)

		# [新增] 发送拿起信号
		MGIS.sig_item_picked_up.emit(single_item)
		return true

	# 场景 B: 手里有物品 -> 合并 (吸取)
	else:
		var moving_item = moving_service.moving_item
		if moving_item.item_id == item_on_grid.item_id and moving_item is StackableData:
			if not moving_item.is_full():
				moving_item.current_amount += 1
				item_on_grid.current_amount -= 1

				if moving_service.moving_item_view:
					moving_service.moving_item_view.update_stack_label()

				if item_on_grid.current_amount <= 0:
					remove_item_by_data(inv_name, item_on_grid)
				else:
					MGIS.sig_inv_item_updated.emit(inv_name, grid_id)

				# [新增] 吸取也视为拿起，发送信号 (可以播放高音调的 pickup)
				MGIS.sig_item_picked_up.emit(moving_item)
				return true

	return false


## 使用物品（默认：鼠标右键点击格子）
func use_item(container_view: BaseContainerView, grid_id: Vector2i) -> bool:
	var inv_name: String = container_view.container_name
	var item_data = find_item_data_by_grid(inv_name, grid_id)
	if not item_data:
		return false
	var container_type: MGIS.ContainerType = container_view.container_type
	# 物品背包或者仓库则移动
	if container_type == MGIS.ContainerType.INVENTORY:
		# 非堆叠物品直接移动（堆叠物品由调用服务的UI层的节流函数自动触发quick_move_item）
		if not item_data is StackableData:
			quick_move_item(container_view, grid_id, 1)
	# 物品不在背包（正常情况不可能出现）
	else:
		push_warning("settings is error,this service is for inventory to inventory!")

	return false


## 分割物品
func split_item(container_view: BaseContainerView, grid_id: Vector2i, offset: Vector2i, base_size: int) -> BaseItemData:
	var inv_name: String = container_view.container_name
	var inv = _container_repository.get_container(inv_name)
	if inv:
		var item: BaseItemData = inv.find_item_data_by_grid(grid_id)
		if item and item is StackableData and item.stack_size > 1 and item.current_amount > 1:
			var origin_amount = item.current_amount
			var new_amount_1 = origin_amount / 2
			var new_amount_2 = origin_amount - new_amount_1
			item.current_amount = new_amount_1
			MGIS.sig_inv_item_updated.emit(inv_name, grid_id)
			var new_item = item.duplicate()
			new_item.current_amount = new_amount_2
			MGIS.moving_item_service.move_item_by_data(new_item, offset, base_size)
			return new_item
	return null


## 快速移动（默认：Shift + 鼠标右键）
func quick_move(container_view: BaseContainerView, grid_id: Vector2i) -> bool:
	var inv_name: String = container_view.container_name
	var target_inventories: Array = _container_repository.get_relations(inv_name)
	var item_to_move: BaseItemData = _container_repository.get_container(inv_name).find_item_data_by_grid(grid_id)
	if target_inventories.is_empty() or not item_to_move:
		return false
	for target_container: String in target_inventories:
		# 获取快速移动的背包类型（背包间是互相移动关系，背包个商店间是售出关系）
		var target_container_view = MGIS.get_container_view(target_container)
		# 目标背包没打开直接continue
		if not is_instance_valid(target_container_view) or not target_container_view.is_open():
			continue
		if target_container_view.container_type == MGIS.ContainerType.INVENTORY:
			if add_item(target_container, item_to_move, true, target_container_view.is_slot):
				remove_item_by_data(inv_name, item_to_move)
				return true
		elif target_container_view.container_type == MGIS.ContainerType.SHOP:
			# 出售物品
			var sold_success: bool = MGIS.shop_service.sold_item(target_container, item_to_move)
			# 出售成功则删除物品
			if sold_success:
				remove_item_by_data(inv_name, item_to_move)
			return sold_success
		# 装备物品到插槽
		elif target_container_view.container_type == MGIS.ContainerType.SLOT:
			if MGIS.item_slot_service.try_equip(item_to_move):
				remove_item_by_data(inv_name, item_to_move)
				return true

	return false


## 快速移动一半物品（默认：ctrl + 鼠标右键）
func quick_move_half(container_view: BaseContainerView, grid_id: Vector2i) -> bool:
	return quick_move_item(container_view, grid_id)


## 快速移动物品并指定移动数量
func quick_move_item(container_view: BaseContainerView, grid_id: Vector2i, sub_count: int = 0) -> bool:
	var inv_name: String = container_view.container_name
	var target_inventories: Array = _container_repository.get_relations(inv_name)
	var item_to_move: BaseItemData = _container_repository.get_container(inv_name).find_item_data_by_grid(grid_id)
	if target_inventories.is_empty() or not item_to_move:
		return false
	if item_to_move is StackableData:
		var stackable_item: StackableData = item_to_move
		var origin_amount: int = stackable_item.current_amount
		# 如果只有 1 个，则直接快速移动整个堆叠 (等同于 quick_move)
		if origin_amount <= 1:
			return quick_move(container_view, grid_id)
		# 2. 分割数量
		var amount_to_move: int = sub_count  # 移动到目标格子的数量
		# sub_count为0表示移动一半物品数量
		if sub_count == 0:
			amount_to_move = ceili(origin_amount / 2.0)  # 移动到目标格子的数量（向上取整）
		var amount_to_keep: int = origin_amount - amount_to_move  # 原始格子保留的数量
		# 3. 创建要移动的新物品实例
		var item_to_add: StackableData = stackable_item.duplicate()
		item_to_add.current_amount = amount_to_move
		# 4. 尝试添加到目标背包
		for target_container: String in target_inventories:
			# 获取快速移动的背包类型（背包间是互相移动关系，背包与商店间是售出关系）
			var target_container_view = MGIS.get_container_view(target_container)
			# 目标背包没打开直接continue
			if not is_instance_valid(target_container_view) or not target_container_view.is_open():
				continue
			if target_container_view.container_type == MGIS.ContainerType.INVENTORY:
				var amount_before_add: int = item_to_add.current_amount
				# 尝试添加物品
				if add_item(target_container, item_to_add, true, target_container_view.is_slot):
					# 5. 完全添加成功
					stackable_item.current_amount = amount_to_keep
					# 如果原始数量减为 0，则从背包中移除
					if stackable_item.current_amount <= 0:
						remove_item_by_data(inv_name, stackable_item)
					else:
						MGIS.sig_inv_item_updated.emit(inv_name, grid_id)
					return true
				# 6. 部分添加成功 (返回 false，但 item_to_add.current_amount 减少了)
				elif item_to_add.current_amount < amount_before_add:
					var amount_actually_moved: int = amount_before_add - item_to_add.current_amount
					# 从原始堆叠中扣除实际移动的数量
					stackable_item.current_amount -= amount_actually_moved
					MGIS.sig_inv_item_updated.emit(inv_name, grid_id)
					# 如果原始数量减为 0，则移除
					if stackable_item.current_amount <= 0:
						remove_item_by_data(inv_name, stackable_item)
					# 即使只有部分移动成功，也认为操作完成，跳出
					return true
			# 背包与商店间是售出关系，出售物品
			elif target_container_view.container_type == MGIS.ContainerType.SHOP:
				# 出售物品
				var sold_success: bool = MGIS.shop_service.sold_item(target_container, item_to_add)
				if sold_success:
					# 成功出售 amount_to_move 数量
					stackable_item.current_amount = amount_to_keep
					MGIS.sig_inv_item_updated.emit(inv_name, grid_id)
					# 如果原始数量减为 0，则从背包中移除
					if stackable_item.current_amount <= 0:
						remove_item_by_data(inv_name, stackable_item)
				# 成功出售，操作完成，退出函数
				return sold_success
			# 背包与插槽间是装备物品的关系（移动一个或者一半）
			elif target_container_view.container_type == MGIS.ContainerType.SLOT:
				if MGIS.item_slot_service.try_equip(item_to_add):
					# 添加成功
					stackable_item.current_amount = amount_to_keep
					# 如果原始数量减为 0，则从背包中移除
					if stackable_item.current_amount <= 0:
						remove_item_by_data(inv_name, stackable_item)
					else:
						MGIS.sig_inv_item_updated.emit(inv_name, grid_id)
					return true
				else:
					# 注意这里一定是continue，无法装备的话要接着往下查找插槽
					continue

		# 如果循环结束，物品没有被移动（或部分移动）
	else:
		# 非堆叠物品，直接执行 quick_move
		return quick_move(container_view, grid_id)

	return false
