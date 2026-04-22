class_name CombatSystem
extends Node

# 战斗系统 - 全自动 ATB 演算
# 5步伤害公式: 闪避 → 暴击 → 防御 → 护盾 → 本体

# 敌人配置（按危险度）
const ENEMY_TEMPLATES = {
	0: [{"id": "EN-DRONE-01", "name": "废弃无人机", "hp": 80, "dps": 15, "def": 0, "shield": 0, "credits": 50}],
	1: [{"id": "EN-PIR-01", "name": "海盗巡逻艇", "hp": 200, "dps": 35, "def": 5, "shield": 100, "credits": 150}],
	2: [{"id": "EN-PIR-02", "name": "海盗重甲舰", "hp": 400, "dps": 60, "def": 15, "shield": 200, "credits": 300}],
	3: [{"id": "EN-ZOM-01", "name": "拾荒者武装艇", "hp": 600, "dps": 80, "def": 20, "shield": 300, "credits": 500}],
	4: [{"id": "EN-ZOM-02", "name": "机械丧尸", "hp": 1000, "dps": 120, "def": 30, "shield": 500, "credits": 800}],
	5: [{"id": "EN-BOSS-01", "name": "海盗头目：獠牙-7", "hp": 2000, "dps": 200, "def": 50, "shield": 800, "credits": 2000}],
}

static func resolve(player: Dictionary, ship: Dictionary, danger: int) -> Dictionary:
	var result = {
		"player_wins": false,
		"enemy_name": "",
		"credits_gained": 0,
		"hull_damage": 0,
		"log": []
	}

	# 选择敌人
	var templates = ENEMY_TEMPLATES.get(danger, ENEMY_TEMPLATES[0])
	var enemy = templates[randi() % templates.size()].duplicate()
	result["enemy_name"] = enemy["name"]

	# 计算玩家战斗属性
	var player_dps: int = ship.get("dps", 50)
	var player_def: int = ship.get("def", 0)
	var player_shield: int = ship.get("shield", 0)
	var player_hp: int = ship.get("hp", 1000)
	var player_spd: int = ship.get("spd", 0)

	# 闪避率 = SPD / (SPD + 200)，上限 50%
	var evasion_rate: float = min(float(player_spd) / (float(player_spd) + 200.0), 0.5)

	# 模拟战斗回合（最多 20 回合防止死循环）
	var enemy_hp = enemy["hp"]
	var enemy_shield = enemy["shield"]
	var cur_shield = player_shield
	var cur_hp = player_hp
	var log = result["log"]

	for _round in range(20):
		# --- 玩家攻击敌人 ---
		var p_dmg = _calc_player_attack(player_dps, enemy["def"], log, enemy["name"])
		enemy_shield = max(0, enemy_shield - p_dmg)
		if enemy_shield <= 0:
			var overflow = -enemy_shield
			enemy_hp = max(0, enemy_hp - overflow)
			if overflow > 0:
				log.append("护盾击穿！对 %s 造成 %d 点本体伤害" % [enemy["name"], overflow])

		if enemy_hp <= 0:
			log.append("%s 已被摧毁！" % enemy["name"])
			result["player_wins"] = true
			# 危险度越高，奖励越高
			var base_credits = enemy["credits"]
			var bonus = int(base_credits * (danger * 0.5))
			result["credits_gained"] = base_credits + bonus
			break

		# --- 敌人攻击玩家（5步公式）---
		var e_raw_dmg = enemy["dps"]

		# Step 1: 闪避判定
		if randf() < evasion_rate:
			log.append("闪避成功！躲开了 %s 的攻击" % enemy["name"])
			continue

		# Step 2: 暴击判定（敌人暴击率 10%）
		var e_crit = false
		if randf() < 0.10:
			e_raw_dmg = int(e_raw_dmg * 1.75)
			e_crit = true

		# Step 3: 防御减免
		var e_dmg_after_def = max(1, e_raw_dmg - player_def)

		# Step 4: 护盾吸收
		if cur_shield > 0:
			var shield_absorbed = min(cur_shield, e_dmg_after_def)
			cur_shield -= shield_absorbed
			e_dmg_after_def -= shield_absorbed
			if e_crit:
				log.append("[暴击] %s 造成 %d 伤害，护盾吸收 %d" % [enemy["name"], e_raw_dmg, shield_absorbed])
			else:
				log.append("%s 造成 %d 伤害，护盾吸收 %d" % [enemy["name"], e_raw_dmg, shield_absorbed])

		# Step 5: 本体伤害
		if e_dmg_after_def > 0:
			cur_hp -= e_dmg_after_def
			log.append("本体受损 %d 点 HP（剩余 %d）" % [e_dmg_after_def, max(0, cur_hp)])

		if cur_hp <= 0:
			log.append("飞船被摧毁！强制弹射...")
			result["hull_damage"] = player_hp - cur_hp
			break

	if not result["player_wins"] and cur_hp > 0:
		# 超过20回合，玩家胜利（防止卡死）
		result["player_wins"] = true
		result["credits_gained"] = enemy["credits"]

	result["hull_damage"] = max(0, player_hp - cur_hp)
	return result

static func _calc_player_attack(player_dps: int, enemy_def: int, log: Array, enemy_name: String) -> int:
	var raw_dmg = player_dps

	# 玩家暴击率 5%（基础）
	var is_crit = randf() < 0.05
	if is_crit:
		raw_dmg = int(raw_dmg * 1.75)

	var dmg_after_def = max(1, raw_dmg - enemy_def)

	if is_crit:
		log.append("[暴击] 对 %s 造成 %d 伤害" % [enemy_name, dmg_after_def])
	else:
		log.append("对 %s 造成 %d 伤害" % [enemy_name, dmg_after_def])

	return dmg_after_def
