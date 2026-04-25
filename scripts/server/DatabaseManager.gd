class_name DatabaseManager
extends Node

# 数据库管理器 - 封装所有 MySQL 操作
# 通过 GDScript 调用本地 mysql CLI 执行 SQL（服务端专用）

var _mysql_cmd: String = ""
var _db_host: String = "127.0.0.1"
var _db_port: int = 3306
var _db_name: String = "starriver"
var _db_user: String = "starriver"
var _db_pass: String = ""

func connect_db() -> bool:
	if not _load_db_config():
		return false

	# 检查 mysql 客户端是否可用
	var output = []
	OS.execute("which", ["mysql"], output)
	_mysql_cmd = output[0].strip_edges() if output.size() > 0 else ""

	if _mysql_cmd == "":
		push_error("[DB] mysql 客户端未找到")
		return false

	# 测试连接
	var result = _query("SELECT 1")
	if result == null:
		push_error("[DB] 数据库连接测试失败")
		return false

	print("[DB] 数据库连接成功: %s@%s/%s" % [_db_user, _db_host, _db_name])
	_init_poi_resources()
	return true

func _load_db_config() -> bool:
	var config = ConfigFile.new()
	var cfg_err = config.load("res://config/server_config.cfg")
	if cfg_err == OK:
		_db_host = str(config.get_value("database", "host", _db_host))
		_db_port = int(config.get_value("database", "port", _db_port))
		_db_name = str(config.get_value("database", "name", _db_name))
		_db_user = str(config.get_value("database", "user", _db_user))

	var dotenv = _load_dotenv()
	_db_host = _get_secret(dotenv, ["STARRIVER_DB_HOST", "DB_HOST"], _db_host)
	_db_name = _get_secret(dotenv, ["STARRIVER_DB_NAME", "DB_NAME"], _db_name)
	_db_user = _get_secret(dotenv, ["STARRIVER_DB_USER", "DB_USER"], _db_user)

	var port_text = _get_secret(dotenv, ["STARRIVER_DB_PORT", "DB_PORT"], str(_db_port))
	if port_text.is_valid_int():
		_db_port = int(port_text)

	_db_pass = _get_secret(dotenv, ["STARRIVER_DB_PASSWORD", "DB_PASSWORD", "MYSQL_PWD"], "")
	if _db_pass == "":
		push_error("[DB] 数据库密码未配置，请设置 STARRIVER_DB_PASSWORD 环境变量或在 .env 中填写")
		return false
	return true

func _load_dotenv() -> Dictionary:
	var env = {}
	if not FileAccess.file_exists("res://.env"):
		return env
	var file = FileAccess.open("res://.env", FileAccess.READ)
	if file == null:
		return env
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "" or line.begins_with("#") or not line.contains("="):
			continue
		var parts = line.split("=", true, 1)
		var key = parts[0].strip_edges()
		var value = parts[1].strip_edges()
		if value.length() >= 2:
			var first = value.substr(0, 1)
			var last = value.substr(value.length() - 1, 1)
			if (first == "\"" and last == "\"") or (first == "'" and last == "'"):
				value = value.substr(1, value.length() - 2)
		env[key] = value
	return env

func _get_secret(dotenv: Dictionary, keys: Array, fallback: String = "") -> String:
	for key in keys:
		var value = OS.get_environment(str(key))
		if value != "":
			return value
		if dotenv.has(key) and str(dotenv[key]) != "":
			return str(dotenv[key])
	return fallback

