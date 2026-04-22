class_name NetworkClient
extends Node

# 客户端网络层 - WebSocket 连接管理

const SERVER_URL = "ws://8.161.225.239:7777"
const RECONNECT_DELAY = 3.0

signal connected()
signal disconnected()
signal message_received(data: Dictionary)

var _ws: WebSocketPeer
var _reconnect_timer: float = 0.0
var _is_connected: bool = false
var _pending_messages: Array = []

func _ready() -> void:
	_ws = WebSocketPeer.new()
	connect_to_server()

func connect_to_server() -> void:
	print("[Client] 连接到服务器: " + SERVER_URL)
	var err = _ws.connect_to_url(SERVER_URL)
	if err != OK:
		push_error("[Client] 连接失败: " + str(err))

func _process(delta: float) -> void:
	_ws.poll()
	var state = _ws.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _is_connected:
				_is_connected = true
				print("[Client] 已连接到服务器")
				connected.emit()
				# 发送积压的消息
				for msg in _pending_messages:
					_ws.send_text(JSON.stringify(msg))
				_pending_messages.clear()

			# 读取消息
			while _ws.get_available_packet_count() > 0:
				var packet = _ws.get_packet()
				var json_str = packet.get_string_from_utf8()
				var data = JSON.parse_string(json_str)
				if data != null:
					message_received.emit(data)

		WebSocketPeer.STATE_CLOSED:
			if _is_connected:
				_is_connected = false
				print("[Client] 连接断开，%.1f 秒后重连" % RECONNECT_DELAY)
				disconnected.emit()
			_reconnect_timer += delta
			if _reconnect_timer >= RECONNECT_DELAY:
				_reconnect_timer = 0.0
				connect_to_server()

func send(data: Dictionary) -> void:
	if _is_connected and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(data))
	else:
		# 缓存到待发送队列
		_pending_messages.append(data)

func send_login(username: String, password: String) -> void:
	# 密码使用 SHA256 哈希
	var pwd_hash = password.sha256_text()
	send({"type": "login", "username": username, "password": pwd_hash})

func send_action(action: String, payload: Dictionary = {}) -> void:
	send({"type": "action", "action": action, "payload": payload})

func send_ping() -> void:
	send({"type": "ping"})

func is_connected_to_server() -> bool:
	return _is_connected
