class_name CombatSystem
extends Node

# 战斗系统 - ATB 演算 + 船员/前缀特性 + 多样化战报文案

# 敌人配置（按危险度）
const ENEMY_TEMPLATES = {
	0: [{"id": "EN-DRONE-01", "name": "废弃无人机",      "hp": 80,   "dps": 15,  "def": 0,  "shield": 0,   "spd": 20,  "credits": 50}],
	1: [{"id": "EN-PIR-01",   "name": "海盗巡逻艇",      "hp": 200,  "dps": 35,  "def": 5,  "shield": 100, "spd": 40,  "credits": 150}],
	2: [{"id": "EN-PIR-02",   "name": "海盗重甲舰",      "hp": 400,  "dps": 60,  "def": 15, "shield": 200, "spd": 25,  "credits": 300}],
	3: [{"id": "EN-ZOM-01",   "name": "拾荒者武装艇",    "hp": 600,  "dps": 80,  "def": 20, "shield": 300, "spd": 50,  "credits": 500}],
	4: [{"id": "EN-ZOM-02",   "name": "机械丧尸",        "hp": 1000, "dps": 120, "def": 30, "shield": 500, "spd": 30,  "credits": 800}],
	5: [{"id": "EN-BOSS-01",  "name": "海盗头目獠牙-7",  "hp": 2000, "dps": 200, "def": 50, "shield": 800, "spd": 60,  "credits": 2000}],
}

# ── 战报文案库 ──────────────────────────────────────────────
const LINES_ENCOUNTER = [
	"扫描仪突然爆出警报——{enemy}从碎片云中冲出，锁定了我方坐标！",
	"{enemy}截断了航线，双方舰炮同时充能，战斗一触即发！",
	"通讯频道传来嘈杂的干扰信号，{enemy}已进入交战距离！",
	"尾焰探测器捕捉到高速接近的热源——{enemy}，来者不善！",
]
const LINES_PLAYER_HIT = [
	"主炮齐射，对{enemy}造成{dmg}点伤害！",
	"精准锁定！穿甲弹撕裂{enemy}的外壳，伤害{dmg}！",
	"连续点射命中，{enemy}受到{dmg}点伤害！",
	"火控系统锁定目标，{enemy}挨了{dmg}点！",
]
const LINES_PLAYER_CRIT = [
	"[暴击] 能量炮核心过载！对{enemy}造成{dmg}点暴击伤害！",
	"[暴击] 精准命中动力舱！{enemy}受到{dmg}点致命打击！",
	"[暴击] 穿甲弹直击指挥核心！{enemy}损伤{dmg}，结构警报拉响！",
]
const LINES_PLAYER_SHIELD_BREAK = [
	"护盾击穿！溢出{dmg}点伤害直接撕裂{enemy}的装甲！",
	"能量场崩溃！{enemy}的本体暴露在炮口之下，受到{dmg}点穿透伤害！",
	"护盾过载瓦解！{dmg}点伤害贯穿{enemy}的外壳！",
]
const LINES_ENEMY_HIT = [
	"{enemy}的炮击命中，本体受损{dmg}点（剩余HP {hp}）！",
	"躲避失败！{enemy}的导弹撕开了侧翼装甲，损失{dmg}点HP！",
	"{enemy}火力全开，结构受损{dmg}点，剩余HP {hp}！",
]
const LINES_ENEMY_CRIT = [
	"[敌方暴击] {enemy}的重炮直击推进器，造成{dmg}点爆炸伤害！",
	"[敌方暴击] 精准的电磁炮击穿了防护层，损失{dmg}点HP！",
	"[敌方暴击] 核心区域中弹！{enemy}造成{dmg}点暴击伤害！",
]
const LINES_SHIELD_ABSORB = [
	"偏导力场全力运转，吸收了来自{enemy}的{absorbed}点伤害（护盾剩余{shield}）！",
	"能量护盾拦截了{enemy}的攻击，吸收{absorbed}点（护盾{shield}）！",
	"护盾展开！{enemy}的{absorbed}点伤害被完全偏转（剩余{shield}）！",
]
const LINES_EVASION = [
	"引擎爆发推力，以极限机动躲开了{enemy}的攻击！",
	"速度优势发挥作用，{enemy}的炮击打了个空！",
	"紧急变轨成功！{enemy}的锁定被成功甩脱！",
]
const LINES_SELF_DAMAGE = [  # 过载狂人特性
	"[过载] 武器系统过热，飞船自身承受了{dmg}点结构损伤！",
	"[过载] 反应堆过载的代价——本体损失{dmg}点HP！",
]
const LINES_FIRST_CRIT = [  # 奇点锁定特性
	"[奇点锁定] 首轮战斗，[奇点]武器精准锁定敌方弱点，必然暴击！",
]
const LINES_VICTORY = [
	"{enemy}的动力核心引发连锁爆炸，彻底瓦解！获得{credits}星币战利品！",
	"最后一发穿甲弹终结了{enemy}，残骸漂浮在虚空中。收获{credits}星币！",
	"{enemy}发出求救信号后沉默——战斗结束，缴获{credits}星币！",
]
const LINES_DEFEAT = [
	"飞船结构强度归零，紧急弹射舱启动，逃离战场！",
	"推进器被击毁，无法机动，触发自动弹射程序！",
	"主控系统宕机，弹射！弹射！弹射！",
]
const LINES_TIMEOUT = [
	"双方弹药告罄，推进器过热，默契地脱离了接触。",
	"漫长的消耗战后，双方均无力继续，战术撤退。",
	"交战100次仍未分出胜负，战场陷入僵局，各自撤离。",
]

