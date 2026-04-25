class_name MainScreen
extends Control

# ── 顶部状态栏 ─────────────────────────────────────────────────────────────────
@onready var status_primary: Label     = $TopBar/TopHBox/StatusCard/StatusContent/StatusPrimary
@onready var status_secondary: Label   = $TopBar/TopHBox/StatusCard/StatusContent/StatusSecondary
@onready var poi_name_label: Label     = $TopBar/TopHBox/PoiCard/PoiContent/PoiNameLabel
@onready var poi_coord_label: Label    = $TopBar/TopHBox/PoiCard/PoiContent/PoiCoordLabel
@onready var power_percent: Label      = $TopBar/TopHBox/PowerCard/PowerContent/PowerPercent
@onready var power_status_label: Label = $TopBar/TopHBox/PowerCard/PowerContent/PowerStatusLabel
@onready var hp_percent: Label         = $TopBar/TopHBox/HpCard/HpContent/HpPercent
@onready var hp_numeric_label: Label   = $TopBar/TopHBox/HpCard/HpContent/HpNumericLabel
@onready var cargo_percent: Label      = $TopBar/TopHBox/CargoCard/CargoContent/CargoPercent
@onready var cargo_numeric_label: Label = $TopBar/TopHBox/CargoCard/CargoContent/CargoNumericLabel
@onready var credits_amount_label: Label = $TopBar/TopHBox/CreditsCard/CreditsContent/CreditsAmountLabel
@onready var eta_label: Label          = $TopBar/TopHBox/EtaLabel

# ── 视觉中心三场景 ──────────────────────────────────────────────────────────────
@onready var visual_center: Control    = $VisualCenter
@onready var station_view: Control     = $VisualCenter/StationView
@onready var planet_view: Control      = $VisualCenter/PlanetView
@onready var transit_view: Control     = $VisualCenter/TransitView

# 空间站场景节点
@onready var poi_option: OptionButton  = $VisualCenter/StationView/StationBg/StationContent/OpsPanel/PoiOption
@onready var depart_btn: Button        = $VisualCenter/StationView/StationBg/StationContent/OpsPanel/DepartBtn
@onready var grid_btn: Button          = $VisualCenter/StationView/StationBg/StationContent/OpsPanel/GridBtn
@onready var fuel_spin: SpinBox        = $VisualCenter/StationView/StationBg/StationContent/OpsPanel/FuelRow/FuelSpin
@onready var fuel_btn: Button          = $VisualCenter/StationView/StationBg/StationContent/OpsPanel/FuelRow/FuelBtn
@onready var mission_list: ItemList    = $VisualCenter/StationView/StationBg/StationContent/MissionPanel/MissionHSplit/MissionList
@onready var active_mission_list: ItemList = $VisualCenter/StationView/StationBg/StationContent/MissionPanel/MissionHSplit/ActiveList
@onready var accept_btn: Button        = $VisualCenter/StationView/StationBg/StationContent/MissionPanel/MissionHSplit/MissionList/AcceptBtn
@onready var crew_roster: VBoxContainer = $VisualCenter/StationView/StationBg/StationContent/CrewPanel/CrewRoster
@onready var recruit_role_option: OptionButton = $VisualCenter/StationView/StationBg/StationContent/CrewPanel/RecruitPanel/RoleOption
@onready var recruit_tier_option: OptionButton = $VisualCenter/StationView/StationBg/StationContent/CrewPanel/RecruitPanel/TierOption
@onready var recruit_cost_label: Label = $VisualCenter/StationView/StationBg/StationContent/CrewPanel/RecruitPanel/CostLabel
@onready var recruit_btn: Button       = $VisualCenter/StationView/StationBg/StationContent/CrewPanel/RecruitPanel/RecruitBtn

# 星球场景节点
@onready var dock_btn: Button          = $VisualCenter/PlanetView/PlanetBg/PlanetContent/PlanetOpsPanel/DockBtn
@onready var planet_depart_btn: Button = $VisualCenter/PlanetView/PlanetBg/PlanetContent/PlanetOpsPanel/PlanetDepartBtn
@onready var sos_btn: Button           = $VisualCenter/PlanetView/PlanetBg/PlanetContent/PlanetOpsPanel/SosBtn
@onready var planet_poi_option: OptionButton = $VisualCenter/PlanetView/PlanetBg/PlanetContent/PlanetOpsPanel/PlanetPoiOption
@onready var planet_active_list: ItemList = $VisualCenter/PlanetView/PlanetBg/PlanetContent/PlanetMissionPanel/PlanetActiveList

# 航行中场景节点
@onready var transit_eta_label: Label  = $VisualCenter/TransitView/TransitBg/TransitContent/TransitInfoPanel/TransitEtaLabel
@onready var transit_route_label: Label = $VisualCenter/TransitView/TransitBg/TransitContent/TransitInfoPanel/TransitRouteLabel
@onready var log_box: RichTextLabel    = $VisualCenter/TransitView/TransitBg/TransitContent/TransitLogPanel/LogBox

