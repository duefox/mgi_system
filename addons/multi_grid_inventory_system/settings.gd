extends RefCounted

## 配置项
const SETTING_MGIS: String = "mgi_system/"
const SETTING_MGIS_CONFIG: String = SETTING_MGIS + "config/"
const SETTING_INFO_DICT: Dictionary[StringName, Dictionary] = {
	"mgi_system/config/save_directory":
	{
		"name": SETTING_MGIS_CONFIG + "save_directory",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
		"hint_string": "save directory",
		"basic": true,
		"default": "user://saves",
	},
	"mgi_system/config/enabled_proxy_save":
	{
		"name": SETTING_MGIS_CONFIG + "enabled_proxy_save",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "proxy save/load",
		"basic": true,
		"default": false,
	},
}


## 设置路径和字典名称里只要填对一个就能得到参数的傻瓜方法
static func get_setting_value(setting_name: StringName, default_value: Variant = null) -> Variant:
	var setting_dict: Dictionary = {}

	if SETTING_INFO_DICT.has(setting_name):
		setting_dict = SETTING_INFO_DICT.get(setting_name)
		setting_name = setting_dict.get("name")

	if setting_dict.is_empty():
		for dict in SETTING_INFO_DICT.values():
			if dict.get("name") == setting_name:
				setting_dict = dict
				break

	if setting_dict.has("default") && default_value == null:
		default_value = setting_dict.get("default")

	return ProjectSettings.get_setting(setting_name, default_value)
