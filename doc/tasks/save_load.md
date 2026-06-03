# save_load 模块设计

## 目标

`save_load` 模块负责完整游戏状态的序列化、反序列化、文件落盘和读档恢复。

首版目标：

- 支持手动保存
- 支持手动读档
- 保存完整游戏状态
- 使用可人工调试的 JSON 格式
- 支持基础版本字段，避免后续结构变化时完全失控

## 职责边界

### 负责

- 存档路径管理
- 存档结构定义
- 运行时状态转 JSON
- JSON 转运行时可重建数据
- 存档列表查询

### 不负责

- 游戏规则结算
- UI 布局
- 地图静态数据定义

## 核心数据结构

### 存档路径设计决策

统一使用 Godot 的 `user://saves/`。

理由：

- Godot 会自动映射到各平台合适目录
- Windows、macOS、Linux 不需要写平台分支代码

### `SaveEnvelope`

```gdscript
class_name SaveEnvelope

var save_version: int
var created_at_unix: int
var game_state: Dictionary
```

### `GameStateDTO`

建议按模块拆分序列化字段：

```json
{
  "turn_index": 1,
  "player_state": {},
  "map_runtime_state": {},
  "city_states": [],
  "tech_state": {},
  "selected_city_id": "",
  "selected_tile_key": "",
  "rule_version": 1
}
```

说明：

- 静态定义数据不应写入存档
- 存档只保存运行时变化状态
- 读档时仍需重新加载 `data` 模块的静态定义

## 主要流程

### 保存流程

1. `ui` 发出保存请求。
2. `core` 将当前 `GameState` 交给 `SaveLoadService`。
3. `SaveLoadService` 将其转换为 `Dictionary`。
4. 包装为 `SaveEnvelope`。
5. 序列化为 JSON。
6. 写入 `user://saves/slot_001.json` 或其他命名规则。

### 读档流程

1. `ui` 发出读档请求。
2. `SaveLoadService` 读取目标文件。
3. 解析 `SaveEnvelope`。
4. 校验 `save_version`。
5. 将 `game_state` 数据交还给 `core`。
6. `core` 重建运行时对象。

### 存档列表流程

1. 扫描 `user://saves/`。
2. 读取文件名和基础元数据。
3. 返回给 `ui` 展示。

## 场景/脚本拆分

建议文件：

```text
game/scripts/save/save_load_service.gd
game/scripts/save/save_serializer.gd
game/scripts/save/save_deserializer.gd
game/scripts/save/save_slot_info.gd
```

建议职责：

- `save_load_service.gd`
  - 对外统一入口
- `save_serializer.gd`
  - 运行时对象转字典
- `save_deserializer.gd`
  - 字典转可重建数据
- `save_slot_info.gd`
  - 供 UI 展示的存档摘要

## 输入输出

### 输入

- `GameState`
- 目标存档槽位名

### 输出

- JSON 存档文件
- 可供 `core` 重建的字典数据
- 存档列表摘要

## 依赖关系

### 依赖

- `core`
- `map`
- `city`
- `tech`

### 被依赖

- `core`
- `ui`

## 风险

- 如果运行时对象直接被 JSON 化，后续类结构一改就会破坏兼容性
- 如果没有 `save_version`，未来新增字段会让老存档难以处理
- 如果把静态定义写入存档，文件会膨胀且容易产生重复数据

## 子任务 checklist

- [ ] 设计 `SaveEnvelope`
- [ ] 设计 `GameStateDTO`
- [ ] 确定 `user://saves/` 路径策略
- [ ] 实现 `SaveLoadService`
- [ ] 实现 `SaveSerializer`
- [ ] 实现 `SaveDeserializer`
- [ ] 实现存档列表查询
- [ ] 实现保存流程
- [ ] 实现读档流程
- [ ] 增加 `save_version` 校验
- [ ] 验证跨平台存档路径可用性
