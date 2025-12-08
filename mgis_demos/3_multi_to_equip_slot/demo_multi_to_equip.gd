extends Control

@onready var inventory: ColorRect = $Inventory
@onready var character: ColorRect = $Character
@onready var inventory_view: InventoryView = $Inventory/ScrollContainer/InventoryView


func _ready() -> void:
	MGIS.current_inventories = ["demo2_inventory"]
	MGIS.add_relation("demo2_inventory", "item_solt_1")
	MGIS.add_relation("demo2_inventory", "item_solt_2")
	MGIS.add_relation("demo2_inventory", "item_solt_3")
	MGIS.add_relation("demo2_inventory", "demo2_slot_1")
	MGIS.add_relation("demo2_inventory", "demo2_slot_2")

	_on_button_add_test_items_pressed()

	# 代理导出和导入背包数据
	MGIS.sig_proxy_save.connect(_on_proxy_save)
	MGIS.sig_proxy_load.connect(_on_proxy_load)


## 代理导出保存资源
func _on_proxy_save(save_data: Variant, inv_name: String, _request_id: int) -> void:
	var success: bool = await SaveSystem.export_as(save_data, inv_name)
	print("_on_proxy_save->inv_name:", inv_name, ",success:", success)


## 代理导人加载资源
func _on_proxy_load(inv_name: String, _request_id: int) -> void:
	var result = await SaveSystem.import_as(inv_name)
	print("_on_proxy_load->inv_name:", inv_name, ",result:", result)
	MGIS.proxy_load(inv_name, result, true)


func _on_button_close_inventory_pressed() -> void:
	inventory.hide()


func _on_button_close_character_pressed() -> void:
	character.hide()


func _on_button_toggle_inventory_pressed() -> void:
	inventory.visible = not inventory.visible


func _on_button_toggle_character_pressed() -> void:
	character.visible = not character.visible


func _on_button_add_test_items_pressed() -> void:
	var animal_1 = load("res://mgis_demos/resources/animal_1.tres")
	MGIS.add_item("demo2_inventory", animal_1)
	#return
	var item_11 = load("res://mgis_demos/resources/equipment_2.tres")
	MGIS.add_item("demo2_inventory", item_11)

	var item_10 = load("res://mgis_demos/resources/equipment_1.tres")
	var item_12 = load("res://mgis_demos/resources/equipment_3.tres")
	var item_2 = load("res://mgis_demos/resources/stackable_1.tres")
	var item_3 = load("res://mgis_demos/resources/consumable_1.tres")
	MGIS.add_item("demo2_inventory", item_10)
	MGIS.add_item("demo2_inventory", item_12)
	MGIS.add_item("demo2_inventory", item_2)
	MGIS.add_item("demo2_inventory", item_3)


func _on_button_save_pressed() -> void:
	MGIS.save("demo2_inventory")


func _on_button_load_pressed() -> void:
	# 加载背包并同步加载装备
	MGIS.load("demo2_inventory", true)


func _on_button_close_storage_pressed() -> void:
	pass  # Replace with function body.


func _on_button_toggle_storage_pressed() -> void:
	pass  # Replace with function body.
