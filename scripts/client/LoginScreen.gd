class_name LoginScreen
extends Control

@onready var username_input: LineEdit = $VBox/UsernameInput
@onready var password_input: LineEdit = $VBox/PasswordInput
@onready var login_btn: Button = $VBox/LoginBtn
@onready var register_btn: Button = $VBox/RegisterBtn
@onready var status_label: Label = $VBox/StatusLabel

var _client: Node

func _ready() -> void:
	_client = get_tree().get_root().get_node("ClientMain")
	password_input.secret = true
	login_btn.pressed.connect(_on_login_pressed)
	register_btn.pressed.connect(_on_register_pressed)
	username_input.text_submitted.connect(func(_t): _on_login_pressed())
	password_input.text_submitted.connect(func(_t): _on_login_pressed())

func _on_login_pressed() -> void:
	var username = username_input.text.strip_edges()
	var password = password_input.text

	if username == "":
		status_label.text = "请输入用户名"
		return
	if password == "":
		status_label.text = "请输入密码"
		return

	login_btn.disabled = true
	status_label.text = "登录中..."
	_client.login(username, password)

func _on_register_pressed() -> void:
	var username = username_input.text.strip_edges()
	var password = password_input.text

	if username == "" or password == "":
		status_label.text = "请输入用户名和密码"
		return

	login_btn.disabled = true
	register_btn.disabled = true
	status_label.text = "注册中..."
	_client.register(username, password)

func show_error(msg: String) -> void:
	status_label.text = msg
	login_btn.disabled = false
	register_btn.disabled = false