# ── 底部面板 ───────────────────────────────────────────────────────────────────
@onready var slot_hbox: HBoxContainer  = $BottomPanel/TabContainer/TabSlots/SlotScroll/SlotHBox
@onready var equip_grid: GridContainer = $BottomPanel/TabContainer/TabCargo/CargoHBox/EquipSection/EquipGrid
@onready var slot_option: OptionButton = $BottomPanel/TabContainer/TabCargo/CargoHBox/EquipSection/EquipActionRow/SlotOption
@onready var equip_btn: Button         = $BottomPanel/TabContainer/TabCargo/CargoHBox/EquipSection/EquipActionRow/EquipBtn
@onready var unequip_btn: Button       = $BottomPanel/TabContainer/TabCargo/CargoHBox/EquipSection/EquipActionRow/UnequipBtn
@onready var ore_bars: VBoxContainer   = $BottomPanel/TabContainer/TabCargo/CargoHBox/OreSection/OreBars

# ── 通知 ───────────────────────────────────────────────────────────────────────
@onready var notification_label: Label = $NotificationLabel
@onready var notification_timer: Timer = $NotificationTimer

var _game_state: GameState
var _client: Node

# 当前选中的装备格（comp_id），用于装/卸
var _selected_equip_comp: String = ""
var _selected_equip_is_installed: bool = false

# 槽位容量（从 ActionHandler 同步）
const SKELETON_CAPACITY = {
	"nose": 8, "wings": 8, "hull": 10, "tail": 6, "core": 6, "cabin": 8
}
const SLOT_NAMES   = ["nose", "wings", "hull", "tail", "core"]
const SLOT_DISPLAY = ["舰头", "舰翼", "舰身", "舰尾", "能源"]
const ALL_SLOT_NAMES   = ["nose", "wings", "hull", "tail", "core", "cabin"]
const ALL_SLOT_DISPLAY = ["舰头", "舰翼", "舰身", "舰尾", "能源", "舰仓"]

# 矿石类型（从 Constants 同步）
const ORE_TYPES = ["钛", "精炼钛", "铱", "精炼铱", "暗面废料"]

# 默认货仓容量（cabin 组件决定）
const DEFAULT_CARGO_CAP = 80
# cabin 组件 cargo_cap 映射（与服务端 COMPONENT_DATA 保持一致）
const CABIN_CARGO_CAP = {
	"CGO-T1-001": 80,  "CGO-T1-002": 100,
	"CGO-T2-001": 180, "CGO-T2-002": 240,
	"CGO-T3-001": 500,
}
# cabin 组件装备仓容量映射
const CABIN_EQUIP_CAP = {
	"CGO-T1-001": 10, "CGO-T1-002": 12,
	"CGO-T2-001": 20, "CGO-T2-002": 24,
	"CGO-T3-001": 30,
}

const POI_INFO = {
	"CYG-SS-01": {"name": "铁砧-IV 采掘前哨", "is_station": true},
	"CYG-SS-02": {"name": "折光 科考平台",     "is_station": true},
	"CYG-SS-03": {"name": "锈蚀深渊 走私港",   "is_station": true},
	"CYG-PL-01": {"name": "塔洛斯 碎石星",     "is_station": false},
	"CYG-PL-02": {"name": "西风-7 气态巨星",   "is_station": false},
	"CYG-MO-01": {"name": "灰烬 T-09",         "is_station": false},
	"CYG-AS-01": {"name": "阿尔法碎石带",       "is_station": false},
	"CYG-RU-01": {"name": "第17号船坟地带",     "is_station": false},
	"CYG-RU-02": {"name": "废弃同位素精炼厂",   "is_station": false},
	"CYG-ST-01": {"name": "天鹅座 X-1 白矮星", "is_station": false},
}

const DANGER_LABEL = ["[安全]", "[危险1]", "[危险2]", "[危险3]", "[危险4]", "[危险5]"]
const POI_DANGER = {
	"CYG-SS-01": 0, "CYG-SS-02": 1, "CYG-SS-03": 2,
	"CYG-PL-01": 1, "CYG-PL-02": 2, "CYG-MO-01": 0,
	"CYG-AS-01": 3, "CYG-RU-01": 4, "CYG-RU-02": 4, "CYG-ST-01": 5,
}

