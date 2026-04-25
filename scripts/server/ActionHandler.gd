class_name ActionHandler
extends Node

# 玩家操作处理器 - 处理所有客户端指令

# 组件配置（从 CSV 加载，此处内联核心数据用于服务端校验）
# 格式: component_id -> {slot_allowlist, cost, p_cost, dps, shield, def, spd, mining_rate, power_cap, prefix}
const COMPONENT_DATA = {
	# 武器
	"WPN-T1-001": {"name": "通用突击机炮", "slots": ["nose","wings"], "cost": 2, "p_cost": 0, "dps": 35, "prefix": "none"},
	"WPN-T1-002": {"name": "撕裂者重机枪", "slots": ["nose","wings"], "cost": 2, "p_cost": 0, "dps": 45, "prefix": "ironclad"},
	"WPN-T1-003": {"name": "聚能脉冲器", "slots": ["nose","wings"], "cost": 2, "p_cost": 25, "dps": 60, "prefix": "macula"},
	"WPN-T2-001": {"name": "贫铀穿甲自动炮", "slots": ["nose","wings"], "cost": 4, "p_cost": 0, "dps": 110, "prefix": "none"},
	"WPN-T2-002": {"name": "洛伦兹加速枪", "slots": ["nose","wings"], "cost": 4, "p_cost": 80, "dps": 170, "prefix": "singularity"},
	"WPN-T3-001": {"name": "重型质量投射器", "slots": ["nose"], "cost": 7, "p_cost": 0, "dps": 320, "prefix": "none"},
	"WPN-T3-002": {"name": "伽马射线矛", "slots": ["nose"], "cost": 7, "p_cost": 120, "dps": 420, "prefix": "macula"},
	"WPN-T3-003": {"name": "空间裂隙发生器", "slots": ["nose"], "cost": 8, "p_cost": 300, "dps": 600, "prefix": "singularity"},
	# 矿机
	"MIN-T1-001": {"name": "小行星物理钻头", "slots": ["nose","wings"], "cost": 2, "p_cost": 0, "mining_rate": 25, "prefix": "none"},
	"MIN-T1-002": {"name": "轰击式采掘器", "slots": ["nose","wings"], "cost": 2, "p_cost": 0, "mining_rate": 35, "prefix": "ironclad"},
	"MIN-T2-001": {"name": "重型地幔粉碎阵列", "slots": ["nose","wings"], "cost": 4, "p_cost": 0, "mining_rate": 90, "prefix": "none"},
	"MIN-T2-002": {"name": "地核剥离光束", "slots": ["nose","wings"], "cost": 4, "p_cost": 40, "mining_rate": 120, "prefix": "macula"},
	"MIN-T3-001": {"name": "碎星者工业阵列", "slots": ["nose"], "cost": 7, "p_cost": 0, "mining_rate": 320, "prefix": "ironclad"},
	"MIN-T3-002": {"name": "暗物质泵浦", "slots": ["nose"], "cost": 8, "p_cost": 200, "mining_rate": 500, "prefix": "singularity"},
	# 护盾/护甲
	"SRV-T1-001": {"name": "碳纤维复合装甲", "slots": ["hull"], "cost": 2, "p_cost": 0, "def": 15, "prefix": "none"},
	"SRV-T1-002": {"name": "民用偏导力场", "slots": ["hull"], "cost": 3, "p_cost": 10, "shield": 300, "prefix": "none"},
	"SRV-T2-001": {"name": "相位折射护盾", "slots": ["hull"], "cost": 5, "p_cost": 30, "shield": 1000, "prefix": "none"},
	"SRV-T3-001": {"name": "强相互作用力外壳", "slots": ["hull"], "cost": 7, "p_cost": 0, "def": 120, "prefix": "none"},
	"SRV-T3-002": {"name": "多维时空曲面屏障", "slots": ["hull"], "cost": 8, "p_cost": 100, "shield": 3000, "prefix": "none"},
	# 引擎
	"ENG-T1-001": {"name": "化学工质推进器", "slots": ["tail"], "cost": 2, "p_cost": 0, "spd": 20, "prefix": "none"},
	"ENG-T3-001": {"name": "空间曲率折叠引擎", "slots": ["tail"], "cost": 7, "p_cost": 0, "spd": 250, "prefix": "none"},
	# 反应堆
	"CORE-T1-001": {"name": "裂变反应堆", "slots": ["core"], "cost": 2, "p_cost": 0, "fuel_ratio": 10, "prefix": "none"},
	"CORE-T2-001": {"name": "托卡马克聚变芯", "slots": ["core"], "cost": 4, "p_cost": 0, "fuel_ratio": 20, "prefix": "none"},
	# 电池/太阳能
	"BAT-T1-001": {"name": "标准蓄电池组", "slots": ["cabin"], "cost": 2, "p_cost": 0, "power_cap": 300, "prefix": "none"},
	"BAT-T3-001": {"name": "暗物质微型电容", "slots": ["cabin"], "cost": 6, "p_cost": 0, "power_cap": 3500, "prefix": "none"},
	"SOL-T1-001": {"name": "展开式光伏薄膜", "slots": ["cabin"], "cost": 4, "p_cost": 0, "solar_rate": 150, "prefix": "none"},
	"SOL-T3-001": {"name": "戴森球碎片结构", "slots": ["cabin"], "cost": 8, "p_cost": 0, "solar_rate": 1200, "prefix": "none"},
	# 货舱
	"CGO-T1-001": {"name": "标准模块化货舱", "slots": ["cabin"], "cost": 2, "p_cost": 0, "cargo_cap": 80, "prefix": "none"},
	"CGO-T1-002": {"name": "铆钉式加固货舱", "slots": ["cabin"], "cost": 2, "p_cost": 0, "cargo_cap": 100, "prefix": "ironclad"},
	"CGO-T2-001": {"name": "密封低温货舱", "slots": ["cabin"], "cost": 4, "p_cost": 0, "cargo_cap": 180, "prefix": "none"},
	"CGO-T2-002": {"name": "相位折叠货舱", "slots": ["cabin"], "cost": 4, "p_cost": 10, "cargo_cap": 240, "prefix": "macula"},
	"CGO-T3-001": {"name": "维度跃迁货舱", "slots": ["cabin"], "cost": 7, "p_cost": 30, "cargo_cap": 500, "prefix": "none"},
}

