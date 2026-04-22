class_name DatabaseManager
extends Node

# 数据库管理器 - 封装所有 MySQL 操作
# 通过 GDScript 调用本地 mysql CLI 执行 SQL（服务端专用）

const DB_HOST = "127.0.0.1"
const DB_PORT = 3306
const DB_NAME = "starriver"
const DB_USER = "starriver"
const DB_PASS = "StarRiver2026!"

var _mysql_cmd: String = ""

func connect_db() -> bool:
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

	print("[DB] 数据库连接成功: %s@%s/%s" % [DB_USER, DB_HOST, DB_NAME])
	return true

func _query(sql: String) -> Array:
	var args = [
		"-h", DB_HOST,
		"-P", str(DB_PORT),
		"-u", DB_USER,
		"-p" + DB_PASS,
		"-D", DB_NAME,
		"--batch",
		"--skip-column-names",
		"-e", sql
	]
	var output = []
	var exit_code = OS.execute(_mysql_cmd, args, output, true, true)
	if exit_code != 0:
		push_error("[DB] SQL 执行失败: " + sql)
		return []

	var rows = []
	var raw = output[0] if output.size() > 0 else ""
	for line in raw.split("\n"):
		if line.strip_edges() != "":
			rows.append(line.split("\t"))
	return rows

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
	var ship_rows = _query("SELECT status, current_poi, target_poi, depart_time, eta, hp, shield, power, max_power, credits FROM ships WHERE player_id=%d LIMIT 1" % player_id)
	if ship_rows.size() > 0:
		var r = ship_rows[0]
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
			"credits": int(r[9])
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
	var crew_rows = _query("SELECT slot, tier, trait_id, name, salary, debt FROM crew WHERE player_id=%d" % player_id)
	player["crew"] = []
	for r in crew_rows:
		player["crew"].append({
			"slot": r[0], "tier": r[1], "trait_id": r[2],
			"name": r[3], "salary": int(r[4]), "debt": int(r[5])
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

	return player

func _default_ship(player_id: int) -> Dictionary:
	var ship = {
		"player_id": player_id,
		"status": "docked",
		"current_poi": "CYG-ST-01",
		"target_poi": "",
		"depart_time": 0.0,
		"eta": 0.0,
		"hp": 1000,
		"shield": 0,
		"power": 500,
		"max_power": 500,
		"credits": 1000
	}
	# 插入数据库
	_query("INSERT INTO ships (player_id, status, current_poi, hp, shield, power, max_power, credits) VALUES (%d, 'docked', 'CYG-ST-01', 1000, 0, 500, 500, 1000)" % player_id)
	return ship

func save_ship(ship: Dictionary) -> void:
	var player_id = ship.get("player_id", 0)
	if player_id == 0:
		return
	_query("UPDATE ships SET status='%s', current_poi='%s', target_poi='%s', hp=%d, shield=%d, power=%d, max_power=%d, credits=%d WHERE player_id=%d" % [
		_escape(ship.get("status", "docked")),
		_escape(ship.get("current_poi", "")),
		_escape(ship.get("target_poi", "")),
		ship.get("hp", 100),
		ship.get("shield", 0),
		ship.get("power", 0),
		ship.get("max_power", 500),
		ship.get("credits", 0),
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
