extends Control

@onready var map_view: SparseMapView = %MapView
@onready var map_boot_view: MapView = %MapBootView
@onready var toggle_build_mode: Button = %ToggleBuildMode
@onready var game_map: GameMap = $SparseMap/ScrollContainer/GameMap

var _show_grid_lines: bool = true
var _is_build_mode: bool = false


func _ready() -> void:
	MGIS.sig_show_item_detail.connect(_on_show_item_detail)
	MGIS.sig_grid_interact_pressed.connect(_on_grid_interact_pressed)
	MGIS.sig_show_item_range.connect(_on_show_item_range)
	MGIS.sig_hide_item_range.connect(_on_hide_item_range)
	MGIS.sig_enter_item.connect(_on_enter_item)


func _on_show_item_detail(inv_name: String, _grid_id: Vector2i, Item_view: ItemView) -> void:
	var item_data: BaseItemData = Item_view.data
	print("inv_name:", inv_name, ",item_id:", item_data.item_id)


func _on_grid_interact_pressed(inv_name: String, grid_id: Vector2i, Item_view: ItemView) -> void:
	var item_data: BaseItemData = Item_view.data
	print("inv_name:", inv_name, ",grid_id:", grid_id, ",item_id:", item_data.item_id)


func _on_show_item_range(inv_name: String, Item_view: ItemView) -> void:
	var item_data: BaseItemData = Item_view.data
	print("inv_name:", inv_name, ",item_id:", item_data.item_id)


func _on_hide_item_range(inv_name: String, Item_view: ItemView) -> void:
	var item_data: BaseItemData = Item_view.data
	print("inv_name:", inv_name, ",item_id:", item_data.item_id)


func _on_enter_item(inv_name: String, Item_view: ItemView) -> void:
	var item_data: BaseItemData = Item_view.data
	print("inv_name:", inv_name, ",item_id:", item_data.item_id)


func _on_btn_add_items_pressed() -> void:
	var terrain_1 = load("res://mgis_demos/resources/terrain_1.tres")
	MGIS.add_item("demo5_map", terrain_1)
	#return
	var animal_1 = load("res://mgis_demos/resources/animal_1.tres")
	MGIS.add_item("demo5_slot_inventory", animal_1)
	#return
	var item_11 = load("res://mgis_demos/resources/equipment_2.tres")
	MGIS.add_item("demo5_slot_inventory", item_11)

	var item_10 = load("res://mgis_demos/resources/equipment_1.tres")
	var item_12 = load("res://mgis_demos/resources/equipment_3.tres")
	var item_2 = load("res://mgis_demos/resources/stackable_1.tres")
	var item_3 = load("res://mgis_demos/resources/consumable_1.tres")
	MGIS.add_item("demo5_slot_inventory", item_10)
	MGIS.add_item("demo5_slot_inventory", item_12)
	MGIS.add_item("demo5_slot_inventory", item_2)
	MGIS.add_item("demo5_slot_inventory", item_3)


func _on_btn_save_pressed() -> void:
	MGIS.save("demo5_slot_inventory", false)
	MGIS.save("demo5_boot_map", false)
	MGIS.save("demo5_map", false)


func _on_btn_load_pressed() -> void:
	MGIS.load("demo5_slot_inventory")
	MGIS.load("demo5_boot_map")
	MGIS.load("demo5_map")


func _on_btn_toggle_map_grid_pressed() -> void:
	_show_grid_lines = not _show_grid_lines
	map_view.show_grid_lines = _show_grid_lines


func _on_toggle_build_mode_pressed() -> void:
	_is_build_mode = not _is_build_mode
	#map_view.is_build_mode = _is_build_mode
	#map_boot_view.is_build_mode = _is_build_mode
	game_map.set_build_mode(_is_build_mode)
	if _is_build_mode:
		toggle_build_mode.text = "Build mode on"
	else:
		toggle_build_mode.text = "Build mode off"