# POI 资源产出配置（资源类型列表，第一个为主产出，多个时按权重随机）
# 格式: poi_id -> [resource_type, ...]  权重均等，多个相同条目提高概率
const POI_RESOURCES = {
	# 天鹅座
	"CYG-SS-01": [],          # 空间站，无采矿
	"CYG-SS-02": [],
	"CYG-SS-03": [],
	"CYG-PL-01": ["钛", "钛", "钛"],                        # 塔洛斯碎石星：纯钛
	"CYG-PL-02": ["钛", "钛"],                              # 西风-7：钛（气态巨星，低产）
	"CYG-MO-01": ["钛"],                                    # 灰烬卫星：钛
	"CYG-AS-01": ["钛", "钛", "暗面废料"],                  # 碎石带：钛为主，少量废料
	"CYG-RU-01": ["暗面废料", "暗面废料"],                  # 船坟：废料
	"CYG-RU-02": ["精炼钛", "暗面废料"],                    # 精炼厂废墟：精炼钛+废料
	"CYG-ST-01": ["精炼钛", "精炼钛", "精炼钛"],            # X-1白矮星：高危高回报精炼钛
	# 猎户座
	"ORI-SS-01": [],
	"ORI-SS-02": [],
	"ORI-SS-03": [],
	"ORI-PL-01": ["铱", "铱", "铱"],                        # 赫菲斯托斯：铱
	"ORI-PL-02": ["铱", "铱"],                              # 翠绿-Sigma：铱
	"ORI-PL-03": ["铱", "铱", "铱"],                        # 卡拉克沙海：铱
	"ORI-MO-01": ["铱"],                                    # 欧罗巴冰卫：铱
	"ORI-AS-01": ["铱", "暗面废料"],                        # 战备封锁线：铱+废料
	"ORI-RU-01": ["暗面废料", "暗面废料", "暗面废料"],      # 奥林匹斯残骸：废料
	"ORI-RU-02": ["精炼铱", "精炼铱"],                      # 方尖碑遗址：精炼铱
	"ORI-ST-01": ["精炼铱", "精炼铱", "精炼铱"],            # 参宿七蓝巨星：精炼铱
	"ORI-ST-02": ["铱"],                                    # 余烬红矮星：铱（低光照）
}

# 骨架容量上限（T1默认值）
const SKELETON_CAPACITY = {
	"nose": 8, "wings": 8, "hull": 10, "tail": 6, "core": 6, "cabin": 8
}

