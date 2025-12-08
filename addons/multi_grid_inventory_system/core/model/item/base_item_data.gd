extends Resource
## 物品数据基类，所有物品的基类
class_name BaseItemData

## 物品类型
enum ItemType {
	ANIMAL,  # 动物
	ANIMALEGG,  # 动物蛋
	FOOD,  # 食物
	EQUIPMENT,  # 装备
	MATERIAL,  # 材料
	BUILD,  # 建造
	DEVICE,  # 设备
	LANDSCAPE,  # 造景
	TERRIAIN,  # 地形（世界地图容器中不可拖拽的物品，小型长按拆除，大型只能在详情面板拆除）
	CONSUMABLE,  # 消耗品
	OTHERS,  # 其他，废物之类
	NONE,  # 无类型
}
## 物品最高级别
enum ItemLevel {
	BASIC,  # 普通
	MAGIC,  # 稀有
	EPIC,  # 罕见
	MYTHIC,  # 传说
	NONE,  # 无级别
}

##  性别
enum Gender {
	NONE,  # 无性别
	FEMALE,  # 雌性
	MALE,  # 雄性
}

#食性
enum FeedingHabits {
	OMNIVOROUS,  #杂食 Omnivorous
	HERBIVOROUS,  #草食 Herbivorous
	CARNIVOROUS,  #肉食 Carnivorous
	SCAVENGING,  #腐食 Scavenging
}

## 旋转方向
enum ORI {
	VER,  # 代表竖直方向
	HOR,  # 代表横向方向
	NONE,
}

##  体型大小
enum BodySize { SMALL, MIDDLE, BIG }

@export_group("Common Settings")
## 物品id，需要唯一
@export var item_id: String = &""
## 内部私有id，主要用于放置到房间内相同物品的区分
@export var private_id: int
## 物品插槽类型，值为“ANY”表示所有类型
## 这个字段用来匹配是否能装备物品，不用枚举是让装备可以用字符串区分如：消耗品，项链，头，胸，足等方便扩展
@export var type: String = "ANY"
## 物品级别
@export var item_level: ItemLevel = ItemLevel.BASIC
## 物品类型
@export var item_type: ItemType = ItemType.NONE
## 昵称
@export var nickname: String = ""
## 描述
@export_multiline var descrip: String = ""
## 物品基础价格，实际出售价格和级别、成长度相关
@export var base_price: float = 1.0
## 是否可以拖拽移动
@export var can_drag: bool = true
## 是否显示StyleBox
@export var show_style_box: bool = true
## tooltip的文本
@export var tooltips: String = ""

@export_group("Display Settings")
## 物品图标（有些物品可以单独图标贴图，默认为空，为空时程序自动获取texture的当前frame对应的贴图）
@export var icon: Texture2D
##  方向，默认0,竖直方向
@export var orientation: ORI = ORI.VER
## 物品占的列数（占用格子的宽）
@export var columns: int = 1
## 物品占的行数（占用格子的高）
@export var rows: int = 1
##  动画贴图相关信息（放置后，非仓库状态下动画）
@export_group("Texture & Aimate")
##  动画帧默认序列帧贴图
@export var texture: Texture2D
##  动画帧的第二形态
@export var pupa_texture: Texture2D
##  动画帧的第三形态
@export var adult_texture: Texture2D
##  动画帧的第四形态
@export var old_texture: Texture2D
## 额外贴图,居中绘制（默认为空，不随旋转而变化；不支持旋转，不支持缩放；给不能拖到物体准备的）
@export var extra_texture: Texture2D = null
## 额外贴图偏移量（和底图的偏移，假如需要的话）
@export var extra_offset: Vector2 = Vector2.ZERO
##  动画帧设置
@export var hframes: int = 1
@export var vframes: int = 1
##  当前帧序号
@export var frame: int = 0


## 国际化时对存储的 nickname 进行翻译
func get_translated_name() -> String:
	return tr(nickname)


## 国际化时对存储的 descrip 进行翻译
func get_translated_desp() -> String:
	return tr(descrip)


## 获取货品形状
## @param is_slot:是否是单格背包
func get_shape(is_slot: bool = false) -> Vector2i:
	if is_slot:
		return Vector2i.ONE

	if orientation == ORI.HOR:
		return Vector2i(get_rows(), get_columns())
	else:
		return Vector2i(get_columns(), get_rows())


## 获取物品占用的列数（如果列数是动态变化的请在外部重写）
func get_columns() -> int:
	return columns


## 获取物品占用的行数（如果行数是动态变化的请在外部重写）
func get_rows() -> int:
	return rows


## 获取当前动画贴图（如果贴图是动态变化的请在外部重写）
## 比如季节变化，成长变化
func get_texture() -> Texture2D:
	return texture


## 获得额外贴图（如果贴图是动态变化的请在外部重写）
## 比如季节变化，成长变化
func get_extra_texture() -> Texture2D:
	return extra_texture


func can_drop() -> bool:
	push_warning("[Override this function] check if the item [%s] can drop" % item_id)
	return true


## 丢弃物品时调用，需重写
func drop() -> void:
	push_warning("[Override this function] item [%s] dropped" % item_id)


## 物品是否能出售（是否贵重物品等）
func can_sell() -> bool:
	push_warning("[Override this function] check if the item [%s] can be sell" % item_id)
	return true


## 物品是否能购买（检查资源是否足够等）
func can_buy(item_to_buy: BaseItemData) -> bool:
	push_warning("[Override this function] check if the item [%s] can be bought" % item_to_buy.item_id)
	return true


## 购买后扣除资源
func cost(item_to_buy: BaseItemData) -> void:
	push_warning("[Override this function] [%s] cost resource" % item_to_buy.item_id)


## 出售后增加资源
func sold() -> void:
	push_warning("[Override this function] [%s] add resource" % item_id)


## 检测装备是否可用，需重写
func test_need(slot_name: String) -> bool:
	push_warning("[Override this function] [%s]:[%s] Equipment slot test passed." % [MGIS.current_player, slot_name])
	return true


## 装备时调用，需重写；也可以使用 MGIS.sig_slot_item_equipped 信号行处理
func equipped(slot_name: String) -> void:
	push_warning("[Override this function] [%s] equipped item [%s] at slot [%s]" % [MGIS.current_player, item_id, slot_name])


## 脱装备时调用，需重写；也可以用 MGIS.sig_slot_item_unequipped 信号进行处理
func unequipped(slot_name: String) -> void:
	push_warning("[Override this function] [%s] unequipped item [%s] at slot [%s]" % [MGIS.current_player, item_id, slot_name])


## 虚函数：格式化tooltips的文本
func formatter_tooltip() -> void:
	push_warning("[Override this function] [%s] format the tooltip text" % item_id)


## 购买并添加到背包
## @param item_to_buy: 已经设置好购买数量的物品副本
func buy(item_to_buy: BaseItemData) -> bool:
	# 检查金钱
	if not can_buy(item_to_buy):
		return false
	for target_inv: String in MGIS.current_inventories:
		var container_view: BaseContainerView = MGIS.get_container_view(target_inv)
		# 注意：item_to_buy 应该已经在 ShopService 中完成了 duplicate()
		if MGIS.inventory_service.add_item(target_inv, item_to_buy, false, container_view.is_slot):
			# 扣费
			cost(item_to_buy)
			return true
	return false
