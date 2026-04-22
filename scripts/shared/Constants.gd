extends Node

# 全局常量 - 客户端和服务端共享

# 飞船状态枚举
enum ShipStatus {
	DOCKED,
	IN_TRANSIT,
	WORKING,
	STRANDED
}

const SHIP_STATUS_NAMES = {
	"docked": "停泊",
	"in_transit": "航行中",
	"working": "作业中",
	"stranded": "抛锚"
}

# 资源类型
const RESOURCE_TYPES = ["钛", "精炼钛", "铱", "精炼铱", "暗面废料"]

# 槽位名称
const SLOT_NAMES = {
	"nose": "舰头",
	"wings": "舰翼",
	"hull": "舰身",
	"tail": "舰尾",
	"core": "能源",
	"cabin": "舰仓"
}

# 前缀名称
const PREFIX_NAMES = {
	"none": "无",
	"ironclad": "[铁骑]",
	"macula": "[光斑]",
	"singularity": "[奇点]"
}

# 危险度颜色（UI 用）
const DANGER_COLORS = {
	0: Color(0.5, 1.0, 0.5),   # 绿色
	1: Color(0.8, 1.0, 0.3),   # 黄绿
	2: Color(1.0, 0.9, 0.2),   # 黄色
	3: Color(1.0, 0.6, 0.1),   # 橙色
	4: Color(1.0, 0.3, 0.1),   # 红橙
	5: Color(1.0, 0.1, 0.1),   # 红色
}

# 电力颜色阈值
const POWER_COLOR_HIGH = Color(0.2, 0.8, 0.2)   # 绿色 > 50%
const POWER_COLOR_MID = Color(1.0, 0.8, 0.0)    # 黄色 20-50%
const POWER_COLOR_LOW = Color(1.0, 0.2, 0.2)    # 红色 < 20%

# 距离耗电系数
const POWER_PER_DISTANCE = 10
# 航行基础时间（分钟/距离单位）
const MINUTES_PER_DISTANCE = 2
# 电网充电速率（电力/分钟）
const GRID_CHARGE_RATE = 10
