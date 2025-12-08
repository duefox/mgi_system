extends Control

@onready var inventory: ColorRect = $Inventory
@onready var shop: ColorRect = $Shop
@onready var shop_view: ShopView = $Shop/ShopView


func _ready() -> void:
	MGIS.current_inventories = ["demo3_inventory"]
	# 背包快速出售给商店的关系
	MGIS.add_relation("demo3_inventory", "demo3_shop")

	_on_button_add_test_items_pressed()

	MGIS.sig_inventory_full.connect(_on_inventory_full)


func _on_inventory_full(inv_name: String) -> void:
	if not inv_name == "demo3_inventory":
		return
	print("inventory is full")


func _on_button_close_inventory_pressed() -> void:
	inventory.hide()


func _on_button_toggle_inventory_pressed() -> void:
	inventory.visible = not inventory.visible


func _on_button_close_storage_pressed() -> void:
	shop.hide()


func _on_button_toggle_storage_pressed() -> void:
	shop.visible = not shop.visible


func _on_button_add_goods_pressed() -> void:
	var item_1 = load("res://mgis_demos/resources/equipment_1.tres")
	var item_2 = load("res://mgis_demos/resources/stackable_1.tres")
	var item_3 = load("res://mgis_demos/resources/consumable_1.tres")
	shop_view.goods.append_array([item_1, item_2, item_3])
	shop_view.update_goods()


func _on_button_add_test_items_pressed() -> void:
	var item_1 = load("res://mgis_demos/resources/equipment_1.tres")
	var item_2 = load("res://mgis_demos/resources/stackable_1.tres")
	var item_3 = load("res://mgis_demos/resources/consumable_1.tres")
	MGIS.add_item("demo3_inventory", item_1)
	MGIS.add_item("demo3_inventory", item_2)
	MGIS.add_item("demo3_inventory", item_3)


func _on_button_save_pressed() -> void:
	MGIS.save("demo3_inventory")
	MGIS.save("demo3_shop")


func _on_button_load_pressed() -> void:
	MGIS.load("demo3_inventory")
	MGIS.load("demo3_shop")
