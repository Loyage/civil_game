# ui 模块设计

## 目标

`ui` 模块负责展示当前回合、城市信息、科技进度、地块信息，以及向 `core` 发出玩家操作请求。

首版目标：

- 显示基础 HUD
- 显示结束回合按钮
- 显示城市信息面板
- 显示科技进度面板
- 显示地块信息面板
- 支持保存/读档入口

## 职责边界

### 负责

- 界面布局
- 用户输入入口
- 只读状态展示
- 与 `core` 的交互事件发送

### 不负责

- 业务规则结算
- 地图文件解析
- 科技或城市公式
- 存档数据序列化

## 核心数据结构

UI 层尽量少定义业务模型，主要消费运行时状态。

建议定义轻量视图模型：

### `CityPanelViewData`

```gdscript
class_name CityPanelViewData

var city_name: String
var population: int
var food_progress_text: String
var production_name: String
var production_progress_text: String
var owned_tile_count: int
```

### `TileInfoViewData`

```gdscript
class_name TileInfoViewData

var terrain_name: String
var yields_text: String
var owner_city_name: String
var flags_text: String
```

### `TechPanelViewData`

```gdscript
class_name TechPanelViewData

var active_tech_name: String
var progress_text: String
var completed_names: PackedStringArray
```

## 主要流程

### HUD 初始化流程

1. `GameRoot` 创建 UI 根节点。
2. `UIRoot` 订阅 `GameEvents`。
3. 首次读取 `GameState` 并刷新所有面板。

### 结束回合流程

1. 玩家点击 `结束回合`。
2. `ui` 发出请求给 `core`。
3. 在结算期间暂时禁用按钮。
4. 回合推进完成后刷新所有面板。

### 地块信息刷新流程

1. 玩家点击地图地块。
2. `map` 发出 `selected_tile_changed`。
3. `ui` 读取对应 `TileState`。
4. 刷新地块信息面板。

### 城市信息刷新流程

1. 新游戏或读档时默认选中起始城市。
2. `city` 状态发生变化后触发刷新。
3. UI 读取当前 `CityState` 并组装 `CityPanelViewData`。

## 场景/脚本拆分

建议文件：

```text
game/scenes/ui/UIRoot.tscn
game/scenes/ui/HudBar.tscn
game/scenes/ui/CityPanel.tscn
game/scenes/ui/TechPanel.tscn
game/scenes/ui/TileInfoPanel.tscn
game/scenes/ui/SaveLoadPanel.tscn
game/scripts/ui/ui_root.gd
game/scripts/ui/hud_bar.gd
game/scripts/ui/city_panel.gd
game/scripts/ui/tech_panel.gd
game/scripts/ui/tile_info_panel.gd
game/scripts/ui/save_load_panel.gd
game/scripts/ui/ui_presenter.gd
```

建议职责：

- `UIRoot.tscn`
  - 所有 UI 场景的容器
- `ui_root.gd`
  - 订阅信号并协调刷新
- `ui_presenter.gd`
  - 将业务状态转换为视图数据
- 各 Panel 脚本
  - 仅负责绑定控件和渲染文本

### 推荐布局

- 顶部：回合数、金币、结束回合按钮
- 左侧：城市信息
- 右侧：科技进度
- 底部：地块信息

设计决策：

- 首版不追求复杂 UI 动画
- 优先保证信息读得清楚、交互链路顺畅

## 输入输出

### 输入

- `GameState`
- `MapState`
- `CityState`
- `TechState`
- 来自 `GameEvents` 的状态变化信号

### 输出

- `结束回合` 请求
- `保存` 请求
- `读档` 请求
- 未来可扩展的科技切换请求

## 依赖关系

### 依赖

- `core`
- `map`
- `city`
- `tech`

### 被依赖

- 无，UI 为展示层

## 风险

- 如果 UI 直接依赖底层实现细节，后续状态结构改动会带来大面积修改
- 如果没有单独的 presenter 层，面板脚本很快会混入业务逻辑
- 首版虽然功能少，但面板过多时仍可能造成状态同步混乱

## 子任务 checklist

- [ ] 创建 `UIRoot.tscn`
- [ ] 创建 `HudBar.tscn`
- [ ] 创建 `CityPanel.tscn`
- [ ] 创建 `TechPanel.tscn`
- [ ] 创建 `TileInfoPanel.tscn`
- [ ] 创建 `SaveLoadPanel.tscn`
- [ ] 实现 `ui_root.gd`
- [ ] 实现 `ui_presenter.gd`
- [ ] 实现结束回合按钮联动
- [ ] 实现城市信息渲染
- [ ] 实现科技信息渲染
- [ ] 实现地块信息渲染
- [ ] 实现保存/读档入口
- [ ] 在回合结算时禁用交互按钮
