extends Node
## ========= 重要 ==========
## 全局名称必须配置为：MGIS
## ========= 重要 ==========

## 插件配置文件
const SETTINGS: Script = preload("res://addons/multi_grid_inventory_system/settings.gd")
## 默认角色
const DEFAULT_PLAYER: String = "player_1"
## 默认背包名称
const DEFAULT_INVENTORY_NAME: String = "Inventory"
## 默认商店名称
const DEFAULT_SHOP_NAME: String = "Shop"
## 默认装备槽名称
const DEFAULT_SLOT_NAME: String = "Equipment Slot"
## 默认保存路径
const DEFAULT_SAVE_FOLDER: String = "user://saves"

## 物品级别背景色
const LEVEL_COLOR: Dictionary = {
	0: Color("FFFFFFE0"),  # 普通
	1: Color("FFFF00E0"),  # 稀有
	2: Color("00BFFFE0"),  # 罕见
	3: Color("A335EEE0"),  # 传说
	4: Color("FFFFFF00"),  # 无级别
	#... 可以加更多，需要和资源类中枚举级别匹配
}
## 物品的style box样式配置border_width
const CORNER_RADIUS: float = 4.0
const BORDER_WIDTH: float = 0.0
const BORDER_COLOR: Color = Color("00000000")
## 物品所在容器的类型
enum ContainerType {
	INVENTORY,  # 背包
	SHOP,  # 商店
	SLOT,  # 装备插槽
}

## 物品已添加
@warning_ignore("unused_signal")
signal sig_inv_item_added(inv_name: String, item_data: BaseItemData, grids: Array[Vector2i])
## 物品已移除
@warning_ignore("unused_signal")
signal sig_inv_item_removed(inv_name: String, item_data: BaseItemData)
## 物品已更新
@warning_ignore("unused_signal")
signal sig_inv_item_updated(inv_name: String, grid_id: Vector2i)
## 刷新所有背包
@warning_ignore("unused_signal")
signal sig_inv_refresh
## 刷新所有商店
@warning_ignore("unused_signal")
signal sig_shop_refresh
## 刷新所有装备槽
@warning_ignore("unused_signal")
signal sig_slot_refresh
## 物品已装备
@warning_ignore("unused_signal")
signal sig_slot_item_equipped(slot_name: String, item_data: BaseItemData)
## 物品已脱下
@warning_ignore("unused_signal")
signal sig_slot_item_unequipped(slot_name: String, item_data: BaseItemData)
## 焦点物品：监听这个信号以处理信息显示
@warning_ignore("unused_signal")
signal sig_item_focused(item_data: BaseItemData)
## 物品丢失焦点：监听这个信号以清除物品信息显示
@warning_ignore("unused_signal")
signal sig_item_focus_lost(item_data: BaseItemData)
## 背包满了
@warning_ignore("unused_signal")
signal sig_inventory_full(inv_name: String)
## 不允许添加的物品类型
@warning_ignore("unused_signal")
signal sig_item_disallowed(inv_name: String, item_data: BaseItemData)
## 显示物品的详情面板
@warning_ignore("unused_signal")
signal sig_show_item_detail(inv_name: String, grid_id: Vector2i, Item_view: ItemView)
## 长按网格
@warning_ignore("unused_signal")
signal sig_grid_long_pressed(inv_name: String, grid_id: Vector2i, Item_view: ItemView)
## 显示物品的范围
@warning_ignore("unused_signal")
signal sig_show_item_range(inv_name: String, Item_view: ItemView)
signal sig_hide_item_range(inv_name: String, Item_view: ItemView)
## 进入物品内部
@warning_ignore("unused_signal")
signal sig_enter_item(inv_name: String, Item_view: ItemView)
## 代理保存
@warning_ignore("unused_signal")
signal sig_proxy_save(save_data: Variant, inv_name: String, request_id: int)
## 代理加载
@warning_ignore("unused_signal")
signal sig_proxy_load(inv_name: String, request_id: int)

## 背包业务类全局引用，如有需要可以使用，不要自己new
var inventory_service: InventoryService = InventoryService.new()
## 背包业务类全局引用，如有需要可以使用，不要自己new
var shop_service: ShopService = ShopService.new()
## 物品插槽业务类全局引用，如有需要可以使用，不要自己new
var item_slot_service: ItemSlotService = ItemSlotService.new()
## 移动物品业务类全局引用，如有需要可以使用，不要自己new
var moving_item_service: MovingItemService = MovingItemService.new()
## 物品焦点业务类（处理鼠标在不在物品上），如有需要可以使用，不要自己new
var item_focus_service: ItemFocusService = ItemFocusService.new()
## 稀疏地图网格业务类，如有需要可以使用，不要自己new
var sparse_map_service: SparseMapService = SparseMapService.new()

## 当前角色，如果是单角色，不予理会即可，如果是多角色，操作每个角色前应更新这个值
var current_player: String = DEFAULT_PLAYER
## 当前角色的背包，用于快捷脱装备和购买装备时物品的去向，多角色请及时更新
var current_inventories: Array[String] = []

## 是否开启代理保存（对数据加解密，使用外部代码实现，开启后通过信号关联）
var enable_proxy: bool = SETTINGS.get_setting_value("mgi_system/config/enabled_proxy_save")
## 当前保存路径
var current_save_path: String = SETTINGS.get_setting_value("mgi_system/config/save_directory") + "/"
## 当前存档名，支持 "tres" 和 "res"，目前版本会保存两个文件：inv_存档名、item_slot_存档名
var current_save_name: String = "_default.tres"
## 保存装备栏物品的前缀
var item_slot_prefix: String = "item_slot"
## ===============重要=====================
## 自定义tooltip代理（必须封装了一个create函数）
## ===============重要=====================
var proxy_tooltip: Node = null
## 鼠标经过格子的grid_id（全局）
var mouse_cell_id: Vector2i = Vector2i.ZERO
## 鼠标所在的当前背包
var current_container: BaseContainerView

