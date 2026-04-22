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

# 骨架容量上限（T1默认值）
const SKELETON_CAPACITY = {
	"nose": 8, "wings": 8, "hull": 10, "tail": 6, "core": 6, "cabin": 8
}

# POI 距离矩阵（从 map.md 提取，天鹅座）
const DISTANCE_MATRIX = {
	"CYG-ST-01": {"CYG-PL-01": 15, "CYG-PL-02": 20, "CYG-ST-02": 25, "CYG-AST-01": 22, "CYG-WRK-01": 28, "CYG-STR-01": 40},
	"CYG-ST-02": {"CYG-PL-01": 18, "CYG-PL-02": 12, "CYG-ST-01": 25, "CYG-AST-01": 10, "CYG-WRK-01": 8, "CYG-STR-01": 30},
}

# POI 危险度
const POI_DANGER = {
	"CYG-ST-01": 0, "CYG-ST-02": 0,
	"CYG-PL-01": 1, "CYG-PL-02": 0,
	"CYG-AST-01": 3, "CYG-WRK-01": 4,
	"CYG-STR-01": 5,
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

	# 计算耗电
	var p_cost_total = _calc_p_cost(player)
	var total_power_cost = distance * 10 + p_cost_total

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
	components[component_id] = slot
	player["components"] = components
	inventory[component_id] = inventory.get(component_id, 1) - 1
	player["inventory"] = inventory

	db._query("INSERT INTO ship_components (player_id, slot, component_id) VALUES (%d, '%s', '%s')" % [
		player.get("player_id", 0), slot, component_id
	])

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

	components.erase(component_id)
	player["components"] = components

	var inventory = player.get("inventory", {})
	inventory[component_id] = inventory.get(component_id, 0) + 1
	player["inventory"] = inventory

	db._query("DELETE FROM ship_components WHERE player_id=%d AND component_id='%s'" % [
		player.get("player_id", 0), component_id
	])

	server.send_to_peer(peer_id, {"type": "action_result", "action": "unequip", "success": true, "component_id": component_id})

static func handle_accept_mission(peer_id: int, player: Dictionary, payload: Dictionary, db: DatabaseManager, server: Node) -> void:
	var mission_id: String = payload.get("mission_id", "")
	var now = Time.get_unix_time_from_system()

	# 检查任务是否已接取
	for m in player.get("missions", []):
		if m.get("mission_id") == mission_id:
			server.send_to_peer(peer_id, {"type": "error", "message": "该任务已接取"})
			return

	# 任务时限从接取时开始计算（具体时限从任务配置表读取）
	var deadline_hours = payload.get("deadline_hours", 24)
	var deadline = now + deadline_hours * 3600.0

	player["missions"].append({
		"mission_id": mission_id,
		"status": "active",
		"accepted_at": now,
		"progress": 0,
		"deadline": deadline
	})

	db._query("INSERT INTO missions (player_id, mission_id, status, accepted_at, progress, deadline) VALUES (%d, '%s', 'active', %f, 0, %f)" % [
		player.get("player_id", 0), mission_id, now, deadline
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

static func handle_connect_grid(peer_id: int, player: Dictionary, _payload: Dictionary, _db: DatabaseManager, server: Node) -> void:
	var ship = player.get("ship", {})
	if ship.get("status", "") != "docked":
		server.send_to_peer(peer_id, {"type": "error", "message": "只能在停泊状态连接电网"})
		return

	# 检查当前 POI 是否是空间站
	var current_poi = ship.get("current_poi", "")
	if not current_poi.contains("-ST-"):
		server.send_to_peer(peer_id, {"type": "error", "message": "只能在空间站连接电网"})
		return

	ship["grid_connected"] = true
	ship["grid_connect_time"] = Time.get_unix_time_from_system()

	server.send_to_peer(peer_id, {
		"type": "action_result", "action": "connect_grid", "success": true,
		"message": "已连接电网，充电速率 10 电力/分钟"
	})

static func handle_sos(peer_id: int, player: Dictionary, _payload: Dictionary, _db: DatabaseManager, server: Node) -> void:
	var ship = player.get("ship", {})
	if ship.get("status", "") != "stranded":
		server.send_to_peer(peer_id, {"type": "error", "message": "只有抛锚状态才能发射 SOS 信标"})
		return

	# 生成 SOS 文本（调用 AI 节点，此处简化为固定文本）
	var captain_name = _get_captain_name(player)
	var poi = ship.get("current_poi", "未知位置")
	var sos_text = "[SOS] %s 在 %s 抛锚，急需电力支援！" % [captain_name, poi]

	# 广播给全服（此处简化，实际需要广播给所有在线玩家）
	server.send_to_peer(peer_id, {
		"type": "action_result", "action": "sos", "success": true,
		"sos_text": sos_text
	})

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

static func _get_captain_name(player: Dictionary) -> String:
	for crew in player.get("crew", []):
		if crew.get("slot") == "captain":
			return crew.get("name", "未知舰长")
	return "未知舰长"
