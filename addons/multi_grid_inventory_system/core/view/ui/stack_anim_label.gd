## 堆叠文本动画类扩展小组件
extends Label
class_name StackAnimLabel

## 动画配置常量
const ANIMATION_SCALE: float = 1.2
const ANIMATION_DURATION: float = 0.15
var _font_tween: Tween = null
## 动画文本代理字段
@export var animated_text: String:
	set = _set_animated_text,
	get = _get_animated_text
## 内部文本
var _internal_text: String = ""
## 存储 LabelSettings 中最初设定的字体大小，用于动画基准。
var _base_font_size: int = 14


func _ready() -> void:
	_base_font_size = label_settings.font_size


func _set_animated_text(new_text: String) -> void:
	if _internal_text != new_text:
		var old_text = _internal_text
		_internal_text = new_text
		super.set("text", _internal_text)
		_animate_font_size()


func _get_animated_text() -> String:
	return _internal_text


# 字体缩放动画逻辑 (针对 label_settings)
func _animate_font_size():
	# 确保节点已进入树，否则无法获取主题信息
	if not is_inside_tree():
		return
	# 没用label_settings直接返回
	if not is_instance_valid(label_settings):
		return
	var label_set: LabelSettings = label_settings
	# 动画的起点和终点都是固定的
	var base_size: int = _base_font_size
	var enlarged_size: float = base_size * ANIMATION_SCALE

	# 销毁旧 Tween
	if is_instance_valid(_font_tween):
		_font_tween.kill()
	# 创建新 Tween
	_font_tween = create_tween()
	_font_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# 放大阶段：从 base_size 放大到 enlarged_size
	_font_tween.tween_property(label_set, "font_size", enlarged_size, ANIMATION_DURATION)
	# 恢复阶段：从 enlarged_size 恢复到 base_size (固定值)
	_font_tween.tween_property(label_set, "font_size", base_size, ANIMATION_DURATION * 1.5)
	_font_tween.tween_callback(func(): _font_tween = null)