# POI 距离矩阵（天鹅座 10×10 + 猎户座 12×12，来自 map.md）
# 矩阵对称，_get_distance() 会自动双向查找
const DISTANCE_MATRIX = {
	# 天鹅座（CYG）
	"CYG-SS-01": {
		"CYG-SS-02": 35, "CYG-SS-03": 25, "CYG-PL-01": 8,  "CYG-PL-02": 22,
		"CYG-MO-01": 10, "CYG-AS-01": 15, "CYG-RU-01": 28, "CYG-RU-02": 18, "CYG-ST-01": 45
	},
	"CYG-SS-02": {
		"CYG-SS-01": 35, "CYG-SS-03": 30, "CYG-PL-01": 28, "CYG-PL-02": 12,
		"CYG-MO-01": 30, "CYG-AS-01": 25, "CYG-RU-01": 40, "CYG-RU-02": 32, "CYG-ST-01": 38
	},
	"CYG-SS-03": {
		"CYG-SS-01": 25, "CYG-SS-02": 30, "CYG-PL-01": 22, "CYG-PL-02": 26,
		"CYG-MO-01": 24, "CYG-AS-01": 18, "CYG-RU-01": 12, "CYG-RU-02": 20, "CYG-ST-01": 50
	},
	"CYG-PL-01": {
		"CYG-SS-01": 8,  "CYG-SS-02": 28, "CYG-SS-03": 22, "CYG-PL-02": 18,
		"CYG-MO-01": 3,  "CYG-AS-01": 10, "CYG-RU-01": 25, "CYG-RU-02": 15, "CYG-ST-01": 40
	},
	"CYG-PL-02": {
		"CYG-SS-01": 22, "CYG-SS-02": 12, "CYG-SS-03": 26, "CYG-PL-01": 18,
		"CYG-MO-01": 20, "CYG-AS-01": 22, "CYG-RU-01": 35, "CYG-RU-02": 28, "CYG-ST-01": 35
	},
	"CYG-MO-01": {
		"CYG-SS-01": 10, "CYG-SS-02": 30, "CYG-SS-03": 24, "CYG-PL-01": 3,  "CYG-PL-02": 20,
		"CYG-AS-01": 12, "CYG-RU-01": 26, "CYG-RU-02": 16, "CYG-ST-01": 42
	},
	"CYG-AS-01": {
		"CYG-SS-01": 15, "CYG-SS-02": 25, "CYG-SS-03": 18, "CYG-PL-01": 10, "CYG-PL-02": 22,
		"CYG-MO-01": 12, "CYG-RU-01": 20, "CYG-RU-02": 12, "CYG-ST-01": 38
	},
	"CYG-RU-01": {
		"CYG-SS-01": 28, "CYG-SS-02": 40, "CYG-SS-03": 12, "CYG-PL-01": 25, "CYG-PL-02": 35,
		"CYG-MO-01": 26, "CYG-AS-01": 20, "CYG-RU-02": 25, "CYG-ST-01": 55
	},
	"CYG-RU-02": {
		"CYG-SS-01": 18, "CYG-SS-02": 32, "CYG-SS-03": 20, "CYG-PL-01": 15, "CYG-PL-02": 28,
		"CYG-MO-01": 16, "CYG-AS-01": 12, "CYG-RU-01": 25, "CYG-ST-01": 46
	},
	"CYG-ST-01": {
		"CYG-SS-01": 45, "CYG-SS-02": 38, "CYG-SS-03": 50, "CYG-PL-01": 40, "CYG-PL-02": 35,
		"CYG-MO-01": 42, "CYG-AS-01": 38, "CYG-RU-01": 55, "CYG-RU-02": 46
	},
	# 猎户座（ORI）
	"ORI-SS-01": {
		"ORI-SS-02": 70, "ORI-SS-03": 35, "ORI-PL-01": 18, "ORI-PL-02": 45, "ORI-PL-03": 12,
		"ORI-MO-01": 48, "ORI-AS-01": 25, "ORI-RU-01": 40, "ORI-RU-02": 55, "ORI-ST-01": 80, "ORI-ST-02": 65
	},
	"ORI-SS-02": {
		"ORI-SS-01": 70, "ORI-SS-03": 40, "ORI-PL-01": 55, "ORI-PL-02": 22, "ORI-PL-03": 65,
		"ORI-MO-01": 15, "ORI-AS-01": 35, "ORI-RU-01": 50, "ORI-RU-02": 45, "ORI-ST-01": 25, "ORI-ST-02": 75
	},
	"ORI-SS-03": {
		"ORI-SS-01": 35, "ORI-SS-02": 40, "ORI-PL-01": 28, "ORI-PL-02": 32, "ORI-PL-03": 38,
		"ORI-MO-01": 35, "ORI-AS-01": 15, "ORI-RU-01": 20, "ORI-RU-02": 30, "ORI-ST-01": 55, "ORI-ST-02": 45
	},
	"ORI-PL-01": {
		"ORI-SS-01": 18, "ORI-SS-02": 55, "ORI-SS-03": 28, "ORI-PL-02": 38, "ORI-PL-03": 22,
		"ORI-MO-01": 42, "ORI-AS-01": 20, "ORI-RU-01": 35, "ORI-RU-02": 48, "ORI-ST-01": 70, "ORI-ST-02": 55
	},
	"ORI-PL-02": {
		"ORI-SS-01": 45, "ORI-SS-02": 22, "ORI-SS-03": 32, "ORI-PL-01": 38, "ORI-PL-03": 50,
		"ORI-MO-01": 4,  "ORI-AS-01": 28, "ORI-RU-01": 42, "ORI-RU-02": 35, "ORI-ST-01": 40, "ORI-ST-02": 60
	},
	"ORI-PL-03": {
		"ORI-SS-01": 12, "ORI-SS-02": 65, "ORI-SS-03": 38, "ORI-PL-01": 22, "ORI-PL-02": 50,
		"ORI-MO-01": 52, "ORI-AS-01": 30, "ORI-RU-01": 45, "ORI-RU-02": 60, "ORI-ST-01": 75, "ORI-ST-02": 68
	},
	"ORI-MO-01": {
		"ORI-SS-01": 48, "ORI-SS-02": 15, "ORI-SS-03": 35, "ORI-PL-01": 42, "ORI-PL-02": 4,  "ORI-PL-03": 52,
		"ORI-AS-01": 32, "ORI-RU-01": 46, "ORI-RU-02": 38, "ORI-ST-01": 38, "ORI-ST-02": 62
	},
	"ORI-AS-01": {
		"ORI-SS-01": 25, "ORI-SS-02": 35, "ORI-SS-03": 15, "ORI-PL-01": 20, "ORI-PL-02": 28, "ORI-PL-03": 30,
		"ORI-MO-01": 32, "ORI-RU-01": 18, "ORI-RU-02": 35, "ORI-ST-01": 50, "ORI-ST-02": 48
	},
	"ORI-RU-01": {
		"ORI-SS-01": 40, "ORI-SS-02": 50, "ORI-SS-03": 20, "ORI-PL-01": 35, "ORI-PL-02": 42, "ORI-PL-03": 45,
		"ORI-MO-01": 46, "ORI-AS-01": 18, "ORI-RU-02": 25, "ORI-ST-01": 65, "ORI-ST-02": 35
	},
	"ORI-RU-02": {
		"ORI-SS-01": 55, "ORI-SS-02": 45, "ORI-SS-03": 30, "ORI-PL-01": 48, "ORI-PL-02": 35, "ORI-PL-03": 60,
		"ORI-MO-01": 38, "ORI-AS-01": 35, "ORI-RU-01": 25, "ORI-ST-01": 55, "ORI-ST-02": 15
	},
	"ORI-ST-01": {
		"ORI-SS-01": 80, "ORI-SS-02": 25, "ORI-SS-03": 55, "ORI-PL-01": 70, "ORI-PL-02": 40, "ORI-PL-03": 75,
		"ORI-MO-01": 38, "ORI-AS-01": 50, "ORI-RU-01": 65, "ORI-RU-02": 55, "ORI-ST-02": 85
	},
	"ORI-ST-02": {
		"ORI-SS-01": 65, "ORI-SS-02": 75, "ORI-SS-03": 45, "ORI-PL-01": 55, "ORI-PL-02": 60, "ORI-PL-03": 68,
		"ORI-MO-01": 62, "ORI-AS-01": 48, "ORI-RU-01": 35, "ORI-RU-02": 15, "ORI-ST-01": 85
	},
}