const MISSION_CONFIG = {
	"CYG-DLV-001": {"name": "军火运输",     "desc": "将标准军火箱从铁砧-IV运到塔洛斯碎石星",  "type": "派送", "deadline_hours": 2,   "reward": 800},
	"CYG-DLV-002": {"name": "维修零件配送", "desc": "将维修零件包从铁砧-IV运到西风-7",        "type": "派送", "deadline_hours": 3,   "reward": 450},
	"CYG-DLV-003": {"name": "机密快递",     "desc": "将机密数据盒从折光平台运回铁砧-IV",      "type": "派送", "deadline_hours": 2,   "reward": 900},
	"CYG-DLV-004": {"name": "走私货运",     "desc": "从第17号船坟将走私冷藏舱运到锈蚀深渊",   "type": "派送", "deadline_hours": 1.5, "reward": 1400},
	"CYG-MIN-001": {"name": "钛矿采集",     "desc": "在塔洛斯碎石星采集5000单位钛",           "type": "采矿", "deadline_hours": 24,  "reward": 2200},
	"CYG-MIN-002": {"name": "卫星采矿",     "desc": "在灰烬T-09采集1500单位钛",               "type": "采矿", "deadline_hours": 24,  "reward": 800},
	"CYG-MIN-003": {"name": "碎石带作业",   "desc": "在阿尔法碎石带采集3000单位钛",           "type": "采矿", "deadline_hours": 24,  "reward": 1800},
	"CYG-MIN-004": {"name": "废料回收",     "desc": "在阿尔法碎石带采集800单位暗面废料",      "type": "采矿", "deadline_hours": 24,  "reward": 2600},
	"CYG-BTY-001": {"name": "清剿拾荒者",   "desc": "在阿尔法碎石带击杀8艘拾荒者武装艇",     "type": "讨伐", "deadline_hours": 6,   "reward": 2500},
	"CYG-BTY-002": {"name": "丧尸清除",     "desc": "在第17号船坟击杀20个机械丧尸",           "type": "讨伐", "deadline_hours": 6,   "reward": 3200},
	"CYG-BTY-003": {"name": "悬赏：獠牙-7", "desc": "击杀海盗头目獠牙-7",                    "type": "讨伐", "deadline_hours": 3,   "reward": 4800},
	"CYG-BTY-004": {"name": "极限辐射采样", "desc": "在X-1白矮星采集30份放射性样本",          "type": "讨伐", "deadline_hours": 2,   "reward": 6500},
}

const CREW_ROLES        = ["captain", "gunner", "engineer"]
const CREW_ROLE_DISPLAY = ["舰长", "炮手", "轮机长"]
const CREW_TIERS        = ["T1", "T2", "T3"]
const CREW_TIER_DISPLAY = ["T1 资深 (★300)", "T2 精英 (★800)", "T3 传奇 (★2500)"]
const RECRUIT_COST      = {"T1": 300, "T2": 800, "T3": 2500}

const TRAIT_DESC = {
	"captain_t1_ironclad":       "每件[铁骑]组件 DEF+5",
	"captain_t2_lone_wolf":      "独行时武器伤害+40%",
	"captain_t3_capitalist":     "薪水减半，遭遇战星币+30%",
	"gunner_t1_kinetic":         "[动能]武器+20%，无法装[电磁]",
	"gunner_t2_overload":        "武器+50%，每次开火自损10HP",
	"gunner_t3_singularity":     "首回合[奇点]武器必暴击无视闪避",
	"engineer_t1_efficient":     "航行耗电-15%",
	"engineer_t2_shield_geek":   "无护盾时SPD翻倍",
	"engineer_t3_jump_resonance":"跃迁耗电-500，抛锚时缓慢回电",
}

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_client = get_tree().get_root().get_node("ClientMain")
	_game_state = _client.get_node("GameState")
	_game_state.state_updated.connect(refresh)
	notification_timer.timeout.connect(_hide_notification)
	notification_label.visible = false

	# 初始化矿石进度条
	_build_ore_bars()

	# 初始化舰体槽位格
	_build_slot_panels()

	# 填充 POI 下拉列表
	_populate_poi_options()

	# 填充槽位下拉列表（装备 tab）
	for s in ALL_SLOT_DISPLAY:
		slot_option.add_item(s)

	# 按钮信号
	depart_btn.pressed.connect(_on_depart_pressed)
	planet_depart_btn.pressed.connect(_on_depart_pressed)
	dock_btn.pressed.connect(_on_dock_pressed)
	grid_btn.pressed.connect(_on_grid_pressed)
	fuel_btn.pressed.connect(_on_fuel_pressed)
	sos_btn.pressed.connect(_on_sos_pressed)
	equip_btn.pressed.connect(_on_equip_pressed)
	unequip_btn.pressed.connect(_on_unequip_pressed)
	accept_btn.pressed.connect(_on_accept_mission_pressed)

	# 船员 tab
	for r in CREW_ROLE_DISPLAY:
		recruit_role_option.add_item(r)
	for t in CREW_TIER_DISPLAY:
		recruit_tier_option.add_item(t)
	recruit_btn.pressed.connect(_on_recruit_pressed)
	recruit_tier_option.item_selected.connect(_on_tier_selected)
	_update_recruit_cost_label()

# 矿石切图资源路径（与 ORE_TYPES 顺序对应：钛/精炼钛/铱/精炼铱/暗面废料）
const ORE_ROW_TEXTURES = [
	"res://ui/ui_slices_starship_inventory/assets/x0034_y0821_w0764_h0048__row_titanium_ore.png",
	"res://ui/ui_slices_starship_inventory/assets/x0034_y0821_w0764_h0048__row_titanium_ore.png",
	"res://ui/ui_slices_starship_inventory/assets/x0034_y0877_w0764_h0050__row_crystal.png",
	"res://ui/ui_slices_starship_inventory/assets/x0034_y0877_w0764_h0050__row_crystal.png",
	"res://ui/ui_slices_starship_inventory/assets/x0034_y0934_w0764_h0051__row_rare_metal.png",
]
const ORE_ICON_TEXTURES: Array = []

