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
var _last_query_ok: bool = true
var _ship_columns: Dictionary = {}

const OPTIONAL_SHIP_COLUMNS = {
	"total_power_cost": "INT DEFAULT 0",
	"power_used_so_far": "INT DEFAULT 0",
	"travel_distance": "DOUBLE DEFAULT 0",
	"last_encounter_dist": "DOUBLE DEFAULT 0",
	"target_danger": "INT DEFAULT 0",
	"mining_resource": "VARCHAR(64) DEFAULT ''",
	"mining_rate": "DOUBLE DEFAULT 0",
	"last_work_tick": "DOUBLE DEFAULT 0",
	"grid_connected": "TINYINT DEFAULT 0",
	"last_grid_tick": "DOUBLE DEFAULT 0"
}
const OPTIONAL_SHIP_INT_COLUMNS = ["total_power_cost", "power_used_so_far", "target_danger"]
const OPTIONAL_SHIP_FLOAT_COLUMNS = ["travel_distance", "last_encounter_dist", "mining_rate", "last_work_tick", "last_grid_tick"]
const OPTIONAL_SHIP_STRING_COLUMNS = ["mining_resource"]
const OPTIONAL_SHIP_BOOL_COLUMNS = ["grid_connected"]

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
	if not _last_query_ok or result.size() == 0 or result[0].size() == 0 or str(result[0][0]) != "1":
		push_error("[DB] 数据库连接测试失败")
		return false

	if not _load_schema_info():
		push_error("[DB] 数据库表结构读取失败")
		return false
	if not _ensure_optional_ship_columns():
		push_error("[DB] ships 表缺少必要的运行状态字段，且自动补列失败")
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

func _load_schema_info() -> bool:
	_ship_columns.clear()
	var rows = _query("SHOW COLUMNS FROM ships")
	if not _last_query_ok:
		return false
	for r in rows:
		if r.size() > 0:
			_ship_columns[str(r[0])] = true
	return true

func _ensure_optional_ship_columns() -> bool:
	for col in OPTIONAL_SHIP_COLUMNS.keys():
		if _ship_columns.has(col):
			continue
		_query("ALTER TABLE ships ADD COLUMN %s %s" % [col, OPTIONAL_SHIP_COLUMNS[col]])
		if _last_query_ok:
			_ship_columns[col] = true
		else:
			return false
	return true

func _write_mysql_defaults_file() -> String:
	var local_path = "user://mysql_client.cnf"
	var file = FileAccess.open(local_path, FileAccess.WRITE)
	if file == null:
		push_error("[DB] 无法创建 MySQL 临时配置文件")
		return ""
	file.store_line("[client]")
	file.store_line("host=%s" % _mysql_option_value(_db_host))
	file.store_line("port=%d" % _db_port)
	file.store_line("user=%s" % _mysql_option_value(_db_user))
	file.store_line("password=%s" % _mysql_option_value(_db_pass))
	file.close()

	var global_path = ProjectSettings.globalize_path(local_path)
	OS.execute("chmod", ["600", global_path])
	return global_path

func _mysql_option_value(value: String) -> String:
	return value.replace("\n", "").replace("\r", "")