# POI 危险度
const POI_DANGER = {
	# 天鹅座
	"CYG-SS-01": 0, "CYG-SS-02": 1, "CYG-SS-03": 2,
	"CYG-PL-01": 1, "CYG-PL-02": 2, "CYG-MO-01": 0,
	"CYG-AS-01": 3, "CYG-RU-01": 4, "CYG-RU-02": 4, "CYG-ST-01": 5,
	# 猎户座
	"ORI-SS-01": 1, "ORI-SS-02": 1, "ORI-SS-03": 2,
	"ORI-PL-01": 4, "ORI-PL-02": 4, "ORI-PL-03": 3,
	"ORI-MO-01": 3, "ORI-AS-01": 4, "ORI-RU-01": 4, "ORI-RU-02": 5,
	"ORI-ST-01": 5, "ORI-ST-02": 2,
}

# POI 基本信息（名称、是否为空间站、光照强度）
const POI_INFO = {
	"CYG-SS-01": {"name": "铁砧-IV 采掘前哨", "is_station": true,  "light": "mid"},
	"CYG-SS-02": {"name": "折光 科考平台",     "is_station": true,  "light": "mid"},
	"CYG-SS-03": {"name": "锈蚀深渊 走私港",   "is_station": true,  "light": "low"},
	"CYG-PL-01": {"name": "塔洛斯 碎石星",     "is_station": false, "light": "mid"},
	"CYG-PL-02": {"name": "西风-7 气态巨星",   "is_station": false, "light": "high"},
	"CYG-MO-01": {"name": "灰烬 T-09",         "is_station": false, "light": "mid"},
	"CYG-AS-01": {"name": "阿尔法碎石带",       "is_station": false, "light": "mid"},
	"CYG-RU-01": {"name": "第17号船坟地带",     "is_station": false, "light": "low"},
	"CYG-RU-02": {"name": "废弃同位素精炼厂",   "is_station": false, "light": "low"},
	"CYG-ST-01": {"name": "天鹅座 X-1 白矮星", "is_station": false, "light": "extreme"},
	"ORI-SS-01": {"name": "无畏堡垒 星港",      "is_station": true,  "light": "mid"},
	"ORI-SS-02": {"name": "耀斑枢纽 星港",      "is_station": true,  "light": "mid"},
	"ORI-SS-03": {"name": "折射点 自由港",      "is_station": true,  "light": "low"},
	"ORI-PL-01": {"name": "赫菲斯托斯 燃烧星", "is_station": false, "light": "high"},
	"ORI-PL-02": {"name": "翠绿-Sigma 生态星", "is_station": false, "light": "mid"},
	"ORI-PL-03": {"name": "卡拉克 沙海星",     "is_station": false, "light": "high"},
	"ORI-MO-01": {"name": "欧罗巴二型 冰卫",   "is_station": false, "light": "low"},
	"ORI-AS-01": {"name": "柯伊伯战备封锁线",   "is_station": false, "light": "mid"},
	"ORI-RU-01": {"name": "奥林匹斯 战舰残骸带","is_station": false, "light": "low"},
	"ORI-RU-02": {"name": "远古方尖碑遗址",     "is_station": false, "light": "low"},
	"ORI-ST-01": {"name": "参宿七 狂暴蓝巨星", "is_station": false, "light": "extreme"},
	"ORI-ST-02": {"name": "余烬-9 红矮星",     "is_station": false, "light": "low"},
}