# ── 矿石进度条构建 ─────────────────────────────────────────────────────────────
func _build_ore_bars() -> void:
	for i in range(ORE_TYPES.size()):
		var ore = ORE_TYPES[i]
		var row = Control.new()
		row.name = "Ore_" + ore
		row.custom_minimum_size = Vector2(0, 40)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# 行背景切图
		var row_bg = TextureRect.new()
		row_bg.layout_mode = 1
		row_bg.anchors_preset = Control.PRESET_FULL_RECT
		row_bg.anchor_right = 1.0
		row_bg.anchor_bottom = 1.0
		row_bg.stretch_mode = TextureRect.STRETCH_SCALE
		row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < ORE_ROW_TEXTURES.size():
			row_bg.texture = load(ORE_ROW_TEXTURES[i])
		row.add_child(row_bg)

		# 内容 HBox（叠加在背景上）
		var hbox = HBoxContainer.new()
		hbox.layout_mode = 1
		hbox.anchors_preset = Control.PRESET_FULL_RECT
		hbox.anchor_right = 1.0
		hbox.anchor_bottom = 1.0
		hbox.add_theme_constant_override("separation", 8)

		# 矿石图标
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if i < ORE_ICON_TEXTURES.size():
			icon.texture = load(ORE_ICON_TEXTURES[i])
		hbox.add_child(icon)

		var lbl = Label.new()
		lbl.custom_minimum_size = Vector2(60, 0)
		lbl.text = ore
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(lbl)

		var bar = ProgressBar.new()
		bar.name = "Bar"
		bar.custom_minimum_size = Vector2(180, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = DEFAULT_CARGO_CAP
		bar.value = 0
		bar.show_percentage = false
		hbox.add_child(bar)

		var val_lbl = Label.new()
		val_lbl.name = "Val"
		val_lbl.custom_minimum_size = Vector2(80, 0)
		val_lbl.text = "0 / %d" % DEFAULT_CARGO_CAP
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(val_lbl)

		row.add_child(hbox)
		ore_bars.add_child(row)

# ── 舰体槽位格构建 ─────────────────────────────────────────────────────────────
func _build_slot_panels() -> void:
	for i in range(SLOT_NAMES.size()):
		var slot = SLOT_NAMES[i]
		var cap  = SKELETON_CAPACITY[slot]

		var panel = VBoxContainer.new()
		panel.name = "SlotPanel_" + slot
		panel.add_theme_constant_override("separation", 4)
		panel.custom_minimum_size = Vector2(130, 0)

		# 标题行（名称 + 耐久）
		var title_row = HBoxContainer.new()
		title_row.name = "TitleRow"
		title_row.add_theme_constant_override("separation", 6)

		var name_lbl = Label.new()
		name_lbl.name = "NameLbl"
		name_lbl.text = SLOT_DISPLAY[i]
		name_lbl.modulate = Color(0.9, 0.85, 0.5)
		title_row.add_child(name_lbl)

		var hp_lbl = Label.new()
		hp_lbl.name = "HpLbl"
		hp_lbl.text = "HP—"
		hp_lbl.modulate = Color(0.6, 0.9, 0.6)
		hp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(hp_lbl)

		panel.add_child(title_row)

		# 组件格子
		var grid = GridContainer.new()
		grid.name = "Grid"
		grid.columns = 4

		for _j in range(cap):
			var cell = Button.new()
			cell.custom_minimum_size = Vector2(28, 28)
			cell.text = ""
			cell.tooltip_text = ""
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
			grid.add_child(cell)

		panel.add_child(grid)
		slot_hbox.add_child(panel)

# ── 填充 POI 下拉列表 ──────────────────────────────────────────────────────────
func _populate_poi_options() -> void:
	var current = _game_state.ship.get("current_poi", "") if _game_state else ""
	_fill_poi_option(poi_option, current)
	_fill_poi_option(planet_poi_option, current)

func _fill_poi_option(opt: OptionButton, exclude: String) -> void:
	opt.clear()
	for poi_id in POI_INFO.keys():
		if poi_id == exclude:
			continue
		var info = POI_INFO[poi_id]
		var danger = POI_DANGER.get(poi_id, 0)
		opt.add_item("%s %s" % [info["name"], DANGER_LABEL[danger]])
		opt.set_item_metadata(opt.item_count - 1, poi_id)

# ── _process：每帧更新 ETA ─────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _game_state and _game_state.get_ship_status() == "in_transit":
		var secs = _game_state.get_eta_remaining_seconds()
		var eta_str = "ETA: " + _format_time(secs)
		eta_label.text = eta_str
		eta_label.visible = true
		transit_eta_label.text = eta_str
	else:
		eta_label.visible = false

# ── refresh：主刷新 ───────────────────────────────────────────────────────────
func refresh() -> void:
	var ship   = _game_state.ship
	var status = ship.get("status", "docked")

	# ── 顶部状态栏 ──
	status_primary.text = Constants.SHIP_STATUS_NAMES.get(status, status)
	if status == "in_transit":
		status_secondary.text = "航行中..."
	elif status == "docked":
		status_secondary.text = "点击起航"
	elif status == "working":
		status_secondary.text = "作业中"
	elif status == "stranded":
		status_secondary.text = "SOS 求救"
	else:
		status_secondary.text = ""

	# 电量
	var power     = ship.get("power", 0)
	var max_power = ship.get("max_power", 500)
	var pct = float(power) / float(max_power) if max_power > 0 else 0.0
	power_percent.text = "%d%%" % int(pct * 100)
	if status == "docked" and ship.get("charging", false):
		power_status_label.text = "充电中"
		power_status_label.add_theme_color_override("font_color", Color(0.259, 0.843, 1.0, 1))
	elif pct >= 1.0:
		power_status_label.text = "已充满"
		power_status_label.add_theme_color_override("font_color", Color(0.259, 0.843, 1.0, 1))
	elif pct > 0.2:
		power_status_label.text = "%d / %d" % [power, max_power]
		power_status_label.add_theme_color_override("font_color", Color(0.604, 0.627, 0.651, 1))
	else:
		power_status_label.text = "电量不足！"
		power_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1))

	# 耐久度
	var hp     = ship.get("hp", 0)
	var max_hp = ship.get("max_hp", 1000)
	var hp_pct = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	hp_percent.text = "%d%%" % int(hp_pct * 100)
	hp_numeric_label.text = "%d / %d" % [hp, max_hp]

	# 位置
	var current = ship.get("current_poi", "")
	var target  = ship.get("target_poi", "")
	if target != "" and status == "in_transit":
		var c_name = POI_INFO.get(current, {}).get("name", current)
		var t_name = POI_INFO.get(target,  {}).get("name", target)
		poi_name_label.text  = t_name
		poi_coord_label.text = c_name + " →"
		transit_route_label.text = "%s → %s" % [c_name, t_name]
	else:
		var c_name = POI_INFO.get(current, {}).get("name", current)
		poi_name_label.text  = c_name
		poi_coord_label.text = ""

	# 星币
	credits_amount_label.text = "%d" % ship.get("credits", 0)

	# 货仓容量（从 cabin 组件读）
	var cargo_cap  = _get_cabin_cargo_cap()
	var equip_cap  = _get_cabin_equip_cap()
	var total_ore  = _get_total_ore()
	var cargo_pct  = float(total_ore) / float(cargo_cap) if cargo_cap > 0 else 0.0
	cargo_percent.text      = "%d%%" % int(cargo_pct * 100)
	cargo_numeric_label.text = "%d / %d" % [int(total_ore), cargo_cap]

	# ── 视觉中心切换 ──
	_switch_view(status, current)

	# ── 刷新 POI 下拉 ──
	_populate_poi_options()

	# ── 刷新舰体 tab ──
	_refresh_slots()

	# ── 刷新货仓 tab ──
	_refresh_equip_grid(equip_cap)
	_refresh_ore_bars(cargo_cap)

	# ── 刷新任务 ──
	_refresh_missions()

	# ── 刷新船员 ──
	_refresh_crew()

	# 招募按钮仅在空间站可用
	var at_station = POI_INFO.get(current, {}).get("is_station", false)
	recruit_btn.disabled = not at_station or status != "docked"

	# 按钮状态
	depart_btn.disabled        = (status != "docked")
	planet_depart_btn.disabled = (status != "docked" and status != "working")
	dock_btn.disabled          = (status != "working")
	grid_btn.disabled          = (status != "docked")
	sos_btn.disabled           = (status != "stranded")
	fuel_btn.disabled          = (status == "in_transit")

