@tool
extends EditorPlugin

const SYSTEM_NAME: String = "MGIS"
const SETTINGS: Script = preload("./settings.gd")
const SETTING_INFO_DICT: Dictionary[StringName, Dictionary] = SETTINGS.SETTING_INFO_DICT

## 系统核心代码路径
var SYSTEM_PATH: String = "res://addons/multi_grid_inventory_system/core/multi_grid_inv_system.gd"


## 在插件运行时添加项目设置
func _enter_tree() -> void:
	_add_project_settings()
	add_autoload_singleton(SYSTEM_NAME, SYSTEM_PATH)
	ProjectSettings.save()


## 在禁用插件时恢复项目配置
func _disable_plugin() -> void:
	remove_autoload_singleton(SYSTEM_NAME)
	_remove_project_settings()
	ProjectSettings.save()


## 添加配置脚本中的设置项
func _add_project_settings() -> void:
	for setting_dict in SETTING_INFO_DICT.values():
		_add_setting_dict(setting_dict)


## 移除配置脚本中的设置项
func _remove_project_settings() -> void:
	for setting_dict in SETTING_INFO_DICT.values():
		_remove_setting_dict(setting_dict)


## 使用hint_dictionary添加选项
func _add_setting_dict(info_dict: Dictionary) -> void:
	var setting_name: String = info_dict["name"]
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, info_dict["default"])

	ProjectSettings.set_as_basic(setting_name, info_dict["basic"])
	ProjectSettings.set_initial_value(setting_name, info_dict["default"])
	ProjectSettings.add_property_info(info_dict)


## 使用hint_dictionary移除选项
func _remove_setting_dict(info_dict: Dictionary) -> void:
	var setting_name: String = info_dict["name"]
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, null)


## 添加单个设置项
func _add_setting(name: String, default_value, type: int, hint: int, hint_string: String = "") -> void:
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default_value)

	ProjectSettings.set_initial_value(name, default_value)
	ProjectSettings.add_property_info({"name": name, "type": type, "hint": hint, "hint_string": hint_string})
