class_name MissionManager
extends Node

# 任务管理器 - 处理任务进度检查、完成结算、失败惩罚

const MISSION_CONFIG = {
	"CYG-DLV-001": {"type": "delivery", "cargo": "标准军火箱",  "from": "CYG-SS-01", "to": "CYG-PL-01", "deadline_hours": 2,   "reward_credits": 800,  "penalty": 600,  "rep_faction": "ironclad", "rep_reward": 5},
	"CYG-DLV-002": {"type": "delivery", "cargo": "维修零件包",  "from": "CYG-SS-01", "to": "CYG-PL-02", "deadline_hours": 3,   "reward_credits": 450,  "penalty": 0,    "rep_faction": "ironclad", "rep_reward": 3},
	"CYG-DLV-003": {"type": "delivery", "cargo": "机密数据盒",  "from": "CYG-SS-02", "to": "CYG-SS-01", "deadline_hours": 2,   "reward_credits": 900,  "penalty": 700,  "rep_faction": "macula",   "rep_reward": 5},
	"CYG-DLV-004": {"type": "delivery", "cargo": "走私冷藏舱",  "from": "CYG-RU-01", "to": "CYG-SS-03", "deadline_hours": 1.5, "reward_credits": 1400, "penalty": 1200, "rep_faction": "neutral",  "rep_reward": 6},
	"CYG-MIN-001": {"type": "mining", "resource": "钛",         "amount": 5000, "poi": "CYG-PL-01", "deadline_hours": 24, "reward_credits": 2200, "penalty": 0, "rep_faction": "ironclad", "rep_reward": 12},
	"CYG-MIN-002": {"type": "mining", "resource": "钛",         "amount": 1500, "poi": "CYG-MO-01", "deadline_hours": 24, "reward_credits": 800,  "penalty": 0, "rep_faction": "ironclad", "rep_reward": 6},
	"CYG-MIN-003": {"type": "mining", "resource": "钛",         "amount": 3000, "poi": "CYG-AS-01", "deadline_hours": 24, "reward_credits": 1800, "penalty": 0, "rep_faction": "macula",   "rep_reward": 10},
	"CYG-MIN-004": {"type": "mining", "resource": "暗面废料",   "amount": 800,  "poi": "CYG-AS-01", "deadline_hours": 24, "reward_credits": 2600, "penalty": 0, "rep_faction": "neutral",  "rep_reward": 12},
	"CYG-BTY-001": {"type": "bounty", "target": "拾荒者武装艇", "count": 8,  "poi": "CYG-AS-01", "deadline_hours": 6, "reward_credits": 2500, "penalty": 0, "rep_faction": "ironclad", "rep_reward": 15},
	"CYG-BTY-002": {"type": "bounty", "target": "机械丧尸",     "count": 20, "poi": "CYG-RU-01", "deadline_hours": 6, "reward_credits": 3200, "penalty": 0, "rep_faction": "macula",   "rep_reward": 18},
	"CYG-BTY-003": {"type": "bounty", "target": "海盗头目獠牙-7","count": 1, "poi": "CYG-RU-01", "deadline_hours": 3, "reward_credits": 4800, "penalty": 0, "rep_faction": "neutral",  "rep_reward": 22},
	"CYG-BTY-004": {"type": "bounty", "target": "放射性样本",   "count": 30, "poi": "CYG-ST-01", "deadline_hours": 2, "reward_credits": 6500, "penalty": 0, "rep_faction": "macula",   "rep_reward": 30},
}

# 检查任务超时（每 Tick 调用）
# 返回失败事件列表 [{mission_id, penalty}]
static func check_timeouts(player: Dictionary, db: Node) -> Array:
	var events = []
	var now = Time.get_unix_time_from_system()
	for mission in player.get("missions", []):
		if mission.get("status") != "active":
			continue
		if now <= mission.get("deadline", 0):
			continue
		var mission_id = mission.get("mission_id", "")
		var config = MISSION_CONFIG.get(mission_id, {})
		var penalty = config.get("penalty", 0)
		_fail_mission(player, mission, penalty, db)
		events.append({"mission_id": mission_id, "penalty": penalty})
	return events

# 战败时检查是否导致派送任务失败
static func check_defeat_missions(player: Dictionary, db: Node) -> Array:
	var events = []
	for mission in player.get("missions", []):
		if mission.get("status") != "active":
			continue
		var mission_id = mission.get("mission_id", "")
		var config = MISSION_CONFIG.get(mission_id, {})
		if config.is_empty():
			continue
		# 派送任务战败即失败（货物丢失）
		if config["type"] == "delivery":
			var penalty = config.get("penalty", 0)
			_fail_mission(player, mission, penalty, db)
			events.append({"mission_id": mission_id, "penalty": penalty})
	return events

