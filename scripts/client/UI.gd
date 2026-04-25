class_name UI
extends CanvasLayer

# UI 总控制器 - 管理各界面的显示切换

@onready var login_screen: Control = $LoginScreen
@onready var connecting_screen: Control = $ConnectingScreen
@onready var main_screen: Control = $MainScreen
@onready var error_popup: AcceptDialog = $ErrorPopup

var _client: Node  # ClientMain 引用

func _ready() -> void:
	_client = get_parent()
	show_connecting_screen()

func show_login_screen() -> void:
	login_screen.visible = true
	connecting_screen.visible = false
	main_screen.visible = false

func show_connecting_screen() -> void:
	login_screen.visible = false
	connecting_screen.visible = true
	main_screen.visible = false

func show_main_screen() -> void:
	login_screen.visible = false
	connecting_screen.visible = false
	main_screen.visible = true

func show_error(msg: String) -> void:
	error_popup.dialog_text = msg
	error_popup.popup_centered()

func update_ship_status() -> void:
	if main_screen.visible:
		main_screen.refresh()

func handle_action_result(data: Dictionary) -> void:
	if main_screen.visible:
		main_screen.on_action_result(data)

func show_combat_log(payload: Dictionary) -> void:
	if main_screen.visible:
		main_screen.show_combat_log(payload)

func show_arrival_notification(poi: String) -> void:
	if main_screen.visible:
		main_screen.show_notification("已抵达 " + poi + "，开始作业")

func show_stranded_alert() -> void:
	if main_screen.visible:
		main_screen.show_notification("⚠ 电力耗尽！飞船进入抛锚状态！", true)

func show_global_event(payload: Dictionary) -> void:
	if main_screen.visible:
		main_screen.show_notification(payload.get("message", "全服事件"))

func show_mission_notification(msg: String, is_failure: bool = false) -> void:
	if main_screen.visible:
		main_screen.show_notification(msg, is_failure)
		main_screen.refresh()

func show_crew_banter(log_text: String) -> void:
	if main_screen.visible and log_text != "":
		main_screen.append_log("[color=#aaddff]── 通讯频道 ──[/color]\n" + log_text)