# ── 视觉中心切换 ──────────────────────────────────────────────────────────────
func _switch_view(status: String, current_poi: String) -> void:
	var at_station = POI_INFO.get(current_poi, {}).get("is_station", false)
	station_view.visible = false
	planet_view.visible  = false
	transit_view.visible = false

	match status:
		"docked":
			if at_station:
				station_view.visible = true
			else:
				planet_view.visible = true
		"working":
			planet_view.visible = true
		"in_transit":
			transit_view.visible = true
		"stranded":
			planet_view.visible = true
		_:
			station_view.visible = true

# ── 舰体 tab 刷新 ─────────────────────────────────────────────────────────────
func _refresh_slots() -> void:
	var components = _game_state.components  # {comp_id: slot_name}
	var slot_hp    = _game_state.ship.get("slot_hp", {})

	# 按槽位整理已安装组件
	var by_slot: Dictionary = {}
	for comp_id in components.keys():
		var sn = components[comp_id]
		if not by_slot.has(sn):
			by_slot[sn] = []
		by_slot[sn].append(comp_id)

	for i in range(SLOT_NAMES.size()):
		var slot = SLOT_NAMES[i]
		var panel = slot_hbox.get_node_or_null("SlotPanel_" + slot)
		if panel == null:
			continue

		# 更新耐久标签（在 title_row HBoxContainer 内）
		var title_row_node = panel.get_node_or_null("TitleRow")
		var hp_lbl = null
		if title_row_node:
			hp_lbl = title_row_node.get_node_or_null("HpLbl")
		if hp_lbl:
			var hp_val = slot_hp.get(slot, "—")
			hp_lbl.text = "HP %s" % str(hp_val)

		# 更新格子
		var grid = panel.get_node_or_null("Grid")
		if grid == null:
			continue
		var installed = by_slot.get(slot, [])
		var cap = SKELETON_CAPACITY[slot]
		for j in range(grid.get_child_count()):
			var cell: Button = grid.get_child(j)
			if j < installed.size():
				cell.text = "■"
				cell.tooltip_text = installed[j]
				cell.modulate = Color(0.4, 0.8, 1.0)
			else:
				cell.text = "□"
				cell.tooltip_text = ""
				cell.modulate = Color(0.4, 0.4, 0.4)

