class_name GeminiClient
extends Node

# Gemini AI 客户端 - 封装 4 个游戏 AI 节点
# 使用 Godot HTTPRequest 调用 Gemini API

const API_KEY = ""  # 在此填入 Gemini API Key，或从环境变量读取
const API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

# 回调队列：{request_id -> Callable}
var _pending: Dictionary = {}
var _next_id: int = 0
var _api_key_override: String = ""

func _ready() -> void:
	# 尝试从环境变量读取 API Key
	var env_key = OS.get_environment("GEMINI_API_KEY")
	if env_key != "":
		_api_key_override = env_key

func _get_key() -> String:
	return _api_key_override if _api_key_override != "" else API_KEY

# ── 节点1：招募时生成船员人设 ──────────────────────────────────
func generate_crew(role: String, tier: String, trait_desc: String, callback: Callable) -> void:
	var faction_bg = "宇宙中有三大阵营：铁骑财团（重工业/暴力开采）、光斑序列（极端科技/热能武器）、奇点圣约（神秘失落文明/电磁量子）。月之暗面是机械丧尸病毒。"
	var prompt = """你是一个硬核科幻游戏的世界观生成器。请为一名船员生成人设。
输入参数：
- 岗位：[%s]
- 品级：[%s]
- 特长：[%s]
- 宇宙背景：%s

请输出 JSON，包含以下字段（仅输出 JSON，不要其他文字）：
{
  "name": "带有赛博朋克或异星风格的姓名",
  "backstory": "结合特长的背景故事（50字以内）",
  "catchphrase": "战斗时爱说的一句简短口头禅（15字以内）"
}""" % [role, tier, trait_desc, faction_bg]
	_call_api(prompt, "application/json", callback)

# ── 节点2：航行中随机船员对话 ──────────────────────────────────
func generate_banter(ship_status: Dictionary, crew_list: Array, callback: Callable) -> void:
	if crew_list.size() < 2:
		callback.call("")
		return
	var c1 = crew_list[0]
	var c2 = crew_list[1]
	var power_pct = int(float(ship_status.get("power", 0)) / float(max(ship_status.get("max_power", 500), 1)) * 100)
	var target = ship_status.get("target_poi", "未知星域")
	var prompt = """请模拟星舰船员的内部通讯频道。
当前飞船状态：
- 目的地：%s
- 电力剩余：%d%%
- 船员A（%s，%s）：背景：%s，口头禅：%s
- 船员B（%s，%s）：背景：%s，口头禅：%s

请生成一段简短的两人对话（JSON格式，仅输出JSON）：
{
  "lines": [
    {"speaker": "船员A名字", "dialog": "台词"},
    {"speaker": "船员B名字", "dialog": "台词"}
  ]
}
表现出航行紧张感或对当前状态的吐槽，不要产生任何游戏数值。""" % [
		target, power_pct,
		c1.get("name","?"), c1.get("slot","?"), c1.get("backstory",""), c1.get("catchphrase",""),
		c2.get("name","?"), c2.get("slot","?"), c2.get("backstory",""), c2.get("catchphrase","")
	]
	_call_api(prompt, "application/json", callback)

# ── 节点3：SOS 求救广播文本 ────────────────────────────────────
func generate_sos(captain_name: String, poi_name: String, backstory: String, callback: Callable) -> void:
	var prompt = """你是一艘在深空失去动力的星舰舰长。你的名字是【%s】，你的飞船在【%s】抛锚了，周围可能有机械丧尸出没。
你的背景：%s

请生成一段不超过40个字的最高级别求救广播（SOS）。
文本要符合你的性格：可以是惊恐求救，也可以是死鸭子嘴硬的傲娇请求。
直接输出纯文本，不要任何格式。""" % [captain_name, poi_name, backstory]
	_call_api(prompt, "text/plain", callback)

# ── 节点4：Boss 战后终局真相播报 ──────────────────────────────
func generate_boss_truth(boss_name: String, callback: Callable) -> void:
	var prompt = """作为【奇点圣约】的太虚监察者AI，你刚刚观测到全服玩家击退了名为【%s】的月之暗面丧尸群。

请生成一段80字以内的加密解码日志。
日志需要透露：这只怪物的残骸中，发现了属于【光斑序列】或【铁骑财团】的秘密实验标记。
暗示这场丧尸瘟疫并非天灾，而是人祸。
文风要求冷酷、高维视角、充满神谕感。
直接输出纯文本，不要任何格式。""" % [boss_name]
	_call_api(prompt, "text/plain", callback)

# ── 内部 HTTP 调用 ─────────────────────────────────────────────
func _call_api(prompt: String, response_mime: String, callback: Callable) -> void:
	var key = _get_key()
	if key == "":
		push_error("[Gemini] API Key 未配置，跳过 AI 生成")
		callback.call(null)
		return

	var http = HTTPRequest.new()
	add_child(http)

	var request_id = _next_id
	_next_id += 1
	_pending[request_id] = callback

	http.request_completed.connect(func(result, code, _headers, body):
		_on_response(request_id, result, code, body, response_mime, http)
	)

	var url = API_URL + "?key=" + key
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"contents": [{"parts": [{"text": prompt}]}],
		"generationConfig": {
			"responseMimeType": response_mime if response_mime == "application/json" else "text/plain"
		}
	})

	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("[Gemini] HTTP 请求失败: %d" % err)
		_pending.erase(request_id)
		http.queue_free()
		callback.call(null)

func _on_response(request_id: int, result: int, code: int, body: PackedByteArray, mime: String, http: HTTPRequest) -> void:
	http.queue_free()
	var cb = _pending.get(request_id)
	_pending.erase(request_id)

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_error("[Gemini] API 响应错误: result=%d code=%d" % [result, code])
		if cb:
			cb.call(null)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		if cb:
			cb.call(null)
		return

	# 提取 candidates[0].content.parts[0].text
	var text = ""
	var candidates = json.get("candidates", [])
	if candidates.size() > 0:
		var parts = candidates[0].get("content", {}).get("parts", [])
		if parts.size() > 0:
			text = parts[0].get("text", "")

	if cb:
		if mime == "application/json":
			# 尝试解析 JSON
			var parsed = JSON.parse_string(text.strip_edges())
			cb.call(parsed if parsed != null else text)
		else:
			cb.call(text.strip_edges())
