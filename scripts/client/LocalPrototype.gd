class_name LocalPrototype
extends RefCounted

const START_POI = "CYG-SS-01"
const START_CREDITS = 4200
const START_POWER = 620
const MAX_POWER = 900
const ARRIVAL_SECONDS = 18.0
const FUEL_UNIT_PRICE = 4
const FUEL_POWER_PER_UNIT = 10

const POI_CATALOG = {
	"CYG-SS-01": {"name": "铁砧-IV 采掘前哨", "is_station": true, "danger": 0, "x": 124.7, "y": -892.3},
	"CYG-SS-02": {"name": "折光 科考平台", "is_station": true, "danger": 1, "x": 92.4, "y": -862.8},
	"CYG-SS-03": {"name": "锈蚀深渊 走私港", "is_station": true, "danger": 2, "x": 155.1, "y": -875.6},
	"CYG-PL-01": {"name": "塔洛斯 碎石星", "is_station": false, "danger": 1, "x": 112.6, "y": -920.4},
	"CYG-PL-02": {"name": "西风-7 气态巨星", "is_station": false, "danger": 2, "x": 174.9, "y": -904.7},
	"CYG-MO-01": {"name": "灰烬 T-09", "is_station": false, "danger": 0, "x": 118.3, "y": -934.2},
	"CYG-AS-01": {"name": "阿尔法碎石带", "is_station": false, "danger": 3, "x": 146.8, "y": -948.5},
	"CYG-RU-01": {"name": "第17号船坟地带", "is_station": false, "danger": 4, "x": 184.5, "y": -866.1},
	"CYG-RU-02": {"name": "废弃同位素精炼厂", "is_station": false, "danger": 4, "x": 198.2, "y": -918.9},
	"CYG-ST-01": {"name": "天鹅座 X-1 白矮星", "is_station": false, "danger": 5, "x": 231.0, "y": -842.0}
}

const COMPONENT_SLOTS = {
	"NOSE-T1-001": "nose",
	"WNG-T1-001": "wings",
	"HUL-T1-001": "hull",
	"TAIL-T1-001": "tail",
	"PWR-T1-001": "core",
	"CGO-T1-002": "cabin"
}

static func build_snapshot() -> Dictionary:
	return {
		"player_id": 1,
		"username": "试航舰长",
		"ship": {
			"status": "docked",
			"current_poi": START_POI,
			"target_poi": "",
			"hp": 860,
			"max_hp": 1000,
			"shield": 240,
			"power": START_POWER,
			"max_power": MAX_POWER,
			"credits": START_CREDITS,
			"eta": 0.0,
			"dps": 42,
			"def": 18,
			"spd": 35,
			"charging": false,
			"slot_hp": {
				"nose": 96,
				"wings": 88,
				"hull": 100,
				"tail": 91,
				"core": 84,
				"cabin": 100
			}
		},
		"resources": {
			"钛": 1200.0,
			"精炼钛": 180.0,
			"铱": 34.0,
			"精炼铱": 8.0,
			"暗面废料": 12.0
		},
		"components": COMPONENT_SLOTS.duplicate(),
		"inventory": {
			"NOSE-T1-002": 1,
			"WNG-T1-002": 1,
			"HUL-T1-002": 1,
			"PWR-T1-002": 1,
			"CGO-T2-001": 1,
			"LAS-T1-001": 2,
			"SHD-T1-001": 1
		},
		"crew": [
			{"slot": "captain", "name": "林砚", "tier": "T1", "trait_id": "captain_t1_ironclad", "salary": 60, "debt": 0},
			{"slot": "engineer", "name": "阿洛", "tier": "T1", "trait_id": "engineer_t1_efficient", "salary": 50, "debt": 0}
		],
		"missions": [
			{
				"mission_id": "CYG-MIN-001",
				"status": "active",
				"deadline": Time.get_unix_time_from_system() + 24.0 * 3600.0,
				"progress": 1200
			}
		],
		"reputation": {"ironclad": 12, "macula": 3, "neutral": 7},
		"poi_catalog": POI_CATALOG.duplicate(true)
	}

static func poi_name(poi_id: String) -> String:
	return POI_CATALOG.get(poi_id, {}).get("name", poi_id)

static func estimate_power_cost(from_poi: String, target_poi: String) -> int:
	var from_info = POI_CATALOG.get(from_poi, {})
	var target_info = POI_CATALOG.get(target_poi, {})
	if from_info.is_empty() or target_info.is_empty():
		return 80
	var dx = float(from_info.get("x", 0.0)) - float(target_info.get("x", 0.0))
	var dy = float(from_info.get("y", 0.0)) - float(target_info.get("y", 0.0))
	return clampi(int(round(sqrt(dx * dx + dy * dy) * 3.0)), 40, 260)
