extends Resource
## 背包数据库，管理 ContainerData 的存取
class_name ContainerRepository

## 保存时的前缀
const PREFIX: String = "container_"
## 保存的文件扩展名
const SAVE_EXTENSION: String = ".tres"

## 用于生成唯一的保存请求ID
static var _next_request_id: int = 0

## 单例
static var instance: ContainerRepository:
	get:
		if not instance:
			instance = ContainerRepository.new()
		return instance

## 所有背包数据
var _container_data_map: Dictionary[String, ContainerData] = {}
## 所有背包的快速移动关系 (重新声明为全局属性)
var _quick_move_relations_map: Dictionary[String, Array] = {}


## 保存指定的背包数据 (只保存单个 inv_name)
func save(inv_name: String) -> int:
	var container_data = get_container(inv_name)
	if not container_data:
		push_warning("Container '" + inv_name + "' not found for saving.")
		return -1
	# 启用代理保存导出
	if MGIS.enable_proxy:
		_next_request_id += 1
		var request_id = _next_request_id
		# 确保发送一个副本，防止外部保存系统在异步处理时修改了实时数据
		var data_to_save = container_data.duplicate(true)
		# MGIS 发出保存请求信号
		MGIS.sig_proxy_save.emit(data_to_save, inv_name, request_id)
		return request_id
	else:
		var save_path = _get_container_save_path(inv_name)
		var error = ResourceSaver.save(container_data, save_path)
		return error


## 从文件中读取并注册指定的背包数据
## 加载完成后自动设置数据，不再返回 ContainerData 实例。
## @param inv_name:背包名称
func load(inv_name: String) -> bool:
	# 启用代理加载导入
	if MGIS.enable_proxy:
		_next_request_id += 1
		var request_id = _next_request_id
		# MGIS 发出保存请求信号
		MGIS.sig_proxy_load.emit(inv_name, request_id)
		return true

	var load_path = _get_container_save_path(inv_name)
	print("load_path:", load_path)
	var loaded_resource: Resource = load(load_path)

	if loaded_resource is ContainerData:
		# 确保返回一个独立的副本
		var loaded_container = loaded_resource.duplicate(true)
		# 将加载的数据注册到内存中
		_container_data_map[inv_name] = loaded_container
		return true  # 加载成功

	push_warning("Failed to load Container '" + inv_name + "'. File not found or is invalid.")
	return false  # 加载失败


## 代理载入指定的背包数据
## 加载完成后自动设置数据，不再返回 ContainerData 实例。
## @param inv_name:背包名称
## @param proxy_data:代理载入的资源数据
func proxy_load(inv_name: String, proxy_data: Resource) -> bool:
	var loaded_resource: Resource = proxy_data
	if loaded_resource is ContainerData:
		# 确保返回一个独立的副本
		var loaded_container = loaded_resource.duplicate(true)
		# 将加载的数据注册到内存中
		_container_data_map[inv_name] = loaded_container
		return true  # 加载成功

	push_warning("Failed to load Container '" + inv_name + "'. File not found or is invalid.")
	return false  # 加载失败


## 增加并返回背包，如果已存在，返回已经注册的背包
## 此函数只负责内存注册，不涉及文件加载
func add_container(inv_name: String, columns: int, rows: int, activated_rows: int, avilable_types: Array[String]) -> ContainerData:
	var inv = get_container(inv_name)
	if inv:
		return inv

	# 仅创建新实例并注册
	var new_container = ContainerData.new(inv_name, columns, rows, activated_rows, avilable_types)
	_container_data_map[inv_name] = new_container
	return new_container


## 获取背包数据
func get_container(inv_name: String) -> ContainerData:
	return _container_data_map.get(inv_name)


## 整理物品数据
## @param inv_name:背包名称
## @param attri:资源的属性值 (例如 "item_level", "price", "rarity")
## @param reverse:是否倒序排序 (默认 false: 升序/从小到大; true: 降序/从大到小)
## return 返回是否整理成功
func sort_items_by_attri(inv_name: String, attri: String, reverse: bool = false) -> Array[BaseItemData]:
	var container_data: ContainerData = get_container(inv_name)
	if not is_instance_valid(container_data):
		return []

	var grid_item_map: Dictionary[Vector2i, Variant] = container_data.grid_item_map
	if grid_item_map.is_empty():
		return []

	# 1. 收集所有物品 (基于实例ID去重，防止多格物品被重复统计)
	# 注意：如果背包里有两个属性完全一样的铁剑，它们是两个不同的实例，Instance ID 不同，不会被去重，这是正确的。
	# 只有同一个“占两格的大剑”在 map 中出现两次时，会被视为同一个实例而去重。
	var items_to_sort: Array[BaseItemData] = []
	var seen_instance_ids: Dictionary = {}

	for item_data: Variant in grid_item_map.values():
		if item_data is BaseItemData:
			var id = item_data.get_instance_id()
			if not seen_instance_ids.has(id):
				# 检查属性是否存在
				if not MGIS.check_has_property(item_data, attri):
					push_warning("Item '%s' missing property '%s', sorting aborted." % [item_data, attri])
					return []
				items_to_sort.append(item_data)
				seen_instance_ids[id] = true

	if items_to_sort.is_empty():
		return []
	# 2. 执行排序
	items_to_sort.sort_custom(
		func(a: BaseItemData, b: BaseItemData):
			var val_a = a.get(attri)
			var val_b = b.get(attri)
			# 类型安全检查
			if typeof(val_a) != typeof(val_b):
				# 不同类型无法直接比较，按字符串处理或返回 false
				return str(val_a) < str(val_b)
			if reverse:
				return val_a > val_b  # 降序
			else:
				return val_a < val_b  # 升序
	)

	# 3.清空当前容器所有物品映射
	container_data.clear()

	return items_to_sort


## 增加快速移动关系 (使用全局 Map)
func add_relation(inv_name: String, target_inv_name: String) -> void:
	if _quick_move_relations_map.has(inv_name):
		var relations = _quick_move_relations_map[inv_name]
		if not relations.has(target_inv_name):  # 避免重复添加
			relations.append(target_inv_name)
	else:
		var arr: Array[String] = [target_inv_name]
		_quick_move_relations_map[inv_name] = arr


## 移除快速移动关系
func remove_relation(inv_name: String, target_inv_name: String) -> void:
	if _quick_move_relations_map.has(inv_name):
		var relations = _quick_move_relations_map[inv_name]
		relations.erase(target_inv_name)


## 获取指定背包的快速移动关系
func get_relations(inv_name: String) -> Array[String]:
	return _quick_move_relations_map.get(inv_name, [] as Array[String])


## 根据 inv_name 生成保存路径
func _get_container_save_path(inv_name: String) -> String:
	return MGIS.current_save_path + PREFIX + inv_name + SAVE_EXTENSION