# ── 主入口 ──────────────────────────────────────────────────
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
	var log: Array = result["log"]

	# 计算玩家实际战斗属性（含特性/前缀加成）
	var stats = _calc_player_stats(player, ship)
	var player_dps: int   = stats["dps"]
	var player_def: int   = stats["def"]
	var player_spd: int   = stats["spd"]
	var player_crit: float = stats["crit_rate"]
	var ignore_def: bool  = stats["ignore_enemy_def"]   # 光斑4件
	var ignore_eva: bool  = stats["ignore_evasion"]     # 光斑4件
	var overload: bool    = stats["overload"]           # 过载狂人
	var singularity_lock: bool = stats["singularity_lock"]  # 奇点锁定
	var lone_wolf_bonus: float = stats["lone_wolf_bonus"]   # 独狼战术

	# 提取炮手口头禅（用于暴击/护盾击穿时插入）
	var gunner_catchphrase = ""
	var gunner_name = ""
	for c in player.get("crew", []):
		if c.get("slot") == "gunner":
			gunner_catchphrase = c.get("catchphrase", "")
			gunner_name = c.get("name", "")

	var player_hp: int    = ship.get("hp", 1000)
	var player_shield: int = ship.get("shield", 0)

	# 闪避率（敌方攻击时）
	var evasion_rate: float = min(float(player_spd) / (float(player_spd) + 200.0), 0.5)

	var enemy_hp: int    = enemy["hp"]
	var enemy_shield: int = enemy["shield"]
	var enemy_spd: int   = enemy.get("spd", 30)
	# 敌方闪避率（玩家攻击时）
	var enemy_evasion: float = min(float(enemy_spd) / (float(enemy_spd) + float(player_spd) + 1.0) * 0.5, 0.3)
	if ignore_eva:
		enemy_evasion = 0.0

	var cur_shield: int = player_shield
	var cur_hp: int     = player_hp

	log.append(_pick(LINES_ENCOUNTER).format({"enemy": enemy["name"]}))

	# ATB：用行动值驱动，双方各自累积 AV，≥1000 则出手
	var player_av: float = 0.0
	var enemy_av: float  = 0.0
	var total_attacks: int = 0
	var first_round: bool = true

	while total_attacks < 100:
		# 推进行动值（以速度比例推进，每"tick"双方各+SPD）
		player_av += float(player_spd) + 100.0   # 玩家基础速度+100保证有速度时更快
		enemy_av  += float(enemy_spd)

		# 同时达到 1000 → 玩家先手
		var player_acts = player_av >= 1000.0
		var enemy_acts  = enemy_av  >= 1000.0

		if player_acts:
			player_av -= 1000.0
			total_attacks += 1

			# 奇点锁定：首回合必暴击
			var force_crit = first_round and singularity_lock
			first_round = false

			# 敌方闪避判定
			if not ignore_eva and randf() < enemy_evasion:
				log.append("对方机动规避，本次攻击落空！")
			else:
				# 计算伤害
				var raw = player_dps
				if lone_wolf_bonus > 0:
					raw = int(raw * (1.0 + lone_wolf_bonus))
				var is_crit = force_crit or (randf() < player_crit)
				if is_crit:
					raw = int(raw * 1.75)
				var eff_def = 0 if ignore_def else enemy["def"]
				var dmg = max(1, raw - eff_def)

				# 护盾优先
				if enemy_shield > 0:
					var absorbed = min(enemy_shield, dmg)
					enemy_shield -= absorbed
					dmg -= absorbed
					if dmg > 0:
						enemy_hp = max(0, enemy_hp - dmg)
						if is_crit:
							log.append(_pick(LINES_PLAYER_CRIT).format({"enemy": enemy["name"], "dmg": raw}))
						log.append(_pick(LINES_PLAYER_SHIELD_BREAK).format({"enemy": enemy["name"], "dmg": dmg}))
						# 护盾击穿时插入炮手口头禅
						if gunner_catchphrase != "":
							log.append("[炮手 %s]：「%s」" % [gunner_name, gunner_catchphrase])
					else:
						if is_crit:
							log.append(_pick(LINES_PLAYER_CRIT).format({"enemy": enemy["name"], "dmg": raw}))
							# 暴击时插入炮手口头禅
							if gunner_catchphrase != "":
								log.append("[炮手 %s]：「%s」" % [gunner_name, gunner_catchphrase])
						else:
							log.append(_pick(LINES_PLAYER_HIT).format({"enemy": enemy["name"], "dmg": absorbed}))
				else:
					enemy_hp = max(0, enemy_hp - dmg)
					if is_crit:
						log.append(_pick(LINES_PLAYER_CRIT).format({"enemy": enemy["name"], "dmg": dmg}))
						# 暴击时插入炮手口头禅
						if gunner_catchphrase != "":
							log.append("[炮手 %s]：「%s」" % [gunner_name, gunner_catchphrase])
					else:
						log.append(_pick(LINES_PLAYER_HIT).format({"enemy": enemy["name"], "dmg": dmg}))

				# 过载狂人：每次开火自损10HP
				if overload:
					cur_hp = max(0, cur_hp - 10)
					log.append(_pick(LINES_SELF_DAMAGE).format({"dmg": 10}))

			if enemy_hp <= 0:
				var base_credits = enemy["credits"]
				result["credits_gained"] = base_credits + int(base_credits * danger * 0.5)
				result["player_wins"] = true
				log.append(_pick(LINES_VICTORY).format({"enemy": enemy["name"], "credits": result["credits_gained"]}))
				break

		if enemy_acts:
			enemy_av -= 1000.0
			total_attacks += 1

			# 玩家闪避
			if randf() < evasion_rate:
				log.append(_pick(LINES_EVASION).format({"enemy": enemy["name"]}))
			else:
				var e_raw = enemy["dps"]
				var e_crit = randf() < 0.10
				if e_crit:
					e_raw = int(e_raw * 1.75)
				var e_dmg = max(1, e_raw - player_def)

				# 护盾吸收
				if cur_shield > 0:
					var absorbed = min(cur_shield, e_dmg)
					cur_shield -= absorbed
					e_dmg -= absorbed
					log.append(_pick(LINES_SHIELD_ABSORB).format({
						"enemy": enemy["name"], "absorbed": absorbed, "shield": cur_shield
					}))

				if e_dmg > 0:
					cur_hp = max(0, cur_hp - e_dmg)
					if e_crit:
						log.append(_pick(LINES_ENEMY_CRIT).format({"enemy": enemy["name"], "dmg": e_dmg}))
					else:
						log.append(_pick(LINES_ENEMY_HIT).format({"enemy": enemy["name"], "dmg": e_dmg, "hp": cur_hp}))

			if cur_hp <= 0:
				log.append(_pick(LINES_DEFEAT))
				result["hull_damage"] = player_hp
				break

	# 超过100次攻击 → 平局，玩家胜
	if not result["player_wins"] and cur_hp > 0:
		result["player_wins"] = true
		result["credits_gained"] = enemy["credits"]
		log.append(_pick(LINES_TIMEOUT))

	result["hull_damage"] = max(0, player_hp - cur_hp)

	# 战斗结束后，根据受损比例随机损伤 1-2 个槽位骨架耐久
	if result["hull_damage"] > 0:
		var damage_ratio = float(result["hull_damage"]) / float(max(player_hp, 1))
		var slot_damage = int(damage_ratio * 300.0)  # 最多损伤300点骨架耐久
		if slot_damage > 0:
			var slots = ["nose", "wings", "hull", "tail", "core", "cabin"]
			# 随机选 1-2 个槽位受损
			var hit_count = 2 if damage_ratio > 0.5 else 1
			var damaged_slots = []
			for _i in range(hit_count):
				var s = slots[randi() % slots.size()]
				if s not in damaged_slots:
					damaged_slots.append(s)
			result["slot_damage"] = {}
			for s in damaged_slots:
				result["slot_damage"][s] = slot_damage

	return result