func _query(sql: String) -> Array:
	_last_query_ok = false
	var defaults_path = _write_mysql_defaults_file()
	if defaults_path == "":
		return []
	var args = [
		"--defaults-extra-file=" + defaults_path,
		"-D", _db_name,
		"--batch",
		"--skip-column-names",
		"-e", sql
	]
	var output = []
	var exit_code = OS.execute(_mysql_cmd, args, output, true, false)
	DirAccess.remove_absolute(defaults_path)
	if exit_code != 0:
		push_error("[DB] SQL 执行失败: " + sql)
		return []

	_last_query_ok = true
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
	var ship_fields = ["status", "current_poi", "target_poi", "depart_time", "eta", "hp", "shield", "power", "max_power", "credits", "slot_hp"]
	for col in OPTIONAL_SHIP_INT_COLUMNS + OPTIONAL_SHIP_FLOAT_COLUMNS + OPTIONAL_SHIP_STRING_COLUMNS + OPTIONAL_SHIP_BOOL_COLUMNS:
		if _ship_columns.has(col):
			ship_fields.append(col)
	var ship_rows = _query("SELECT %s FROM ships WHERE player_id=%d LIMIT 1" % [", ".join(ship_fields), player_id])
	if ship_rows.size() > 0:
		var row = _row_to_dict(ship_fields, ship_rows[0])
		var slot_hp_raw = row.get("slot_hp", "")
		var slot_hp = JSON.parse_string(slot_hp_raw) if slot_hp_raw != "" and slot_hp_raw != "NULL" else {}
		if not slot_hp is Dictionary:
			slot_hp = {}
		# 确保所有槽位都有默认耐久
			for slot in ["nose", "wings", "hull", "tail", "core", "cabin"]:
				if not slot_hp.has(slot):
					slot_hp[slot] = 1000
			player["ship"] = {
				"player_id": player_id,
				"status": row.get("status", "docked"),
				"current_poi": row.get("current_poi", ""),
				"target_poi": row.get("target_poi", ""),
			"depart_time": _row_float(row, "depart_time", 0.0),
			"eta": _row_float(row, "eta", 0.0),
			"hp": _row_int(row, "hp", 1000),
			"shield": _row_int(row, "shield", 0),
			"power": _row_int(row, "power", 0),
			"max_power": _row_int(row, "max_power", 500),
			"credits": _row_int(row, "credits", 0),
			"slot_hp": slot_hp
		}
		for col in OPTIONAL_SHIP_INT_COLUMNS:
			if row.has(col):
				player["ship"][col] = _row_int(row, col, 0)
		for col in OPTIONAL_SHIP_FLOAT_COLUMNS:
			if row.has(col):
				player["ship"][col] = _row_float(row, col, 0.0)
		for col in OPTIONAL_SHIP_STRING_COLUMNS:
			if row.has(col):
				player["ship"][col] = row[col] if row[col] != "NULL" else ""
		for col in OPTIONAL_SHIP_BOOL_COLUMNS:
			if row.has(col):
				player["ship"][col] = _row_bool(row, col, false)
	else:
		# 新玩家默认飞船
		player["ship"] = _default_ship(player_id)

	# 加载资源
	var res_rows = _query("SELECT resource_type, amount FROM resources WHERE player_id=%d" % player_id)
	player["resources"] = {}
	for r in res_rows:
		player["resources"][r[0]] = float(r[1])

	# 加载仓库
	var inv_rows = _query("SELECT component_id, quantity FROM inventory WHERE player_id=%d" % player_id)
	player["inventory"] = {}
	for r in inv_rows:
		if r.size() >= 2:
			player["inventory"][r[0]] = int(r[1])

	# 加载装配组件
	var comp_rows = _query("SELECT slot, component_id FROM ship_components WHERE player_id=%d" % player_id)
	player["components"] = {}
	for r in comp_rows:
		if r.size() >= 2:
			player["components"][r[1]] = r[0]

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

	_hydrate_runtime_ship_state(player)
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
		"slot_hp": default_slot_hp,
		"total_power_cost": 0,
		"power_used_so_far": 0,
		"travel_distance": 0.0,
		"last_encounter_dist": 0.0,
		"target_danger": 0,
		"mining_resource": "",
		"mining_rate": 0.0,
		"last_work_tick": 0.0,
		"grid_connected": false,
		"last_grid_tick": 0.0
	}
	_query("INSERT INTO ships (player_id, status, current_poi, hp, shield, power, max_power, credits, slot_hp) VALUES (%d, 'docked', 'CYG-SS-01', 1000, 0, 500, 500, 1000, '%s')" % [player_id, _escape(slot_hp_json)])
	return ship