func _query(sql: String) -> Array:
	var args = [
		"-h", _db_host,
		"-P", str(_db_port),
		"-u", _db_user,
		"-p" + _db_pass,
		"-D", _db_name,
		"--batch",
		"--skip-column-names",
		"-e", sql
	]
	var output = []
	var exit_code = OS.execute(_mysql_cmd, args, output, true, false)
	if exit_code != 0:
		push_error("[DB] SQL 执行失败: " + sql)
		return []

	var rows = []
	var raw = output[0] if output.size() > 0 else ""
	for line in raw.split("\n"):
		# 跳过空行和 mysql 警告行
		if line == "" or line == "\r":
			continue
		if "Warning" in line or "warning" in line:
			continue
		# 去掉行尾的 \r（Windows 换行）
		var clean = line.trim_suffix("\r")
		rows.append(clean.split("\t", true))
	return rows

func register_player(username: String, password_hash: String) -> Dictionary:
	# 检查用户名是否已存在
	var check = _query("SELECT id FROM players WHERE username='%s' LIMIT 1" % _escape(username))
	if check.size() > 0:
		return {}

	_query("INSERT INTO players (username, password_hash) VALUES ('%s', '%s')" % [
		_escape(username), _escape(password_hash)
	])
	var rows = _query("SELECT id FROM players WHERE username='%s' LIMIT 1" % _escape(username))
	if rows.size() == 0:
		return {}

	var player_id = int(rows[0][0])
	var player = _load_full_player(player_id)
	return player

func authenticate_player(username: String, password_hash: String) -> Dictionary:
	# 实际使用时 password_hash 应为 SHA256 哈希
	var sql = "SELECT id, username FROM players WHERE username='%s' AND password_hash='%s' LIMIT 1" % [
		_escape(username), _escape(password_hash)
	]
	var rows = _query(sql)
	if rows.size() == 0:
		return {}

	var player_id = int(rows[0][0])
	var player = _load_full_player(player_id)

	# 更新最后登录时间
	_query("UPDATE players SET last_login=NOW() WHERE id=%d" % player_id)
	return player

func _load_full_player(player_id: int) -> Dictionary:
	var player = {"player_id": player_id}

	# 加载飞船状态
	var ship_rows = _query("SELECT status, current_poi, target_poi, depart_time, eta, hp, shield, power, max_power, credits, slot_hp FROM ships WHERE player_id=%d LIMIT 1" % player_id)
	if ship_rows.size() > 0:
		var r = ship_rows[0]
		var slot_hp_raw = r[10] if r.size() > 10 else ""
		var slot_hp = JSON.parse_string(slot_hp_raw) if slot_hp_raw != "" and slot_hp_raw != "NULL" else {}
		if not slot_hp is Dictionary:
			slot_hp = {}
		# 确保所有槽位都有默认耐久
		for slot in ["nose", "wings", "hull", "tail", "core", "cabin"]:
			if not slot_hp.has(slot):
				slot_hp[slot] = 1000
		player["ship"] = {
			"status": r[0],
			"current_poi": r[1],
			"target_poi": r[2],
			"depart_time": float(r[3]) if r[3] != "NULL" else 0.0,
			"eta": float(r[4]) if r[4] != "NULL" else 0.0,
			"hp": int(r[5]),
			"shield": int(r[6]),
			"power": int(r[7]),
			"max_power": int(r[8]),
			"credits": int(r[9]),
			"slot_hp": slot_hp
		}
	else:
		# 新玩家默认飞船
		player["ship"] = _default_ship(player_id)

	# 加载资源
	var res_rows = _query("SELECT resource_type, amount FROM resources WHERE player_id=%d" % player_id)
	player["resources"] = {}
	for r in res_rows:
		player["resources"][r[0]] = float(r[1])

	# 加载装配组件
	var comp_rows = _query("SELECT slot, component_id FROM ship_components WHERE player_id=%d" % player_id)
	player["components"] = {}
	for r in comp_rows:
		player["components"][r[0]] = r[1]

	# 加载船员
	var crew_rows = _query("SELECT slot, tier, trait_id, name, backstory, catchphrase, salary, debt FROM crew WHERE player_id=%d" % player_id)
	player["crew"] = []
	for r in crew_rows:
		player["crew"].append({
			"slot": r[0], "tier": r[1], "trait_id": r[2],
			"name": r[3], "backstory": r[4] if r.size() > 4 else "",
			"catchphrase": r[5] if r.size() > 5 else "",
			"salary": int(r[6]) if r.size() > 6 else 0,
			"debt": int(r[7]) if r.size() > 7 else 0
		})

	# 加载任务
	var mission_rows = _query("SELECT mission_id, status, accepted_at, progress, deadline FROM missions WHERE player_id=%d AND status='active'" % player_id)
	player["missions"] = []
	for r in mission_rows:
		player["missions"].append({
			"mission_id": r[0], "status": r[1],
			"accepted_at": float(r[2]), "progress": int(r[3]),
			"deadline": float(r[4])
		})

	# 加载声望
	var rep_rows = _query("SELECT ironclad_rep, macula_rep, neutral_rep FROM players WHERE id=%d LIMIT 1" % player_id)
	if rep_rows.size() > 0:
		player["reputation"] = {
			"ironclad": int(rep_rows[0][0]),
			"macula":   int(rep_rows[0][1]),
			"neutral":  int(rep_rows[0][2])
		}
	else:
		player["reputation"] = {"ironclad": 0, "macula": 0, "neutral": 0}

	return player