# ── 货仓 tab：装备格刷新 ──────────────────────────────────────────────────────
func _refresh_equip_grid(equip_cap: int) -> void:
	# 清除旧格子
	for child in equip_grid.get_children():
		child.queue_free()

	var inventory   = _game_state.inventory    # {comp_id: qty}
	var components  = _game_state.components   # {comp_id: slot}

	# 收集所有库存中的 comp_id（展开数量）
	var inv_items: Array = []
	for comp_id in inventory.keys():
		var qty = inventory[comp_id]
		for _k in range(qty):
			inv_items.append(comp_id)

	# 总格子数 = equip_cap（最多30）
	var total_cells = min(equip_cap, 30)
	_selected_equip_comp = ""

	var slot_tex = load("res://ui/ui_slices_starship_inventory/assets/x0889_y0710_w0107_h0092__empty_slot_r01_c01.png")

	for idx in range(total_cells):
		var cell_wrap = Control.new()
		cell_wrap.custom_minimum_size = Vector2(44, 44)

		var slot_bg = TextureRect.new()
		slot_bg.layout_mode = 1
		slot_bg.anchors_preset = Control.PRESET_FULL_RECT
		slot_bg.anchor_right = 1.0
		slot_bg.anchor_bottom = 1.0
		slot_bg.texture = slot_tex
		slot_bg.stretch_mode = TextureRect.STRETCH_SCALE
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_wrap.add_child(slot_bg)

		var cell = Button.new()
		cell.layout_mode = 1
		cell.anchors_preset = Control.PRESET_FULL_RECT
		cell.anchor_right = 1.0
		cell.anchor_bottom = 1.0
		cell.toggle_mode = true
		cell.flat = true

		if idx < inv_items.size():
			var cid = inv_items[idx]
			cell.text = "▣"
			cell.tooltip_text = cid
			cell.modulate = Color(0.8, 1.0, 0.6)
			cell.pressed.connect(_on_equip_cell_pressed.bind(cid, false, cell))
		else:
			cell.text = ""
			cell.disabled = true
			cell.modulate = Color(0.5, 0.5, 0.5)

		cell_wrap.add_child(cell)
		equip_grid.add_child(cell_wrap)

# ── 货仓 tab：矿石进度条刷新 ──────────────────────────────────────────────────
func _refresh_ore_bars(cargo_cap: int) -> void:
	var resources = _game_state.resources
	for ore in ORE_TYPES:
		var row = ore_bars.get_node_or_null("Ore_" + ore)
		if row == null:
			continue
		# Bar and Val are inside the HBoxContainer child of the row Control
		var bar     = _find_named_child(row, "Bar")
		var val_lbl = _find_named_child(row, "Val")
		var amount  = resources.get(ore, 0.0)
		if bar:
			bar.max_value = cargo_cap
			bar.value     = amount
		if val_lbl:
			val_lbl.text = "%d / %d" % [int(amount), cargo_cap]

func _find_named_child(parent: Node, child_name: String) -> Node:
	var direct = parent.get_node_or_null(child_name)
	if direct:
		return direct
	for child in parent.get_children():
		var found = child.get_node_or_null(child_name)
		if found:
			return found
	return null

# ── 任务刷新 ──────────────────────────────────────────────────────────────────
func _refresh_missions() -> void:
	var active_ids: Dictionary = {}
	for m in _game_state.missions:
		if m.get("status", "active") == "active":
			active_ids[m.get("mission_id", "")] = true

	# 可接任务（空间站面板）
	mission_list.clear()
	for mission_id in MISSION_CONFIG.keys():
		if mission_id in active_ids:
			continue
		var cfg = MISSION_CONFIG[mission_id]
		mission_list.add_item("[%s] %s  ★%d" % [cfg["type"], cfg["name"], cfg["reward"]])
		mission_list.set_item_metadata(mission_list.item_count - 1, mission_id)

	# 进行中任务（两个面板共用）
	var now = Time.get_unix_time_from_system()
	var active_lines: Array = []
	for m in _game_state.missions:
		var mid = m.get("mission_id", "")
		var cfg = MISSION_CONFIG.get(mid, {})
		if cfg.is_empty():
			continue
		var mstatus   = m.get("status", "active")
		var remaining = int(m.get("deadline", now) - now)
		var progress  = m.get("progress", 0)
		var label: String
		match mstatus:
			"completed":
				label = "[完成] %s  ★%d" % [cfg["name"], cfg["reward"]]
			"failed":
				label = "[失败] %s  违约:-%d" % [cfg["name"], cfg.get("penalty", 0)]
			_:
				label = "[%s] %s  进度:%d  剩余:%s" % [cfg["type"], cfg["name"], progress, _format_time(remaining)]
		active_lines.append({"label": label, "mid": mid, "status": mstatus})

	active_mission_list.clear()
	planet_active_list.clear()
	for item in active_lines:
		var idx = active_mission_list.item_count
		active_mission_list.add_item(item["label"])
		active_mission_list.set_item_metadata(idx, item["mid"])
		if item["status"] == "completed":
			active_mission_list.set_item_custom_fg_color(idx, Color(0.4, 1.0, 0.4))
		elif item["status"] == "failed":
			active_mission_list.set_item_custom_fg_color(idx, Color(1.0, 0.4, 0.4))

		var pidx = planet_active_list.item_count
		planet_active_list.add_item(item["label"])
		planet_active_list.set_item_metadata(pidx, item["mid"])
		if item["status"] == "completed":
			planet_active_list.set_item_custom_fg_color(pidx, Color(0.4, 1.0, 0.4))
		elif item["status"] == "failed":
			planet_active_list.set_item_custom_fg_color(pidx, Color(1.0, 0.4, 0.4))