func save_ship(ship: Dictionary) -> void:
	var player_id = ship.get("player_id", 0)
	if player_id == 0:
		return
	var slot_hp_json = JSON.stringify(ship.get("slot_hp", {}))
	var sets = [
		"status='%s'" % _escape(ship.get("status", "docked")),
		"current_poi='%s'" % _escape(ship.get("current_poi", "")),
		"target_poi='%s'" % _escape(ship.get("target_poi", "")),
		"depart_time=%f" % float(ship.get("depart_time", 0.0)),
		"eta=%f" % float(ship.get("eta", 0.0)),
		"hp=%d" % int(ship.get("hp", 100)),
		"shield=%d" % int(ship.get("shield", 0)),
		"power=%d" % int(ship.get("power", 0)),
		"max_power=%d" % int(ship.get("max_power", 500)),
		"credits=%d" % int(ship.get("credits", 0)),
		"slot_hp='%s'" % _escape(slot_hp_json)
	]
	for col in OPTIONAL_SHIP_INT_COLUMNS:
		_append_optional_ship_set(sets, ship, col, "int")
	for col in OPTIONAL_SHIP_FLOAT_COLUMNS:
		_append_optional_ship_set(sets, ship, col, "float")
	for col in OPTIONAL_SHIP_STRING_COLUMNS:
		_append_optional_ship_set(sets, ship, col, "string")
	for col in OPTIONAL_SHIP_BOOL_COLUMNS:
		_append_optional_ship_set(sets, ship, col, "bool")
	_query("UPDATE ships SET %s WHERE player_id=%d" % [", ".join(sets), player_id])

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

	# 保存仓库，以内存快照为准，避免已移除物品在 DB 中残留
	_query("DELETE FROM inventory WHERE player_id=%d" % player_id)
	for component_id in player.get("inventory", {}).keys():
		var quantity = int(player["inventory"][component_id])
		if quantity > 0:
			_query("INSERT INTO inventory (player_id, component_id, quantity) VALUES (%d, '%s', %d)" % [
				player_id, _escape(component_id), quantity
			])

	# 保存装配组件，统一使用 {component_id: slot}
	_query("DELETE FROM ship_components WHERE player_id=%d" % player_id)
	for component_id in player.get("components", {}).keys():
		var slot = str(player["components"][component_id])
		if slot != "":
			_query("INSERT INTO ship_components (player_id, slot, component_id) VALUES (%d, '%s', '%s')" % [
				player_id, _escape(slot), _escape(component_id)
			])

func install_component(player_id: int, slot: String, component_id: String) -> void:
	_query("DELETE FROM ship_components WHERE player_id=%d AND component_id='%s'" % [
		player_id, _escape(component_id)
	])
	_query("INSERT INTO ship_components (player_id, slot, component_id) VALUES (%d, '%s', '%s')" % [
		player_id, _escape(slot), _escape(component_id)
	])

func remove_component(player_id: int, component_id: String) -> void:
	_query("DELETE FROM ship_components WHERE player_id=%d AND component_id='%s'" % [
		player_id, _escape(component_id)
	])

