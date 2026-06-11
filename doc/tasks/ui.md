# ui 模块设计

## 目标

`ui` 模块负责展示当前回合、城市信息、科技进度、地块信息，以及向 `core` 发出玩家操作请求。

首版目标：

- 显示启动主菜单
- 显示新游戏地图选择界面
- 支持最终地貌预览
- 显示基础 HUD
- 显示结束回合按钮
- 暂不显示城市信息面板
- 暂不显示科技进度面板
- 显示地块信息面板
- 支持保存/读档入口
- 支持地图参数保存/读取入口
- 支持地图纹理/调试符号显示切换入口

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

1. `Main.tscn` 挂载 `core_root.gd`，作为当前临时上层调度节点。
2. `MapRoot` 和 `UIRoot` 作为同级节点存在。
3. `UIRoot` 先显示启动主菜单，HUD 和地块信息面板隐藏。
4. 玩家进入地图选择界面后，可调整 `seed`、地图尺寸、小地图边长、海洋比例、山脉数量、河流源数量和大陆倾向。
5. 玩家主动点击“生成预览”后，地图选择界面生成最终地貌预览，并自动标出建议起始地块。
6. 玩家点击“开始本局”后，`CoreRoot` 调用 `MapRoot.start_new_game(config)`。
7. `CoreRoot` 从 `MapRoot` 读取起始地块，并调用 `UIRoot.show_tile(tile)` 初始化 HUD。

### 结束回合流程

1. 玩家点击 `结束回合`。
2. 首版按钮禁用，悬停提示“暂未实现”。
3. 后续实现 core 回合逻辑后，由 `ui` 发出请求给 `core`。
4. 在结算期间暂时禁用按钮。
5. 回合推进完成后刷新所有面板。

### 地块信息刷新流程

1. 玩家点击地图地块。
2. `MapRoot` 发出 `tile_selected(tile)`。
3. `CoreRoot` 接收信号。
4. `CoreRoot` 调用 `UIRoot.show_tile(tile)`。
5. `UIRoot` 刷新 HUD 中的当前坐标和地块信息面板。

### 城市信息刷新流程

1. 新游戏或读档时默认选中起始城市。
2. `city` 状态发生变化后触发刷新。
3. UI 读取当前 `CityState` 并组装 `CityPanelViewData`。

## 场景/脚本拆分

建议文件：

```text
game/scenes/ui/UIRoot.tscn
game/scenes/ui/HudBar.tscn
game/scenes/ui/TileInfoPanel.tscn
game/scripts/ui/ui_root.gd
game/scripts/ui/hud_bar.gd
game/scripts/ui/tile_info_panel.gd
game/scripts/core/core_root.gd
```

建议职责：

- `UIRoot.tscn`
  - 所有首版 UI 场景的容器
- `ui_root.gd`
  - 显示启动主菜单和地图选择界面，对外暴露 `show_tile(tile)`，转发 HUD 按钮信号
- `HudBar.tscn`
  - 顶部横贯全屏 HUD，显示回合、金币、当前选中坐标、保存/读档/结束回合入口和 `Texture / Symbol` 按钮
- `TileInfoPanel.tscn`
  - 左下角中等尺寸地块信息卡片
- `core_root.gd`
  - 当前临时上层调度脚本，负责连接 `MapRoot` 与 `UIRoot`

### 推荐布局

- 顶部横条：回合数、金币、当前选中坐标、`Texture / Symbol`、保存、读档、结束回合
- 左下角浮动卡片：当前地块信息
- 城市信息、科技进度、保存/读档面板暂不显示，后续对应模块开始实现后再接入

设计决策：

- 首版不追求复杂 UI 动画
- 优先保证信息读得清楚、交互链路顺畅
- `map` 和 `ui` 不直接互相依赖，由上层 `core_root.gd` 负责调度通信

## 输入输出

### 输入

- `MapState`
- `TileState`
- 来自 `MapRoot` 的 `tile_selected(tile)` 信号
- 来自 `CoreRoot` 的初始化调用

### 输出

- `结束回合` 请求，当前按钮禁用
- `保存` 请求，当前按钮禁用
- `读档` 请求，当前按钮禁用
- `Texture / Symbol` 调试符号切换请求
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
- 如果 `map` 和 `ui` 直接互相引用，后续 core 状态管理会难以收敛

## 子任务 checklist

- [x] 创建 `UIRoot.tscn`
- [x] 创建 `HudBar.tscn`
- [x] 实现启动主菜单
- [x] 实现新游戏地图参数选择界面
- [x] 实现最终地貌预览
- [ ] 创建 `CityPanel.tscn`
- [ ] 创建 `TechPanel.tscn`
- [x] 创建 `TileInfoPanel.tscn`
- [ ] 创建 `SaveLoadPanel.tscn`
- [x] 实现 `ui_root.gd`
- [ ] 实现 `ui_presenter.gd`
- [x] 实现 HUD 中禁用的结束回合入口
- [ ] 实现城市信息渲染
- [ ] 实现科技信息渲染
- [x] 实现地块信息渲染
- [x] 实现 HUD 中禁用的保存/读档入口
- [x] 实现地图参数保存/读取入口
- [ ] 在回合结算时禁用交互按钮
- [x] 实现 `Texture / Symbol` 地图调试符号切换入口
- [x] 实现 `CoreRoot` 调度 `MapRoot` 与 `UIRoot`