# ── 船员刷新 ──────────────────────────────────────────────────────────────────
func _refresh_crew() -> void:
	for child in crew_roster.get_children():
		child.queue_free()

	var crew_by_role: Dictionary = {}
	for c in _game_state.crew:
		crew_by_role[c.get("slot", "")] = c

	for i in range(CREW_ROLES.size()):
		var role         = CREW_ROLES[i]
		var role_display = CREW_ROLE_DISPLAY[i]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var role_lbl = Label.new()
		role_lbl.custom_minimum_size = Vector2(50, 0)
		role_lbl.text = role_display
		row.add_child(role_lbl)

		if crew_by_role.has(role):
			var c       = crew_by_role[role]
			var tier    = c.get("tier", "T1")
			var trait_id = c.get("trait_id", "")
			var debt    = c.get("debt", 0)

			var name_lbl = Label.new()
			name_lbl.custom_minimum_size = Vector2(130, 0)
			name_lbl.text = "[%s] %s" % [tier, c.get("name", "?")]
			if debt > 0:
				name_lbl.modulate = Color(1, 0.4, 0.4)
			row.add_child(name_lbl)

			var trait_lbl = Label.new()
			trait_lbl.custom_minimum_size = Vector2(200, 0)
			trait_lbl.text = TRAIT_DESC.get(trait_id, trait_id)
			trait_lbl.modulate = Color(0.8, 0.9, 1.0)
			row.add_child(trait_lbl)

			var salary_lbl = Label.new()
			salary_lbl.custom_minimum_size = Vector2(110, 0)
			if debt > 0:
				salary_lbl.text = "薪水★%d  欠债★%d" % [c.get("salary", 0), debt]
				salary_lbl.modulate = Color(1, 0.4, 0.4)
			else:
				salary_lbl.text = "薪水 ★%d/30min" % c.get("salary", 0)
			row.add_child(salary_lbl)

			var fire_btn = Button.new()
			fire_btn.text = "解雇"
			fire_btn.custom_minimum_size = Vector2(54, 26)
			fire_btn.pressed.connect(_on_fire_crew_pressed.bind(role))
			row.add_child(fire_btn)
		else:
			var empty_lbl = Label.new()
			empty_lbl.text = "（空缺）"
			empty_lbl.modulate = Color(0.5, 0.5, 0.5)
			row.add_child(empty_lbl)

		crew_roster.add_child(row)

	# 声望行
	var rep = _game_state.reputation
	var rep_row = HBoxContainer.new()
	rep_row.add_theme_constant_override("separation", 16)
	var rep_title = Label.new()
	rep_title.text = "── 阵营声望 ──"
	rep_title.modulate = Color(0.9, 0.85, 0.5)
	rep_row.add_child(rep_title)
	for pair in [["铁骑", "ironclad"], ["光斑", "macula"], ["中立", "neutral"]]:
		var lbl = Label.new()
		lbl.text = "%s: %d" % [pair[0], rep.get(pair[1], 0)]
		lbl.modulate = Color(0.7, 0.9, 1.0)
		rep_row.add_child(lbl)
	crew_roster.add_child(rep_row)

# ── 辅助：cabin 容量 ──────────────────────────────────────────────────────────
func _get_cabin_cargo_cap() -> int:
	var components = _game_state.components
	for comp_id in components.keys():
		if components[comp_id] == "cabin" and CABIN_CARGO_CAP.has(comp_id):
			return CABIN_CARGO_CAP[comp_id]
	return DEFAULT_CARGO_CAP

func _get_cabin_equip_cap() -> int:
	var components = _game_state.components
	for comp_id in components.keys():
		if components[comp_id] == "cabin" and CABIN_EQUIP_CAP.has(comp_id):
			return CABIN_EQUIP_CAP[comp_id]
	return 10

func _get_total_ore() -> float:
	var total = 0.0
	for ore in ORE_TYPES:
		total += _game_state.resources.get(ore, 0.0)
	return total

func _update_recruit_cost_label() -> void:
	var tier = CREW_TIERS[recruit_tier_option.selected]
	recruit_cost_label.text = "招募费用：★ %d" % RECRUIT_COST.get(tier, 300)

# ── 装备格点击回调 ────────────────────────────────────────────────────────────
func _on_equip_cell_pressed(comp_id: String, is_installed: bool, cell: Button) -> void:
	_selected_equip_comp = comp_id
	_selected_equip_is_installed = is_installed

