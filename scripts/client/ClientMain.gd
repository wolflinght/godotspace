class_name ClientMain
extends Node

const LOCAL_PROTOTYPE_SETTING = "star_river/local_prototype_enabled"
const LOCAL_SIM_TICK = 1.0
const LocalPrototypeData = preload("res://scripts/client/LocalPrototype.gd")

@onready var network: NetworkClient = $NetworkClient
@onready var game_state: GameState = $GameState
@onready var ui: UI = $UI

var _ping_timer: float = 0.0
var _local_mode: bool = false
var _local_tick_timer: float = 0.0
const PING_INTERVAL = 30.0

func _ready() -> void:
	_local_mode = ProjectSettings.get_setting(LOCAL_PROTOTYPE_SETTING, true)
	if _local_mode:
		network.set_network_enabled(false)
		game_state.apply_snapshot(LocalPrototypeData.build_snapshot())
		ui.show_main_screen()
		ui.show_mission_notification("本地原型模式：已载入试航存档")
		return

	network.connected.connect(_on_connected)
	network.disconnected.connect(_on_disconnected)
	network.message_received.connect(_on_message_received)

func _process(delta: float) -> void:
	if _local_mode:
		_process_local(delta)
		return

	if network.is_connected_to_server():
		_ping_timer += delta
		if _ping_timer >= PING_INTERVAL:
			_ping_timer = 0.0
			network.send_ping()

func _on_connected() -> void:
	var saved = _load_saved_credentials()
	if saved.size() > 0:
		network.send_login(saved["username"], saved["password_raw"])
	else:
		ui.show_login_screen()

func _on_disconnected() -> void:
	ui.show_connecting_screen()

func _on_message_received(data: Dictionary) -> void:
	var msg_type: String = data.get("type", "")
	match msg_type:
		"state_snapshot":
			game_state.apply_snapshot(data.get("payload", {}))
			ui.show_main_screen()
		"state_update":
			game_state.apply_state_update(data.get("payload", {}))
			ui.update_ship_status()
		"event":
			var event_name = data.get("event", "")
			var payload = data.get("payload", {})
			game_state.apply_event(event_name, payload)
			_handle_event(event_name, payload)
		"action_result":
			if not data.get("success", true):
				ui.show_error(data.get("message", "操作失败"))
			else:
				_apply_action_result(data)
			ui.handle_action_result(data)
		"error":
			var msg = data.get("message", "未知错误")
			# 登录失败时通知登录界面
			var login_screen = ui.get_node_or_null("LoginScreen")
			if login_screen and login_screen.visible:
				login_screen.show_error(msg)
			else:
				ui.show_error(msg)
		"pong":
			pass

func _apply_action_result(data: Dictionary) -> void:
	# 将 action_result 中的增量数据同步到 GameState，避免重新登录才刷新
	var action = data.get("action", "")
	match action:
		"recruit":
			var new_crew = data.get("crew", {})
			if not new_crew.is_empty():
				game_state.crew.append(new_crew)
				game_state.ship["credits"] = game_state.ship.get("credits", 0) - data.get("cost", 0)
				game_state.state_updated.emit()
		"fire_crew":
			var role = data.get("role", "")
			game_state.crew = game_state.crew.filter(func(c): return c.get("slot") != role)
			game_state.state_updated.emit()
		"buy_fuel":
			var p = data.get("payload", {})
			if p.has("power"):
				game_state.ship["power"] = p["power"]
			if p.has("credits"):
				game_state.ship["credits"] = p["credits"]
			game_state.state_updated.emit()
		"equip":
			var equip_component_id = data.get("component_id", "")
			var slot = data.get("slot", "")
			if equip_component_id != "" and slot != "":
				game_state.components[equip_component_id] = slot
				var current_qty = game_state.inventory.get(equip_component_id, 0)
				if current_qty > 1:
					game_state.inventory[equip_component_id] = current_qty - 1
				else:
					game_state.inventory.erase(equip_component_id)
				game_state.state_updated.emit()
		"unequip":
			var unequip_component_id = data.get("component_id", "")
			if unequip_component_id != "":
				game_state.components.erase(unequip_component_id)
				game_state.inventory[unequip_component_id] = game_state.inventory.get(unequip_component_id, 0) + 1
				game_state.state_updated.emit()
		"accept_mission":
			var mid = data.get("mission_id", "")
			var deadline = data.get("deadline", 0.0)
			if mid != "":
				# 更新或添加到本地任务列表
				var found = false
				for m in game_state.missions:
					if m.get("mission_id") == mid:
						m["status"] = "active"
						m["deadline"] = deadline
						m["progress"] = 0
						found = true
						break
				if not found:
					game_state.missions.append({"mission_id": mid, "status": "active", "deadline": deadline, "progress": 0})
				game_state.state_updated.emit()