func _default_ship(player_id: int) -> Dictionary:
	var default_slot_hp = {"nose": 1200, "wings": 1000, "hull": 1600, "tail": 900, "core": 1100, "cabin": 1300}
	var slot_hp_json = JSON.stringify(default_slot_hp)
	var ship = {
		"player_id": player_id,
		"status": "docked",
		"current_poi": "CYG-SS-01",
		"target_poi": "",
		"depart_time": 0.0,
		"eta": 0.0,
		"hp": 1000,
		"shield": 0,
		"power": 500,
		"max_power": 500,
		"credits": 1000,
		"slot_hp": default_slot_hp
	}
	_query("INSERT INTO ships (player_id, status, current_poi, hp, shield, power, max_power, credits, slot_hp) VALUES (%d, 'docked', 'CYG-SS-01', 1000, 0, 500, 500, 1000, '%s')" % [player_id, _escape(slot_hp_json)])
	return ship

func save_ship(ship: Dictionary) -> void:
	var player_id = ship.get("player_id", 0)
	if player_id == 0:
		return
	var slot_hp_json = JSON.stringify(ship.get("slot_hp", {}))
	_query("UPDATE ships SET status='%s', current_poi='%s', target_poi='%s', hp=%d, shield=%d, power=%d, max_power=%d, credits=%d, slot_hp='%s' WHERE player_id=%d" % [
		_escape(ship.get("status", "docked")),
		_escape(ship.get("current_poi", "")),
		_escape(ship.get("target_poi", "")),
		ship.get("hp", 100),
		ship.get("shield", 0),
		ship.get("power", 0),
		ship.get("max_power", 500),
		ship.get("credits", 0),
		_escape(slot_hp_json),
		player_id
	])

func save_player_state(player: Dictionary) -> void:
	var ship = player.get("ship", {})
	ship["player_id"] = player.get("player_id", 0)
	save_ship(ship)

	# 保存资源
	var player_id = player.get("player_id", 0)
	for resource_type in player.get("resources", {}).keys():
		var amount = player["resources"][resource_type]
		_query("INSERT INTO resources (player_id, resource_type, amount) VALUES (%d, '%s', %f) ON DUPLICATE KEY UPDATE amount=%f" % [
			player_id, _escape(resource_type), amount, amount
		])

func add_player_resource(player_id: int, resource_type: String, amount: float) -> void:
	_query("INSERT INTO resources (player_id, resource_type, amount) VALUES (%d, '%s', %f) ON DUPLICATE KEY UPDATE amount=amount+%f" % [
		player_id, _escape(resource_type), amount, amount
	])

func add_credits(player_id: int, amount: int) -> void:
	_query("UPDATE ships SET credits=credits+%d WHERE player_id=%d" % [amount, player_id])

