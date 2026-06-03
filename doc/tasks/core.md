# core 模块设计

## 目标

`core` 模块负责驱动游戏主循环，并作为运行时总协调层管理各子模块的初始化、回合推进和状态同步。

首版目标：

- 启动游戏并加载固定地图
- 创建初始游戏状态
- 接收玩家 `结束回合`、`新游戏`、`保存`、`读档` 等操作
- 按固定顺序驱动 `city`、`tech`、`save_load`、`ui` 等模块
- 为未来扩展多城市、多文明、AI 回合保留结构

## 职责边界

### 负责

- 游戏启动流程
- `GameState` 生命周期管理
- 回合计数与回合阶段编排
- 模块间调用顺序定义
- 高层信号广播
- 新游戏与读档后的世界重建入口

### 不负责

- 六边形坐标计算
- 地图数据解析细节
- 城市增长公式
- 科技解锁内容定义
- 存档文件读写细节
- 具体 UI 展示

## 核心数据结构

### `GameState`

用于保存当前运行中的完整游戏状态引用。

建议字段：

```gdscript
class_name GameState

var turn_index: int
var map_state: MapState
var city_states: Array[CityState]
var tech_state: TechState
var player_state: PlayerState
var selected_city_id: String
var selected_tile_key: String
var rule_version: int
```

说明：

- V1 虽然只有一个城市，但 `city_states` 仍使用数组，避免后续重构
- `selected_*` 属于会话态，也可后续拆到 UI 层；首版可暂存在 `GameState`

### `PlayerState`

```gdscript
class_name PlayerState

var civilization_id: String
var gold: int
```

### `TurnContext`

用于回合推进时向各模块传递统一上下文。

```gdscript
class_name TurnContext

var turn_index: int
var game_state: GameState
```

## 主要流程

### 新游戏流程

1. `GameRoot` 启动。
2. `CoreBootstrap` 加载静态数据。
3. `MapService` 读取固定地图并创建 `MapState`。
4. `CityService` 根据预设创建初始城市。
5. `TechService` 创建初始科技状态。
6. `Core` 组装 `GameState`。
7. `UI` 根据 `GameState` 首次渲染。

### 结束回合流程

建议固定顺序如下：

1. 锁定当前玩家输入。
2. `CityService.process_turn()` 计算地块产出、粮食、生产、边界扩张。
3. `TechService.process_turn()` 累加科研并结算科技完成。
4. `Core` 递增 `turn_index`。
5. 广播 `turn_advanced` 信号。
6. `UI` 刷新显示。
7. 解锁玩家输入。

设计决策：

- V1 没有 AI 和战斗，因此回合结算顺序应尽量简单且稳定
- 统一由 `core` 调度，避免 `city` 直接调用 `tech` 或 `ui`

### 读档流程

1. `SaveLoadService` 返回反序列化后的原始数据。
2. `Core` 调用工厂方法重建 `GameState`。
3. `Map`、`City`、`Tech`、`UI` 依次绑定新状态。
4. 广播 `game_loaded` 信号。

## 场景/脚本拆分

建议文件：

```text
game/scenes/main/GameRoot.tscn
game/scripts/core/game_root.gd
game/scripts/core/core_bootstrap.gd
game/scripts/core/game_state.gd
game/scripts/core/player_state.gd
game/scripts/core/turn_context.gd
game/scripts/core/turn_manager.gd
game/scripts/core/game_events.gd
```

建议职责：

- `GameRoot.tscn`
  - 顶层运行时场景
  - 挂载地图层和 UI 层
- `game_root.gd`
  - 连接按钮事件
  - 调用 `TurnManager`
  - 响应新游戏/读档
- `core_bootstrap.gd`
  - 负责数据加载和首局初始化
- `turn_manager.gd`
  - 回合推进入口
  - 只负责顺序编排，不持有复杂业务公式
- `game_events.gd`
  - 建议作为 `autoload`
  - 统一声明跨模块信号

推荐信号：

```gdscript
signal game_started(game_state: GameState)
signal game_loaded(game_state: GameState)
signal turn_advanced(turn_index: int)
signal selected_tile_changed(tile_key: String)
signal selected_city_changed(city_id: String)
```

## 输入输出

### 输入

- UI 发出的 `新游戏`
- UI 发出的 `结束回合`
- UI 发出的 `保存`
- UI 发出的 `读档`
- 地图层发出的选中事件

### 输出

- 更新后的 `GameState`
- 广播式运行时信号
- 提供给 `ui` 的只读状态引用

## 依赖关系

### 依赖

- `data`
- `map`
- `city`
- `tech`
- `save_load`
- `ui`

### 被依赖

- 无，`core` 应作为顶层调度模块

## 风险

- 如果 `core` 直接承载过多业务细节，后续扩展会非常难拆
- 如果没有统一回合顺序，未来加入 AI、单位或多城后容易出现状态不一致
- 如果把 UI 状态和游戏状态混在一起，存档和读档会变复杂

## 子任务 checklist

- [ ] 创建 `GameRoot.tscn`
- [ ] 创建 `game_root.gd`
- [ ] 定义 `GameState`
- [ ] 定义 `PlayerState`
- [ ] 定义 `TurnContext`
- [ ] 实现 `CoreBootstrap`
- [ ] 实现 `TurnManager`
- [ ] 定义并注册 `GameEvents` 信号
- [ ] 实现新游戏初始化流程
- [ ] 实现结束回合流程
- [ ] 实现读档后世界重建流程
- [ ] 为 `core` 补充基础调试日志
