# 《星河放置：暗面危机》技术架构文档（V1.0）

- **文档编号**：SYS-010
- **系统定位**：服务端/客户端技术选型、通信协议、数据持久化方案

---

## 一、整体架构概览

```
[玩家浏览器]
    │  HTML5 (Godot Export)
    │  WebSocket 长连接
    ▼
[云服务器]
    ├── Godot Headless Server（游戏逻辑层）
    │       持续运行，按现实时间驱动所有状态
    └── MySQL（数据持久化层）
            存储玩家档案、飞船状态、资源、任务进度
```

---

## 二、服务端（Godot Headless Server）

### 职责
- 按现实时间持续运转，驱动所有玩家状态：
  - 航行进度推进 + 动态耗电扣除
  - 作业中资源产出累计
  - 船员薪水每 30 分钟扣除
  - 遭遇战按距离分段触发 + 战斗结算
  - POI 资源池每日 00:00 重置
  - 每晚 20:00 全服 Boss 防守事件
- 所有数值计算在服务端完成，客户端不参与任何逻辑运算（Server-Authoritative）

### 运行模式
```bash
godot --headless --path /path/to/project res://scenes/server/ServerMain.tscn
```

### 核心 Tick 机制
- 服务端维护一个全局 Timer，每秒推进一次游戏状态
- 玩家离线期间服务端继续运算，玩家上线时直接同步当前状态快照

---

## 三、客户端（Godot HTML5 Export）

### 职责
- 纯展示层：渲染 UI、播放战报文案、展示飞船状态
- 所有操作（起飞、装配、接任务）通过 WebSocket 发送指令到服务端
- 服务端验证后返回结果，客户端更新显示

### 导出配置
- Godot 导出为 HTML5，部署到云服务器的静态文件目录
- 玩家通过浏览器直接访问，无需安装客户端

---

## 四、通信协议（WebSocket）

### 连接流程
```
客户端启动 → 建立 WebSocket 连接 → 发送登录验证
→ 服务端返回玩家完整状态快照 → 进入游戏
```

### 消息格式（JSON）
```json
// 客户端 → 服务端（指令）
{
  "type": "action",
  "action": "depart",
  "payload": {
    "target_poi": "CYG-PL-01"
  }
}

// 服务端 → 客户端（状态推送）
{
  "type": "state_update",
  "payload": {
    "power": 320,
    "status": "in_transit",
    "eta_minutes": 12
  }
}

// 服务端 → 客户端（事件推送）
{
  "type": "event",
  "event": "encounter",
  "payload": {
    "enemy": "EN-PIR-01",
    "combat_log": ["...", "..."]
  }
}
```

### 主要消息类型

| 方向 | type | 说明 |
|------|------|------|
| C→S | action | 玩家操作指令（起飞/停泊/装配/接任务） |
| C→S | ping | 心跳保活 |
| S→C | state_update | 状态变化推送（电力/位置/资源） |
| S→C | event | 事件通知（遭遇战/任务完成/薪水扣除） |
| S→C | combat_log | 战报文案推送 |
| S→C | global_event | 全服事件（Boss防守/资源重置） |

---

## 五、数据库（MySQL）

### 核心数据表设计

**players**（玩家账户）
```sql
id, username, password_hash, created_at, last_login
```

**ships**（飞船状态）
```sql
player_id, status(docked/in_transit/working/stranded),
current_poi, target_poi, depart_time, eta,
hp, shield, power, max_power,
credits(星币)
```

**ship_components**（装配组件）
```sql
player_id, slot(nose/wings/hull/tail/core/cabin),
component_id, installed_at
```

**inventory**（仓库）
```sql
player_id, component_id, quantity
```

**resources**（资源库存）
```sql
player_id, resource_type(钛/精炼钛/铱/精炼铱/暗面废料), amount
```

**crew**（船员）
```sql
player_id, slot(captain/gunner/engineer),
tier, trait_id, name, backstory, catchphrase,
hired_at, salary, debt(欠薪累计)
```

**missions**（任务进度）
```sql
player_id, mission_id, status(active/completed/failed),
accepted_at, progress, deadline
```

**poi_resources**（POI资源池，全服共享）
```sql
poi_id, resource_type, remaining, last_reset
```

---

## 六、云服务部署建议

### 最小配置
- **服务器**：2核4G，足够支撑早期玩家规模
- **带宽**：5Mbps（WebSocket 消息量较小）
- **存储**：50GB SSD（MySQL + 静态文件）

### 目录结构
```
/server/
  godot_server/        # Godot headless server 文件
  web/                 # HTML5 客户端静态文件
  nginx.conf           # 反向代理配置（HTTP → 静态文件，WS → Godot Server）

/etc/systemd/system/
  godot-server.service # 开机自启动服务
```

### Nginx 反向代理
```nginx
# 静态文件（客户端）
location / {
    root /server/web;
    index index.html;
}

# WebSocket（转发到 Godot Server）
location /ws {
    proxy_pass http://127.0.0.1:7777;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

### 进程守护
```ini
# /etc/systemd/system/godot-server.service
[Unit]
Description=StarRiver Game Server
After=network.target mysql.service

[Service]
ExecStart=/usr/bin/godot --headless --path /server/godot_server res://scenes/server/ServerMain.tscn
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

## 七、关键技术风险与应对

| 风险 | 说明 | 应对 |
|------|------|------|
| 服务端崩溃 | 所有玩家状态丢失 | 每分钟将关键状态写入 MySQL，重启后从数据库恢复 |
| WebSocket 断线 | 玩家操作丢失 | 客户端自动重连，重连后拉取最新状态快照 |
| 玩家并发过高 | Godot 单线程瓶颈 | 早期够用；后期可按星系分 Server 实例 |
| MySQL 性能 | 高频写入（每秒tick） | 内存中维护状态，定期批量写库，不每秒写 |