# ── 计算玩家实际战斗属性（含船员特性 + 前缀联动）─────────────
static func _calc_player_stats(player: Dictionary, ship: Dictionary) -> Dictionary:
	var components: Dictionary = player.get("components", {})
	var crew: Array = player.get("crew", [])

	# 基础属性（从组件累加）
	var base_dps: int = 0
	var base_def: int = 0
	var base_spd: int = 0
	var has_shield: bool = ship.get("shield", 0) > 0

	# 统计各前缀件数
	var prefix_count = {"ironclad": 0, "macula": 0, "singularity": 0}
	# 统计武器标签（用于动能偏执狂）
	var has_kinetic_weapon = false
	var has_em_weapon = false

	# 获取失效槽位（slot_hp == 0 的槽位组件不生效）
	var slot_hp: Dictionary = ship.get("slot_hp", {})
	var broken_slots = {}
	for slot in slot_hp.keys():
		if slot_hp[slot] <= 0:
			broken_slots[slot] = true

	# 从 ActionHandler 的组件数据中读取（跳过失效槽位）
	for comp_id in components.keys():
		var slot = components[comp_id]  # components 格式: {comp_id: slot}
		if slot in broken_slots:
			continue  # 该槽位骨架损毁，组件效果不生效
		var cd = ActionHandler.COMPONENT_DATA.get(comp_id, {})
		base_dps += cd.get("dps", 0)
		base_def += cd.get("def", 0)
		base_spd += cd.get("spd", 0)
		var pfx = cd.get("prefix", "none")
		if pfx in prefix_count:
			prefix_count[pfx] += 1
		# 武器标签检测（WPN 前缀）
		if comp_id.begins_with("WPN"):
			if pfx == "none" or pfx == "ironclad":
				has_kinetic_weapon = true
			if pfx == "macula" or pfx == "singularity":
				has_em_weapon = true

	# ── 前缀联动效果 ──
	var ignore_enemy_def = false
	var ignore_evasion   = false

	# [铁骑] 2件：DEF+20；4件：武器火力+30%
	if prefix_count["ironclad"] >= 2:
		base_def += 20
	if prefix_count["ironclad"] >= 4:
		base_dps = int(base_dps * 1.30)

	# [光斑] 2件：无视敌方30%防御（在伤害计算时 ignore_def）；4件：武器+50%、必中
	if prefix_count["macula"] >= 2:
		ignore_enemy_def = true   # 在 resolve 里判断
	if prefix_count["macula"] >= 4:
		base_dps = int(base_dps * 1.50)
		ignore_evasion = true

	# [奇点] 2件：电力上限+500（在 ActionHandler 处理，此处不影响战斗）
	# [奇点] 4件：组件耗电-50%（ActionHandler 处理），20%概率秒杀低护盾敌人（战斗中处理）

	# ── 船员特性效果 ──
	var crit_rate: float = 0.05  # 基础暴击率
	var overload = false
	var singularity_lock = false
	var lone_wolf_bonus: float = 0.0
	var kinetic_blocked = false

	var crew_count = crew.size()

	for c in crew:
		var trait_id = c.get("trait_id", "")
		match trait_id:
			# 舰长
			"captain_t1_ironclad":
				# 每件[铁骑]组件 DEF+5
				base_def += prefix_count["ironclad"] * 5
			"captain_t2_lone_wolf":
				# 仅1名船员时武器+40%
				if crew_count == 1:
					lone_wolf_bonus = 0.40
			"captain_t3_capitalist":
				# 薪水减半+遭遇战星币+30%（星币加成在 resolve 返回值外处理，此处标记）
				pass  # credits bonus handled in ServerMain

			# 炮手
			"gunner_t1_kinetic":
				# [动能]武器+20%（此处直接加，装配约束在 equip 时检查）
				if has_kinetic_weapon and not has_em_weapon:
					base_dps = int(base_dps * 1.20)
			"gunner_t2_overload":
				# 武器+50%，每次开火自损10HP
				base_dps = int(base_dps * 1.50)
				overload = true
			"gunner_t3_singularity":
				# 首回合[奇点]武器必暴击无视闪避
				if prefix_count["singularity"] > 0:
					singularity_lock = true

			# 轮机长
			"engineer_t1_efficient":
				pass  # 耗电-15% 在 ActionHandler.handle_depart 处理
			"engineer_t2_shield_geek":
				# 无护盾时 SPD 翻倍
				if not has_shield:
					base_spd *= 2
			"engineer_t3_jump_resonance":
				pass  # 跃迁/抛锚回电在 ServerMain 处理

	# 保证基础值
	if base_dps <= 0:
		base_dps = 30  # 无武器时的裸机火力

	return {
		"dps": base_dps,
		"def": base_def,
		"spd": base_spd,
		"crit_rate": crit_rate,
		"ignore_enemy_def": ignore_enemy_def,
		"ignore_evasion": ignore_evasion,
		"overload": overload,
		"singularity_lock": singularity_lock,
		"lone_wolf_bonus": lone_wolf_bonus,
	}

# ── 工具：随机选取文案 ───────────────────────────────────────
static func _pick(lines: Array) -> String:
	return lines[randi() % lines.size()]