func add_reputation(player_id: int, faction: String, amount: int) -> void:
	var col_map = {"ironclad": "ironclad_rep", "macula": "macula_rep", "neutral": "neutral_rep"}
	var col = col_map.get(faction, "")
	if col == "":
		return
	_query("UPDATE players SET %s=%s+%d WHERE id=%d" % [col, col, amount, player_id])

func consume_poi_resource(poi_id: String, resource_type: String, amount: float) -> float:
	# 从 POI 资源池扣除，返回实际扣除量
	var rows = _query("SELECT remaining FROM poi_resources WHERE poi_id='%s' AND resource_type='%s' LIMIT 1" % [
		_escape(poi_id), _escape(resource_type)
	])
	if rows.size() == 0:
		return 0.0

	var remaining = float(rows[0][0])
	var actual = min(amount, remaining)
	if actual <= 0:
		return 0.0

	_query("UPDATE poi_resources SET remaining=remaining-%f WHERE poi_id='%s' AND resource_type='%s'" % [
		actual, _escape(poi_id), _escape(resource_type)
	])
	return actual

# POI 资源池默认值（来自 map.md）
const POI_RESOURCE_DEFAULTS = [
	# 天鹅座
	["CYG-PL-01", "钛",       50000],
	["CYG-PL-02", "燃料气体", 40000],
	["CYG-MO-01", "钛",       15000],
	["CYG-AS-01", "钛",       25000],
	["CYG-AS-01", "暗面废料",  5000],
	["CYG-RU-02", "暗面废料",  6000],
	["CYG-ST-01", "放射性材料",2000],
	# 猎户座
	["ORI-PL-01", "重金属矿", 80000],
	["ORI-PL-02", "生物质样本",30000],
	["ORI-PL-03", "稀土",     60000],
	["ORI-MO-01", "冰核样本", 20000],
	["ORI-AS-01", "战备残骸", 50000],
	["ORI-RU-02", "遗迹碎片",  8000],
	["ORI-ST-02", "低频信标",  5000],
]

func _init_poi_resources() -> void:
	# 用 INSERT IGNORE 确保已有数据不被覆盖（只初始化缺失行）
	for entry in POI_RESOURCE_DEFAULTS:
		var poi_id = entry[0]
		var res_type = entry[1]
		var daily_limit = entry[2]
		_query("INSERT IGNORE INTO poi_resources (poi_id, resource_type, remaining, daily_limit) VALUES ('%s', '%s', %d, %d)" % [
			_escape(poi_id), _escape(res_type), daily_limit, daily_limit
		])
	print("[DB] POI 资源池初始化完成")

func reset_all_poi_resources() -> void:
	# 每日 00:00 重置所有 POI 资源池
	_query("UPDATE poi_resources SET remaining=daily_limit, last_reset=NOW()")
	print("[DB] 所有 POI 资源池已重置")

func deduct_crew_salaries() -> void:
	# 每30分钟扣除船员薪水
	var now = Time.get_unix_time_from_system()
	var rows = _query("SELECT c.player_id, c.slot, c.salary, s.credits FROM crew c JOIN ships s ON c.player_id=s.player_id")
	for r in rows:
		var player_id = int(r[0])
		var salary = int(r[2])
		var credits = int(r[3])
		if credits >= salary:
			_query("UPDATE ships SET credits=credits-%d WHERE player_id=%d" % [salary, player_id])
		else:
			# 进入负债
			var debt = salary - credits
			_query("UPDATE ships SET credits=0 WHERE player_id=%d" % player_id)
			_query("UPDATE crew SET debt=debt+%d WHERE player_id=%d AND slot='%s'" % [debt, player_id, _escape(r[1])])

func _escape(s: String) -> String:
	# 基础 SQL 转义（防注入）
	return s.replace("'", "''").replace("\\", "\\\\")
