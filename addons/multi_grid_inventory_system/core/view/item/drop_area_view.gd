@tool
extends Control
## 丢弃物品视图，加到场景中即可，会自动全屏并移到最底层
class_name DropAreaView


## 初始化
func _ready() -> void:
	if not Engine.is_editor_hint():
		MGIS.moving_item_service.drop_area_view = self
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	await get_tree().process_frame
	_on_resize()


## 防呆，自动移到最底层，防止挡住背包导致无法放置
func _on_resize() -> void:
	if is_inside_tree():
		if get_parent() is Control:
			size = (get_parent() as Control).size
		else:
			size = Vector2.ZERO
		get_parent().move_child(self, 0)


## 输入控制
func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(MGIS.input_click):
		if MGIS.has_moving_item() and MGIS.moving_item_service.moving_item.can_drop():
			MGIS.moving_item_service.moving_item.drop()
			MGIS.moving_item_service.clear_moving_item()
