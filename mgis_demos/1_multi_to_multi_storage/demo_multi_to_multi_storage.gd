extends Control

@onready var inventory: ColorRect = $Inventory
@onready var storage: ColorRect = $Storage


func _ready() -> void:
	MGIS.add_relation("demo1_inventory", "demo1_storage")
	MGIS.add_relation("demo1_storage", "demo1_inventory")
	_on_button_add_test_items_pressed()

	MGIS.sig_inventory_full.connect(_on_inventory_full)
	MGIS.sig_item_disallowed.connect(_on_item_disallowed)
	# 代理导出和导入背包数据
	MGIS.sig_proxy_save.connect(_on_proxy_save)
	MGIS.sig_proxy_load.connect(_on_proxy_load)


## 代理导出保存资源
func _on_proxy_save(save_data: Variant, inv_name: String, _request_id: int) -> void:
	# 假设你有SaveSystem单列做导出
	var success: bool = await SaveSystem.export_as(save_data, inv_name)
	print("_on_proxy_save->inv_name:", inv_name, ",success:", success)


## 代理导人加载资源
func _on_proxy_load(inv_name: String, _request_id: int) -> void:
	# 假设你有SaveSystem单列做导入
	var result = await SaveSystem.import_as(inv_name)
	print("_on_proxy_load->inv_name:", inv_name, ",result:", result)
	MGIS.proxy_load(inv_name, result)


## 仓库满了
func _on_inventory_full(inv_name: String) -> void:
	print("_on_inventory_full->inv_name:", inv_name)


## 添加了禁止添加的物品类型
func _on_item_disallowed(inv_name: String, item_data: BaseItemData) -> void:
	print("_on_item_disallowed->inv_name:", inv_name, ",item_id:", item_data.item_id)


func _on_button_close_inventory_pressed() -> void:
	inventory.hide()


func _on_button_close_storage_pressed() -> void:
	storage.hide()


func _on_button_toggle_inventory_pressed() -> void:
	inventory.visible = not inventory.visible


func _on_button_toggle_storage_pressed() -> void:
	storage.visible = not storage.visible


func _on_button_add_test_items_pressed() -> void:
	#var terrain_1 = load("res://mgis_demos/resources/terrain_1.tres")
	#MGIS.add_item("demo1_storage", terrain_1)
	#return
	var animal_1 = load("res://mgis_demos/resources/animal_1.tres")
	MGIS.add_item("demo1_inventory", animal_1)
	#return
	var item_11 = load("res://mgis_demos/resources/equipment_2.tres")
	MGIS.add_item("demo1_inventory", item_11)

	var item_10 = load("res://mgis_demos/resources/equipment_1.tres")
	var item_12 = load("res://mgis_demos/resources/equipment_3.tres")
	var item_2 = load("res://mgis_demos/resources/stackable_1.tres")
	var item_3 = load("res://mgis_demos/resources/consumable_1.tres")
	MGIS.add_item("demo1_inventory", item_10)
	MGIS.add_item("demo1_inventory", item_12)
	MGIS.add_item("demo1_inventory", item_2)
	MGIS.add_item("demo1_inventory", item_3)


func _on_button_save_pressed() -> void:
	MGIS.save("demo1_inventory", false)
	MGIS.save("demo1_storage", false)


func _on_button_load_pressed() -> void:
	MGIS.load("demo1_inventory")
	MGIS.load("demo1_storage")