# ── 按钮回调 ──────────────────────────────────────────────────────────────────
func _on_depart_pressed() -> void:
	# 优先用空间站 poi_option，若不可见则用星球 poi_option
	var opt = poi_option if station_view.visible else planet_poi_option
	var idx = opt.selected
	if idx < 0:
		show_notification("请选择目的地", true)
		return
	var target_poi = opt.get_item_metadata(idx)
	_client.action_depart(target_poi)

func _on_dock_pressed() -> void:
	_client.action_dock()

func _on_grid_pressed() -> void:
	_client.action_connect_grid()

func _on_fuel_pressed() -> void:
	var amount = int(fuel_spin.value)
	if amount <= 0:
		return
	_client.action_buy_fuel(amount)

func _on_sos_pressed() -> void:
	_client.action_sos()

func _on_equip_pressed() -> void:
	if _selected_equip_comp == "":
		show_notification("请先在装备仓中选择组件", true)
		return
	var slot_idx = slot_option.selected
	var slot = ALL_SLOT_NAMES[slot_idx]
	_client.action_equip(_selected_equip_comp, slot)

func _on_unequip_pressed() -> void:
	if _selected_equip_comp == "":
		show_notification("请先选择已装组件", true)
		return
	_client.action_unequip(_selected_equip_comp)

func _on_recruit_pressed() -> void:
	var role = CREW_ROLES[recruit_role_option.selected]
	var tier = CREW_TIERS[recruit_tier_option.selected]
	_client.action_recruit(role, tier)

func _on_fire_crew_pressed(role: String) -> void:
	_client.action_fire_crew(role)

func _on_tier_selected(_idx: int) -> void:
	_update_recruit_cost_label()

func _on_accept_mission_pressed() -> void:
	var sel = mission_list.get_selected_items()
	if sel.is_empty():
		show_notification("请先选择任务", true)
		return
	var mission_id = mission_list.get_item_metadata(sel[0])
	var cfg = MISSION_CONFIG.get(mission_id, {})
	_client.action_accept_mission(mission_id, cfg.get("deadline_hours", 24))

# ── 事件展示 ──────────────────────────────────────────────────────────────────
func on_action_result(data: Dictionary) -> void:
	var action  = data.get("action", "")
	var success = data.get("success", false)
	if success:
		match action:
			"depart":
				var p = data.get("payload", {})
				_append_log("[color=cyan]起飞！前往 %s，预计 %s，耗电 %d[/color]" % [
					p.get("target_poi", ""), _format_time(p.get("eta_minutes", 0) * 60), p.get("total_power_cost", 0)
				])
			"dock":
				_append_log("[color=green]已停泊[/color]")
			"connect_grid":
				_append_log("[color=yellow]已连接电网，充电中（10 电力/分钟）[/color]")
			"buy_fuel":
				var p = data.get("payload", {})
				_append_log("[color=yellow]购买燃料，电力 → %d[/color]" % p.get("power", 0))
			"equip":
				_append_log("[color=cyan]已装配 %s 到 %s 槽[/color]" % [data.get("component_id",""), data.get("slot","")])
			"unequip":
				_append_log("[color=gray]已卸载 %s[/color]" % data.get("component_id",""))
			"accept_mission":
				_append_log("[color=green]已接取任务[/color]")
			"recruit":
				var c = data.get("crew", {})
				_append_log("[color=cyan]招募成功！[%s] %s 加入船队[/color]" % [c.get("tier",""), c.get("name","")])
				_append_log("  特性：%s" % data.get("trait_desc", ""))
				_append_log("  花费 ★%d" % data.get("cost", 0))
			"fire_crew":
				_append_log("[color=gray]已解雇 %s 岗位船员[/color]" % data.get("role", ""))
			"sos":
				_append_log("[color=red]%s[/color]" % data.get("sos_text", "SOS 信标已发射"))
	else:
		_append_log("[color=red]操作失败：%s[/color]" % data.get("message", ""))

func show_combat_log(payload: Dictionary) -> void:
	var result    = payload.get("result", "")
	var enemy     = payload.get("enemy", "")
	var log_lines: Array = payload.get("combat_log", [])

	_append_log("\n[color=orange]━━ 遭遇战 ━━[/color]")
	_append_log("敌人：" + enemy)
	for line in log_lines:
		_append_log("  " + line)
	if result == "victory":
		_append_log("[color=green]胜利！获得 %d 星币[/color]" % payload.get("credits_gained", 0))
	else:
		_append_log("[color=red]战败！弹射至 %s[/color]" % payload.get("ejected_to", ""))
	_append_log("[color=orange]━━━━━━━━━━━━[/color]\n")

func show_notification(msg: String, urgent: bool = false) -> void:
	notification_label.text    = msg
	notification_label.modulate = Color.RED if urgent else Color.WHITE
	notification_label.visible = true
	notification_timer.start(3.0)

func _hide_notification() -> void:
	notification_label.visible = false

func _append_log(text: String) -> void:
	log_box.append_text(text + "\n")
	await get_tree().process_frame
	log_box.scroll_to_line(log_box.get_line_count())

func append_log(text: String) -> void:
	_append_log(text)

func _format_time(secs: float) -> String:
	var s = int(secs)
	if s >= 3600:
		return "%dh %dm" % [s / 3600, (s % 3600) / 60]
	elif s >= 60:
		return "%dm %ds" % [s / 60, s % 60]
	else:
		return "%ds" % s
