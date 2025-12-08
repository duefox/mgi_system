## 地图生成的地形资源类
extends StackableData
class_name TerrainData

## 地形枚举
enum Terrains {
	NONE,  # 空地
	# 大型地形
	MOON_LAKE,  # 月溪湖
	WET_LAND,  # 枯木湿地
	COLOR_ISLAND,  #彩贝礁
	HOT_RIFT,  # 热泉裂谷
	GROTTO,  # 地底溶洞
	SULPHUR_RIDGE,  # 硫磺山脊
	HIGH_FOREST,  # 高山云林
	THUNDER_PEAK,  # 雷鸣峰
	# 小型地形的基础资源
	WOOD,  # 水杉木
	SOIL,  # 腐质泥土
	CORAL,  # 海藻珊瑚
	ROCK,  # 沉积岩
	STONE,  # 石块
	SULPHUR,  # 硫磺
	FEATHER,  # 羽毛
	THUNDER_CRYSTAL,  # 碎雷晶
	OTHERS,  # 其他类型
}
## 升级花费类型
enum UpgradeType { NONE, GOLD, MATERIAL, BOTH }

## 地形权重
@export var generate_weight: int
## 地形
@export var terrain_type: Terrains = Terrains.NONE
## 体型大小（big：升级能获得buffer；middle：特定建筑，不获的buffer但有特定增益；small：地面直接可以拾取的物品）
@export var body_size: BodySize = BodySize.SMALL
## 是否可以拆除
@export var can_delete: bool = true
## buffer辐射半径
@export var radius: int = 0
## 主要产出数组，值是材料的物品id
@export var output_items: Array[String] = []
## 升级对应获得buffer的id数组集合
@export var output_buffer: Array[String] = []
## 升级类型
@export var upgrade_type: UpgradeType = UpgradeType.BOTH
## 升级对应需要的材料id列表
@export var upgrade_materials: Array[Dictionary] = [
	{"id": "", "level": 0, "count": 5},
	{"id": "", "level": 0, "count": 1},
	{"id": "", "level": 1, "count": 5},
	{"id": "", "level": 1, "count": 1},
	{"id": "", "level": 2, "count": 5},
	{"id": "", "level": 2, "count": 1},
]
## 升级费用
@export var upgrade_costs: Array = [1000, 2000, 5000]
## 描述补充主要产出
@export var output_desc: String = ""