static func handle_depart(peer_id: int, player: Dictionary, payload: Dictionary, db: DatabaseManager, server: Node) -> void:
	var ship = player.get("ship", {})
	var status = ship.get("status", "docked")

	if status != "docked":
		server.send_to_peer(peer_id, {"type": "error", "message": "飞船当前状态不允许起飞：" + status})
		return

	var target_poi: String = payload.get("target_poi", "")
	if target_poi == "":
		server.send_to_peer(peer_id, {"type": "error", "message": "请指定目标 POI"})
		return

	var current_poi: String = ship.get("current_poi", "")

	# 计算距离
	var distance = _get_distance(current_poi, target_poi)
	if distance <= 0:
		server.send_to_peer(peer_id, {"type": "error", "message": "无法计算航行距离"})
		return

	# 计算耗电（含奇点4件-50%、节能调度-15%）
	var p_cost_total = _calc_p_cost(player)
	var base_dist_cost = distance * 10
	# 奇点4件：组件耗电-50%
	if _count_prefix(player, "singularity") >= 4:
		p_cost_total = int(p_cost_total * 0.5)
	# 节能调度（轮机长T1）：基础距离耗电-15%
	if _has_trait(player, "engineer_t1_efficient"):
		base_dist_cost = int(base_dist_cost * 0.85)
	var total_power_cost = base_dist_cost + p_cost_total

	# 奇点2件：电力上限+500（影响 max_power，起飞前更新）
	if _count_prefix(player, "singularity") >= 2:
		ship["max_power"] = ship.get("max_power", 500) + 500

	# 检查电力是否足够
	var current_power = ship.get("power", 0)
	if current_power < total_power_cost:
		server.send_to_peer(peer_id, {
			"type": "error",
			"message": "电力不足！需要 %d，当前 %d" % [total_power_cost, current_power]
		})
		return

	# 计算航行时间
	var spd = _calc_ship_spd(player)
	# 护盾极客（轮机长T2）：无护盾时SPD翻倍（影响航行速度）
	if _has_trait(player, "engineer_t2_shield_geek") and ship.get("shield", 0) == 0:
		spd *= 2
	var base_minutes = distance * 2.0
	var spd_reduction = float(spd) / (float(spd) + 200.0)
	var travel_minutes = base_minutes * (1.0 - spd_reduction)
	travel_minutes = max(1.0, travel_minutes)

	var now = Time.get_unix_time_from_system()
	var eta = now + travel_minutes * 60.0

	# 更新飞船状态
	ship["status"] = "in_transit"
	ship["target_poi"] = target_poi
	ship["depart_time"] = now
	ship["eta"] = eta
	ship["total_power_cost"] = total_power_cost
	ship["power_used_so_far"] = 0
	ship["travel_distance"] = distance
	ship["last_encounter_dist"] = 0.0
	ship["target_danger"] = POI_DANGER.get(target_poi, 0)
	ship["grid_connected"] = false
	ship["last_grid_tick"] = 0.0

	# 绑定目标 POI 的采矿资源类型（随机选一种，抵达后生效）
	var res_pool = POI_RESOURCES.get(target_poi, [])
	if res_pool.size() > 0:
		ship["mining_resource"] = res_pool[randi() % res_pool.size()]
	else:
		ship["mining_resource"] = ""

	# 计算采矿速率（累加所有矿机组件）
	var total_mining_rate: float = 0.0
	for comp_id in player.get("components", {}).keys():
		total_mining_rate += COMPONENT_DATA.get(comp_id, {}).get("mining_rate", 0)
	# 铁骑4件：矿机产出+30%
	if _count_prefix(player, "ironclad") >= 4:
		total_mining_rate *= 1.30
	ship["mining_rate"] = total_mining_rate

	db.save_ship(ship)

	server.send_to_peer(peer_id, {
		"type": "action_result",
		"action": "depart",
		"success": true,
		"payload": {
			"target_poi": target_poi,
			"eta": eta,
			"eta_minutes": int(travel_minutes),
			"total_power_cost": total_power_cost,
			"distance": distance
		}
	})

static func handle_dock(peer_id: int, player: Dictionary, _payload: Dictionary, db: DatabaseManager, server: Node) -> void:
	var ship = player.get("ship", {})
	if ship.get("status", "") != "working":
		server.send_to_peer(peer_id, {"type": "error", "message": "只有作业中状态才能停泊"})
		return

	ship["status"] = "docked"
	db.save_ship(ship)
	server.send_to_peer(peer_id, {"type": "action_result", "action": "dock", "success": true})

static func handle_equip(peer_id: int, player: Dictionary, payload: Dictionary, db: DatabaseManager, server: Node) -> void:
	var ship = player.get("ship", {})
	if ship.get("status", "") != "docked":
		server.send_to_peer(peer_id, {"type": "error", "message": "只能在停泊状态装配组件"})
		return

	var component_id: String = payload.get("component_id", "")
	var slot: String = payload.get("slot", "")

	if not COMPONENT_DATA.has(component_id):
		server.send_to_peer(peer_id, {"type": "error", "message": "未知组件: " + component_id})
		return

	var comp = COMPONENT_DATA[component_id]

	# 检查槽位匹配
	if slot not in comp["slots"]:
		server.send_to_peer(peer_id, {"type": "error", "message": "组件不能安装在 %s 槽位" % slot})
		return

	# 检查仓库中是否有该组件
	var inventory = player.get("inventory", {})
	if inventory.get(component_id, 0) <= 0:
		server.send_to_peer(peer_id, {"type": "error", "message": "仓库中没有该组件"})
		return

	# 检查容量
	var components = player.get("components", {})
	var slot_components = []
	for s_comp_id in components.keys():
		if components[s_comp_id] == slot:  # 同槽位的组件
			slot_components.append(s_comp_id)

	var current_cost = 0
	for s_comp_id in slot_components:
		current_cost += COMPONENT_DATA.get(s_comp_id, {}).get("cost", 0)

	var cap_max = SKELETON_CAPACITY.get(slot, 8)
	if current_cost + comp["cost"] > cap_max:
		server.send_to_peer(peer_id, {"type": "error", "message": "容量不足！当前 %d/%d，需要 %d" % [current_cost, cap_max, comp["cost"]]})
		return

	# 装配
	var player_id = player.get("player_id", 0)
	components[component_id] = slot
	player["components"] = components
	inventory[component_id] = max(0, inventory.get(component_id, 1) - 1)
	if inventory[component_id] <= 0:
		inventory.erase(component_id)
	player["inventory"] = inventory

	db.install_component(player_id, slot, component_id)
	db.adjust_inventory(player_id, component_id, -1)

	server.send_to_peer(peer_id, {"type": "action_result", "action": "equip", "success": true, "component_id": component_id, "slot": slot})

static func handle_unequip(peer_id: int, player: Dictionary, payload: Dictionary, db: DatabaseManager, server: Node) -> void:
	var ship = player.get("ship", {})
	if ship.get("status", "") != "docked":
		server.send_to_peer(peer_id, {"type": "error", "message": "只能在停泊状态卸载组件"})
		return

	var component_id: String = payload.get("component_id", "")
	var components = player.get("components", {})

	if not components.has(component_id):
		server.send_to_peer(peer_id, {"type": "error", "message": "该组件未安装"})
		return

	var player_id = player.get("player_id", 0)
	components.erase(component_id)
	player["components"] = components

	var inventory = player.get("inventory", {})
	inventory[component_id] = inventory.get(component_id, 0) + 1
	player["inventory"] = inventory

	db.remove_component(player_id, component_id)
	db.adjust_inventory(player_id, component_id, 1)

	server.send_to_peer(peer_id, {"type": "action_result", "action": "unequip", "success": true, "component_id": component_id})

