# tech 模块设计

## 目标

`tech` 模块负责科技定义读取、当前研究目标管理、每回合科研推进以及科技完成后的解锁状态维护。

首版目标：

- 支持最小科技树
- 支持 `制陶术`、`采石术`
- 支持固定科研产出推进
- 支持建筑的前置科技校验
- 为未来扩展更完整科技树保留结构

## 职责边界

### 负责

- 科技定义读取
- 当前研究目标记录
- 科研点累积
- 科技完成判定
- 解锁状态维护
- 对外提供“某建筑是否可建”的查询接口

### 不负责

- 科研点来源计算细节
- 建筑具体效果
- UI 面板排版
- 存档文件写入

## 核心数据结构

### `TechDefinition`

```gdscript
class_name TechDefinition

var tech_id: String
var display_name: String
var science_cost: int
var prerequisite_ids: PackedStringArray
var unlock_building_ids: PackedStringArray
```

### `TechProgress`

```gdscript
class_name TechProgress

var tech_id: String
var accumulated_science: int
var is_completed: bool
```

### `TechState`

```gdscript
class_name TechState

var active_tech_id: String
var completed_tech_ids: PackedStringArray
var progress_by_tech_id: Dictionary
```

## 主要流程

### 初始化流程

1. 从 `data` 读取科技定义。
2. 创建空的 `TechState`。
3. 默认设置一个当前研究目标。

设计决策：

- 首版默认研究目标建议为 `pottery`
- 当 `pottery` 完成后，若玩家未手动选择，则自动切换到 `masonry`

### 每回合科研推进流程

1. `city` 模块返回本回合科研贡献。
2. `tech` 将科研值加到当前科技。
3. 检查是否达到 `science_cost`。
4. 若完成，加入 `completed_tech_ids`。
5. 更新可解锁内容。
6. 通知 `ui` 刷新科技面板。

### 可建造校验流程

`city` 在尝试加入生产队列时调用：

- `is_building_unlocked(building_id)`

当前推荐前置关系：

- `纪念碑`
  - 无前置科技
- `粮仓`
  - 需要 `制陶术`

关于 `采石术` 的设计决策：

- 首版保留在科技树中
- 作为“科技系统通路验证项”
- 当前不强制绑定已实现建筑

说明：

- 这样可以先验证多节点科技系统，但也意味着 `采石术` 在 V1 的即时收益偏弱

## 场景/脚本拆分

建议文件：

```text
game/scripts/tech/tech_state.gd
game/scripts/tech/tech_definition.gd
game/scripts/tech/tech_progress.gd
game/scripts/tech/tech_service.gd
game/scripts/tech/tech_query_service.gd
```

建议职责：

- `tech_service.gd`
  - 回合推进
  - 科技完成处理
- `tech_query_service.gd`
  - 对外提供查询接口

## 输入输出

### 输入

- `data` 提供的科技定义
- 来自 `city` 的科研贡献
- 来自 `ui` 的科技切换操作

### 输出

- 更新后的 `TechState`
- 当前科技进度
- 建筑解锁查询结果
- 科技完成事件

## 依赖关系

### 依赖

- `data`

### 被依赖

- `core`
- `city`
- `ui`
- `save_load`

## 风险

- `采石术` 在 V1 没有足够直接收益时，可能让玩家感觉研究结果不明显
- 如果科技定义和建筑前置不数据化，后续扩展成本会很高
- 科技切换规则如果不统一，UI 显示和实际状态容易脱节

## 子任务 checklist

- [ ] 定义 `TechDefinition`
- [ ] 定义 `TechProgress`
- [ ] 定义 `TechState`
- [ ] 实现 `TechService`
- [ ] 实现 `TechQueryService`
- [ ] 接入每回合科研推进
- [ ] 实现科技完成判定
- [ ] 实现建筑前置校验
- [ ] 实现默认研究目标切换
- [ ] 为科技完成添加事件广播