static func check_arrival(player: Dictionary, ship: Dictionary, db: Node) -> Array:
	var events = []
	var current_poi = ship.get("current_poi", "")
	var now = Time.get_unix_time_from_system()

	for mission in player.get("missions", []):
		if mission.get("status") != "active":
			continue

		var mission_id = mission.get("mission_id", "")
		var config = MISSION_CONFIG.get(mission_id, {})
		if config.is_empty():
			continue

		# 超时判定
		if now > mission.get("deadline", 0):
			var penalty = config.get("penalty", 0)
			_fail_mission(player, mission, penalty, db)
			events.append({"type": "failed", "mission_id": mission_id, "penalty": penalty})
			continue

		# 派送任务：到达目的地完成
		if config["type"] == "delivery" and current_poi == config.get("to", ""):
			var reward = config.get("reward_credits", 0)
			_complete_mission(player, mission, reward, db)
			events.append({"type": "completed", "mission_id": mission_id, "reward": reward})
	return events

static func check_mining_progress(player: Dictionary, resource_type: String, amount: float, db: Node) -> Array:
	var events = []
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
		db._query("UPDATE missions SET progress=%d WHERE player_id=%d AND mission_id='%s'" % [
			mission["progress"], player.get("player_id", 0), mission_id
		])

		if mission["progress"] >= config.get("amount", 0):
			# 完成奖励 +30%
			var reward = int(config.get("reward_credits", 0) * 1.3)
			_complete_mission(player, mission, reward, db)
			events.append({"mission_id": mission_id, "reward": reward})
	return events

static func check_kill(player: Dictionary, enemy_name: String, kill_count: int, db: Node) -> Array:
	var events = []
	for mission in player.get("missions", []):
		if mission.get("status") != "active":
			continue

		var mission_id = mission.get("mission_id", "")
		var config = MISSION_CONFIG.get(mission_id, {})
		if config.is_empty() or config["type"] != "bounty":
			continue
		if config.get("target") != enemy_name:
			continue

		mission["progress"] = mission.get("progress", 0) + kill_count
		db._query("UPDATE missions SET progress=%d WHERE player_id=%d AND mission_id='%s'" % [
			mission["progress"], player.get("player_id", 0), mission_id
		])

		if mission["progress"] >= config.get("count", 1):
			var reward = config.get("reward_credits", 0)
			_complete_mission(player, mission, reward, db)
			events.append({"mission_id": mission_id, "reward": reward})
	return events

# ── 内部结算 ─────────────────────────────────────────────────

static func _complete_mission(player: Dictionary, mission: Dictionary, reward: int, db: Node) -> void:
	mission["status"] = "completed"
	player["ship"]["credits"] = player["ship"].get("credits", 0) + reward
	var player_id = player.get("player_id", 0)
	var mission_id = mission.get("mission_id", "")
	db._query("UPDATE missions SET status='completed' WHERE player_id=%d AND mission_id='%s'" % [
		player_id, mission_id
	])
	db._query("UPDATE ships SET credits=credits+%d WHERE player_id=%d" % [reward, player_id])
	# 声望奖励
	var config = MISSION_CONFIG.get(mission_id, {})
	var faction = config.get("rep_faction", "")
	var rep = config.get("rep_reward", 0)
	if faction != "" and rep > 0:
		db.add_reputation(player_id, faction, rep)
		if not player.has("reputation"):
			player["reputation"] = {"ironclad": 0, "macula": 0, "neutral": 0}
		player["reputation"][faction] = player["reputation"].get(faction, 0) + rep

static func _fail_mission(player: Dictionary, mission: Dictionary, penalty: int, db: Node) -> void:
	mission["status"] = "failed"
	var player_id = player.get("player_id", 0)
	db._query("UPDATE missions SET status='failed' WHERE player_id=%d AND mission_id='%s'" % [
		player_id, mission.get("mission_id", "")
	])
	if penalty > 0:
		# 扣违约金，最多扣到0（不进负数）
		var current = player["ship"].get("credits", 0)
		var actual_penalty = min(penalty, current)
		player["ship"]["credits"] = current - actual_penalty
		db._query("UPDATE ships SET credits=MAX(0, credits-%d) WHERE player_id=%d" % [penalty, player_id])