func adjust_inventory(player_id: int, component_id: String, delta: int) -> void:
	if delta == 0:
		return
	if delta > 0:
		_query("INSERT INTO inventory (player_id, component_id, quantity) VALUES (%d, '%s', %d) ON DUPLICATE KEY UPDATE quantity=quantity+%d" % [
			player_id, _escape(component_id), delta, delta
		])
	else:
		var amount = abs(delta)
		_query("UPDATE inventory SET quantity=GREATEST(0, quantity-%d) WHERE player_id=%d AND component_id='%s'" % [
			amount, player_id, _escape(component_id)
		])
		_query("DELETE FROM inventory WHERE player_id=%d AND component_id='%s' AND quantity<=0" % [
			player_id, _escape(component_id)
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

func _append_optional_ship_set(sets: Array, ship: Dictionary, col: String, kind: String) -> void:
	if not _ship_columns.has(col):
		return
	match kind:
		"int":
			sets.append("%s=%d" % [col, int(ship.get(col, 0))])
		"float":
			sets.append("%s=%f" % [col, float(ship.get(col, 0.0))])
		"string":
			sets.append("%s='%s'" % [col, _escape(str(ship.get(col, "")))])
		"bool":
			sets.append("%s=%d" % [col, 1 if ship.get(col, false) else 0])

func _row_to_dict(fields: Array, values: Array) -> Dictionary:
	var row = {}
	for i in range(fields.size()):
		row[fields[i]] = values[i] if i < values.size() else "NULL"
	return row

func _row_int(row: Dictionary, key: String, fallback: int = 0) -> int:
	var value = str(row.get(key, "NULL"))
	if value == "" or value == "NULL":
		return fallback
	return int(value)

func _row_float(row: Dictionary, key: String, fallback: float = 0.0) -> float:
	var value = str(row.get(key, "NULL"))
	if value == "" or value == "NULL":
		return fallback
	return float(value)

func _row_bool(row: Dictionary, key: String, fallback: bool = false) -> bool:
	var value = str(row.get(key, "NULL")).to_lower()
	if value == "" or value == "null":
		return fallback
	return value == "1" or value == "true" or value == "yes"

func _hydrate_runtime_ship_state(player: Dictionary) -> void:
	var ship = player.get("ship", {})
	if ship.is_empty():
		return
	var status = ship.get("status", "docked")
	if status == "in_transit":
		var current_poi = ship.get("current_poi", "")
		var target_poi = ship.get("target_poi", "")
		var distance = float(ship.get("travel_distance", 0.0))
		if distance <= 0.0 and target_poi != "":
			distance = float(ActionHandler._get_distance(current_poi, target_poi))
		ship["travel_distance"] = distance
		ship["target_danger"] = ActionHandler.POI_DANGER.get(target_poi, 0)
		if int(ship.get("total_power_cost", 0)) <= 0:
			ship["total_power_cost"] = _calc_travel_power_cost(player, int(distance))
		if not ship.has("power_used_so_far"):
			ship["power_used_so_far"] = 0
		if not ship.has("last_encounter_dist"):
			ship["last_encounter_dist"] = 0.0
		if ship.get("mining_resource", "") == "":
			ship["mining_resource"] = _pick_default_mining_resource(target_poi)
		if float(ship.get("mining_rate", 0.0)) <= 0.0:
			ship["mining_rate"] = _calc_mining_rate(player)
	elif status == "working":
		var current_poi = ship.get("current_poi", "")
		if ship.get("mining_resource", "") == "":
			ship["mining_resource"] = _pick_default_mining_resource(current_poi)
		if float(ship.get("mining_rate", 0.0)) <= 0.0:
			ship["mining_rate"] = _calc_mining_rate(player)
		if not ship.has("last_work_tick") or float(ship.get("last_work_tick", 0.0)) <= 0.0:
			ship["last_work_tick"] = Time.get_unix_time_from_system()

func _calc_travel_power_cost(player: Dictionary, distance: int) -> int:
	var p_cost_total = ActionHandler._calc_p_cost(player)
	var base_dist_cost = distance * 10
	if ActionHandler._count_prefix(player, "singularity") >= 4:
		p_cost_total = int(p_cost_total * 0.5)
	if ActionHandler._has_trait(player, "engineer_t1_efficient"):
		base_dist_cost = int(base_dist_cost * 0.85)
	return base_dist_cost + p_cost_total

func _calc_mining_rate(player: Dictionary) -> float:
	var total_mining_rate: float = 0.0
	for comp_id in player.get("components", {}).keys():
		total_mining_rate += ActionHandler.COMPONENT_DATA.get(comp_id, {}).get("mining_rate", 0)
	if ActionHandler._count_prefix(player, "ironclad") >= 4:
		total_mining_rate *= 1.30
	return total_mining_rate

func _pick_default_mining_resource(poi_id: String) -> String:
	var res_pool = ActionHandler.POI_RESOURCES.get(poi_id, [])
	return res_pool[0] if res_pool.size() > 0 else ""

func _escape(s: String) -> String:
	# 基础 SQL 转义（防注入）
	return s.replace("'", "''").replace("\\", "\\\\")