static func handle_accept_mission(peer_id: int, player: Dictionary, payload: Dictionary, db: DatabaseManager, server: Node) -> void:
	var mission_id: String = payload.get("mission_id", "")
	var now = Time.get_unix_time_from_system()

	# 检查任务配置是否存在
	var config = MissionManager.MISSION_CONFIG.get(mission_id, {})
	if config.is_empty():
		server.send_to_peer(peer_id, {"type": "error", "message": "未知任务：" + mission_id})
		return

	# 检查任务是否已在进行中（已完成/失败的可重接）
	for m in player.get("missions", []):
		if m.get("mission_id") == mission_id and m.get("status") == "active":
			server.send_to_peer(peer_id, {"type": "error", "message": "该任务正在进行中"})
			return

	var ship = player.get("ship", {})

	# 前置条件校验
	var mission_type = config.get("type", "")
	match mission_type:
		"delivery":
			# 货仓空位：舰仓容量 - 已占用货物数（简化：delivery 任务占用 2 格）
			var cargo_cap = _get_cargo_cap(player)
			var active_deliveries = 0
			for m in player.get("missions", []):
				if m.get("status") == "active":
					var mc = MissionManager.MISSION_CONFIG.get(m.get("mission_id", ""), {})
					if mc.get("type") == "delivery":
						active_deliveries += 1
			var slots_used = active_deliveries * 2
			if cargo_cap - slots_used < 2:
				server.send_to_peer(peer_id, {"type": "error", "message": "舰仓空位不足（需要 2 格空位）"})
				return
		"mining":
			# 必须装配至少 1 个矿机
			var has_miner = false
			for comp_id in player.get("components", {}).keys():
				if comp_id.begins_with("MIN"):
					has_miner = true
					break
			if not has_miner:
				server.send_to_peer(peer_id, {"type": "error", "message": "未装配采矿设备"})
				return

	# 使用配置里的 deadline_hours（忽略客户端传来的，以服务端为准）
	var deadline_hours = config.get("deadline_hours", 24)
	var deadline = now + deadline_hours * 3600.0

	# 如果已有同 mission_id 的旧记录（已完成/失败），更新而非插入
	var existing = false
	for m in player.get("missions", []):
		if m.get("mission_id") == mission_id:
			m["status"] = "active"
			m["accepted_at"] = now
			m["progress"] = 0
			m["deadline"] = deadline
			existing = true
			break

	if not existing:
		player["missions"].append({
			"mission_id": mission_id,
			"status": "active",
			"accepted_at": now,
			"progress": 0,
			"deadline": deadline
		})

	var player_id = player.get("player_id", 0)
	# 先删除旧记录（已完成/失败），再插入新记录
	db._query("DELETE FROM missions WHERE player_id=%d AND mission_id='%s' AND status!='active'" % [
		player_id, mission_id
	])
	db._query("INSERT IGNORE INTO missions (player_id, mission_id, status, accepted_at, progress, deadline) VALUES (%d, '%s', 'active', %f, 0, %f)" % [
		player_id, mission_id, now, deadline
	])

	server.send_to_peer(peer_id, {"type": "action_result", "action": "accept_mission", "success": true, "mission_id": mission_id, "deadline": deadline})

static func handle_buy_fuel(peer_id: int, player: Dictionary, payload: Dictionary, db: DatabaseManager, server: Node) -> void:
	var ship = player.get("ship", {})
	var fuel_amount: int = payload.get("amount", 1)

	# 查找已安装的反应堆
	var fuel_ratio = _get_fuel_ratio(player)
	if fuel_ratio <= 0:
		server.send_to_peer(peer_id, {"type": "error", "message": "飞船未安装反应堆"})
		return

	var power_gain = fuel_amount * fuel_ratio
	var cost_credits = fuel_amount * 10  # 1燃料=10星币

	if ship.get("credits", 0) < cost_credits:
		server.send_to_peer(peer_id, {"type": "error", "message": "星币不足"})
		return

	ship["credits"] = ship.get("credits", 0) - cost_credits
	ship["power"] = min(ship.get("max_power", 500), ship.get("power", 0) + power_gain)
	db.save_ship(ship)

	server.send_to_peer(peer_id, {
		"type": "action_result", "action": "buy_fuel", "success": true,
		"payload": {"power": ship["power"], "credits": ship["credits"]}
	})

static func handle_connect_grid(peer_id: int, player: Dictionary, _payload: Dictionary, db: DatabaseManager, server: Node) -> void:
	var ship = player.get("ship", {})
	if ship.get("status", "") != "docked":
		server.send_to_peer(peer_id, {"type": "error", "message": "只能在停泊状态连接电网"})
		return

	# 检查当前 POI 是否是空间站
	var current_poi = ship.get("current_poi", "")
	if not POI_INFO.get(current_poi, {}).get("is_station", false):
		server.send_to_peer(peer_id, {"type": "error", "message": "只能在空间站连接电网"})
		return

	ship["grid_connected"] = true
	ship["last_grid_tick"] = Time.get_unix_time_from_system()
	db.save_ship(ship)

	server.send_to_peer(peer_id, {
		"type": "action_result", "action": "connect_grid", "success": true,
		"message": "已连接电网，充电速率 10 电力/分钟"
	})

