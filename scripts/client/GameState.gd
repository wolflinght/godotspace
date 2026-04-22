class_name GameState
extends Node

# 客户端游戏状态管理 - 存储从服务端同步的所有状态

signal state_updated()
signal event_received(event_name: String, payload: Dictionary)

# 玩家状态
var player_id: int = 0
var username: String = ""

# 飞船状态
var ship: Dictionary = {
	"status": "docked",
	"current_poi": "",
	"target_poi": "",
	"hp": 1000,
	"shield": 0,
	"power": 500,
	"max_power": 500,
	"credits": 0,
	"eta": 0.0
}

# 资源
var resources: Dictionary = {}

# 装配组件
var components: Dictionary = {}

# 船员
var crew: Array = []

# 任务
var missions: Array = []

# 仓库
var inventory: Dictionary = {}

func apply_snapshot(data: Dictionary) -> void:
	player_id = data.get("player_id", 0)
	ship = data.get("ship", ship)
	resources = data.get("resources", {})
	components = data.get("components", {})
	crew = data.get("crew", [])
	missions = data.get("missions", [])
	inventory = data.get("inventory", {})
	state_updated.emit()

func apply_state_update(payload: Dictionary) -> void:
	for key in payload.keys():
		ship[key] = payload[key]
	state_updated.emit()

func apply_event(event_name: String, payload: Dictionary) -> void:
	event_received.emit(event_name, payload)

func get_ship_status() -> String:
	return ship.get("status", "docked")

func get_power_percent() -> float:
	var max_p = ship.get("max_power", 500)
	if max_p <= 0:
		return 0.0
	return float(ship.get("power", 0)) / float(max_p)

func get_eta_remaining_seconds() -> float:
	var eta = ship.get("eta", 0.0)
	var now = Time.get_unix_time_from_system()
	return max(0.0, eta - now)

func get_resource(resource_type: String) -> float:
	return resources.get(resource_type, 0.0)

func get_total_dps() -> int:
	# 客户端只做展示，不参与计算
	return ship.get("dps", 0)
