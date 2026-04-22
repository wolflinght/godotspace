class_name MissionManager
extends Node

# 任务管理器 - 处理任务进度检查、完成结算

# 任务配置表（对应 mission_cygnus_tasks.csv）
const MISSION_CONFIG = {
	"CYG-DLV-001": {"type": "delivery", "cargo": "标准军火箱", "from": "CYG-ST-01", "to": "CYG-PL-01", "deadline_hours": 2, "reward_credits": 800, "penalty": 600},
	"CYG-DLV-002": {"type": "delivery", "cargo": "维修零件包", "from": "CYG-ST-01", "to": "CYG-PL-02", "deadline_hours": 3, "reward_credits": 450, "penalty": 0},
	"CYG-DLV-003": {"type": "delivery", "cargo": "机密数据盒", "from": "CYG-ST-02", "to": "CYG-ST-01", "deadline_hours": 2, "reward_credits": 900, "penalty": 700},
	"CYG-DLV-004": {"type": "delivery", "cargo": "走私冷藏舱", "from": "CYG-WRK-01", "to": "CYG-ST-02", "deadline_hours": 1.5, "reward_credits": 1400, "penalty": 1200},
	"CYG-MIN-001": {"type": "mining", "resource": "钛", "amount": 5000, "poi": "CYG-PL-01", "deadline_hours": 24, "reward_credits": 2200},
	"CYG-MIN-002": {"type": "mining", "resource": "钛", "amount": 1500, "poi": "CYG-PL-02", "deadline_hours": 24, "reward_credits": 800},
	"CYG-MIN-003": {"type": "mining", "resource": "钛", "amount": 3000, "poi": "CYG-ST-02", "deadline_hours": 24, "reward_credits": 1800},
	"CYG-MIN-004": {"type": "mining", "resource": "暗面废料", "amount": 800, "poi": "CYG-AST-01", "deadline_hours": 24, "reward_credits": 2600},
	"CYG-BTY-001": {"type": "bounty", "target": "拾荒者武装艇", "count": 8, "poi": "CYG-AST-01", "deadline_hours": 6, "reward_credits": 2500},
	"CYG-BTY-002": {"type": "bounty", "target": "机械丧尸", "count": 20, "poi": "CYG-WRK-01", "deadline_hours": 6, "reward_credits": 3200},
	"CYG-BTY-003": {"type": "bounty", "target": "海盗头目：獠牙-7", "count": 1, "poi": "CYG-WRK-01", "deadline_hours": 3, "reward_credits": 4800},
	"CYG-BTY-004": {"type": "bounty", "target": "放射性样本", "count": 30, "poi": "CYG-STR-01", "deadline_hours": 2, "reward_credits": 6500},
}

static func check_arrival(player: Dictionary, ship: Dictionary) -> void:
	var current_poi = ship.get("current_poi", "")
	var now = Time.get_unix_time_from_system()

	for mission in player.get("missions", []):
		if mission.get("status") != "active":
			continue

		var mission_id = mission.get("mission_id", "")
		var config = MISSION_CONFIG.get(mission_id, {})
		if config.is_empty():
			continue

		# 检查时限
		if now > mission.get("deadline", 0):
			mission["status"] = "failed"
			continue

		# 派送任务：检查是否到达目的地
		if config["type"] == "delivery" and current_poi == config.get("to", ""):
			_complete_delivery(player, ship, mission, config)

static func check_mining_progress(player: Dictionary, resource_type: String, amount: float) -> void:
	for mission in player.get("missions", []):
		if mission.get("status") != "active":
			continue

		var mission_id = mission.get("mission_id", "")
		var config = MISSION_CONFIG.get(mission_id, {})
		if config.is_empty() or config["type"] != "mining":
			continue

		if config.get("resource") != resource_type:
			continue

		mission["progress"] = mission.get("progress", 0) + int(amount)
		if mission["progress"] >= config.get("amount", 0):
			mission["status"] = "completed"
			# 奖励 +30% 完成奖励
			var reward = int(config.get("reward_credits", 0) * 1.3)
			player["ship"]["credits"] = player["ship"].get("credits", 0) + reward

static func check_kill(player: Dictionary, enemy_name: String, kill_count: int) -> void:
	for mission in player.get("missions", []):
		if mission.get("status") != "active":
			continue

		var mission_id = mission.get("mission_id", "")
		var config = MISSION_CONFIG.get(mission_id, {})
		if config.is_empty() or config["type"] != "bounty":
			continue

		if config.get("target") != enemy_name:
			continue

		# 单次遭遇战中所有击杀都计入
		mission["progress"] = mission.get("progress", 0) + kill_count
		if mission["progress"] >= config.get("count", 1):
			mission["status"] = "completed"
			var reward = config.get("reward_credits", 0)
			player["ship"]["credits"] = player["ship"].get("credits", 0) + reward

static func _complete_delivery(player: Dictionary, _ship: Dictionary, mission: Dictionary, config: Dictionary) -> void:
	mission["status"] = "completed"
	var reward = config.get("reward_credits", 0)
	player["ship"]["credits"] = player["ship"].get("credits", 0) + reward