## 所有背包或者插槽字典数据
var container_dict: Dictionary[String,Control] = {}

## 点击物品（购买单个），鼠标左键
var input_click: String = "inv_click"
## 快速移动（售卖），shift+鼠标右键
var input_quick_move: String = "inv_quick_move"
## 快速移动一半（购买/售卖一半），ctrl+鼠标右键
var input_move_half: String = "inv_move_half"
## 特殊组件键ctrl（组合键需要和别的按键配合使用）
var input_ctrl: String = "inv_ctrl"
## 使用物品，鼠标右键
var input_use: String = "inv_use"
## 分割物品，鼠标中键
var input_split: String = "inv_split"
## 旋转物品，键盘R键
var input_rotate: String = "inv_rotate"
## 节流时间字典
var _throttle_timers: Dictionary[String,float] = {}


## 保存背包和装备槽
## @param inv_name: 背包名（到底保存哪个背包）
## @param save_slot: 是否同步保存装备，默认true
func save(inv_name: String, save_slot: bool = true) -> void:
	print("MGIS save->inv_name:", inv_name)
	if inv_name.is_empty():
		return
	inventory_service.save(inv_name)
	if save_slot:
		item_slot_service.save()


## 读取背包和装备槽
## @param inv_name: 背包名
## @param load_slot: 是否同步加载装备，默认false
func load(inv_name: String, load_slot: bool = false) -> void:
	await get_tree().process_frame
	# 装备数据
	if load_slot:
		item_slot_service.load()
		sig_slot_refresh.emit()
	# 背包数据
	inventory_service.load(inv_name)
	var container_view: BaseContainerView = get_container_view(inv_name) as BaseContainerView
	if not is_instance_valid(container_view):
		return
	if container_view.container_type == ContainerType.INVENTORY:
		sig_inv_refresh.emit()
	elif container_view.container_type == ContainerType.SHOP:
		sig_shop_refresh.emit()


## 代理载入
## @param inv_name: 背包名
## @param load_slot: 是否同步加载装备，默认false
## @param proxy_data: 代理载入的数组资源
func proxy_load(inv_name: String, proxy_data: Resource, load_slot: bool = false) -> void:
	await get_tree().process_frame
	# 无效数据直接返回
	if not is_instance_valid(proxy_data) or not proxy_data is Resource:
		return
	# 装备数据
	if load_slot:
		item_slot_service.proxy_load(proxy_data)
		sig_slot_refresh.emit()
	# 背包数据
	inventory_service.proxy_load(inv_name, proxy_data)
	var container_view: BaseContainerView = get_container_view(inv_name) as BaseContainerView
	if not is_instance_valid(container_view):
		return
	if container_view.container_type == ContainerType.INVENTORY:
		sig_inv_refresh.emit()
	elif container_view.container_type == ContainerType.SHOP:
		sig_shop_refresh.emit()


## 获取场景树的根（主要在Service中使用，因为Service没有加入场景树，所以没有 get_tree()）
func get_root() -> Node:
	return get_tree().root


## 向背包添加物品
## @param inv_name:背包名称
## @param item_data:待添加的资源数据
## @param need_duplicate:是否需要深度拷贝
## @param is_slot:是否放入单格背包（非多格占用的情况）
## @param head_pos:是否放入背包的指定位置
func add_item(inv_name: String, item_data: BaseItemData, need_duplicate: bool = true, is_slot: bool = false, head_pos: Vector2i = -Vector2i.ONE) -> bool:
	#print("add_item->inv_name:", inv_name)
	# 更新提示
	item_data.formatter_tooltip()
	return inventory_service.add_item(inv_name, item_data, need_duplicate, is_slot, head_pos)


## 增加背包间的关系
func add_relation(inv_name: String, target_inv_name: String, service: BaseContainerService = inventory_service) -> void:
	service.add_relation(inv_name, target_inv_name)


## 删除背包间的关系
func remove_relation(inv_name: String, target_inv_name: String, service: BaseContainerService = inventory_service) -> void:
	service.remove_relation(inv_name, target_inv_name)


## 是否有正在移动的物品
func has_moving_item() -> bool:
	return moving_item_service.moving_item != null


## 卖出物品到商店
func sold_item(inv_name: String, item_data: BaseItemData) -> bool:
	return shop_service.sell_item(inv_name, item_data)


## 通过名称获取背包或者插槽容器
func get_container_view(inv_name: String) -> Control:
	return container_dict.get(inv_name, null)


## 节流函数 (throttle)
## @param key: 节流函数的唯一标识符
## @param delay: 冷却时间（秒）
## @param func: 待执行的函数
## @param args: 待执行函数的参数（可选）
func throttle(key: String, delay: float, cbk: Callable, args: Array = []) -> void:
	# 检查当前 key 是否存在于计时器中，并且是否还在冷却期
	if _throttle_timers.has(key) and Time.get_ticks_msec() < _throttle_timers[key]:
		return
	# 如果不在冷却期，执行函数
	cbk.callv(args)
	# 重置计时器
	_throttle_timers[key] = Time.get_ticks_msec() + delay * 1000


## 检查对象是否包含指定的属性
func check_has_property(object: Object, property_name: String) -> bool:
	# 确保对象有效
	if not is_instance_valid(object):
		return false
	# 遍历属性列表
	var property_list: Array = object.get_property_list()
	for prop in property_list:
		# prop 是一个包含 "name" 和 "type" 的字典
		if prop.get("name") == property_name:
			return true

	return false