# 船员特性配置表
const CREW_TRAITS = {
	"captain_t1_ironclad": {
		"role": "captain", "tier": "T1", "salary": 50,
		"name": "阵营拥趸-铁骑", "desc": "每有一件[铁骑]前缀组件，防御力+5"
	},
	"captain_t2_lone_wolf": {
		"role": "captain", "tier": "T2", "salary": 150,
		"name": "独狼战术", "desc": "仅1名船员时，全体武器伤害+40%"
	},
	"captain_t3_capitalist": {
		"role": "captain", "tier": "T3", "salary": 500,
		"name": "资本家", "desc": "所有薪水减半，遭遇战星币+30%"
	},
	"gunner_t1_kinetic": {
		"role": "gunner", "tier": "T1", "salary": 50,
		"name": "动能偏执狂", "desc": "[动能]武器伤害+20%，无法装[电磁]武器"
	},
	"gunner_t2_overload": {
		"role": "gunner", "tier": "T2", "salary": 150,
		"name": "过载狂人", "desc": "武器伤害+50%，每次开火自损10HP"
	},
	"gunner_t3_singularity": {
		"role": "gunner", "tier": "T3", "salary": 500,
		"name": "奇点锁定", "desc": "首回合[奇点]武器必暴击且无视闪避"
	},
	"engineer_t1_efficient": {
		"role": "engineer", "tier": "T1", "salary": 50,
		"name": "节能调度", "desc": "航行基础耗电降低15%"
	},
	"engineer_t2_shield_geek": {
		"role": "engineer", "tier": "T2", "salary": 150,
		"name": "护盾极客", "desc": "无护盾组件时，速度(SPD)翻倍"
	},
	"engineer_t3_jump_resonance": {
		"role": "engineer", "tier": "T3", "salary": 500,
		"name": "跃迁引擎共鸣", "desc": "跃迁耗电-500，抛锚时缓慢自动回电"
	},
}

# 招募费用（按品级）
const RECRUIT_COST = {"T1": 300, "T2": 800, "T3": 2500}

# 默认船员名字库（无 AI 时使用）
const DEFAULT_NAMES = {
	"captain": ["钢铁舰长 Rex", "指挥官 Vega", "舰长 Kira", "统帅 Dorn"],
	"gunner":  ["炮手 Zeke", "神枪 Lyra", "爆破手 Ash", "炮兵 Cruz"],
	"engineer":["轮机长 Bolt", "工程师 Nova", "技师 Finn", "机械师 Renn"],
}

static func handle_recruit(peer_id: int, player: Dictionary, payload: Dictionary, db: DatabaseManager, server: Node) -> void:
	var ship = player.get("ship", {})
	# 只能在空间站招募
	var current_poi = ship.get("current_poi", "")
	if not POI_INFO.get(current_poi, {}).get("is_station", false):
		server.send_to_peer(peer_id, {"type": "error", "message": "只能在空间站酒馆招募船员"})
		return

	var role: String = payload.get("role", "")
	var tier: String = payload.get("tier", "T1")

	if role not in ["captain", "gunner", "engineer"]:
		server.send_to_peer(peer_id, {"type": "error", "message": "无效岗位"})
		return

	# 检查该岗位是否已有船员
	for c in player.get("crew", []):
		if c.get("slot") == role:
			server.send_to_peer(peer_id, {"type": "error", "message": "该岗位已有船员，请先解雇"})
			return

	# 检查星币
	var cost = RECRUIT_COST.get(tier, 300)
	if ship.get("credits", 0) < cost:
		server.send_to_peer(peer_id, {"type": "error", "message": "星币不足，需要 %d" % cost})
		return

	# 随机抽取该岗位+品级的特性
	var matching_traits = []
	for trait_id in CREW_TRAITS.keys():
		var t = CREW_TRAITS[trait_id]
		if t["role"] == role and t["tier"] == tier:
			matching_traits.append(trait_id)

	if matching_traits.is_empty():
		server.send_to_peer(peer_id, {"type": "error", "message": "无可用特性"})
		return

	var trait_id = matching_traits[randi() % matching_traits.size()]
	var trait_data = CREW_TRAITS[trait_id]
	var salary = trait_data["salary"]
	var player_id = player.get("player_id", 0)

	# 扣星币（先扣，防止重复招募）
	ship["credits"] -= cost
	db._query("UPDATE ships SET credits=credits-%d WHERE player_id=%d" % [cost, player_id])

	# 角色名称映射
	var role_cn = {"captain": "舰长", "gunner": "炮手", "engineer": "轮机长"}.get(role, role)
	var tier_cn = {"T1": "T1（资深）", "T2": "T2（精英）", "T3": "T3（传奇）"}.get(tier, tier)

	# 尝试用 Gemini 生成人设，失败则用默认随机名
	var gemini: GeminiClient = server.get_gemini() if server.has_method("get_gemini") else null
	if gemini != null:
		gemini.generate_crew(role_cn, tier_cn, trait_data["desc"], func(ai_data):
			var crew_name: String
			var backstory: String = ""
			var catchphrase: String = ""
			if ai_data is Dictionary:
				crew_name = ai_data.get("name", "")
				backstory = ai_data.get("backstory", "")
				catchphrase = ai_data.get("catchphrase", "")
			if crew_name == "":
				var names = DEFAULT_NAMES.get(role, ["未知船员"])
				crew_name = names[randi() % names.size()]
			_finish_recruit(peer_id, player, ship, db, server, role, tier, trait_id, trait_data, crew_name, backstory, catchphrase, salary, cost)
		)
	else:
		var names = DEFAULT_NAMES.get(role, ["未知船员"])
		var crew_name = names[randi() % names.size()]
		_finish_recruit(peer_id, player, ship, db, server, role, tier, trait_id, trait_data, crew_name, "", "", salary, cost)