func _handle_event(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"encounter":
			ui.show_combat_log(payload)
		"arrival":
			ui.show_arrival_notification(payload.get("poi", ""))
		"stranded":
			ui.show_stranded_alert()
		"global_event":
			ui.show_global_event(payload)
		"mission_completed":
			var mid = payload.get("mission_id", "")
			var reward = payload.get("reward", 0)
			game_state.apply_mission_status(mid, "completed")
			ui.show_mission_notification("任务完成：%s  +%d ★" % [mid, reward], false)
		"mission_failed":
			var mid = payload.get("mission_id", "")
			var penalty = payload.get("penalty", 0)
			game_state.apply_mission_status(mid, "failed")
			var msg = "任务失败：%s" % mid
			if penalty > 0:
				msg += "  违约金 -%d ★" % penalty
			ui.show_mission_notification(msg, true)
		"salary_warning":
			ui.show_mission_notification(payload.get("message", "薪水不足！"), true)
		"poi_depleted":
			ui.show_mission_notification(payload.get("message", "资源枯竭"), true)
		"sos_distress":
			ui.show_mission_notification(payload.get("message", ""), false)
		"slot_broken":
			ui.show_mission_notification(payload.get("message", "骨架受损！"), true)
		"crew_banter":
			ui.show_crew_banter(payload.get("log", ""))

func _process_local(delta: float) -> void:
	_local_tick_timer += delta
	if _local_tick_timer < LOCAL_SIM_TICK:
		return
	_local_tick_timer = 0.0

	var status = game_state.ship.get("status", "docked")
	match status:
		"in_transit":
			if game_state.get_eta_remaining_seconds() <= 0.0:
				var arrived_poi = game_state.ship.get("target_poi", "")
				game_state.ship["status"] = "working"
				game_state.ship["current_poi"] = arrived_poi
				game_state.ship["target_poi"] = ""
				game_state.ship["eta"] = 0.0
				game_state.state_updated.emit()
				_handle_event("arrival", {"poi": LocalPrototypeData.poi_name(arrived_poi)})
		"docked":
			if game_state.ship.get("charging", false):
				var max_power = int(game_state.ship.get("max_power", 0))
				var next_power = min(max_power, int(game_state.ship.get("power", 0)) + 20)
				game_state.ship["power"] = next_power
				if next_power >= max_power:
					game_state.ship["charging"] = false
				game_state.state_updated.emit()
		"working":
			var poi = game_state.ship.get("current_poi", "")
			var resource_key = "暗面废料" if poi.begins_with("CYG-RU") else "钛"
			game_state.resources[resource_key] = float(game_state.resources.get(resource_key, 0.0)) + 18.0
			game_state.ship["power"] = max(0, int(game_state.ship.get("power", 0)) - 1)
			game_state.state_updated.emit()
			if int(game_state.ship.get("power", 0)) <= 0:
				game_state.ship["status"] = "stranded"
				game_state.state_updated.emit()
				_handle_event("stranded", {})

func _send_or_apply_local_action(action: String, payload: Dictionary = {}) -> void:
	if not _local_mode:
		network.send_action(action, payload)
		return

	var result = _apply_local_action(action, payload)
	if not result.get("success", false):
		ui.show_error(result.get("message", "操作失败"))
	ui.handle_action_result(result)

func _apply_local_action(action: String, payload: Dictionary = {}) -> Dictionary:
	var result = {"type": "action_result", "action": action, "success": true}
	match action:
		"depart":
			var target_poi = str(payload.get("target_poi", ""))
			var current_poi = str(game_state.ship.get("current_poi", ""))
			if not LocalPrototypeData.POI_CATALOG.has(target_poi):
				return _local_error(action, "未知目的地")
			if target_poi == current_poi:
				return _local_error(action, "已经在该地点")
			var power_cost = LocalPrototypeData.estimate_power_cost(current_poi, target_poi)
			if int(game_state.ship.get("power", 0)) < power_cost:
				return _local_error(action, "电力不足，无法起航")
			game_state.ship["status"] = "in_transit"
			game_state.ship["target_poi"] = target_poi
			game_state.ship["eta"] = Time.get_unix_time_from_system() + LocalPrototypeData.ARRIVAL_SECONDS
			game_state.ship["power"] = int(game_state.ship.get("power", 0)) - power_cost
			game_state.ship["charging"] = false
			result["payload"] = {
				"target_poi": LocalPrototypeData.poi_name(target_poi),
				"eta_minutes": LocalPrototypeData.ARRIVAL_SECONDS / 60.0,
				"total_power_cost": power_cost
			}
		"dock":
			game_state.ship["status"] = "docked"
			game_state.ship["target_poi"] = ""
			game_state.ship["eta"] = 0.0
		"connect_grid":
			game_state.ship["charging"] = true
		"buy_fuel":
			var amount = max(0, int(payload.get("amount", 0)))
			if amount == 0:
				return _local_error(action, "燃料数量无效")
			var cost = amount * LocalPrototypeData.FUEL_UNIT_PRICE
			if int(game_state.ship.get("credits", 0)) < cost:
				return _local_error(action, "星币不足")
			var max_power = int(game_state.ship.get("max_power", LocalPrototypeData.MAX_POWER))
			game_state.ship["credits"] = int(game_state.ship.get("credits", 0)) - cost
			game_state.ship["power"] = min(max_power, int(game_state.ship.get("power", 0)) + amount * LocalPrototypeData.FUEL_POWER_PER_UNIT)
			result["payload"] = {"power": game_state.ship["power"], "credits": game_state.ship["credits"]}
		"equip":
			var equip_component_id = str(payload.get("component_id", ""))
			var slot = str(payload.get("slot", ""))
			var current_qty = int(game_state.inventory.get(equip_component_id, 0))
			if current_qty <= 0:
				return _local_error(action, "仓库中没有该组件")
			game_state.components[equip_component_id] = slot
			if current_qty > 1:
				game_state.inventory[equip_component_id] = current_qty - 1
			else:
				game_state.inventory.erase(equip_component_id)
			result["component_id"] = equip_component_id
			result["slot"] = slot
		"unequip":
			var unequip_component_id = str(payload.get("component_id", ""))
			if not game_state.components.has(unequip_component_id):
				return _local_error(action, "该组件未装配")
			game_state.components.erase(unequip_component_id)
			game_state.inventory[unequip_component_id] = int(game_state.inventory.get(unequip_component_id, 0)) + 1
			result["component_id"] = unequip_component_id
		"accept_mission":
			var mid = str(payload.get("mission_id", ""))
			var deadline_hours = float(payload.get("deadline_hours", 24.0))
			game_state.missions.append({
				"mission_id": mid,
				"status": "active",
				"deadline": Time.get_unix_time_from_system() + deadline_hours * 3600.0,
				"progress": 0
			})
			result["mission_id"] = mid
			result["deadline"] = Time.get_unix_time_from_system() + deadline_hours * 3600.0
		"recruit":
			var role = str(payload.get("role", "captain"))
			var tier = str(payload.get("tier", "T1"))
			var cost = {"T1": 300, "T2": 800, "T3": 2500}.get(tier, 300)
			if int(game_state.ship.get("credits", 0)) < cost:
				return _local_error(action, "星币不足")
			game_state.ship["credits"] = int(game_state.ship.get("credits", 0)) - cost
			var new_crew = {
				"slot": role,
				"name": _local_crew_name(role, tier),
				"tier": tier,
				"trait_id": _local_trait_id(role, tier),
				"salary": int(cost / 10),
				"debt": 0
			}
			game_state.crew = game_state.crew.filter(func(c): return c.get("slot", "") != role)
			game_state.crew.append(new_crew)
			result["crew"] = new_crew
			result["cost"] = cost
			result["trait_desc"] = "本地试航船员特性"
		"fire_crew":
			var fire_role = str(payload.get("role", ""))
			game_state.crew = game_state.crew.filter(func(c): return c.get("slot", "") != fire_role)
			result["role"] = fire_role
		"sos":
			game_state.ship["status"] = "docked"
			game_state.ship["current_poi"] = LocalPrototypeData.START_POI
			game_state.ship["target_poi"] = ""
			game_state.ship["power"] = 120
			result["sos_text"] = "救援艇已将你拖回铁砧-IV"
		_:
			return _local_error(action, "本地原型暂不支持该操作")

	game_state.state_updated.emit()
	return result

func _local_error(action: String, message: String) -> Dictionary:
	return {"type": "action_result", "action": action, "success": false, "message": message}

func _local_crew_name(role: String, tier: String) -> String:
	var names = {
		"captain": {"T1": "周衡", "T2": "沈星河", "T3": "洛伊"},
		"gunner": {"T1": "秦烁", "T2": "赤霖", "T3": "牙七"},
		"engineer": {"T1": "米娅", "T2": "韩泊", "T3": "白隼"}
	}
	return names.get(role, {}).get(tier, "临时船员")

func _local_trait_id(role: String, tier: String) -> String:
	var traits = {
		"captain": {"T1": "captain_t1_ironclad", "T2": "captain_t2_lone_wolf", "T3": "captain_t3_capitalist"},
		"gunner": {"T1": "gunner_t1_kinetic", "T2": "gunner_t2_overload", "T3": "gunner_t3_singularity"},
		"engineer": {"T1": "engineer_t1_efficient", "T2": "engineer_t2_shield_geek", "T3": "engineer_t3_jump_resonance"}
	}
	return traits.get(role, {}).get(tier, "")

# 操作接口
func login(username: String, password: String) -> void:
	if _local_mode:
		ui.show_main_screen()
		return
	_save_credentials(username, password)
	network.send_login(username, password)

func register(username: String, password: String) -> void:
	if _local_mode:
		ui.show_main_screen()
		return
	network.send({"type": "register", "username": username, "password": password.sha256_text()})

func action_depart(target_poi: String) -> void:
	_send_or_apply_local_action("depart", {"target_poi": target_poi})

func action_dock() -> void:
	_send_or_apply_local_action("dock")

func action_buy_fuel(amount: int) -> void:
	_send_or_apply_local_action("buy_fuel", {"amount": amount})

func action_equip(component_id: String, slot: String) -> void:
	_send_or_apply_local_action("equip", {"component_id": component_id, "slot": slot})

func action_unequip(component_id: String) -> void:
	_send_or_apply_local_action("unequip", {"component_id": component_id})

func action_accept_mission(mission_id: String, deadline_hours: float) -> void:
	_send_or_apply_local_action("accept_mission", {"mission_id": mission_id, "deadline_hours": deadline_hours})

func action_recruit(role: String, tier: String) -> void:
	_send_or_apply_local_action("recruit", {"role": role, "tier": tier})

func action_fire_crew(role: String) -> void:
	_send_or_apply_local_action("fire_crew", {"role": role})

func action_connect_grid() -> void:
	_send_or_apply_local_action("connect_grid")

func action_sos() -> void:
	_send_or_apply_local_action("sos")

func _save_credentials(username: String, password: String) -> void:
	var config = ConfigFile.new()
	config.set_value("auth", "username", username)
	config.set_value("auth", "password_raw", password)
	config.save("user://credentials.cfg")

func _load_saved_credentials() -> Dictionary:
	var config = ConfigFile.new()
	if config.load("user://credentials.cfg") != OK:
		return {}
	return {
		"username": config.get_value("auth", "username", ""),
		"password_raw": config.get_value("auth", "password_raw", "")
	}
