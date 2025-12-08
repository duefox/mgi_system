extends RefCounted
## 物品焦点业务类
class_name ItemFocusService

## 当前焦点目标
var _current_focus_item: ItemView

## 焦点物品
func focus_item(item: ItemView) -> void:
	if _current_focus_item and _current_focus_item != item and not MGIS.moving_item_service.moving_item:
		item_lose_focus(_current_focus_item)
		MGIS.sig_item_focused.emit(item.data)
		_current_focus_item = item

## 焦点丢失
func item_lose_focus(item: ItemView) -> void:
	if item:
		if _current_focus_item != item:
			return
		MGIS.sig_item_focus_lost.emit(item.data)
		_current_focus_item = null