static func _finish_recruit(peer_id: int, player: Dictionary, ship: Dictionary, db: DatabaseManager, server: Node,
		role: String, tier: String, trait_id: String, trait_data: Dictionary,
		crew_name: String, backstory: String, catchphrase: String, salary: int, cost: int) -> void:
	var player_id = player.get("player_id", 0)
	db._query("INSERT INTO crew (player_id, slot, tier, trait_id, name, backstory, catchphrase, salary, debt) VALUES (%d, '%s', '%s', '%s', '%s', '%s', '%s', %d, 0)" % [
		player_id, role, tier, trait_id,
		db._escape(crew_name), db._escape(backstory), db._escape(catchphrase), salary
	])
	var new_crew = {
		"slot": role, "tier": tier, "trait_id": trait_id,
		"name": crew_name, "backstory": backstory, "catchphrase": catchphrase,
		"salary": salary, "debt": 0
	}
	player["crew"].append(new_crew)
	server.send_to_peer(peer_id, {
		"type": "action_result", "action": "recruit", "success": true,
		"crew": new_crew, "cost": cost, "trait_desc": trait_data["desc"]
	})

static func handle_fire_crew(peer_id: int, player: Dictionary, payload: Dictionary, db: DatabaseManager, server: Node) -> void:
	var role: String = payload.get("role", "")
	var player_id = player.get("player_id", 0)

	var found = false
	var new_crew = []
	for c in player.get("crew", []):
		if c.get("slot") == role:
			found = true
		else:
			new_crew.append(c)

	if not found:
		server.send_to_peer(peer_id, {"type": "error", "message": "该岗位没有船员"})
		return

	player["crew"] = new_crew
	db._query("DELETE FROM crew WHERE player_id=%d AND slot='%s'" % [player_id, role])

	server.send_to_peer(peer_id, {"type": "action_result", "action": "fire_crew", "success": true, "role": role})

static func handle_sos(peer_id: int, player: Dictionary, _payload: Dictionary, _db: DatabaseManager, server: Node) -> void:
	var ship = player.get("ship", {})
	if ship.get("status", "") != "stranded":
		server.send_to_peer(peer_id, {"type": "error", "message": "只有抛锚状态才能发射 SOS 信标"})
		return

	var captain_name = _get_captain_name(player)
	var poi = ship.get("current_poi", "未知位置")
	var poi_name = POI_INFO.get(poi, {}).get("name", poi)

	# 获取舰长背景故事
	var backstory = ""
	for c in player.get("crew", []):
		if c.get("slot") == "captain":
			backstory = c.get("backstory", "")
			break

	var gemini: GeminiClient = server.get_gemini() if server.has_method("get_gemini") else null
	var fallback_text = "[SOS] 舰长「%s」的飞船在【%s】附近失去动力，急需电力支援！" % [captain_name, poi_name]

	# 回复发送者（先发确认）
	server.send_to_peer(peer_id, {
		"type": "action_result", "action": "sos", "success": true
	})

	if gemini != null:
		gemini.generate_sos(captain_name, poi_name, backstory, func(text):
			var sos_text = text if (text != null and text != "") else fallback_text
			server.broadcast_event("sos_distress", {
				"message": sos_text, "poi": poi, "sender_id": player.get("player_id", 0)
			}, peer_id)
		)
	else:
		server.broadcast_event("sos_distress", {
			"message": fallback_text, "poi": poi, "sender_id": player.get("player_id", 0)
		}, peer_id)

# 工具函数

static func _get_distance(from_poi: String, to_poi: String) -> int:
	if DISTANCE_MATRIX.has(from_poi) and DISTANCE_MATRIX[from_poi].has(to_poi):
		return DISTANCE_MATRIX[from_poi][to_poi]
	if DISTANCE_MATRIX.has(to_poi) and DISTANCE_MATRIX[to_poi].has(from_poi):
		return DISTANCE_MATRIX[to_poi][from_poi]
	return 0

static func _calc_p_cost(player: Dictionary) -> int:
	var total = 0
	for comp_id in player.get("components", {}).keys():
		total += COMPONENT_DATA.get(comp_id, {}).get("p_cost", 0)
	return total

static func _calc_ship_spd(player: Dictionary) -> int:
	var total = 0
	for comp_id in player.get("components", {}).keys():
		total += COMPONENT_DATA.get(comp_id, {}).get("spd", 0)
	return total

static func _get_fuel_ratio(player: Dictionary) -> int:
	for comp_id in player.get("components", {}).keys():
		var ratio = COMPONENT_DATA.get(comp_id, {}).get("fuel_ratio", 0)
		if ratio > 0:
			return ratio
	return 0

static func _count_prefix(player: Dictionary, prefix: String) -> int:
	var count = 0
	for comp_id in player.get("components", {}).keys():
		if COMPONENT_DATA.get(comp_id, {}).get("prefix", "") == prefix:
			count += 1
	return count

static func _has_trait(player: Dictionary, trait_id: String) -> bool:
	for c in player.get("crew", []):
		if c.get("trait_id", "") == trait_id:
			return true
	return false

static func _get_nearest_station(from_poi: String) -> String:
	var best_poi = "CYG-SS-01"
	var best_dist = 999999
	for poi_id in POI_INFO.keys():
		if not POI_INFO[poi_id].get("is_station", false):
			continue
		var d = _get_distance(from_poi, poi_id)
		if d < best_dist:
			best_dist = d
			best_poi = poi_id
	return best_poi

static func _get_cargo_cap(player: Dictionary) -> int:
	var cap = 0
	for comp_id in player.get("components", {}).keys():
		cap += COMPONENT_DATA.get(comp_id, {}).get("cargo_cap", 0)
	return cap

static func _get_captain_name(player: Dictionary) -> String:
	for crew in player.get("crew", []):
		if crew.get("slot") == "captain":
			return crew.get("name", "未知舰长")
	return "未知舰长"
